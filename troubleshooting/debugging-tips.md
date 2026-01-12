# Debugging Tips for Crossplane

A practical guide to debugging Crossplane issues like a pro.

## Quick Diagnostics Checklist

```bash
# The "Is it working?" 5-second check
kubectl get providers                    # All should show HEALTHY: True
kubectl get xrd                         # Your XRDs should be listed
kubectl get compositions                # Your compositions should be listed
kubectl get developercombo -A           # Your claims and their status
```

If any of these fail, you have your starting point!

## Understanding the Resource Hierarchy

Crossplane creates a hierarchy of resources:

```
Claim (namespace-scoped)
  └── Composite Resource (cluster-scoped)
      └── Managed Resources (cluster-scoped)
          └── Actual Cloud Resources (in Azure)
```

**Debugging flow:** Start at the top (Claim) and work your way down.

## Essential kubectl Commands

### 1. Check Claim Status

```bash
# List all claims
kubectl get developercombo -A

# Detailed information
kubectl describe developercombo <name> -n <namespace>

# Watch for changes
watch kubectl get developercombo -A

# Get as YAML to see full status
kubectl get developercombo <name> -n <namespace> -o yaml
```

**What to look for:**
- `Status.Ready: True/False`
- `Status.Conditions` - shows detailed progress
- `Status.ResourceRefs` - links to managed resources

### 2. Find the Composite Resource

```bash
# Claims reference a Composite Resource (XR)
kubectl get composite

# Or filter by type
kubectl get xdevelopercombo

# Describe it
kubectl describe xdevelopercombo <name>
```

### 3. Check Managed Resources

```bash
# List all managed resources
kubectl get managed

# Or be specific
kubectl get resourcegroup
kubectl get flexibleserver
kubectl get storageaccount
kubectl get virtualnetwork

# Describe a specific resource
kubectl describe flexibleserver <name>
```

**Pro tip:** The managed resource names are auto-generated. Use `-o wide` or `describe` to match them to your claim.

## Reading Resource Status

Every Crossplane resource has a `Status` section with critical information:

```yaml
status:
  conditions:
  - type: Ready
    status: "False"  # Not ready yet
    reason: Creating
    message: "Creating cloud resource"
  
  - type: Synced
    status: "True"  # Crossplane has synced
    reason: ReconcileSuccess
```

**Key condition types:**
- **Ready**: Is the resource fully provisioned?
- **Synced**: Has Crossplane successfully applied the configuration?

## Common Status Messages Decoded

### "Waiting for crossplane to be ready"
**Meaning:** Claim is waiting for the Composite Resource to exist  
**Action:** Check if XRD and Composition are properly installed

### "Waiting for reconciliation"
**Meaning:** Provider is working on creating the resource  
**Action:** Wait, or check provider logs if stuck >10 minutes

### "Cannot resolve resource references"
**Meaning:** A resource needs another resource that doesn't exist yet  
**Action:** Check `spec.forProvider` for selectors that might not match

### "Invalid resource configuration"
**Meaning:** The resource spec has errors  
**Action:** Check provider logs for details

## Checking Provider Logs

Providers do the actual work of creating cloud resources. Their logs are invaluable:

```bash
# List all providers
kubectl get providers

# Find provider pods
kubectl get pods -n crossplane-system

# View logs for a specific provider
kubectl logs -n crossplane-system <provider-pod-name>

# Follow logs in real-time
kubectl logs -n crossplane-system <provider-pod-name> -f

# View previous logs if pod restarted
kubectl logs -n crossplane-system <provider-pod-name> --previous
```

**What to look for in logs:**
- Authentication errors
- API rate limiting
- Resource creation failures
- Validation errors

## Checking Crossplane Controller Logs

```bash
# Main Crossplane controller
kubectl logs -n crossplane-system deployment/crossplane

# Follow logs
kubectl logs -n crossplane-system deployment/crossplane -f

# Get logs with timestamps
kubectl logs -n crossplane-system deployment/crossplane --timestamps
```

## Using Events

Kubernetes events provide a timeline of what happened:

```bash
# Events for a specific claim
kubectl describe developercombo <name> -n <namespace> | grep -A10 Events

# All events in a namespace
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# All events in all namespaces
kubectl get events -A --sort-by='.lastTimestamp'

# Filter for errors/warnings
kubectl get events -A | grep -i error
kubectl get events -A | grep -i warning
```

## Debugging Workflow Example

Let's walk through debugging a stuck claim:

```bash
# 1. Check the claim
kubectl get developercombo myapp-dev -n development
# Output: READY=False, AGE=15m

# 2. Get detailed status
kubectl describe developercombo myapp-dev -n development
# Look at Conditions and Events

# 3. Find the composite resource
kubectl get composite | grep myapp-dev
# Output: myapp-dev-xyz123

# 4. Check the composite
kubectl describe xdevelopercombo myapp-dev-xyz123
# Look at Status.ResourceRefs

# 5. Check managed resources
kubectl get managed | grep myapp-dev
# Output: Shows resourcegroup, flexibleserver, etc.

# 6. Find the failing resource
kubectl describe flexibleserver myapp-dev-db-abc456
# Look at Status.Conditions.Message

# 7. Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-dbforpostgresql
# Look for errors related to your resource
```

## Debugging Compositions

### Test composition changes safely:

```bash
# Create a test claim
cat <<EOF | kubectl apply -f -
apiVersion: example.com/v1alpha1
kind: DeveloperCombo
metadata:
  name: test-composition
  namespace: testing
spec:
  size: small
  includeDatabase: false  # Faster for testing
EOF

# Monitor it
watch kubectl get developercombo test-composition -n testing

# Check what resources were created
kubectl get managed | grep test-composition

# Delete when done
kubectl delete developercombo test-composition -n testing
```

### Validate composition syntax:

```bash
# Dry-run to check for errors
kubectl apply -f manifests/compositions/composition-azure-basic.yaml --dry-run=client

# Validate against the API server
kubectl apply -f manifests/compositions/composition-azure-basic.yaml --dry-run=server
```

## Debugging Patches

Patches are where most composition errors occur:

```yaml
# Add debug output to see what's being patched
patches:
- type: FromCompositeFieldPath
  fromFieldPath: spec.size
  toFieldPath: spec.forProvider.skuName
  transforms:
  - type: map
    map:
      small: B_Standard_B1ms
      medium: GP_Standard_D2s_v3
      # What if size is "large" but we forgot to add it?
```

**Debug approach:**
1. Check the claim's `spec.size` value
2. Check if the managed resource has the expected `spec.forProvider.skuName`
3. Add the missing mapping

```bash
# View the managed resource to see what was actually applied
kubectl get flexibleserver <name> -o yaml | grep -A5 "forProvider:"
```

## Debugging Network Issues

Provider needs internet access to download and to call Azure APIs:

```bash
# Check if provider pod can reach internet
kubectl exec -n crossplane-system <provider-pod> -- curl -I https://management.azure.com

# Check DNS resolution
kubectl exec -n crossplane-system <provider-pod> -- nslookup management.azure.com
```

## Debugging Authentication

```bash
# Verify the secret exists
kubectl get secret azure-credentials -n crossplane-system

# Check the secret contents (be careful with this!)
kubectl get secret azure-credentials -n crossplane-system -o jsonpath='{.data.credentials}' | base64 -d | jq

# Verify ProviderConfig is pointing to the secret
kubectl describe providerconfig default
```

## Performance Debugging

### Why is reconciliation slow?

```bash
# Check Crossplane resource usage
kubectl top pod -n crossplane-system

# Check for resource constraints
kubectl describe pod -n crossplane-system <crossplane-pod>

# Look for OOMKilled or resource limits
kubectl get pods -n crossplane-system -o yaml | grep -A5 "resources:"
```

### Why are resources taking forever to create?

**Common causes:**
1. Azure resource provisioning is genuinely slow (databases take 5-10 min)
2. API rate limiting (check provider logs)
3. Resource quotas exceeded in Azure
4. Network latency to Azure APIs

```bash
# Check in Azure Portal to see if resources are being created
# Sometimes Crossplane shows "Creating" but Azure is actually working on it
```

## Useful Labels and Annotations

Add these to your claims for easier debugging:

```yaml
metadata:
  labels:
    team: platform
    environment: dev
    app: myapp
  annotations:
    debug: "true"
    created-by: "willem"
    jira-ticket: "PLAT-123"
```

Then filter:
```bash
kubectl get developercombo -A -l team=platform
kubectl get developercombo -A -l environment=dev
```

## Interactive Debugging Tools

### Using K9s (if available)

```bash
# Launch k9s
k9s

# Navigate:
# :xrd          - View XRDs
# :compositions - View Compositions
# :managed      - View managed resources
# :providers    - View providers
```

### Using kubectx/kubens

```bash
# Switch namespace quickly
kubens development
kubectl get developercombo

kubens staging
kubectl get developercombo
```

## Emergency Procedures

### Stuck claim won't delete

```bash
# Remove finalizers (THIS WILL NOT DELETE AZURE RESOURCES)
kubectl patch developercombo <name> -n <namespace> \
  -p '{"metadata":{"finalizers":[]}}' --type=merge

kubectl delete developercombo <name> -n <namespace> --force --grace-period=0
```

### Provider crashed and won't restart

```bash
# Delete the provider pod to force restart
kubectl delete pod -n crossplane-system <provider-pod-name>

# Or restart the whole provider
kubectl rollout restart deployment -n crossplane-system <provider-deployment>
```

### Complete reset (nuclear option)

```bash
# WARNING: This deletes EVERYTHING Crossplane-related
# Azure resources may remain orphaned!

# Delete all claims
kubectl delete developercombo --all -A

# Delete all managed resources (be VERY careful)
kubectl delete managed --all

# Reinstall Crossplane
helm uninstall crossplane -n crossplane-system
kubectl delete namespace crossplane-system
# Then run setup.sh again
```

## Debugging Best Practices

1. **Start simple**: Deploy dev environment first, not all three at once
2. **One change at a time**: Modify composition, test, then modify again
3. **Use version control**: Keep your manifests in Git
4. **Add comments**: Document why you made specific choices in compositions
5. **Test locally**: Use kind/minikube for composition testing before production
6. **Enable verbose logging**: When debugging, increase log levels

## Creating Debug Claims

Keep a "debug" claim template:

```yaml
apiVersion: example.com/v1alpha1
kind: DeveloperCombo
metadata:
  name: debug-test
  namespace: debug
  annotations:
    debug: "true"
spec:
  size: small           # Fastest to provision
  includeDatabase: false # Skip slow resources initially
  storageSize: "10Gi"   # Minimum size
```

## Useful Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
alias kgd='kubectl get developercombo -A'
alias kgm='kubectl get managed'
alias kgp='kubectl get providers'
alias kgc='kubectl get compositions'
alias kdesc='kubectl describe'
alias klogs='kubectl logs -n crossplane-system'
alias kwatch='watch kubectl get developercombo -A'
```

## When to Ask for Help

You should reach out to the community when:
- Provider logs show errors you don't understand
- Resources work in Azure Portal but not through Crossplane
- You've followed all debugging steps and still stuck after 30 minutes
- You suspect a bug in Crossplane or a provider

**Where to ask:**
- Crossplane Slack: https://slack.crossplane.io/
- GitHub Discussions: https://github.com/crossplane/crossplane/discussions
- Stack Overflow: Tag with `crossplane`

**What to include:**
- Crossplane version: `kubectl get deployment crossplane -n crossplane-system -o yaml | grep image:`
- Provider versions: `kubectl get providers -o yaml`
- Your XRD (sanitized)
- Your Composition (sanitized)
- Your Claim (sanitized)
- Relevant logs
- Error messages
- What you've tried

## Pro Tips

1. **Use `--watch` flag**: `kubectl get developercombo -A --watch`
2. **JSON output for scripting**: `kubectl get developercombo -o json | jq`
3. **Filter by status**: `kubectl get developercombo -A -o json | jq '.items[] | select(.status.ready==false)'`
4. **Check resource age**: Old resources stuck in "Creating" are suspicious
5. **Compare working vs broken**: If one environment works, compare manifests
6. **Check Azure Portal**: Sometimes the issue is on Azure's side, not Crossplane

## Remember

Debugging Crossplane is like debugging any distributed system:
- Follow the logs
- Check the status conditions
- Understand the resource hierarchy
- Be patient (cloud resources are slow)
- Read error messages carefully
- When in doubt, delete and recreate (start small!)

Happy debugging! 🐛🔍