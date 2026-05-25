# GitHub Actions Secrets Configuration

This document explains how to set up GitHub Secrets for the Terraform GCP deployment pipeline.

## Required Secrets

### 1. `WIF_PROVIDER`
The Workload Identity Federation provider resource name.

**Format:**
```
projects/{PROJECT_NUMBER}/locations/global/workloadIdentityPools/{POOL_ID}/providers/{PROVIDER_ID}
```

**Example:**
```
projects/123456789/locations/global/workloadIdentityPools/github-action-landing/providers/github-oidc-provider
```

**Where to find:**
- `{PROJECT_NUMBER}`: Run `gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)'`
- `{POOL_ID}`: Default is `github-action-landing` (from setup script)
- `{PROVIDER_ID}`: Default is `github-oidc-provider` (from setup script)

## Setting Up Secrets in GitHub

### Via Web UI

1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. For each secret:
   - Name: `WIF_PROVIDER`
   - Value: (paste the value from above)
   - Click **Add secret**

### Via GitHub CLI

If you have the GitHub CLI installed:

```bash
# Set WIF_PROVIDER
gh secret set WIF_PROVIDER --body "projects/123456789/locations/global/workloadIdentityPools/github-action-landing/providers/github-oidc-provider"
```

### Via Setup Script

After running `scripts/setup-gcp-auth.sh`, the script will display the exact values to enter.

## Verifying Secrets

You can verify that secrets are properly set:

1. In GitHub UI: Settings → Secrets and variables → Actions
2. Secrets should be listed (values are hidden for security)
3. Look for ✓ indicators next to each secret

## Updating Secrets

If you need to update a secret:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Find the secret
3. Click the pencil icon to edit
4. Enter the new value
5. Click **Update secret**

## Troubleshooting

### Error: "Resource not found" in workflow logs

**Cause**: WIF_PROVIDER value is incorrect

**Solution**:
```bash
# Verify the provider exists
gcloud iam workload-identity-pools providers list \
  --location=global \
  --workload-identity-pool=github-action-landing \
  --project=YOUR_PROJECT_ID
```

### Secrets not available in workflow

**Cause**: Secrets not properly saved

**Solution**:
1. Delete both secrets
2. Re-enter them exactly as shown
3. Ensure no extra spaces or newlines
4. Wait a few seconds after adding

## Security Notes

- **Never** commit secrets to the repository
- Secrets are encrypted at rest by GitHub
- Secrets are only exposed to workflow runs
- Use the minimal required permissions in IAM roles
- Rotate secrets periodically (update the service account credentials)

## Additional Information

For the complete setup instructions, see [README.md](../README.md)

For WIF setup details, refer to [Google Cloud Documentation](https://cloud.google.com/docs/authentication/workload-identity-federation)
