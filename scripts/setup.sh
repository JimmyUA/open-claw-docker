#!/bin/bash
# OpenClaw Setup Script
# Initializes the environment and builds Docker images
#
# Usage:
#   chmod +x scripts/setup.sh
#   ./scripts/setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   OpenClaw Docker Setup                       ║"
echo "║              Full-Featured GCP Deployment                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check for Docker
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed.${NC}"
    echo "Install Docker: https://get.docker.com"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose found${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file from template...${NC}"
    cp .env.example .env
    
    # Generate secure tokens
    GATEWAY_TOKEN=$(openssl rand -hex 32)
    KEYRING_PASSWORD=$(openssl rand -hex 32)
    
    # Update tokens in .env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/OPENCLAW_GATEWAY_TOKEN=change-me-to-a-secure-random-token/OPENCLAW_GATEWAY_TOKEN=$GATEWAY_TOKEN/" .env
        sed -i '' "s/GOG_KEYRING_PASSWORD=change-me-to-a-secure-random-password/GOG_KEYRING_PASSWORD=$KEYRING_PASSWORD/" .env
    else
        # Linux
        sed -i "s/OPENCLAW_GATEWAY_TOKEN=change-me-to-a-secure-random-token/OPENCLAW_GATEWAY_TOKEN=$GATEWAY_TOKEN/" .env
        sed -i "s/GOG_KEYRING_PASSWORD=change-me-to-a-secure-random-password/GOG_KEYRING_PASSWORD=$KEYRING_PASSWORD/" .env
    fi
    
    echo -e "${GREEN}✓ Generated secure tokens${NC}"
    echo -e "${YELLOW}Note: Edit .env to add your API keys and configure options${NC}"
else
    echo -e "${GREEN}✓ .env file exists${NC}"
fi

# Create persistent directories
echo -e "${YELLOW}Creating persistent directories...${NC}"
mkdir -p ~/.openclaw
mkdir -p ~/.openclaw/workspace
mkdir -p ~/.openclaw/skills

# Set permissions (for container user uid 1000)
if [[ "$OSTYPE" != "darwin"* ]]; then
    # Linux only - macOS doesn't need this
    sudo chown -R 1000:1000 ~/.openclaw 2>/dev/null || true
fi

echo -e "${GREEN}✓ Created ~/.openclaw directories${NC}"

# Clone OpenClaw repository if needed
if [ ! -f package.json ]; then
    echo -e "${YELLOW}Cloning OpenClaw repository...${NC}"
    git clone https://github.com/openclaw/openclaw.git temp_openclaw
    mv temp_openclaw/* temp_openclaw/.* . 2>/dev/null || true
    rm -rf temp_openclaw
    echo -e "${GREEN}✓ Cloned OpenClaw repository${NC}"
fi

# Build Docker images
echo -e "${YELLOW}Building Docker images (this may take a while)...${NC}"
echo ""

echo -e "${BLUE}Building main gateway image...${NC}"
docker compose build openclaw-gateway

echo -e "${BLUE}Building sandbox image...${NC}"
docker build -t openclaw-sandbox:bookworm-slim -f Dockerfile.sandbox .

echo -e "${BLUE}Building browser sandbox image...${NC}"
docker build -t openclaw-sandbox-browser:bookworm-slim -f Dockerfile.sandbox-browser .

echo -e "${GREEN}✓ All images built successfully${NC}"

# Run onboarding
echo ""
echo -e "${YELLOW}Running OpenClaw onboarding wizard...${NC}"
docker compose run --rm openclaw-cli onboard

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    Setup Complete!                              ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "To start the gateway:"
echo -e "  ${BLUE}docker compose up -d openclaw-gateway${NC}"
echo ""
echo -e "To view logs:"
echo -e "  ${BLUE}docker compose logs -f openclaw-gateway${NC}"
echo ""
echo -e "To access the Control UI:"
echo -e "  ${BLUE}http://127.0.0.1:18789/${NC}"
echo ""
echo -e "To get the dashboard token:"
echo -e "  ${BLUE}docker compose run --rm openclaw-cli dashboard --no-open${NC}"
echo ""
echo -e "To set up channels:"
echo -e "  ${BLUE}docker compose run --rm openclaw-cli channels login${NC}"
echo ""
