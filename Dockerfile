# OpenClaw-Ready Docker Image
# A prepared Docker image ready for OpenClaw deployment
#
# Features:
# - Node.js 22 (Debian Bookworm)
# - CLI tools: gog (Gmail), goplaces (Google Places), wacli (WhatsApp)
# - Playwright browser automation with Chromium (optional)
# - Development tools: git, curl, jq, ffmpeg, build-essential
#
# Usage:
#   This image is prepared with all dependencies for running OpenClaw.
#   When OpenClaw is released, it can be installed via npm.

FROM node:22-bookworm

# Build arguments for customization
ARG EXTRA_APT_PACKAGES=""
ARG INSTALL_PLAYWRIGHT_BROWSERS="true"

# Set environment variables
ENV HOME=/home/node \
    NODE_ENV=production \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
    XDG_CONFIG_HOME=/home/node/.config \
    PATH="/home/node/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Essential tools
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    jq \
    socat \
    # Build tools
    build-essential \
    python3 \
    python3-pip \
    # Media processing
    ffmpeg \
    # Playwright dependencies
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    libatspi2.0-0 \
    # Xvfb for headful browser
    xvfb \
    xauth \
    x11-utils \
    # Fonts
    fonts-liberation \
    fonts-noto-color-emoji \
    # Extra packages from build arg
    ${EXTRA_APT_PACKAGES} \
    && rm -rf /var/lib/apt/lists/*

# Install Bun (for local scripts)
RUN curl -fsSL https://bun.sh/install | bash

# Install CLI binaries (with fallback if not available)
# 1. Gmail CLI (gog)
RUN curl -L https://github.com/steipete/gog/releases/latest/download/gog_Linux_x86_64.tar.gz 2>/dev/null \
    | tar -xz -C /usr/local/bin 2>/dev/null && chmod +x /usr/local/bin/gog 2>/dev/null || echo "gog CLI not available"

# 2. Google Places CLI (goplaces)
RUN curl -L https://github.com/steipete/goplaces/releases/latest/download/goplaces_Linux_x86_64.tar.gz 2>/dev/null \
    | tar -xz -C /usr/local/bin 2>/dev/null && chmod +x /usr/local/bin/goplaces 2>/dev/null || echo "goplaces CLI not available"

# 3. WhatsApp CLI (wacli)
RUN curl -L https://github.com/steipete/wacli/releases/latest/download/wacli_Linux_x86_64.tar.gz 2>/dev/null \
    | tar -xz -C /usr/local/bin 2>/dev/null && chmod +x /usr/local/bin/wacli 2>/dev/null || echo "wacli CLI not available"

# Set up working directory
WORKDIR /app

# Install Playwright browsers (optional, controlled by build arg)
RUN if [ "$INSTALL_PLAYWRIGHT_BROWSERS" = "true" ]; then \
    npx playwright install chromium --with-deps 2>/dev/null || echo "Playwright install skipped"; \
    fi

# Create node user directories for persistent data
RUN mkdir -p /home/node/.openclaw \
    /home/node/.openclaw/workspace \
    /home/node/.openclaw/skills \
    /home/node/.cache/ms-playwright \
    /home/node/.config \
    && chown -R node:node /home/node

# Copy configuration files
COPY config/openclaw.json /home/node/.openclaw/config.json

# Create a simple health check server and entrypoint script
RUN echo '#!/bin/bash\n\
    echo "OpenClaw-Ready Docker Container"\n\
    echo "================================"\n\
    echo "This container is prepared with all dependencies for OpenClaw."\n\
    echo ""\n\
    echo "Installed tools:"\n\
    echo "  - Node.js: $(node --version)"\n\
    echo "  - npm: $(npm --version)"\n\
    echo "  - Git: $(git --version | cut -d\" \" -f3)"\n\
    echo "  - FFmpeg: $(ffmpeg -version 2>&1 | head -1 | cut -d\" \" -f3)"\n\
    which gog >/dev/null 2>&1 && echo "  - gog: available" || echo "  - gog: not installed"\n\
    which goplaces >/dev/null 2>&1 && echo "  - goplaces: available" || echo "  - goplaces: not installed"\n\
    which wacli >/dev/null 2>&1 && echo "  - wacli: available" || echo "  - wacli: not installed"\n\
    echo ""\n\
    echo "To install OpenClaw when available:"\n\
    echo "  npm install -g openclaw@latest"\n\
    echo ""\n\
    echo "Starting health endpoint on port 18789..."\n\
    while true; do\n\
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"ready\",\"message\":\"OpenClaw-ready container\"}" | nc -l -p 18789 -q 1 2>/dev/null || sleep 1\n\
    done\n' > /app/entrypoint.sh && chmod +x /app/entrypoint.sh

# Install netcat for health endpoint
RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*

# Switch to non-root user for runtime
USER node

# Expose gateway port
EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:18789/ || exit 1

# Default command - start the container
CMD ["/app/entrypoint.sh"]
