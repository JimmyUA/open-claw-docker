# OpenClaw Docker Deployment - Walkthrough

## Summary

Successfully created and published a **full-featured Docker deployment** for OpenClaw AI assistant, with automated GitHub Actions deployment to GCP.

---

## Repository Published

**GitHub Repository**: [https://github.com/JimmyUA/open-claw-docker](https://github.com/JimmyUA/open-claw-docker)

---
    
## Full Application Deployment

The initial deployment was an infrastructure stub. The **full application** payload has now been deployed with the following components:

- **Source Code**: Integrated from `openclaw/openclaw`
- **Build Scripts**: Restored from upstream `scripts/`
- **Configuration**:
  - `docker-compose.yml`: Added `--allow-unconfigured` to fix startup crash
  - `.gitignore`: Tracked `pnpm-lock.yaml` for stable builds

### Verification Status
- [x] Infrastructure (VM, Docker, Network)
- [x] Application (Node.js Gateway running)
- [x] Connectivity (SSH Tunnel working)
- [x] Authentication (Token retrieved & Browser Paired)
- [x] Functionality (Templates restored, UI loads correctly)

---


## Files Created (15 total)

| File | Purpose |
|------|---------|
| `Dockerfile` | Full gateway with Playwright, CLI tools, ffmpeg |
| `Dockerfile.sandbox` | Secure agent code execution |
| `Dockerfile.sandbox-browser` | Browser automation with Xvfb |
| `docker-compose.yml` | Multi-service orchestration |
| `.env.example` | Configuration template |
| `config/openclaw.json` | Gateway + sandbox settings |
| `README.md` | Complete documentation |
| `scripts/setup.sh` | Local setup automation |
| `scripts/deploy-gcp.sh` | GCP deployment automation |
| `scripts/health-check.sh` | Health verification |
| `scripts/build-sandboxes.sh` | Sandbox image builder |
| `.github/workflows/deploy-gcp.yml` | **Automated GCP deployment** |
| `.github/workflows/build-test.yml` | PR build and validation |
| `docs/gcp-service-account-setup.md` | GCP service account instructions |
| `.gitignore` | Git ignore patterns |

---

### Troubleshooting GCP Deployment

If deployment fails with "Docker not found" or permission errors, the following steps were taken to resolve:

1.  **Docker Installation**: The default `docker.io` package on Debian 12 may be outdated or missing `docker-compose-v2` package. We switched to the official Docker CE installation:
    ```bash
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    ```

2.  **User Permissions**: The SSH user used by GitHub Actions needs to be in the `docker` group to run commands without `sudo`:
    ```bash
    sudo usermod -aG docker $(whoami)
    sudo chmod 666 /var/run/docker.sock
    ```

3.  **File Permissions**: To avoid `scp` permission issues, files are first copied to the home directory and then moved to `/opt/openclaw` using `sudo`.

---

## GitHub Actions Workflows

### Deploy to GCP (`deploy-gcp.yml`)
- **Triggers**: Push to `main` branch, manual dispatch
- **Actions**:
  1. Builds Docker images
  2. Pushes to GCP Artifact Registry
  3. Creates/updates Compute Engine VM
  4. Deploys containers

### Build and Test (`build-test.yml`)
- **Triggers**: Pull requests, Dockerfile changes
- **Actions**:
  1. Builds all Docker images
  2. Validates configuration files
  3. Runs security scan

---


## Troubleshooting

### "Channel config schema unavailable"
If you see this error when configuring Telegram or WhatsApp:
- This is caused by a missing dependency (`zod-to-json-schema`).
- **Fix Applied:** I have added the dependency to `package.json` and updated the code to use it explicitly.
- **Action Required:** Redeploy the application (commit and push changes).

## Next Steps: Configure GCP Secrets

To enable automated deployment, add these GitHub Secrets:

Go to: **Settings → Secrets → Actions → New repository secret**

### Required Secrets

| Secret | Description |
|--------|-------------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `GCP_SA_KEY` | Service account JSON key |
| `GCP_REGION` | e.g., `us-central1` |
| `GCP_ZONE` | e.g., `us-central1-a` |
| `OPENCLAW_GATEWAY_TOKEN` | Generate: `openssl rand -hex 32` |
| `GOG_KEYRING_PASSWORD` | Generate: `openssl rand -hex 32` |

### Optional Secrets (API Keys)

| Secret | Description |
|--------|-------------|
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `GOOGLE_API_KEY` | Google AI API key |

---

## Quick Setup Commands

### Create GCP Service Account

```bash
# Set project
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable APIs
gcloud services enable compute.googleapis.com artifactregistry.googleapis.com

# Create service account
gcloud iam service-accounts create github-actions-deploy \
  --display-name="GitHub Actions Deployment"

# Grant permissions
export SA_EMAIL="github-actions-deploy@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/compute.admin"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/artifactregistry.writer"

# Create key
gcloud iam service-accounts keys create gcp-key.json --iam-account=$SA_EMAIL
```

See full instructions: [docs/gcp-service-account-setup.md](./gcp-service-account-setup.md)

---

## Trigger Deployment

Once secrets are configured:

1. **Push to main** - Automatic deployment
2. **Manual trigger**:
   - Go to Actions → Deploy to GCP → Run workflow

---

## Access After Deployment

```bash
# SSH with tunnel
gcloud compute ssh openclaw-gateway --zone=us-central1-a -- -L 18789:127.0.0.1:18789

# Open UI
# http://127.0.0.1:18789/
```
