# 🦞 OpenClaw Docker Deployment for GCP

A full-featured Docker setup for hosting [OpenClaw](https://github.com/openclaw/openclaw) AI assistant on Google Cloud Platform.

## Features

- ✅ **Full Gateway** - Complete OpenClaw gateway with all tools enabled
- ✅ **Browser Automation** - Playwright with Chromium (headful via Xvfb)
- ✅ **Agent Sandboxing** - Secure code execution in isolated containers
- ✅ **Multi-Channel Support** - WhatsApp, Telegram, Discord, Slack, Signal, Gmail
- ✅ **CLI Tools** - gog (Gmail), goplaces (Maps), wacli (WhatsApp)
- ✅ **Persistent Storage** - Configuration and workspaces survive restarts
- ✅ **Health Checks** - Automatic restart on failure
- ✅ **GCP Optimized** - Scripts for Compute Engine deployment

## Quick Start

### Option 1: Local Development

```bash
# 1. Clone this repository
git clone <this-repo>
cd stellar-cassini

# 2. Run setup script
chmod +x scripts/setup.sh
./scripts/setup.sh

# 3. Start the gateway
docker compose up -d openclaw-gateway

# 4. Access Control UI
open http://127.0.0.1:18789/
```

### Option 2: Deploy to GCP

```bash
# 1. Install gcloud CLI
# https://cloud.google.com/sdk/docs/install

# 2. Authenticate
gcloud auth login

# 3. Run deployment script
chmod +x scripts/deploy-gcp.sh
./scripts/deploy-gcp.sh

# 4. SSH with tunnel and access UI
gcloud compute ssh openclaw-gateway --zone=us-central1-a -- -L 18789:127.0.0.1:18789
# Then open: http://127.0.0.1:18789/
```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

**Required settings:**
- `OPENCLAW_GATEWAY_TOKEN` - Secure token for gateway access
- `GOG_KEYRING_PASSWORD` - Password for encrypted credentials

**Optional API keys:**
- `OPENAI_API_KEY` - For GPT models
- `ANTHROPIC_API_KEY` - For Claude models
- `GOOGLE_API_KEY` - For Gemini models

### Gateway Configuration

The `config/openclaw.json` file configures:
- Agent definitions and models
- Sandbox settings and policies
- Channel integrations
- Tool permissions

## Project Structure

```
stellar-cassini/
├── Dockerfile                    # Main gateway image
├── Dockerfile.sandbox            # Agent sandbox image
├── Dockerfile.sandbox-browser    # Browser sandbox image
├── docker-compose.yml            # Service definitions
├── .env.example                  # Environment template
├── config/
│   └── openclaw.json            # Gateway configuration
├── scripts/
│   ├── setup.sh                 # Local setup script
│   └── deploy-gcp.sh            # GCP deployment script
└── README.md                    # This file
```

## Usage

### Managing the Gateway

```bash
# Start gateway
docker compose up -d openclaw-gateway

# View logs
docker compose logs -f openclaw-gateway

# Stop gateway
docker compose down

# Rebuild after changes
docker compose build --no-cache
docker compose up -d
```

### CLI Commands

```bash
# Run onboarding wizard
docker compose run --rm openclaw-cli onboard

# Get dashboard token
docker compose run --rm openclaw-cli dashboard --no-open

# List connected devices
docker compose run --rm openclaw-cli devices list

# Approve device pairing
docker compose run --rm openclaw-cli devices approve <requestId>

# Channel login
docker compose run --rm openclaw-cli channels login

# Add Telegram
docker compose run --rm openclaw-cli channels add --channel telegram --token "<bot_token>"

# Add Discord
docker compose run --rm openclaw-cli channels add --channel discord --token "<bot_token>"

# Health check
docker compose exec openclaw-gateway node dist/index.js health --token "$OPENCLAW_GATEWAY_TOKEN"
```

### Building Sandbox Images

```bash
# Build agent sandbox
docker build -t openclaw-sandbox:bookworm-slim -f Dockerfile.sandbox .

# Build browser sandbox
docker build -t openclaw-sandbox-browser:bookworm-slim -f Dockerfile.sandbox-browser .
```

## Channel Setup

### Telegram
1. Create a bot via [@BotFather](https://t.me/BotFather)
2. Get the bot token
3. Add to OpenClaw:
   ```bash
   docker compose run --rm openclaw-cli channels add --channel telegram --token "<token>"
   ```

### Discord
1. Create application at [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a bot and get the token
3. Enable required intents (Message Content, etc.)
4. Add to OpenClaw:
   ```bash
   docker compose run --rm openclaw-cli channels add --channel discord --token "<token>"
   ```

### WhatsApp
1. Run channel login:
   ```bash
   docker compose run --rm openclaw-cli channels login
   ```
2. Scan QR code with WhatsApp mobile app

### Gmail
1. The `gog` CLI handles Gmail OAuth
2. Run:
   ```bash
   docker compose exec openclaw-gateway gog auth
   ```

## GCP Cost Optimization

### Machine Types
- `e2-micro` (1 vCPU, 1GB) - Free tier eligible, basic usage
- `e2-small` (2 vCPU, 2GB) - Light usage
- `e2-medium` (2 vCPU, 4GB) - **Recommended** for full features
- `e2-standard-2` (2 vCPU, 8GB) - Heavy browser automation

### Stop When Not in Use
```bash
# Stop VM
gcloud compute instances stop openclaw-gateway --zone=us-central1-a

# Start VM
gcloud compute instances start openclaw-gateway --zone=us-central1-a
```

### Preemptible VMs (up to 80% cheaper)
Add `--preemptible` flag when creating the VM for non-critical workloads.

## Troubleshooting

### Permission Errors
```bash
# Fix ownership on host directories
sudo chown -R 1000:1000 ~/.openclaw
```

### Container Not Starting
```bash
# Check logs
docker compose logs openclaw-gateway

# Check health
docker compose ps
```

### Binary Not Found
```bash
# Verify binaries are installed
docker compose exec openclaw-gateway which gog goplaces wacli
```

### Browser Issues
```bash
# Reinstall Playwright browsers
docker compose run --rm openclaw-cli \
  node /app/node_modules/playwright-core/cli.js install chromium --with-deps
```

### SSH Tunnel Issues
```bash
# Check if port is in use
lsof -i :18789

# Use different local port
gcloud compute ssh openclaw-gateway --zone=us-central1-a -- -L 8080:127.0.0.1:18789
# Then access: http://127.0.0.1:8080/
```

## Security Notes

⚠️ **Important Security Considerations:**

1. **Never expose port 18789 publicly** - Always use SSH tunnels
2. **Generate secure tokens** - Use `openssl rand -hex 32`
3. **DM Policy** - Default is "pairing" which requires approval for new contacts
4. **Sandbox isolation** - Agent code runs in isolated containers with no network
5. **Read the security docs** - [OpenClaw Security](https://docs.openclaw.ai/gateway/security)

## Links

- [OpenClaw Documentation](https://docs.openclaw.ai)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [Docker Installation](https://docs.openclaw.ai/install/docker)
- [GCP Deployment Guide](https://docs.openclaw.ai/platforms/gcp)
- [Channel Setup](https://docs.openclaw.ai/channels)

## License

This deployment configuration is provided as-is. OpenClaw is licensed under its own terms.
