# OpenClaw Full-Featured Docker Image
# Optimized for GCP Compute Engine deployment with maximum functionality
#
# Features:
# - Node.js 22 (Debian Bookworm)
# - Bun for build scripts
# - Playwright browser automation with Chromium
# - CLI tools: gog (Gmail), goplaces (Google Places), wacli (WhatsApp)
# - Development tools: git, curl, jq, ffmpeg, build-essential
# - Homebrew support for additional packages

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
    PATH="/home/linuxbrew/.linuxbrew/bin:/home/node/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

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

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash

# Install CLI binaries
# 1. Gmail CLI (gog)
RUN curl -L https://github.com/steipete/gog/releases/latest/download/gog_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/gog

# 2. Google Places CLI (goplaces)
RUN curl -L https://github.com/steipete/goplaces/releases/latest/download/goplaces_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/goplaces

# 3. WhatsApp CLI (wacli)
RUN curl -L https://github.com/steipete/wacli/releases/latest/download/wacli_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/wacli

# Enable corepack for pnpm
RUN corepack enable

# Set up working directory
WORKDIR /app

# Copy package files first for better layer caching
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY scripts ./scripts

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build the application
RUN pnpm build

# Install and build UI
RUN pnpm ui:install
RUN pnpm ui:build

# Install Playwright browsers (optional, controlled by build arg)
RUN if [ "$INSTALL_PLAYWRIGHT_BROWSERS" = "true" ]; then \
    node /app/node_modules/playwright-core/cli.js install chromium --with-deps; \
    fi

# Create node user directories
RUN mkdir -p /home/node/.openclaw \
    /home/node/.openclaw/workspace \
    /home/node/.openclaw/skills \
    /home/node/.cache/ms-playwright \
    && chown -R node:node /home/node

# Switch to non-root user for runtime
USER node

# Expose gateway port
EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD node dist/index.js health --token "${OPENCLAW_GATEWAY_TOKEN}" || exit 1

# Default command - start gateway with allow-unconfigured flag
CMD ["node", "dist/index.js", "gateway", "--allow-unconfigured"]
