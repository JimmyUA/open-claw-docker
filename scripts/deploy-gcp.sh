#!/bin/bash
# OpenClaw GCP Deployment Script
# Automates deployment to Google Cloud Platform Compute Engine
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - GCP project with billing enabled
#
# Usage:
#   chmod +x scripts/deploy-gcp.sh
#   ./scripts/deploy-gcp.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              OpenClaw GCP Deployment Script                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Load configuration from .env if exists
if [ -f .env ]; then
    source .env
fi

# Configuration with defaults
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
ZONE="${GCP_ZONE:-us-central1-a}"
INSTANCE_NAME="${GCP_INSTANCE_NAME:-openclaw-gateway}"
MACHINE_TYPE="${GCP_MACHINE_TYPE:-e2-medium}"
DISK_SIZE="${GCP_DISK_SIZE:-30}"

# Check for gcloud
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed.${NC}"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${YELLOW}Not authenticated with gcloud. Running auth...${NC}"
    gcloud auth login
fi

# Get or set project
if [ -z "$PROJECT_ID" ]; then
    echo -e "${YELLOW}GCP_PROJECT_ID not set. Available projects:${NC}"
    gcloud projects list --format="table(projectId,name)"
    echo ""
    read -p "Enter project ID: " PROJECT_ID
fi

echo -e "${BLUE}Using project: ${PROJECT_ID}${NC}"
gcloud config set project "$PROJECT_ID"

# Enable required APIs
echo -e "${YELLOW}Enabling Compute Engine API...${NC}"
gcloud services enable compute.googleapis.com

# Check if instance exists
if gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" &> /dev/null; then
    echo -e "${YELLOW}Instance '$INSTANCE_NAME' already exists.${NC}"
    read -p "Delete and recreate? (y/N): " RECREATE
    if [[ "$RECREATE" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting existing instance...${NC}"
        gcloud compute instances delete "$INSTANCE_NAME" --zone="$ZONE" --quiet
    else
        echo -e "${BLUE}Connecting to existing instance...${NC}"
        gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE"
        exit 0
    fi
fi

# Create the VM
echo -e "${YELLOW}Creating Compute Engine VM...${NC}"
echo "  Instance: $INSTANCE_NAME"
echo "  Zone: $ZONE"
echo "  Machine type: $MACHINE_TYPE"
echo "  Disk size: ${DISK_SIZE}GB"

gcloud compute instances create "$INSTANCE_NAME" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --boot-disk-size="${DISK_SIZE}GB" \
    --boot-disk-type=pd-balanced \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --tags=openclaw-gateway \
    --metadata=startup-script='#!/bin/bash
# Install Docker
apt-get update
apt-get install -y git curl ca-certificates
curl -fsSL https://get.docker.com | sh
usermod -aG docker $(logname || echo $SUDO_USER)

# Create directories
mkdir -p /home/$(logname || echo $SUDO_USER)/.openclaw
mkdir -p /home/$(logname || echo $SUDO_USER)/.openclaw/workspace
chown -R 1000:1000 /home/$(logname || echo $SUDO_USER)/.openclaw
'

echo -e "${GREEN}✓ VM created successfully${NC}"

# Wait for VM to be ready
echo -e "${YELLOW}Waiting for VM to be ready...${NC}"
sleep 30

# SSH and complete setup
echo -e "${YELLOW}Connecting to VM to complete setup...${NC}"
gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" -- 'bash -s' << 'REMOTE_SCRIPT'
set -e

echo "Waiting for Docker installation..."
while ! command -v docker &> /dev/null; do
    sleep 5
done

# Add current user to docker group if needed
if ! groups | grep -q docker; then
    sudo usermod -aG docker $USER
    echo "Added $USER to docker group. Please reconnect."
fi

# Clone OpenClaw
if [ ! -d "$HOME/openclaw" ]; then
    git clone https://github.com/openclaw/openclaw.git "$HOME/openclaw"
fi

cd "$HOME/openclaw"

# Create directories
mkdir -p ~/.openclaw
mkdir -p ~/.openclaw/workspace

echo ""
echo "=========================================="
echo "  Next steps (run these commands):"
echo "=========================================="
echo ""
echo "cd ~/openclaw"
echo ""
echo "# Copy and edit environment file"
echo "cp .env.example .env"
echo "nano .env  # Add your API keys"
echo ""
echo "# Build and start"
echo "docker compose build"
echo "docker compose up -d openclaw-gateway"
echo ""
echo "# View logs"
echo "docker compose logs -f openclaw-gateway"
echo ""
REMOTE_SCRIPT

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                 GCP Deployment Complete!                        ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "To SSH into your VM:"
echo -e "  ${BLUE}gcloud compute ssh $INSTANCE_NAME --zone=$ZONE${NC}"
echo ""
echo -e "To access the Control UI via SSH tunnel:"
echo -e "  ${BLUE}gcloud compute ssh $INSTANCE_NAME --zone=$ZONE -- -L 18789:127.0.0.1:18789${NC}"
echo -e "  Then open: ${BLUE}http://127.0.0.1:18789/${NC}"
echo ""
echo -e "To check VM status:"
echo -e "  ${BLUE}gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE${NC}"
echo ""
echo -e "To stop the VM (save costs):"
echo -e "  ${BLUE}gcloud compute instances stop $INSTANCE_NAME --zone=$ZONE${NC}"
echo ""
echo -e "To delete the VM:"
echo -e "  ${BLUE}gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE${NC}"
echo ""
