#!/bin/bash
set -e

# Azure Setup Script for Crossplane
# Creates Service Principal and configures Crossplane credentials

echo "☁️  Azure Credential Setup for Crossplane"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found${NC}"
    echo "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

echo -e "${GREEN}✅ Azure CLI found${NC}"
echo ""

# Check if logged in
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged in to Azure${NC}"
    echo "Logging in..."
    az login
fi

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

echo -e "${BLUE}Current Subscription:${NC}"
echo "  ID: $SUBSCRIPTION_ID"
echo "  Name: $SUBSCRIPTION_NAME"
echo ""

read -p "Use this subscription? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please select the correct subscription with: az account set --subscription <id>"
    exit 1
fi

# Service Principal name
SP_NAME="crossplane-sp-$(date +%s)"
echo ""
echo "Creating Service Principal: $SP_NAME"

# Create Service Principal
SP_OUTPUT=$(az ad sp create-for-rbac \
    --name "$SP_NAME" \
    --role Contributor \
    --scopes /subscriptions/"$SUBSCRIPTION_ID" \
    --sdk-auth)

# Extract values
CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.clientId')
CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.clientSecret')
TENANT_ID=$(echo "$SP_OUTPUT" | jq -r '.tenantId')

echo -e "${GREEN}✅ Service Principal created${NC}"
echo ""

# Create credentials JSON
CREDENTIALS_JSON=$(cat <<EOF
{
  "clientId": "$CLIENT_ID",
  "clientSecret": "$CLIENT_SECRET",
  "subscriptionId": "$SUBSCRIPTION_ID",
  "tenantId": "$TENANT_ID"
}
EOF
)

# Create namespace if it doesn't exist
if ! kubectl get namespace crossplane-system &> /dev/null; then
    kubectl create namespace crossplane-system
fi

# Create Kubernetes secret
echo "Creating Kubernetes secret..."
kubectl create secret generic azure-credentials \
    -n crossplane-system \
    --from-literal=credentials="$CREDENTIALS_JSON" \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ Secret created in crossplane-system namespace${NC}"
echo ""

# Create ProviderConfig
echo "Creating ProviderConfig..."
cat <<EOF | kubectl apply -f -
---
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-credentials
      key: credentials
EOF

echo -e "${GREEN}✅ ProviderConfig created${NC}"
echo ""

# Create database password secret
echo "Creating database password secret..."
DB_PASSWORD=$(openssl rand -base64 32)
kubectl create secret generic db-password \
    -n crossplane-system \
    --from-literal=password="$DB_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ Database password secret created${NC}"
echo ""

# Summary
echo "🎉 Azure Setup Complete!"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "  Service Principal: $SP_NAME"
echo "  Client ID: $CLIENT_ID"
echo "  Tenant ID: $TENANT_ID"
echo "  Subscription ID: $SUBSCRIPTION_ID"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "  The client secret has been stored in Kubernetes secret 'azure-credentials'"
echo "  Keep this information secure and do not commit it to version control"
echo ""
echo -e "${BLUE}Service Principal Details:${NC}"
echo "  To view: az ad sp show --id $CLIENT_ID"
echo "  To delete: az ad sp delete --id $CLIENT_ID"
echo ""
echo "Next steps:"
echo "1. Apply XRD: kubectl apply -f manifests/xrds/xrd-developercombo.yaml"
echo "2. Apply Composition: kubectl apply -f manifests/compositions/composition-azure-basic.yaml"
echo "3. Create claim: kubectl apply -f manifests/claims/claim-dev.yaml"