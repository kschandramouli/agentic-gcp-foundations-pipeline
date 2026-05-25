#!/bin/bash
# Validate Workload Identity Federation Setup
# This script checks if WIF is properly configured

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}▶ WIF Configuration Validator${NC}"
echo ""

# Check gcloud
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}✗ gcloud CLI not found${NC}"
    exit 1
fi

# Get inputs
read -p "Enter GCP Project ID: " PROJECT_ID
read -p "Enter WIF Pool ID (default: github-action-landing): " POOL_ID
POOL_ID="${POOL_ID:-github-action-landing}"

read -p "Enter WIF Provider ID (default: github-oidc-provider): " PROVIDER_ID
PROVIDER_ID="${PROVIDER_ID:-github-oidc-provider}"

read -p "Enter Service Account ID (default: github-action): " SA_ID
SA_ID="${SA_ID:-github-action}"

echo ""
echo -e "${BLUE}▶ Validating configuration...${NC}"
echo ""

# Counters
PASSED=0
FAILED=0

# Check Project Number
echo -n "Checking GCP Project... "
if PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)' 2>/dev/null); then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ Project ID not found${NC}"
    FAILED=$((FAILED + 1))
    exit 1
fi

# Check Workload Identity Pool
echo -n "Checking Workload Identity Pool... "
if gcloud iam workload-identity-pools describe "$POOL_ID" \
    --project="$PROJECT_ID" \
    --location=global &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ Pool not found${NC}"
    FAILED=$((FAILED + 1))
fi

# Check OIDC Provider
echo -n "Checking OIDC Provider... "
if gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
    --project="$PROJECT_ID" \
    --location=global \
    --workload-identity-pool="$POOL_ID" &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ Provider not found${NC}"
    FAILED=$((FAILED + 1))
fi

# Check Service Account
SA_EMAIL="${SA_ID}@${PROJECT_ID}.iam.gserviceaccount.com"
echo -n "Checking Service Account... "
if gcloud iam service-accounts describe "$SA_EMAIL" \
    --project="$PROJECT_ID" &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ Service Account not found${NC}"
    FAILED=$((FAILED + 1))
fi

# Check IAM bindings
echo -n "Checking Workload Identity User binding... "
if gcloud iam service-accounts get-iam-policy "$SA_EMAIL" \
    --project="$PROJECT_ID" 2>/dev/null | grep -q "roles/iam.workloadIdentityUser"; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ Binding not found${NC}"
    FAILED=$((FAILED + 1))
fi

# Check Token Creator binding
echo -n "Checking Token Creator binding... "
if gcloud iam service-accounts get-iam-policy "$SA_EMAIL" \
    --project="$PROJECT_ID" 2>/dev/null | grep -q "roles/iam.serviceAccountTokenCreator"; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${YELLOW}⚠ Binding not found${NC}"
    FAILED=$((FAILED + 1))
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ WIF Configuration is valid!${NC}"
    echo ""
    echo "GitHub Secrets Configuration:"
    echo -e "WIF_PROVIDER: ${YELLOW}projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}${NC}"
    echo -e "WIF_SERVICE_ACCOUNT: ${YELLOW}${SA_EMAIL}${NC}"
    exit 0
else
    echo -e "${RED}✗ WIF Configuration has issues${NC}"
    echo "Run setup-gcp-auth.sh to set up WIF properly"
    exit 1
fi
