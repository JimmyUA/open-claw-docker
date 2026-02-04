# GCP Service Account Setup for GitHub Actions

This document explains how to set up a Google Cloud Platform service account for automated deployments from GitHub Actions.

## Prerequisites

- GCP project with billing enabled
- `gcloud` CLI installed and authenticated
- GitHub repository created

## Step 1: Set Your Project

```bash
# Set your project ID
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID
```

## Step 2: Enable Required APIs

```bash
gcloud services enable \
  compute.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com
```

## Step 3: Create Service Account

```bash
# Create the service account
gcloud iam service-accounts create github-actions-deploy \
  --display-name="GitHub Actions Deployment" \
  --description="Service account for GitHub Actions to deploy OpenClaw"

# Get the service account email
export SA_EMAIL="github-actions-deploy@${PROJECT_ID}.iam.gserviceaccount.com"
echo "Service Account: $SA_EMAIL"
```

## Step 4: Grant Required Permissions

```bash
# Compute Engine Admin (create/manage VMs)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/compute.admin"

# Artifact Registry Writer (push Docker images)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/artifactregistry.writer"

# Storage Admin (for Container Registry, if used)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/storage.admin"

# Service Account User (to attach SA to VMs)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountUser"

# OS Login (for SSH access)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/compute.osLogin"
```

## Step 5: Create and Download Key

```bash
# Create a JSON key file
gcloud iam service-accounts keys create gcp-key.json \
  --iam-account=$SA_EMAIL

# Display the key (for copying to GitHub)
cat gcp-key.json
```

> ⚠️ **Security Warning**: Keep this key file secure. Delete it after adding to GitHub Secrets.

## Step 6: Add Secrets to GitHub

Go to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret

Add the following secrets:

| Secret Name | Value |
|------------|-------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `GCP_SA_KEY` | Contents of `gcp-key.json` (paste entire JSON) |
| `GCP_REGION` | e.g., `us-central1` |
| `GCP_ZONE` | e.g., `us-central1-a` |
| `OPENCLAW_GATEWAY_TOKEN` | Generate with `openssl rand -hex 32` |
| `GOG_KEYRING_PASSWORD` | Generate with `openssl rand -hex 32` |

### Optional Secrets (for model providers)

| Secret Name | Value |
|------------|-------|
| `OPENAI_API_KEY` | Your OpenAI API key |
| `ANTHROPIC_API_KEY` | Your Anthropic API key |
| `GOOGLE_API_KEY` | Your Google AI API key |

## Step 7: Clean Up Local Key

```bash
# Delete the local key file after adding to GitHub
rm gcp-key.json
```

## Step 8: Create Artifact Registry Repository

```bash
# Create the Docker repository
gcloud artifacts repositories create openclaw \
  --repository-format=docker \
  --location=us-central1 \
  --description="OpenClaw Docker images"
```

## Verification

After setup, trigger a deployment by:

1. Pushing to the `main` branch, or
2. Going to Actions → Deploy to GCP → Run workflow

## Troubleshooting

### "Permission denied" errors

Ensure the service account has all required roles:

```bash
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --format='table(bindings.role)' \
  --filter="bindings.members:$SA_EMAIL"
```

### "API not enabled" errors

Enable the required API:

```bash
gcloud services enable <api-name>.googleapis.com
```

### SSH connection issues

Ensure OS Login is configured:

```bash
gcloud compute project-info add-metadata \
  --metadata enable-oslogin=TRUE
```

## Security Best Practices

1. **Principle of least privilege**: Only grant necessary permissions
2. **Rotate keys regularly**: Delete and recreate keys periodically
3. **Use Workload Identity Federation**: For production, consider using [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines) instead of JSON keys
4. **Restrict key access**: Use GitHub Environments with required reviewers for production deployments

## Workload Identity Federation (Advanced)

For enhanced security, use Workload Identity Federation instead of JSON keys:

```bash
# Create the workload identity pool
gcloud iam workload-identity-pools create "github-pool" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create the OIDC provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Grant access
gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_GITHUB_USERNAME/open-claw-docker"
```

Then update the workflow to use:

```yaml
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
    service_account: 'github-actions-deploy@PROJECT_ID.iam.gserviceaccount.com'
```
