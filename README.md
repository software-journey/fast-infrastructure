# Fast Infrastructure 🍔☁️

> Order Up! Serving Cloud Infrastructure Like a Fast-Food Menu with Crossplane

Welcome to the companion repository for the article **“I’ll Have a Kubernetes Cluster with a Side of SQL Database, Please: Understanding Crossplane”**

[![Read on Dev.to](https://img.shields.io/badge/Read%20on-Dev.to-0A0A0A?style=for-the-badge&logo=dev.to&logoColor=white)](https://dev.to/the-software-s-journey/fast-infrastructure-understanding-crossplane-like-a-fast-food-restaurant-1ikk)

## 📖 About This Repository

This repository contains all the source code, manifests, and examples referenced in the article that explains Crossplane using a fast-food restaurant metaphor. Just like ordering from a menu, Crossplane lets developers order infrastructure without knowing how to “cook” it.

## 🎯 What’s Inside

This repository provides complete, working examples of:

- **Composite Resource Definitions (XRDs)** - The “menu”
- **Compositions** - The “recipes”
- **Claims** - The “orders”
- **Provider Configurations** - The “kitchen credentials”
- **Complete setup scripts** - Opening your own “franchise”

All examples use **Azure** as the cloud provider and **Crossplane v2** features.

## 📁 Repository Structure

```
fast-infrastructure/
├── README.md                          # This file
├── docs/
│   ├── article.md                     # Full article text
│   ├── header-image-prompt.txt        # DALL-E prompt for header image
│   └── metaphor-mapping.md            # Complete metaphor breakdown
├── examples/
│   ├── 01-basic-developercombo/       # Simple DeveloperCombo example
│   ├── 02-multi-environment/          # Dev/Staging/Prod examples
│   ├── 03-composition-functions/      # Advanced with functions
│   └── 04-full-application-stack/     # Complete app infrastructure
├── manifests/
│   ├── xrds/
│   │   └── xrd-developercombo.yaml    # DeveloperCombo XRD
│   ├── compositions/
│   │   ├── composition-azure-basic.yaml
│   │   ├── composition-azure-secure.yaml
│   │   └── composition-azure-advanced.yaml
│   ├── claims/
│   │   ├── claim-dev.yaml
│   │   ├── claim-staging.yaml
│   │   └── claim-prod.yaml
│   └── providers/
│       ├── provider-azure-storage.yaml
│       ├── provider-azure-sql.yaml
│       ├── provider-azure-network.yaml
│       └── providerconfig.yaml
├── scripts/
│   ├── setup.sh                       # Complete installation script
│   ├── azure-setup.sh                 # Azure Service Principal setup
│   ├── install-providers.sh           # Install Azure providers
│   └── deploy-example.sh              # Deploy example claims
└── troubleshooting/
    ├── common-issues.md               # Troubleshooting guide
    └── debugging-tips.md              # Debugging workflows
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (1.25+)
- kubectl configured
- Azure subscription
- Azure CLI installed
- Helm 3 installed

### 1. Install Crossplane

```bash
# Clone this repository
git clone https://github.com/software-journey/fast-infrastructure.git
cd fast-infrastructure

# Run the setup script
./scripts/setup.sh
```

### 2. Configure Azure Credentials

```bash
# Create Azure Service Principal
./scripts/azure-setup.sh

# This will:
# - Create a Service Principal
# - Assign Contributor role
# - Create Kubernetes secret with credentials
# - Apply ProviderConfig
```

### 3. Install the Menu (XRDs and Compositions)

```bash
# Apply the XRD (menu definition)
kubectl apply -f manifests/xrds/xrd-developercombo.yaml

# Apply the Composition (recipe)
kubectl apply -f manifests/compositions/composition-azure-basic.yaml
```

### 4. Place Your First Order

```bash
# Deploy a development environment
kubectl apply -f manifests/claims/claim-dev.yaml

# Check the status
kubectl get developercombo -n development

# Wait for it to be ready
kubectl wait --for=condition=Ready developercombo/myapp-dev -n development --timeout=10m
```

## 📚 Examples Explained

### Example 1: Basic DeveloperCombo

The simplest “Happy Meal” - includes a database, storage, and networking.

```bash
cd examples/01-basic-developercombo
kubectl apply -f .
```

**What you get:**

- Azure Resource Group
- PostgreSQL Flexible Server (small size)
- Storage Account
- Virtual Network

### Example 2: Multi-Environment Setup

Deploy identical infrastructure across dev, staging, and production with different sizes.

```bash
cd examples/02-multi-environment
kubectl apply -f .
```

**What you get:**

- Dev: Small resources (Kids Meal)
- Staging: Medium resources (Regular Meal)
- Prod: Large resources (Super Size)

### Example 3: With Composition Functions

Advanced example using Crossplane v2 Composition Functions for security hardening.

```bash
cd examples/03-composition-functions
kubectl apply -f .
```

**Additional features:**

- Automatic encryption enablement
- TLS 1.2 minimum version
- Azure Defender integration
- Network security rules

### Example 4: Full Application Stack

Complete application infrastructure - the “Family Meal Deal”

```bash
cd examples/04-full-application-stack
kubectl apply -f .
```

**What you get:**

- DeveloperCombo (database + storage + network)
- Azure Monitor Log Analytics Workspace
- Application Insights
- Container Registry
- AKS Cluster (optional)

## 🎓 Learning Path

Follow this order to learn Crossplane progressively:

1. **Read the article** → [Dev.to article](https://www.google.com)
1. **Understand the metaphor** → Read `docs/metaphor-mapping.md`
1. **Deploy Example 1** → Basic DeveloperCombo
1. **Explore the XRD** → See how the menu is defined
1. **Modify the Composition** → Change the recipe
1. **Deploy Example 2** → Multi-environment setup
1. **Advanced features** → Composition Functions (Example 3)
1. **Build your own** → Create custom XRDs

## 🔧 Configuration

### Customizing the DeveloperCombo

Edit the Composition to change what resources are created:

```yaml
# manifests/compositions/composition-azure-basic.yaml

# Change database size mapping
patches:
- type: FromCompositeFieldPath
  fromFieldPath: spec.size
  toFieldPath: spec.forProvider.skuName
  transforms:
  - type: map
    map:
      small: B_Standard_B1ms      # Change this
      medium: GP_Standard_D2s_v3  # Change this
      large: GP_Standard_D4s_v3   # Change this
```

### Adding New Menu Items

Create a new XRD for different infrastructure patterns:

```bash
# Copy and modify the existing XRD
cp manifests/xrds/xrd-developercombo.yaml manifests/xrds/xrd-datastack.yaml

# Edit to define your new menu item
# Then create a corresponding Composition
```

## 🐛 Troubleshooting

### Common Issues

**Issue: Claim stays in `READY=False`**

```bash
# Check the claim status
kubectl describe developercombo <name> -n <namespace>

# Check provider health
kubectl get providers

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-storage
```

**Issue: Azure credentials not working**

```bash
# Verify the secret exists
kubectl get secret azure-credentials -n crossplane-system

# Verify ProviderConfig
kubectl get providerconfig

# Test Azure login manually
az login --service-principal \
  -u <clientId> \
  -p <clientSecret> \
  --tenant <tenantId>
```

**Issue: Provider installation stuck**

```bash
# Check provider status
kubectl get providers -o wide

# Check package runtime
kubectl get pods -n crossplane-system

# Check for network issues
kubectl describe provider provider-azure-storage
```

See `troubleshooting/common-issues.md` for more detailed solutions.

## 🌟 The Metaphor Explained

|Crossplane Concept                 |Fast-Food Metaphor                   |
|-----------------------------------|-------------------------------------|
|XRD (Composite Resource Definition)|Menu board with available items      |
|Composition                        |Recipe card in the kitchen           |
|Claim                              |Customer’s order                     |
|Composite Resource (XR)            |The completed meal                   |
|Provider                           |Kitchen station (grill, fryer, etc.) |
|Managed Resource                   |Individual food items (burger, fries)|
|ProviderConfig                     |Kitchen access credentials           |
|Crossplane Controller              |Counter staff taking orders          |
|Reconciliation Loop                |Kitchen checking order status        |
|Composition Functions              |Special preparation instructions     |
|CompositionRevisions               |Menu updates/new recipes             |

Full metaphor breakdown: `docs/metaphor-mapping.md`

## 📊 Real-World Use Cases

### Scenario 1: Multi-Tenant SaaS Platform

```yaml
# Each customer gets their own "combo"
apiVersion: example.com/v1alpha1
kind: DeveloperCombo
metadata:
  name: customer-acme-corp
  namespace: tenants
spec:
  size: medium
  includeDatabase: true
  storageSize: "100Gi"
```

### Scenario 2: Ephemeral Development Environments

```yaml
# Developers create/destroy environments on-demand
apiVersion: example.com/v1alpha1
kind: DeveloperCombo
metadata:
  name: feature-new-auth
  namespace: development
spec:
  size: small
  includeDatabase: true
  storageSize: "10Gi"
```

### Scenario 3: Disaster Recovery Setup

```yaml
# Identical infrastructure in secondary region
apiVersion: example.com/v1alpha1
kind: DeveloperCombo
metadata:
  name: myapp-prod-dr
  namespace: production-dr
  annotations:
    region: "northeurope"  # Different region
spec:
  size: large
  includeDatabase: true
  storageSize: "500Gi"
```

## 🤝 Contributing

We welcome contributions! Here’s how you can help:

1. **Add examples** - Create new use cases or patterns
1. **Improve documentation** - Fix typos, add clarity
1. **Create compositions** - Share your recipes
1. **Test on different clouds** - Try AWS, GCP variants
1. **Report issues** - Found a bug? Let us know!

### Contribution Guidelines

1. Fork the repository
1. Create a feature branch (`git checkout -b feature/amazing-composition`)
1. Test your changes thoroughly
1. Commit with clear messages (`git commit -m 'Add: new XRD for ML workloads'`)
1. Push to your fork (`git push origin feature/amazing-composition`)
1. Open a Pull Request

## 📖 Additional Resources

### Official Documentation

- [Crossplane Documentation](https://docs.crossplane.io/)
- [Crossplane v2 Release Notes](https://blog.crossplane.io/)
- [Azure Provider Docs](https://marketplace.upbound.io/providers/upbound/provider-azure/)

### Community

- [Crossplane Slack](https://slack.crossplane.io/)
- [Crossplane GitHub](https://github.com/crossplane/crossplane)
- [CNCF Crossplane Project](https://www.cncf.io/projects/crossplane/)

### Learning Materials

- [Original Article on Dev.to](https://www.google.com)
- [Crossplane Training Course](https://www.upbound.io/training)
- [Crossplane Community Meetings](https://github.com/crossplane/crossplane#get-involved)

### Related Projects

- [Upbound](https://www.upbound.io/) - Commercial Crossplane offering
- [Argo CD](https://argoproj.github.io/cd/) - GitOps for Crossplane
- [External Secrets Operator](https://external-secrets.io/) - Manage secrets

## 🏆 Why Crossplane?

**vs. Terraform:**

- ✅ Continuous reconciliation (not one-shot)
- ✅ Kubernetes-native (no separate state management)
- ✅ Automatic drift detection
- ✅ GitOps-ready out of the box

**vs. ARM Templates/Bicep:**

- ✅ Cloud-agnostic (same API, multiple clouds)
- ✅ Extensible (create custom providers)
- ✅ Uses existing K8s tooling (RBAC, namespaces, etc.)

**vs. Pulumi:**

- ✅ Declarative (vs imperative)
- ✅ Clear separation of concerns (platform vs. developers)
- ✅ API contracts through XRDs

## 📝 License

This project is licensed under the MIT License - see the <LICENSE> file for details.

## 👤 Author

**Willem van Heemstra**

- GitHub: [@vanHeemstraSystems](https://github.com/vanHeemstraSystems)
- LinkedIn: [Willem van Heemstra](https://www.linkedin.com/in/vanheemstra/)
- Dev.to: Article - [Fast Infrastructure with Crossplane](https://www.google.com)

Cloud Engineer and Security Domain Expert with 30 years of IT experience, specializing in cloud-native technologies, DevSecOps, and infrastructure automation.

## 🙏 Acknowledgments

- The Crossplane community for building an amazing tool
- Upbound for excellent provider implementations
- Everyone who uses the fast-food metaphor and finds it helpful!

## ⭐ Star History

If this repository helped you understand Crossplane, please give it a star! ⭐

-----

**Ready to serve cloud infrastructure the fast-food way?** Start with Example 1 and work your way up! 🚀

Have questions? [Open an issue](https://github.com/software-journey/fast-infrastructure/issues) or join the discussion!
