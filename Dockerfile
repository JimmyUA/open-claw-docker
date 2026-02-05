# OpenClaw Full-Featured Docker Image
# Extends the official OpenClaw image with additional tools and CLI utilities
#
# Features:
# - Official OpenClaw gateway (via npm package)
# - CLI tools: gog (Gmail), goplaces (Google Places), wacli (WhatsApp)
# - Playwright browser automation with Chromium
# - Development tools: git, curl, jq, ffmpeg, build-essential

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

# Install CLI binaries
# 1. Gmail CLI (gog)
RUN curl -L https://github.com/steipete/gog/releases/latest/download/gog_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/gog || echo "gog not available"

# 2. Google Places CLI (goplaces)
RUN curl -L https://github.com/steipete/goplaces/releases/latest/download/goplaces_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/goplaces || echo "goplaces not available"

# 3. WhatsApp CLI (wacli)
RUN curl -L https://github.com/steipete/wacli/releases/latest/download/wacli_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/wacli || echo "wacli not available"

# Set up working directory
WORKDIR /app

# Install OpenClaw via npm (using the public package)
RUN npm install -g openclaw@latest || npm install -g @anthropic-ai/claude-code@latest

# Install Playwright browsers (optional, controlled by build arg)
RUN if [ "$INSTALL_PLAYWRIGHT_BROWSERS" = "true" ]; then \
    npx playwright install chromium --with-deps || echo "Playwright install skipped"; \
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

# Switch to non-root user for runtime
USER node

# Expose gateway port
EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:18789/health || exit 1

# Default command - start OpenClaw gateway
CMD ["openclaw", "gateway", "--allow-unconfigured"]
