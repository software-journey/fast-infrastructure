# Fast Infrastructure: Understanding Crossplane like a Fast Food Restaurant

## I'll Have a Kubernetes Cluster with a Side of SQL Database, Please: Understanding Crossplane

*Or: How I learned to stop worrying and love infrastructure abstraction*

---

Ever stood in front of a fast-food counter and marveled at the simplicity? You say "I'll have the number 3," and minutes later, you're walking away with a burger, fries, drink, and a toy for the kids. You didn't need to know how to operate a deep fryer, flip a burger, or calibrate a soda fountain. You just ordered from the menu.

Now imagine if provisioning cloud infrastructure worked the same way.

Spoiler alert: With Crossplane, it does.

## The Problem: Too Many Chefs in the Cloud Kitchen

Let me paint a picture. You're a developer who needs a database, some storage, and maybe a Kubernetes cluster for your new application. In the traditional world, this means:

1. Learning Azure CLI, ARM templates, or Bicep
2. Understanding Azure AD roles, VNet configurations, and Network Security Groups
3. Writing Terraform (and hoping your syntax is perfect)
4. Coordinating with the platform team who controls the "real" credentials
5. Waiting... and waiting... and maybe filling out a ticket

It's like having to go into the kitchen, learn each cooking station, and prepare your own meal while the staff watches skeptically.

There has to be a better way.

## Enter Crossplane: The Fast-Food Franchise Model for Cloud Infrastructure

Crossplane brings the fast-food counter experience to cloud infrastructure. It provides:

- **A menu** (Composite Resource Definitions - XRDs)
- **Standardized recipes** (Compositions)
- **A friendly counter staff** (Crossplane control plane)
- **Skilled kitchen staff** (Cloud Providers)
- **Self-service ordering** (Kubernetes-native APIs)

Let's break down how this works, complete with actual code examples.

## The Menu: Composite Resource Definitions (XRDs)

Every good restaurant starts with a menu. In Crossplane, the **XRD** is your menu board. It defines *what* customers can order without revealing *how* it's made.

Here's our "Happy Meal" equivalent - let's call it a `DeveloperCombo`:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xdevelopercombo.example.com
spec:
  group: example.com
  names:
    kind: XDeveloperCombo
    plural: xdevelopercombo
  claimNames:
    kind: DeveloperCombo
    plural: developercombo
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              size:
                type: string
                description: "Size of your combo: small, medium, or large"
                enum:
                - small
                - medium
                - large
              includeDatabase:
                type: boolean
                description: "Want a database with that?"
                default: true
              storageSize:
                type: string
                description: "Storage account size"
                default: "10Gi"
            required:
            - size
          status:
            type: object
            properties:
              ready:
                type: boolean
              endpoint:
                type: string
```

**What just happened?** 

We created a menu item called `DeveloperCombo`. Customers (developers) can order it in three sizes and choose whether they want a database. They don't need to know about Azure SQL, Storage Account policies, or VNet configurations. They just pick: small, medium, or large.

Just like ordering: "I'll have a medium Happy Meal, please."

## The Recipe: Compositions

Behind every menu item is a recipe. The **Composition** tells the kitchen (cloud providers) *exactly* how to prepare each component.

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: developercombo.azure.example.com
  labels:
    provider: azure
    combo: developer
spec:
  compositeTypeRef:
    apiVersion: example.com/v1alpha1
    kind: XDeveloperCombo
  
  mode: Pipeline
  pipeline:
  - step: patch-and-transform
    functionRef:
      name: function-patch-and-transform
    input:
      apiVersion: pt.fn.crossplane.io/v1beta1
      kind: Resources
      resources:
      
      # The "Burger" - An Azure SQL Database
      - name: database
        base:
          apiVersion: dbforpostgresql.azure.upbound.io/v1beta1
          kind: FlexibleServer
          metadata:
            annotations:
              crossplane.io/external-name: developer-combo-db
          spec:
            forProvider:
              location: westeurope
              resourceGroupNameSelector:
                matchControllerRef: true
              administratorLogin: combouser
              version: "15"
              storageMb: 32768
              skuName: B_Standard_B1ms
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.size
          toFieldPath: spec.forProvider.skuName
          transforms:
          - type: map
            map:
              small: B_Standard_B1ms
              medium: GP_Standard_D2s_v3
              large: GP_Standard_D4s_v3
        - type: ToCompositeFieldPath
          fromFieldPath: status.atProvider.fqdn
          toFieldPath: status.endpoint
        readinessChecks:
        - type: MatchString
          fieldPath: status.atProvider.state
          matchString: "Ready"
      
      # The "Fries" - An Azure Storage Account
      - name: storage
        base:
          apiVersion: storage.azure.upbound.io/v1beta1
          kind: Account
          spec:
            forProvider:
              location: westeurope
              resourceGroupNameSelector:
                matchControllerRef: true
              accountTier: Standard
              accountReplicationType: LRS
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.storageSize
          toFieldPath: spec.forProvider.tags.size
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: metadata.annotations[crossplane.io/external-name]
          transforms:
          - type: string
            string:
              fmt: "combo%sstorage"
              type: Format
      
      # The "Drink" - A Virtual Network
      - name: network
        base:
          apiVersion: network.azure.upbound.io/v1beta1
          kind: VirtualNetwork
          spec:
            forProvider:
              location: westeurope
              resourceGroupNameSelector:
                matchControllerRef: true
              addressSpace:
              - 10.0.0.0/16
              tags:
                Name: developer-combo-vnet
      
      # The "Tray" - Resource Group to hold everything
      - name: resourcegroup
        base:
          apiVersion: azure.upbound.io/v1beta1
          kind: ResourceGroup
          spec:
            forProvider:
              location: westeurope
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: metadata.annotations[crossplane.io/external-name]
          transforms:
          - type: string
            string:
              fmt: "rg-combo-%s"
              type: Format
```

**What's cooking?**

This Composition is like the kitchen's recipe card. When someone orders a `DeveloperCombo`:

1. **The Tray (Resource Group)**: An Azure Resource Group to organize everything
2. **The Burger (Database)**: An Azure Database for PostgreSQL Flexible Server, sized according to the order (small = B1ms, medium = D2s_v3, large = D4s_v3)
3. **The Fries (Storage)**: An Azure Storage Account for storing application data
4. **The Drink (Network)**: A Virtual Network for networking (because even combo meals need connectivity)

Notice the `patches` section? That's like special instructions: "No pickles" or "Extra sauce." Here we're saying: "If they ordered 'medium', make the database a `GP_Standard_D2s_v3`."

## Placing Your Order: The Claim

Now comes the magic moment. A developer walks up to the counter (their Kubernetes cluster) and places an order:

```yaml
apiVersion: example.com/v1alpha1
kind: DeveloperCombo
metadata:
  name: my-awesome-app-infra
  namespace: team-awesome
spec:
  size: medium
  includeDatabase: true
  storageSize: "50Gi"
  
  compositionSelector:
    matchLabels:
      provider: azure
```

That's it. That's the whole order.

No Azure CLI. No ARM templates. No Azure AD role juggling. Just: "I'd like a medium Developer Combo, please, with Azure as the provider."

## Behind the Counter: What Happens Next

Here's where Crossplane shows its real magic. When that claim lands:

1. **The counter staff (Crossplane controller)** receives the order
2. **Validates it against the menu** (XRD schema)
3. **Finds the right recipe** (Composition matching `provider: azure`)
4. **Sends orders to the kitchen stations**:
   - Azure Provider creates the Resource Group
   - Azure Provider creates the PostgreSQL Flexible Server
   - Azure Provider creates the Storage Account
   - Azure Provider creates the Virtual Network
5. **Monitors preparation** (reconciliation loops)
6. **Serves the completed meal** (updates the Claim status)

All of this happens automatically, continuously, and declaratively.

## Checking Your Order Status

Want to know if your infrastructure is ready?

```bash
kubectl get developercombo -n team-awesome
```

```
NAME                     READY   ENDPOINT                                    AGE
my-awesome-app-infra     True    developer-combo-db.postgres.database...     5m
```

Your meal is ready! The `READY` column shows `True`, and you even got the database endpoint where you can start connecting.

## The Kitchen Stations: Providers

In Crossplane v2, **Providers** are like specialized kitchen stations:

- **provider-azure**: The European food station (Azure resources)
- **provider-aws**: The American food station (AWS resources)
- **provider-gcp**: The Asian fusion station (GCP resources)
- **provider-kubernetes**: The salad bar (K8s resources)

Each provider knows how to prepare its specialty items. Installing a provider is like hiring kitchen staff:

```yaml
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
  name: provider-azure-sql
spec:
  package: xpkg.upbound.io/upbound/provider-azure-dbforpostgresql:v1.3.0
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-network
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v1.3.0
```

## Provider Configuration: Kitchen Access Credentials

Even the best chefs need access to their equipment. **ProviderConfig** is like giving your kitchen staff the keys:

```yaml
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
```

This says: "Dear Azure Provider, here are the credentials to access the Azure subscription. Go forth and create resources!"

The secret contains your Azure Service Principal credentials:

```bash
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-literal=credentials='{"clientId": "your-client-id",
  "clientSecret": "your-client-secret",
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id"}'
```

## Upgrades and Menu Changes: CompositionRevisions

What happens when corporate decides to update the Happy Meal recipe? Maybe they swap cookies for apple slices.

In Crossplane, **CompositionRevisions** handle this:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: developercombo.azure.example.com
spec:
  compositeTypeRef:
    apiVersion: example.com/v1alpha1
    kind: XDeveloperCombo
  
  publishConnectionDetailsWithStoreConfigRef:
    name: default
  
  revisionActivationPolicy: Automatic
  revisionHistoryLimit: 3
  
  # ... rest of composition
```

With `revisionActivationPolicy: Automatic`, existing orders automatically get the new recipe. With `Manual`, existing customers keep their old version until they explicitly upgrade.

"I ordered my Happy Meal before you changed the recipe. I want my cookies, not apple slices!"

## Special Orders: Composition Functions

Sometimes customers have special requests: "Can I get extra sauce?" or "No pickles, please."

**Composition Functions** (new in Crossplane v2) let you add custom logic:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: developercombo.custom.example.com
spec:
  mode: Pipeline
  pipeline:
  - step: patch-and-transform
    functionRef:
      name: function-patch-and-transform
    input:
      # Standard patching
      
  - step: add-security-extras
    functionRef:
      name: function-security-hardening
    input:
      apiVersion: security.fn.crossplane.io/v1beta1
      kind: HardenResources
      spec:
        enableEncryption: true
        minimumTLSVersion: "1.2"
        enableDefender: true
```

This is like saying: "After preparing the standard meal, also add extra security seasoning and enable Azure Defender."

## Platform Team vs. Developers: The Beautiful Separation

Here's where Crossplane truly shines:

**Platform Team (Restaurant Management)**:
- Designs the menu (XRDs)
- Creates the recipes (Compositions)
- Manages provider credentials (ProviderConfigs)
- Sets standards and best practices
- Controls costs and governance

**Developers (Customers)**:
- Order from the menu (create Claims)
- Specify their preferences (size, options)
- Receive ready-to-use infrastructure
- Focus on building applications
- No cloud provider expertise required

It's a win-win. Platform teams ensure consistency, security, and cost control. Developers get self-service infrastructure without the complexity.

## Real-World Example: Multi-Environment Combos

Let's get practical. You need different infrastructure for dev, staging, and production:

```yaml
# Development Environment - The "Kids Meal"
apiVersion: example.com/v1alpha1
kind: DeveloperCombo
metadata:
  name: myapp-dev
  namespace: development
spec:
  size: small
  includeDatabase: true
  storageSize: "10Gi"
---
# Staging Environment - The "Regular Meal"
apiVersion: example.com/v1alpha1
kind: DeveloperCombo
metadata:
  name: myapp-staging
  namespace: staging
spec:
  size: medium
  includeDatabase: true
  storageSize: "50Gi"
---
# Production Environment - The "Super Size"
apiVersion: example.com/v1alpha1
kind: DeveloperCombo
metadata:
  name: myapp-prod
  namespace: production
spec:
  size: large
  includeDatabase: true
  storageSize: "500Gi"
```

Same menu, different sizes. The platform team's recipe ensures they're all built the same way, just scaled appropriately.

## The Cleanup: Deletion Policies

What happens when you're done with your meal?

```yaml
spec:
  resources:
  - name: database
    base:
      apiVersion: dbforpostgresql.azure.upbound.io/v1beta1
      kind: FlexibleServer
      spec:
        deletionPolicy: Delete  # Clean up when done
        # OR
        # deletionPolicy: Orphan  # Leave it for later
```

- **Delete**: Take your tray to the trash, clean up everything
- **Orphan**: Leave the leftovers on the table (keep cloud resources even after deleting the Claim)

Useful when you want to delete the Kubernetes object but keep the actual Azure resources.

## Observability: Is My Order Ready?

Crossplane v2 provides excellent observability. Check your order status:

```bash
kubectl describe developercombo my-awesome-app-infra -n team-awesome
```

```yaml
Status:
  Conditions:
    Last Transition Time:  2024-01-12T10:30:00Z
    Reason:               Available
    Status:               True
    Type:                 Ready
    
    Last Transition Time:  2024-01-12T10:30:00Z
    Reason:               ReconcileSuccess
    Status:               True
    Type:                 Synced
  
  Connection Details:
    Last Published Time:  2024-01-12T10:30:00Z
  
  Endpoint:  developer-combo-db.postgres.database.azure.com
```

Your infrastructure is `Ready` and `Synced`. Bon appétit!

## Why This Matters: The Real Value

By now you might be thinking: "This seems like a lot of YAML just to create an Azure SQL Database."

And you'd be right... for a single instance.

But imagine:
- **20 development teams** all needing the same "combo"
- **Consistent security policies** across all infrastructure
- **No accidental cost overruns** (platform team controls the recipes)
- **Developers self-service** without Azure Portal access
- **Multi-cloud flexibility** (swap Azure provider for AWS provider, same menu)
- **GitOps-ready** (all infrastructure as code in Git)
- **Audit trails** (Kubernetes events track every change)

That's when Crossplane becomes transformative.

## Advanced Orders: Composite Compositions

Want to get fancy? You can compose Compositions from other Compositions:

```yaml
apiVersion: example.com/v1alpha1
kind: FullApplicationStack
metadata:
  name: my-complete-app
spec:
  developerCombo:
    size: medium
  monitoring:
    enabled: true
    logAnalyticsWorkspace: true
  cicd:
    gitRepo: https://github.com/myorg/myapp
```

This is like ordering a "Family Meal Deal" that includes multiple Happy Meals plus extras. One order, entire application infrastructure deployed.

## The Secret Sauce: Why Crossplane > Other Tools

**vs. Terraform:**
- Crossplane is **continuous reconciliation** (Terraform is one-shot apply)
- Crossplane is **Kubernetes-native** (Terraform needs state management)
- Crossplane **supports drift detection automatically**

**vs. ARM Templates/Bicep:**
- Crossplane is **cloud-agnostic** (one menu, multiple kitchens)
- Crossplane is **extensible** (add your own providers)
- Crossplane **works with existing K8s tooling** (GitOps, RBAC, etc.)

**vs. Pulumi:**
- Crossplane is **declarative** (Pulumi is imperative)
- Crossplane **separates concerns** (platform vs. developers)
- Crossplane **provides abstractions** (XRDs as API contracts)

## Getting Started: Opening Your Own Franchise

Want to try this yourself? Here's the quick setup:

```bash
# Install Crossplane (the restaurant franchise)
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm install crossplane \
  crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace

# Install Azure Providers (hire kitchen staff)
kubectl apply -f - <<EOF
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
  name: provider-azure-sql
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

# Create Azure Service Principal
az ad sp create-for-rbac \
  --name crossplane-sp \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID

# Configure credentials (give staff access to equipment)
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-literal=credentials='{"clientId": "your-client-id",
  "clientSecret": "your-client-secret",
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id"}'

# Create ProviderConfig
kubectl apply -f providerconfig.yaml

# Apply your XRD and Composition (design the menu)
kubectl apply -f xrd.yaml
kubectl apply -f composition.yaml

# Place your first order!
kubectl apply -f claim.yaml
```

## Common Pitfalls: When the Order Gets Messed Up

**Issue: "My claim stays in `READY=False` forever"**
- Check: `kubectl describe` the claim and look at `Status.Conditions`
- Usually: Provider credentials are wrong, or Azure resource failed to create
- Fix: Check ProviderConfig and Azure subscription quotas

**Issue: "I updated my Composition but nothing changed"**
- Check: Existing claims use the old `CompositionRevision`
- Fix: Either set `revisionActivationPolicy: Automatic` or manually update claims

**Issue: "I deleted my claim but Azure resources still exist"**
- Check: `deletionPolicy` is probably set to `Orphan`
- Fix: Set `deletionPolicy: Delete` in the Composition

**Issue: "Provider installation is stuck"**
- Check: `kubectl get providers` and look for health status
- Usually: Network issues or package registry problems
- Fix: Check Crossplane logs: `kubectl logs -n crossplane-system deployment/crossplane`

## The Future: What's Coming to the Menu

Crossplane v2 introduced major improvements:
- **Composition Functions** (custom logic pipelines)
- **Better observability** (enhanced status reporting)
- **Improved performance** (faster reconciliation)
- **Package management** (easier provider installation)

The roadmap includes even more exciting features like enhanced composition testing, better multi-tenancy, and improved developer experience.

## Conclusion: Your Infrastructure, Served Fresh Daily

Crossplane transforms cloud infrastructure from a complex, error-prone cooking process into a simple, self-service menu experience. Platform teams design the menu and recipes. Developers order what they need. Infrastructure gets provisioned automatically, consistently, and securely.

No secret sauce required. No cooking skills needed. Just order from the menu and get exactly what you need.

The next time someone asks you to explain Crossplane, just say: "It's like a fast-food counter for cloud infrastructure."

And watch their eyes light up with understanding.

---

## Your Turn: What's On Your Menu?

I'd love to hear how your organization is using Crossplane! Are you building similar "combo meals" for your developers? What infrastructure patterns have you abstracted into self-service resources? Any creative uses of Composition Functions?

Drop a comment below and share:
- What's the most complex "menu item" (XRD) you've created?
- How has Crossplane changed your platform team's workflow?
- What challenges did you face during adoption?
- Any tips for teams just starting their Crossplane journey?
- Are you using Azure, AWS, GCP, or multi-cloud? What's your experience?

Let's learn from each other's experiences and build better infrastructure menus together!

---

**About the Author**

*Willem van Heemstra is a Cloud Engineer and Security Domain Expert with nearly 30 years of IT experience, specializing in cloud-native technologies, DevSecOps, and infrastructure automation. When not architecting cloud platforms, he's probably debugging Kubernetes clusters or teaching his dachshunds new tricks (the dogs, not the infrastructure).*

---

## Bonus: Additional Resources

- [Crossplane Official Documentation](https://docs.crossplane.io/)
- [Upbound Provider Marketplace](https://marketplace.upbound.io/)
- [Crossplane Slack Community](https://slack.crossplane.io/)
- [Azure Provider Documentation](https://marketplace.upbound.io/providers/upbound/provider-azure/)
- [GitHub Repository of this article](https://github.com/software-journey/fast-infrastructure) 

---

**Did you find this helpful? Give it a clap! 👏 Want more cloud-native analogies? Follow me for more articles where I explain complex tech through everyday metaphors.**