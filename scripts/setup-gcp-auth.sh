#!/bin/bash
# Setup GCP Workload Identity Federation for GitHub Actions
# This script automates the one-time setup of WIF resources

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}▶ GCP Workload Identity Federation Setup Script${NC}"
echo ""

# Validate required tools
check_tools() {
    local missing_tools=0
    
    for tool in gcloud terraform git; do
        if ! command -v "$tool" &> /dev/null; then
            echo -e "${RED}✗ $tool is not installed${NC}"
            missing_tools=$((missing_tools + 1))
        fi
    done
    
    if [ $missing_tools -gt 0 ]; then
        echo -e "${RED}Please install missing tools and try again${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All required tools found${NC}"
}

check_tools

# Get user inputs (each can be pre-set as an environment variable to skip the prompt)
if [ -z "${PROJECT_ID:-}" ]; then
  read -p "Enter your GCP Project ID: " PROJECT_ID
fi
if [ -z "${GITHUB_REPO_OWNER:-}" ]; then
  read -p "Enter GitHub repository owner (username or org): " GITHUB_REPO_OWNER
fi
if [ -z "${GITHUB_REPO_NAME:-}" ]; then
  read -p "Enter GitHub repository name: " GITHUB_REPO_NAME
fi
if [ -z "${ADMIN_GROUP_EMAIL:-}" ]; then
  read -p "Enter admin Google Group email (e.g. agenticadmingroup@cognizant.com): " ADMIN_GROUP_EMAIL
fi

# Validate inputs
if [ -z "$PROJECT_ID" ] || [ -z "$GITHUB_REPO_OWNER" ] || [ -z "$GITHUB_REPO_NAME" ] || [ -z "$ADMIN_GROUP_EMAIL" ]; then
    echo -e "${RED}Error: All inputs are required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  GCP Project ID: $PROJECT_ID"
echo "  GitHub Repo: $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"
echo "  Admin Group: $ADMIN_GROUP_EMAIL"
echo ""

read -p "Continue with setup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled"
    exit 0
fi

# Get Project Number
echo ""
echo -e "${GREEN}▶ Getting GCP Project Number...${NC}"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)' 2>/dev/null)
if [ -z "$PROJECT_NUMBER" ]; then
    echo -e "${RED}Error: Unable to get project number. Check your project ID.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Project Number: $PROJECT_NUMBER${NC}"

# Enable required APIs
echo ""
echo -e "${GREEN}▶ Enabling required APIs...${NC}"
gcloud services enable \
    iam.googleapis.com \
    iamcredentials.googleapis.com \
    cloudresourcemanager.googleapis.com \
    sts.googleapis.com \
    serviceusage.googleapis.com \
    --project="$PROJECT_ID" 2>/dev/null
echo -e "${GREEN}✓ APIs enabled${NC}"

# Create Workload Identity Pool
echo ""
echo -e "${GREEN}▶ Creating Workload Identity Pool...${NC}"
if gcloud iam workload-identity-pools describe github-action-landing \
    --project="$PROJECT_ID" \
    --location=global &>/dev/null; then
    echo -e "${YELLOW}⚠ Pool already exists${NC}"
else
    gcloud iam workload-identity-pools create github-action-landing \
        --project="$PROJECT_ID" \
        --location=global \
        --display-name="GitHub Actions Pool" \
        --description="Workload Identity Pool for GitHub Actions" 2>/dev/null
    echo -e "${GREEN}✓ Workload Identity Pool created${NC}"
fi

# Create OIDC Provider
echo ""
echo -e "${GREEN}▶ Creating OIDC Provider...${NC}"
if gcloud iam workload-identity-pools providers describe github-oidc-provider \
    --project="$PROJECT_ID" \
    --location=global \
    --workload-identity-pool=github-action-landing &>/dev/null; then
    echo -e "${YELLOW}⚠ Provider already exists${NC}"
else
    gcloud iam workload-identity-pools providers create-oidc github-oidc-provider \
        --project="$PROJECT_ID" \
        --location=global \
        --workload-identity-pool=github-action-landing \
        --display-name="GitHub OIDC Provider" \
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --attribute-condition="assertion.repository == '${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}'" 2>/dev/null
    echo -e "${GREEN}✓ OIDC Provider created${NC}"
fi

# Create Service Account
echo ""
echo -e "${GREEN}▶ Creating Service Account...${NC}"
if gcloud iam service-accounts describe github-action@${PROJECT_ID}.iam.gserviceaccount.com \
    --project="$PROJECT_ID" &>/dev/null; then
    echo -e "${YELLOW}⚠ Service Account already exists${NC}"
else
    gcloud iam service-accounts create github-action \
        --project="$PROJECT_ID" \
        --display-name="GitHub Actions Service Account" 2>/dev/null
    echo -e "${GREEN}✓ Service Account created${NC}"
fi

SERVICE_ACCOUNT_EMAIL="github-action@${PROJECT_ID}.iam.gserviceaccount.com"

# Grant editor role to admin group (service account must be a member of this group)
echo ""
echo -e "${GREEN}▶ Granting roles/editor to admin group...${NC}"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="group:${ADMIN_GROUP_EMAIL}" \
    --role="roles/editor" \
    --condition=None 2>/dev/null
echo -e "${GREEN}✓ roles/editor granted to group:${ADMIN_GROUP_EMAIL}${NC}"

# Bind Workload Identity User role
echo ""
echo -e "${GREEN}▶ Binding Workload Identity User role...${NC}"
gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT_EMAIL" \
    --project="$PROJECT_ID" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-action-landing/attribute.repository/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}" 2>/dev/null
echo -e "${GREEN}✓ roles/iam.workloadIdentityUser bound${NC}"

# Bind Token Creator role
echo ""
echo -e "${GREEN}▶ Binding Service Account Token Creator role...${NC}"
gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT_EMAIL" \
    --project="$PROJECT_ID" \
    --role="roles/iam.serviceAccountTokenCreator" \
    --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-action-landing/attribute.repository/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}" 2>/dev/null
echo -e "${GREEN}✓ roles/iam.serviceAccountTokenCreator bound${NC}"

# Display WIF Provider resource
WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-action-landing/providers/github-oidc-provider"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Add these GitHub Secrets to your repository:"
echo "   → Settings → Secrets and variables → Actions"
echo ""
echo "   WIF_PROVIDER:"
echo -e "     ${GREEN}$WIF_PROVIDER${NC}"
echo ""
echo "   WIF_SERVICE_ACCOUNT:"
echo -e "     ${GREEN}$SERVICE_ACCOUNT_EMAIL${NC}"
echo ""
echo "2. Create terraform.tfvars from template:"
echo "   cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
echo ""
echo "3. Update terraform.tfvars with:"
echo "   gcp_project_id = \"$PROJECT_ID\""
echo "   github_repo_owner = \"$GITHUB_REPO_OWNER\""
echo "   github_repo_name = \"$GITHUB_REPO_NAME\""
echo ""
echo "4. Initialize Terraform (optional - uses local state for now):"
echo "   cd terraform && terraform init && terraform plan"
echo ""
echo "5. Push to GitHub to trigger the workflow:"
echo "   git add . && git commit -m 'Add Terraform GCP deployment' && git push"
echo ""
