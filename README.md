# Terraform GCP Deployment Pipeline with GitHub Actions & Workload Identity Federation

A comprehensive Terraform-based infrastructure-as-code (IaC) solution for deploying resources to Google Cloud Platform (GCP) using GitHub Actions and Workload Identity Federation (WIF). This setup eliminates the need for long-lived service account keys by using ephemeral credentials generated through OIDC token exchange.

## 🏗️ Architecture Overview

```
GitHub Repository
  ├── Push to main (or PR)
  └── Trigger GitHub Actions Workflow
        ├── Terraform Validation & Format Check
        ├── Security Scanning (tfsec, Checkov)
        ├── Terraform Plan
        ├── Manual Approval (for apply)
        └── Terraform Apply
              └── Uses WIF to exchange OIDC token for GCP access token
                    └── Deploy infrastructure to GCP
```

## 📋 Key Components

### 1. **Workload Identity Federation (WIF)**
- GitHub OIDC provider for keyless authentication
- Service account with federation bindings
- No long-lived service account keys stored in GitHub Secrets

### 2. **Terraform Configuration**
- Modular structure with clear separation of concerns
- GCS backend for state management
- Variables for easy customization across environments

### 3. **GitHub Actions Workflow**
- Multi-stage pipeline (validate → scan → plan → approve → apply)
- Automated security scanning with tfsec and Checkov
- Plan artifacts for review before apply
- Manual approval gate before production changes

## 🚀 Quick Start

### Prerequisites

- **GCP Project**: An existing Google Cloud Platform project
- **GitHub Repository**: A GitHub repository with admin access
- **Local Tools**: 
  - Terraform CLI (v1.0+)
  - Google Cloud SDK
  - Git

### Step 1: Set Up GCP Resources (One-time setup)

#### Option A: Using gcloud CLI (Recommended)

```bash
# Set your variables
export PROJECT_ID="your-gcp-project-id"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export GITHUB_REPO_OWNER="your-github-username-or-org"
export GITHUB_REPO_NAME="your-repo-name"

# Enable required APIs
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  sts.googleapis.com \
  serviceusage.googleapis.com

# Create Workload Identity Pool
gcloud iam workload-identity-pools create github-action-landing \
  --project=$PROJECT_ID \
  --location=global \
  --display-name="GitHub Actions Pool" \
  --description="Workload Identity Pool for GitHub Actions"

# Create OIDC Provider
gcloud iam workload-identity-pools providers create-oidc github-oidc-provider \
  --project=$PROJECT_ID \
  --location=global \
  --workload-identity-pool=github-action-landing \
  --display-name="GitHub OIDC Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-condition="assertion.repository == '${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}'"

# Create Service Account
gcloud iam service-accounts create github-action \
  --project=$PROJECT_ID \
  --display-name="GitHub Actions Service Account"

# Grant IAM roles to service account
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-action@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/editor"

# Bind Workload Identity to Service Account
gcloud iam service-accounts add-iam-policy-binding github-action@${PROJECT_ID}.iam.gserviceaccount.com \
  --project=$PROJECT_ID \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-action-landing/attribute.repository/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}"

# Grant Token Creator role
gcloud iam service-accounts add-iam-policy-binding github-action@${PROJECT_ID}.iam.gserviceaccount.com \
  --project=$PROJECT_ID \
  --role="roles/iam.serviceAccountTokenCreator" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-action-landing/attribute.repository/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}"

# Get the WIF Provider resource name
WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-action-landing/providers/github-oidc-provider"
echo "WIF Provider: $WIF_PROVIDER"
```

#### Option B: Using Terraform (Alternative)

Use the provided Terraform configuration to set up WIF:

```bash
cd terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
vim terraform.tfvars

# Initialize and apply
terraform init
terraform plan
terraform apply
```

### Step 2: Configure GitHub Secrets

1. Go to your GitHub repository: **Settings → Secrets and variables → Actions**

2. Create these repository secrets:

   | Secret Name | Value |
   |-------------|-------|
   | `WIF_PROVIDER` | `projects/{PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-action-landing/providers/github-oidc-provider` |

3. Example values:
   ```
   WIF_PROVIDER: projects/123456789/locations/global/workloadIdentityPools/github-action-landing/providers/github-oidc-provider
   ```

### Step 3: Prepare Terraform Variables

In your repository root or `terraform` directory:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:

```hcl
gcp_project_id        = "your-gcp-project-id"
gcp_region            = "us-central1"
github_repo_owner     = "your-username-or-org"
github_repo_name      = "your-repo-name"
service_account_id    = "github-action"
```

### Step 4: Set Up GCS Backend (Optional but Recommended)

Create a GCS bucket for Terraform state:

```bash
PROJECT_ID="your-gcp-project-id"
BUCKET_NAME="${PROJECT_ID}-terraform-state"

gsutil mb -p $PROJECT_ID gs://$BUCKET_NAME
gsutil versioning set on gs://$BUCKET_NAME
gsutil uniformbucketlevelaccess set on gs://$BUCKET_NAME
```

Initialize Terraform with backend:

```bash
cd terraform
terraform init -backend-config="bucket=$BUCKET_NAME"
```

### Step 5: Push to GitHub

```bash
git add .
git commit -m "feat: add Terraform GCP pipeline with WIF"
git push origin main
```

This triggers the GitHub Actions workflow!

## 📁 Directory Structure

```
agentic-gcp-foundations-pipeline/
├── .github/
│   └── workflows/
│       └── terraform.yml                 # GitHub Actions CI/CD workflow
├── terraform/
│   ├── main.tf                          # WIF and service account setup
│   ├── variables.tf                     # Input variables
│   ├── outputs.tf                       # Terraform outputs
│   ├── locals.tf                        # Local values
│   ├── provider.tf                      # GCP provider configuration
│   ├── backend.tf                       # GCS backend configuration
│   └── terraform.tfvars.example         # Example variables
├── scripts/
│   ├── setup-gcp-auth.sh               # One-time GCP setup script
│   └── validate-wif-setup.sh           # Validate WIF configuration
├── README.md                            # This file
└── .gitignore                          # Git ignore rules
```

## 🔐 Security Best Practices

### 1. No Long-lived Credentials
- Uses Workload Identity Federation for keyless authentication
- Short-lived access tokens (1200s for plan, 1800s for apply)
- No service account keys stored in GitHub Secrets

### 2. Automated Security Scanning
- **tfsec**: Scans Terraform code for security misconfigurations
- **Checkov**: Compliance scanning (CIS, NIST, PCI-DSS)
- Results uploaded to GitHub Security tab

### 3. Manual Approval Gate
- All apply operations require manual approval
- Prevents accidental infrastructure changes
- Audit trail in GitHub

### 4. Least Privilege IAM
- Customize service account roles in `terraform.tfvars`
- Start with `roles/editor` for testing, then limit as needed
- Example: Use `roles/compute.admin`, `roles/storage.admin`, etc.

### 5. State File Protection
- Terraform state stored in GCS with versioning enabled
- Encryption at rest with Google-managed keys
- Restrict access via IAM bindings

## 🔄 Workflow Triggers

The GitHub Actions workflow is triggered by:

1. **Push to main**: On changes to `terraform/**` or `.github/workflows/terraform.yml`
2. **Pull Request**: Runs plan only, no apply (manual PR review required)
3. **Manual Workflow Dispatch**: Via GitHub UI with custom inputs

## 📊 Workflow Stages

### 1. Terraform Validation
- Checks code formatting: `terraform fmt -check`
- Validates syntax: `terraform validate`

### 2. Security Scanning
- **tfsec**: Detects security issues in Terraform resources
- **Checkov**: Compliance scanning against security frameworks
- Results appear in GitHub Security tab

### 3. Terraform Plan
- Authenticates to GCP using WIF
- Generates execution plan
- Uploads plan artifacts for review

### 4. Manual Approval (Production)
- Uses GitHub Environments for approval tracking
- Requires manual approval before apply
- Audit trail in workflow logs

### 5. Terraform Apply
- Downloads and applies the reviewed plan
- Runs only on main branch, after approval
- Publishes outputs as artifacts

## 📝 Terraform Configuration

### Main Resources Created

The `main.tf` file creates:

1. **Workload Identity Pool** (`google_iam_workload_identity_pool`)
   - Global pool for GitHub OIDC tokens
   
2. **OIDC Provider** (`google_iam_workload_identity_pool_provider`)
   - Maps GitHub OIDC tokens to GCP identities
   - Only accepts tokens for your specific repository

3. **Service Account** (`google_service_account`)
   - Gmail-style account for workload authentication

4. **IAM Bindings**
   - `roles/iam.workloadIdentityUser`: Allows WIF to impersonate the service account
   - `roles/iam.serviceAccountTokenCreator`: Allows token generation
   - Additional roles as specified in `iam_roles` variable

### Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `gcp_project_id` | - | GCP Project ID |
| `gcp_region` | `us-central1` | GCP Region |
| `github_repo_owner` | - | GitHub username/org |
| `github_repo_name` | - | GitHub repository name |
| `workload_identity_pool_id` | `github-action-landing` | WIF Pool ID |
| `workload_identity_provider_id` | `github-oidc-provider` | WIF Provider ID |
| `service_account_id` | `github-action` | Service account ID |
| `iam_roles` | `["roles/editor"]` | IAM roles to grant |

## 🛠️ Customization

### Add More GCP Resources

1. Create new Terraform files in the `terraform/` directory
2. Reference the service account: `google_service_account.github_actions.email`
3. Ensure service account has required IAM roles
4. Push and trigger the workflow

Example:

```hcl
# terraform/storage.tf
resource "google_storage_bucket" "my_bucket" {
  name     = "my-bucket-${var.gcp_project_id}"
  location = var.gcp_region
  
  project = var.gcp_project_id
}
```

### Customize IAM Roles

Edit `terraform/terraform.tfvars`:

```hcl
iam_roles = [
  "roles/compute.admin",
  "roles/container.admin",
  "roles/storage.admin",
  # Add more as needed
]
```

### Change Workflow Branches

Edit `.github/workflows/terraform.yml`:

```yaml
on:
  push:
    branches:
      - main
      - develop
      - staging
```

### Restrict WIF to Specific Branches

In `main.tf`, modify the `attribute_condition`:

```hcl
attribute_condition = "assertion.repository == '${var.github_repo_owner}/${var.github_repo_name}' && assertion.ref == 'refs/heads/main'"
```

## 🐛 Troubleshooting

### WIF Provider Not Found

**Error**: `Error 401: invalid_grant: Unable to generate access token for the provided Workload Identity credentials`

**Solution**:
1. Verify WIF provider resource name matches `WIF_PROVIDER` secret
2. Check OIDC issuer: `https://token.actions.githubusercontent.com`
3. Ensure service account has `roles/iam.workloadIdentityUser` binding
4. Verify `attribute_condition` matches your repository

### Plan Shows Unexpected Changes

**Solution**:
1. Check `terraform.tfvars` values
2. Run `terraform plan` locally to compare
3. Check for drift: `terraform refresh`

### Approval Step Times Out

**Solution**:
1. Requires member of `minimum-approvers` to approve
2. Approve via GitHub workflow UI
3. Check GitHub Actions permissions in repository settings

### State Lock Issues

**Error**: `Error acquiring the state lock`

**Solution**:
1. Check GCS bucket permissions
2. Verify only one workflow running
3. Unlock manually if needed:
   ```bash
   terraform force-unlock LOCK_ID
   ```

## 🔗 Useful Resources

- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Workload Identity Federation](https://cloud.google.com/docs/authentication/workload-identity-federation)
- [GitHub Actions Google Auth](https://github.com/google-github-actions/auth)
- [tfsec Documentation](https://aquasecurity.github.io/tfsec/)
- [Checkov Documentation](https://www.checkov.io/)

## 📚 Additional Examples

### Deploy to Specific GCP Environment

Create separate `terraform.tfvars` files:

```bash
terraform apply -var-file="prod.tfvars"
terraform apply -var-file="staging.tfvars"
```

### Use Terraform Workspaces

```bash
terraform workspace new prod
terraform workspace new staging
terraform workspace select prod
terraform apply
```

### Add Pre-commit Hooks

```bash
# Install pre-commit
pip install pre-commit
pre-commit install

# Add to .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.85.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: tfsec
```

## 🤝 Contributing

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make changes and test locally
3. Push and create a pull request
4. Workflow will validate and plan changes
5. Get approval before merge

## 📄 License

This project is provided as-is. Modify and use as needed for your GCP deployments.

## ❓ FAQ

**Q: Do I need to create the Workload Identity Pool manually?**
A: No, use the included Terraform configuration to create it, or run the setup script. Only set up GitHub secrets.

**Q: Can I use this with multiple repositories?**
A: Yes, create separate WIF providers for each repo or use the principal set approach.

**Q: Where is Terraform state stored?**
A: In a GCS bucket (configured via backend.tf). Use local state for development or GCS for production.

**Q: How often does the workflow run?**
A: On pushes to main, pull requests, or manual triggers via workflow_dispatch.

**Q: Can I skip the approval step?**
A: Not recommended for production, but you can remove the `manual-approval` job dependency from `terraform-apply`.

---

**Last Updated**: 2026-04-11  
**Terraform Version**: 1.0+  
**GCP Provider Version**: 5.0+
