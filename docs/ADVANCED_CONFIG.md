# Advanced Configuration Guide

This document covers advanced configuration options and customization for the Terraform GCP deployment pipeline.

## Table of Contents

1. [Custom Terraform Modules](#custom-terraform-modules)
2. [Multiple Environments](#multiple-environments)
3. [Custom IAM Roles](#custom-iam-roles)
4. [State Management](#state-management)
5. [Workflow Customization](#workflow-customization)
6. [Monitoring and Logging](#monitoring-and-logging)

## Custom Terraform Modules

### Creating Custom Modules

Create a modular structure:

```
terraform/
├── main.tf                          # WIF setup
├── modules/
│   ├── compute/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── network/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── dev.tfvars
    ├── staging.tfvars
    └── prod.tfvars
```

### Example Module Usage

```hcl
# terraform/main.tf

module "compute" {
  source = "./modules/compute"
  
  project_id = var.gcp_project_id
  region     = var.gcp_region
  
  instance_count = var.compute_instance_count
  machine_type   = var.compute_machine_type
}

module "storage" {
  source = "./modules/storage"
  
  project_id = var.gcp_project_id
  backend_bucket_name = var.storage_bucket_name
}
```

### Service Account in Modules

All modules automatically have access to the service account:

```hcl
# modules/compute/main.tf

resource "google_compute_instance" "web" {
  name         = "web-server"
  machine_type = var.machine_type

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }
}
```

## Multiple Environments

### Environment-Specific Configuration

Create separate variable files:

**terraform/dev.tfvars**
```hcl
gcp_project_id    = "my-dev-project"
gcp_region        = "us-central1"
environment_name  = "development"
instance_count    = 1
machine_type      = "e2-small"

iam_roles = [
  "roles/editor"
]
```

**terraform/staging.tfvars**
```hcl
gcp_project_id    = "my-staging-project"
gcp_region        = "us-central1"
environment_name  = "staging"
instance_count    = 2
machine_type      = "e2-medium"

iam_roles = [
  "roles/compute.admin",
  "roles/storage.admin"
]
```

**terraform/prod.tfvars**
```hcl
gcp_project_id    = "my-prod-project"
gcp_region        = "us-central1"
environment_name  = "production"
instance_count    = 3
machine_type      = "n2-standard-4"

iam_roles = [
  "roles/compute.admin",
  "roles/storage.admin",
  "roles/monitoring.metricWriter"
]
```

### Updating the Workflow for Multiple Environments

Modify `.github/workflows/terraform.yml`:

```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'terraform/**'

env:
  TF_ENVIRONMENT: ${{ github.event_name == 'push' && 'prod' || 'staging' }}

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Plan
        working-directory: ./terraform
        run: terraform plan -var-file="${{ env.TF_ENVIRONMENT }}.tfvars"
```

### Workspace-Based Environments

Alternative approach using Terraform workspaces:

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Deploy to staging
terraform workspace select staging
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"

# Deploy to production
terraform workspace select prod
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

## Custom IAM Roles

### Creating Custom Roles

If you need permissions beyond predefined roles:

```hcl
# terraform/custom_roles.tf

resource "google_project_iam_custom_role" "github_deployer" {
  role_id     = "githubDeployer"
  title       = "GitHub Actions Deployer"
  description = "Custom role for GitHub Actions deployment"

  includedPermissions = [
    "compute.instances.create",
    "compute.instances.delete",
    "compute.instances.get",
    "compute.instances.list",
    "storage.buckets.create",
    "storage.objects.create",
    "storage.objects.delete",
  ]
}

# Grant the custom role to the service account
resource "google_project_iam_member" "github_custom_role" {
  project = var.gcp_project_id
  role    = google_project_iam_custom_role.github_deployer.id
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}
```

### Managed Role Assignment

Create a more flexible IAM assignment:

```hcl
# terraform/variables.tf

variable "iam_roles" {
  type        = list(string)
  default     = []
  description = "IAM roles for the service account"
}

# terraform/main.tf

# Dynamic role assignment
resource "google_project_iam_member" "github_actions_roles" {
  for_each = toset(var.iam_roles)

  project = var.gcp_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}
```

Then specify roles in tfvars:

```hcl
iam_roles = [
  "roles/compute.admin",
  "roles/storage.admin",
  "custom_role_name"
]
```

## State Management

### GCS Backend with Locking

Configure GCS backend with state locking:

**terraform/backend.tf**
```hcl
terraform {
  backend "gcs" {
    bucket = "my-terraform-state"
    prefix = "production/state"
  }
}
```

Initialize with backend config:

```bash
terraform init -backend-config="bucket=my-terraform-state"
```

### State File Encryption

Enable GCS bucket encryption:

```bash
# Create bucket with encryption
gsutil mb -p PROJECT_ID gs://terraform-state/
gsutil encryption set gs://encryption.json gs://terraform-state/

# Enable versioning
gsutil versioning set on gs://terraform-state/

# Lock down permissions
gsutil iam ch serviceAccount:SA_EMAIL:objectViewer gs://terraform-state/
```

### Remote State Outputs

Share state outputs across workspaces:

```hcl
data "terraform_remote_state" "shared" {
  backend = "gcs"
  
  config = {
    bucket = "terraform-state"
    prefix = "shared"
  }
}

locals {
  shared_vpc_id = data.terraform_remote_state.shared.outputs.vpc_id
}
```

## Workflow Customization

### Custom Approval Groups

Modify the approval step in workflow:

```yaml
manual-approval:
  environment:
    name: Production
    reviewers:
      - security-team
      - infrastructure-leads
  steps:
    - name: Approve
      run: echo "Approved for production"
```

### Conditional Deployments

Add conditions to workflow jobs:

```yaml
terraform-apply:
  if: |
    github.ref == 'refs/heads/main' &&
    github.event_name == 'push' &&
    contains(github.actor, 'authorized-user')
```

### Custom Plan Steps

Add additional validation:

```yaml
terraform-plan:
  steps:
    - name: Custom Validation
      run: |
        # Check for specific resources
        terraform plan -json | \
          jq 'select(.type == "resource_drift")'
        
        # Custom script for compliance
        bash scripts/compliance-check.sh
```

### Slack Notifications

Send notifications on deployment:

```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1.24.0
  with:
    payload: |
      {
        "text": "Terraform Deploy: ${{ job.status }}",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "Terraform deployment *${{ job.status }}*\nBranch: ${{ github.ref }}\nCommit: ${{ github.sha }}"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Monitoring and Logging

### Cloud Audit Logs

Enable audit logging for WIF access:

```bash
gcloud logging read "resource.type=service_account" \
  --project=PROJECT_ID \
  --format=json
```

### Terraform Logging

Enable Terraform debug logs:

```yaml
steps:
  - name: Terraform Plan with Debug
    env:
      TF_LOG: DEBUG
    run: terraform plan
```

### Custom Metrics

Export deployment metrics:

```hcl
# terraform/monitoring.tf

resource "google_monitoring_custom_metric" "deployments" {
  metric_descriptor {
    type        = "custom.googleapis.com/deployments/count"
    metric_kind = "GAUGE"
    value_type  = "INT64"
    
    labels {
      key         = "environment"
      value_type  = "STRING"
      description = "Environment name"
    }
  }
}
```

### GitHub Actions Logs Integration

Stream logs to Cloud Logging:

```bash
# Export workflow logs to Cloud Logging
gcloud logging write github-actions \
  "Terraform deployment" \
  --severity=INFO \
  --resource=global
```

## Performance Optimization

### Selective Apply

Only apply changes to specific resources:

```bash
terraform apply -target=google_compute_instance.web
```

### Parallel Operations

Control parallelism:

```bash
# In workflow
terraform apply -parallelism=5
```

### Cache Terraform Provider

Add to workflow for faster initialization:

```yaml
- name: Cache Terraform
  uses: actions/cache@v3
  with:
    path: terraform/.terraform
    key: ${{ runner.os }}-terraform-${{ hashFiles('**/versions.tf') }}
    restore-keys: |
      ${{ runner.os }}-terraform-
```

## Security Hardening

### Restrict WIF to Main Branch

Modify WIF provider condition:

```hcl
attribute_condition = "assertion.repository == '${var.github_repo_owner}/${var.github_repo_name}' && assertion.ref == 'refs/heads/main'"
```

### IP Allowlisting

Restrict to specific GitHub IP ranges:

```bash
# Get GitHub IP ranges
curl https://api.github.com/meta | jq '.actions'

# Add to service account conditions if needed
```

### Secrets Rotation

Regularly rotate service account:

```bash
# Create new service account
gcloud iam service-accounts create github-action-v2

# Update bindings to new account
# Update GitHub secrets with new account

# Delete old account
gcloud iam service-accounts delete github-action
```

## Troubleshooting Advanced Configurations

### Module Not Found

```bash
terraform init -upgrade
terraform get -update
```

### State Corruption

Backup and restore state:

```bash
# Backup
gsutil cp gs://terraform-state/production/state/default.tfstate .

# Restore
gsutil cp default.tfstate gs://terraform-state/production/state/
```

### Permission Denied Errors

Check service account bindings:

```bash
gcloud iam service-accounts get-iam-policy \
  github-action@PROJECT_ID.iam.gserviceaccount.com
```

---

For basic setup, refer to [README.md](../README.md)  
For workflow usage, see [WORKFLOW_GUIDE.md](WORKFLOW_GUIDE.md)
