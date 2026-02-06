# OpenClaw GCP Deployment

Deploys [OpenClaw](https://github.com/openclaw/openclaw) to Google Cloud Platform using the official [alpine/openclaw](https://hub.docker.com/r/alpine/openclaw) Docker image.

## Quick Start

### Local Development
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your settings
# Then start the gateway
docker compose up -d openclaw-gateway
```

### GCP Deployment

The GitHub Actions workflow automatically deploys to GCP Compute Engine on push to `main`.

#### Required GitHub Secrets
| Secret | Description |
|--------|-------------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `GCP_SA_KEY` | Service account JSON key (base64 encoded) |
| `GCP_ZONE` | Compute Engine zone (e.g., `us-central1-a`) |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway security token |
| `OPENAI_API_KEY` | OpenAI API key (optional) |
| `ANTHROPIC_API_KEY` | Anthropic API key (optional) |
| `GOOGLE_API_KEY` | Google AI API key (optional) |

#### Manual Deployment
Trigger the workflow manually from GitHub Actions to deploy a specific image tag:
- `openclaw_image_tag`: Version to deploy (e.g., `latest`, `2026.2.2`)

### Access
After deployment, connect via SSH tunnel:
```bash
gcloud compute ssh openclaw-gateway --zone=YOUR_ZONE -- -L 18789:127.0.0.1:18789
```
Then open: http://127.0.0.1:18789/

## Files
- `docker-compose.yml` - Container orchestration
- `config/openclaw.json` - OpenClaw configuration
- `.github/workflows/deploy-gcp.yml` - GCP deployment workflow
