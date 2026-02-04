#!/bin/bash
# Build all sandbox images
# Usage: ./scripts/build-sandboxes.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "Building OpenClaw sandbox images..."

# Build standard sandbox
echo ""
echo "Building openclaw-sandbox:bookworm-slim..."
docker build -t openclaw-sandbox:bookworm-slim -f Dockerfile.sandbox .

# Build browser sandbox
echo ""
echo "Building openclaw-sandbox-browser:bookworm-slim..."
docker build -t openclaw-sandbox-browser:bookworm-slim -f Dockerfile.sandbox-browser .

# Optionally build common sandbox (includes more tools)
if [ "$1" == "--with-common" ]; then
    echo ""
    echo "Building openclaw-sandbox-common:bookworm-slim..."
    # This would use a more feature-rich Dockerfile
    docker build -t openclaw-sandbox-common:bookworm-slim -f Dockerfile.sandbox \
        --build-arg INSTALL_EXTRAS=true .
fi

echo ""
echo "✓ All sandbox images built successfully"
echo ""
echo "Available images:"
docker images | grep openclaw-sandbox
