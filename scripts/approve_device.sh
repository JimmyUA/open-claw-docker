#!/bin/bash
set -e
cd /opt/openclaw
echo "Listing devices..."
# Capture the JSON output
JSON=$(sudo docker compose exec openclaw-gateway node dist/index.js devices list --json)
echo "Devices JSON: $JSON"

# Extract requestId using sed (fallback if jq missing)
ID=$(echo "$JSON" | sed -n 's/.*"requestId": "\([^"]*\)".*/\1/p' | head -n 1)

if [ -n "$ID" ]; then
  echo "Found pending Request ID: $ID"
  echo "Approving..."
  sudo docker compose exec openclaw-gateway node dist/index.js devices approve "$ID"
  echo "Done!"
else
  echo "No pending requests found."
fi
