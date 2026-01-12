#!/bin/bash
set -e

# Fast Infrastructure Setup Script
# This script sets up Crossplane and Azure providers for the "Fast Food" infrastructure pattern

echo "🍔 Fast Infrastructure Setup"
echo "============================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ helm not found. Please install helm first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites OK${NC}"
echo ""

# Check if already connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Not connected to a Kubernetes cluster${NC}"
    echo "Please configure kubectl to connect to your cluster first"
    exit 1
fi

CLUSTER_NAME=$(kubectl config current-context)
echo -e "${GREEN}✅ Connected to cluster: ${CLUSTER_NAME}${NC}"
echo ""

# Install Crossplane
echo "🔧 Installing Crossplane..."
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

if helm list -n crossplane-system | grep -q crossplane; then
    echo -e "${YELLOW}⚠️  Crossplane already installed, upgrading...${NC}"
    helm upgrade crossplane crossplane-stable/crossplane \
        --namespace crossplane-system \
        --wait
else
    helm install crossplane crossplane-stable/crossplane \
        --namespace crossplane-system \
        --create-namespace \
        --wait
fi

echo -e "${GREEN}✅ Crossplane installed${NC}"
echo ""

# Wait for Crossplane to be ready
echo "⏳ Waiting for Crossplane to be ready..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/crossplane -n crossplane-system

echo -e "${GREEN}✅ Crossplane is ready${NC}"
echo ""

# Install function-patch-and-transform
echo "🔧 Installing function-patch-and-transform..."
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.2.1
EOF

echo -e "${GREEN}✅ Function installed${NC}"
echo ""

# Install Azure Providers
echo "🔧 Installing Azure Providers..."

# Provider Family
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-family-azure
spec:
  package: xpkg.upbound.io/upbound/provider-family-azure:v1.3.0
EOF

# Individual providers
cat <<EOF | kubectl apply -f -
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-storage
spec:
  package: xpkg.upbound.io/upbound/provider-azure-storage:v1.3.0
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-dbforpostgresql
spec:
  package: xpkg.upbound.io/upbound/provider-azure-dbforpostgresql:v1.3.0
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-network
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v1.3.0
EOF

echo "⏳ Waiting for providers to be installed..."
sleep 30

# Check provider status
kubectl get providers

echo -e "${GREEN}✅ Providers installed${NC}"
echo ""

# Next steps
echo "🎉 Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Configure Azure credentials:"
echo "   ./scripts/azure-setup.sh"
echo ""
echo "2. Apply the XRD and Composition:"
echo "   kubectl apply -f manifests/xrds/xrd-developercombo.yaml"
echo "   kubectl apply -f manifests/compositions/composition-azure-basic.yaml"
echo ""
echo "3. Create your first order:"
echo "   kubectl apply -f manifests/claims/claim-dev.yaml"
echo ""
echo "4. Check the status:"
echo "   kubectl get developercombo -A"
echo ""
echo "📖 For more information, see: README.md"