#!/bin/bash
set -e

# Install Azure Providers Script
# Installs all required Azure providers for the Fast Infrastructure pattern

echo "🔧 Installing Azure Providers for Crossplane"
echo "============================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if Crossplane is installed
if ! kubectl get deployment crossplane -n crossplane-system &> /dev/null; then
    echo -e "${YELLOW}⚠️  Crossplane not found. Please run setup.sh first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Crossplane found${NC}"
echo ""

# Install Provider Family (optional but recommended)
echo "📦 Installing Provider Family Azure..."
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-family-azure
spec:
  package: xpkg.upbound.io/upbound/provider-family-azure:v1.3.0
  packagePullPolicy: IfNotPresent
  revisionActivationPolicy: Automatic
  revisionHistoryLimit: 1
EOF

echo -e "${GREEN}✅ Provider family installed${NC}"
echo ""

# Install individual providers
echo "📦 Installing individual Azure providers..."

# Storage Provider
echo "  - Installing provider-azure-storage..."
kubectl apply -f manifests/providers/provider-azure-storage.yaml

# Database Provider
echo "  - Installing provider-azure-dbforpostgresql..."
kubectl apply -f manifests/providers/provider-azure-sql.yaml

# Network Provider
echo "  - Installing provider-azure-network..."
kubectl apply -f manifests/providers/provider-azure-network.yaml

echo -e "${GREEN}✅ All providers applied${NC}"
echo ""

# Wait for providers to install
echo "⏳ Waiting for providers to install (this may take 2-3 minutes)..."
sleep 30

# Check provider status
echo ""
echo -e "${BLUE}Provider Status:${NC}"
kubectl get providers

echo ""
echo "⏳ Waiting for providers to become healthy..."
echo "   This can take up to 5 minutes..."

# Wait for each provider to be healthy
PROVIDERS=(
    "provider-azure-storage"
    "provider-azure-dbforpostgresql"
    "provider-azure-network"
)

for provider in "${PROVIDERS[@]}"; do
    echo "   Waiting for $provider..."
    kubectl wait --for=condition=Healthy provider/$provider --timeout=300s || true
done

echo ""
echo -e "${BLUE}Final Provider Status:${NC}"
kubectl get providers

echo ""
echo "🎉 Provider Installation Complete!"
echo ""
echo "Next steps:"
echo "1. Configure Azure credentials: ./scripts/azure-setup.sh"
echo "2. Apply XRD: kubectl apply -f manifests/xrds/"
echo "3. Apply Compositions: kubectl apply -f manifests/compositions/"
echo "4. Create your first claim: kubectl apply -f manifests/claims/claim-dev.yaml"