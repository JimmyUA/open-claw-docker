#!/bin/bash
# Quick health check script for OpenClaw Gateway
# Usage: ./scripts/health-check.sh

set -e

# Load environment
if [ -f .env ]; then
    source .env
fi

echo "Checking OpenClaw Gateway health..."

# Check if container is running
if ! docker compose ps openclaw-gateway | grep -q "Up"; then
    echo "❌ Gateway container is not running"
    echo "   Run: docker compose up -d openclaw-gateway"
    exit 1
fi

echo "✓ Container is running"

# Check health endpoint
if docker compose exec openclaw-gateway node dist/index.js health --token "${OPENCLAW_GATEWAY_TOKEN}" 2>/dev/null; then
    echo "✓ Gateway health check passed"
else
    echo "⚠ Gateway health check failed"
    echo "   Check logs: docker compose logs openclaw-gateway"
fi

# Check CLI binaries
echo ""
echo "Checking CLI binaries..."
for binary in gog goplaces wacli; do
    if docker compose exec openclaw-gateway which $binary &>/dev/null; then
        echo "✓ $binary found"
    else
        echo "❌ $binary not found"
    fi
done

# Show resource usage
echo ""
echo "Container resource usage:"
docker stats openclaw-gateway --no-stream --format "  CPU: {{.CPUPerc}}, Memory: {{.MemUsage}}"

echo ""
echo "Gateway URL: http://127.0.0.1:${OPENCLAW_GATEWAY_PORT:-18789}/"
