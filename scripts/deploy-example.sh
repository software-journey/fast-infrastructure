TO DO: Deploy example for Azure#!/bin/bash
set -e

# Deploy Example Claims Script
# Deploys development, staging, and production infrastructure

echo "🚀 Deploying Example Infrastructure"
echo "===================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check if XRD is installed
if ! kubectl get xrd xdevelopercombo.example.com &> /dev/null; then
    echo -e "${RED}❌ XRD not found. Please apply it first:${NC}"
    echo "   kubectl apply -f manifests/xrds/xrd-developercombo.yaml"
    exit 1
fi

# Check if Composition exists
if ! kubectl get composition developercombo.azure.example.com &> /dev/null; then
    echo -e "${RED}❌ Composition not found. Please apply it first:${NC}"
    echo "   kubectl apply -f manifests/compositions/composition-azure-basic.yaml"
    exit 1
fi

# Check if providers are healthy
if ! kubectl get providers | grep -q "True.*True"; then
    echo -e "${YELLOW}⚠️  Warning: Providers may not be healthy yet${NC}"
    kubectl get providers
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}✅ Prerequisites OK${NC}"
echo ""

# Function to deploy and wait for claim
deploy_claim() {
    local claim_file=$1
    local claim_name=$2
    local namespace=$3
    
    echo "📦 Deploying $claim_name in namespace $namespace..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply the claim
    kubectl apply -f $claim_file
    
    echo "   Claim created. Waiting for it to become ready..."
    echo "   This typically takes 5-10 minutes for Azure resources..."
}

# Ask which environments to deploy
echo -e "${BLUE}Which environments would you like to deploy?${NC}"
echo "1) Development only"
echo "2) Development + Staging"
echo "3) All (Development + Staging + Production)"
echo "4) Custom selection"
read -p "Enter choice [1-4]: " choice

deploy_dev=false
deploy_staging=false
deploy_prod=false

case $choice in
    1)
        deploy_dev=true
        ;;
    2)
        deploy_dev=true
        deploy_staging=true
        ;;
    3)
        deploy_dev=true
        deploy_staging=true
        deploy_prod=true
        ;;
    4)
        read -p "Deploy Development? (y/n): " -n 1 -r
        echo ""
        [[ $REPLY =~ ^[Yy]$ ]] && deploy_dev=true
        
        read -p "Deploy Staging? (y/n): " -n 1 -r
        echo ""
        [[ $REPLY =~ ^[Yy]$ ]] && deploy_staging=true
        
        read -p "Deploy Production? (y/n): " -n 1 -r
        echo ""
        [[ $REPLY =~ ^[Yy]$ ]] && deploy_prod=true
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""

# Deploy selected environments
if [ "$deploy_dev" = true ]; then
    deploy_claim "manifests/claims/claim-dev.yaml" "myapp-dev" "development"
fi

if [ "$deploy_staging" = true ]; then
    deploy_claim "manifests/claims/claim-staging.yaml" "myapp-staging" "staging"
fi

if [ "$deploy_prod" = true ]; then
    deploy_claim "manifests/claims/claim-prod.yaml" "myapp-prod" "production"
fi

echo ""
echo "🎉 Deployment initiated!"
echo ""
echo -e "${BLUE}Monitor deployment status:${NC}"
echo ""

if [ "$deploy_dev" = true ]; then
    echo "Development:"
    echo "  kubectl get developercombo -n development"
    echo "  kubectl describe developercombo myapp-dev -n development"
fi

if [ "$deploy_staging" = true ]; then
    echo "Staging:"
    echo "  kubectl get developercombo -n staging"
    echo "  kubectl describe developercombo myapp-staging -n staging"
fi

if [ "$deploy_prod" = true ]; then
    echo "Production:"
    echo "  kubectl get developercombo -n production"
    echo "  kubectl describe developercombo myapp-prod -n production"
fi

echo ""
echo "All environments:"
echo "  kubectl get developercombo -A"
echo "  watch kubectl get developercombo -A"
echo ""

# Offer to watch status
read -p "Watch status now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Watching status (Ctrl+C to exit)..."
    echo ""
    watch kubectl get developercombo -A
fi

echo ""
echo -e "${GREEN}Tip:${NC} Resources typically take 5-10 minutes to become ready."
echo "     Check Azure Portal to see resources being created."