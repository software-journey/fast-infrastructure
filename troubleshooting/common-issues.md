# Troubleshooting Guide: Common Issues

When your infrastructure "order" doesn't arrive as expected, here's how to fix it.

## Table of Contents
- [Claim Status Issues](#claim-status-issues)
- [Provider Problems](#provider-problems)
- [Azure Credential Issues](#azure-credential-issues)
- [Resource Creation Failures](#resource-creation-failures)
- [Performance Issues](#performance-issues)
- [Cleanup Problems](#cleanup-problems)

---

## Claim Status Issues

### Issue: Claim stays in `READY=False` forever

**Symptoms:**
```bash
$ kubectl get developercombo -n development
NAME         READY   ENDPOINT   AGE
myapp-dev    False              5m
```

**Diagnosis:**
```bash
# Check detailed status
kubectl describe developercombo myapp-dev -n development

# Look at the conditions section
# Check for error messages
```

**Common Causes:**

1. **Provider not ready**
```bash
# Check provider health
kubectl get providers

# Should show "HEALTHY: True"
NAME                              INSTALLED   HEALTHY   AGE
provider-azure-storage           True        True      10m
provider-azure-dbforpostgresql   True        True      10m
provider-azure-network           True        True      10m
```

2. **Azure credentials invalid**
```bash
# Verify secret exists
kubectl get secret azure-credentials -n crossplane-system

# Check ProviderConfig
kubectl get providerconfig
kubectl describe providerconfig default
```

3. **Resource creation failed**
```bash
# Check managed resources
kubectl get managed

# Get details on failed resource
kubectl describe <resource-type> <resource-name>
```

**Solutions:**
- Wait for providers to become healthy (can take 2-5 minutes after installation)
- Verify Azure credentials are correct
- Check Azure subscription quotas
- Ensure resource names are valid (lowercase, no special characters for storage accounts)

---

### Issue: Claim created but no resources appear

**Symptoms:**
```bash
$ kubectl get developercombo myapp-dev -n development
NAME         READY   AGE
myapp-dev    False   1m

$ kubectl get managed
No resources found
```

**Diagnosis:**
```bash
# Check if composition is selected
kubectl describe developercombo myapp-dev -n development | grep -A5 "Composition"

# Check events
kubectl get events -n development --sort-by='.lastTimestamp'
```

**Solutions:**
1. Verify XRD is installed:
```bash
kubectl get xrd
```

2. Verify Composition exists and matches selector:
```bash
kubectl get compositions
kubectl describe composition developercombo.azure.example.com
```

3. Check composition selector labels match:
```yaml
# In claim
compositionSelector:
  matchLabels:
    provider: azure

# In composition metadata
labels:
  provider: azure  # Must match!
```

---

## Provider Problems

### Issue: Provider installation stuck

**Symptoms:**
```bash
$ kubectl get providers
NAME                            INSTALLED   HEALTHY   AGE
provider-azure-storage          Unknown     Unknown   10m
```

**Diagnosis:**
```bash
# Check provider pods
kubectl get pods -n crossplane-system

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-storage

# Check for image pull issues
kubectl describe pod -n crossplane-system <provider-pod-name>
```

**Solutions:**
1. Check internet connectivity from cluster
2. Verify package registry is accessible
3. Check for sufficient cluster resources:
```bash
kubectl top nodes
kubectl describe nodes
```

4. Restart Crossplane if needed:
```bash
kubectl rollout restart deployment crossplane -n crossplane-system
```

---

### Issue: Provider showing as unhealthy

**Symptoms:**
```bash
$ kubectl get providers
NAME                     INSTALLED   HEALTHY   AGE
provider-azure-storage   True        False     15m
```

**Diagnosis:**
```bash
# Check provider pod status
kubectl get pods -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-storage

# Check provider logs
kubectl logs -n crossplane-system <provider-pod-name>

# Common error: "cannot get ProviderConfig"
```

**Solutions:**
1. Ensure ProviderConfig exists:
```bash
kubectl get providerconfig
```

2. Verify credentials secret:
```bash
kubectl get secret azure-credentials -n crossplane-system
kubectl get secret azure-credentials -n crossplane-system -o jsonpath='{.data.credentials}' | base64 -d | jq
```

3. Test Azure credentials manually:
```bash
# Extract credentials
kubectl get secret azure-credentials -n crossplane-system -o json | \
  jq -r '.data.credentials' | base64 -d > /tmp/creds.json

# Test login
az login --service-principal \
  -u $(cat /tmp/creds.json | jq -r '.clientId') \
  -p $(cat /tmp/creds.json | jq -r '.clientSecret') \
  --tenant $(cat /tmp/creds.json | jq -r '.tenantId')

# Clean up
rm /tmp/creds.json
```

---

## Azure Credential Issues

### Issue: Authentication failed errors

**Error in logs:**
```
cannot create resource: Azure authentication failed
```

**Solutions:**

1. **Recreate Service Principal:**
```bash
./scripts/azure-setup.sh
```

2. **Verify Service Principal has correct role:**
```bash
# Get Service Principal ID
SP_ID=$(kubectl get secret azure-credentials -n crossplane-system -o json | \
  jq -r '.data.credentials' | base64 -d | jq -r '.clientId')

# Check role assignment
az role assignment list --assignee $SP_ID --output table
```

3. **Ensure subscription ID is correct:**
```bash
# Get subscription from secret
kubectl get secret azure-credentials -n crossplane-system -o json | \
  jq -r '.data.credentials' | base64 -d | jq -r '.subscriptionId'

# Compare with current
az account show --query id -o tsv
```

---

## Resource Creation Failures

### Issue: Storage Account creation fails

**Error:**
```
StorageAccountAlreadyExists: The storage account named 'stcombo...' is already taken
```

**Solution:**
Storage account names must be globally unique. The composition generates names, but collisions can occur.

```bash
# Check what name was attempted
kubectl describe storageaccount <resource-name>

# Delete the claim and recreate with a different name
kubectl delete developercombo myapp-dev -n development
# Edit the claim name
kubectl apply -f manifests/claims/claim-dev.yaml
```

---

### Issue: Database subnet delegation fails

**Error:**
```
subnet cannot have any delegation other than Microsoft.DBforPostgreSQL/flexibleServers
```

**Solution:**
The subnet is being reused with wrong delegation. Delete the VNet and let Crossplane recreate:

```bash
# Find the managed VNet
kubectl get virtualnetwork

# Delete it
kubectl delete virtualnetwork <vnet-name>

# Crossplane will recreate with correct configuration
```

---

### Issue: PostgreSQL location error

**Error:**
```
Location 'westeurope' is not accepting new customers for server
```

**Solution:**
Try a different Azure region:

```yaml
spec:
  location: northeurope  # or eastus, westus, etc.
```

---

## Performance Issues

### Issue: Slow reconciliation

**Symptoms:**
- Resources take >10 minutes to become ready
- Multiple reconciliation loops

**Diagnosis:**
```bash
# Check Crossplane logs
kubectl logs -n crossplane-system deployment/crossplane --tail=100

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-storage --tail=100
```

**Solutions:**
1. Increase Crossplane resources:
```bash
kubectl patch deployment crossplane -n crossplane-system -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"crossplane","resources":{"limits":{"memory":"2Gi"},"requests":{"memory":"1Gi","cpu":"500m"}}}]}}}}'
```

2. Check for API rate limiting in logs

3. Reduce number of concurrent claims

---

## Cleanup Problems

### Issue: Cannot delete claim - resources stuck

**Symptoms:**
```bash
$ kubectl delete developercombo myapp-dev -n development
# Hangs indefinitely
```

**Diagnosis:**
```bash
# Check for finalizers
kubectl get developercombo myapp-dev -n development -o yaml | grep -A5 finalizers

# Check managed resources
kubectl get managed
```

**Solutions:**

1. **Safe approach - remove finalizers from managed resources:**
```bash
# List all managed resources
kubectl get managed

# Remove finalizer from each
kubectl patch <resource-type> <resource-name> -p '{"metadata":{"finalizers":[]}}' --type=merge
```

2. **Force delete (use with caution):**
```bash
# This may leave orphaned Azure resources
kubectl patch developercombo myapp-dev -n development -p '{"metadata":{"finalizers":[]}}' --type=merge
kubectl delete developercombo myapp-dev -n development --force --grace-period=0
```

3. **Clean up orphaned Azure resources manually:**
```bash
# List resource groups created by Crossplane
az group list --query "[?tags.\"managed-by\"=='crossplane'].name" -o table

# Delete if needed
az group delete --name <resource-group-name> --yes --no-wait
```

---

### Issue: Azure resources remain after deletion

**Symptoms:**
- Claim deleted successfully
- Azure portal still shows resources

**Cause:**
`deletionPolicy` is set to `Orphan` instead of `Delete`

**Solution:**
Update the Composition before creating new claims:

```yaml
spec:
  resources:
  - name: database
    base:
      spec:
        deletionPolicy: Delete  # Ensure this is set
```

For existing resources:
```bash
# Delete the Azure resources manually
az group delete --name rg-combo-myapp-dev --yes
```

---

## Debugging Workflow

When something goes wrong, follow this systematic approach:

1. **Check Claim Status:**
```bash
kubectl get developercombo -A
kubectl describe developercombo <name> -n <namespace>
```

2. **Check Composite Resource:**
```bash
kubectl get composite
kubectl describe <composite-name>
```

3. **Check Managed Resources:**
```bash
kubectl get managed
kubectl describe <managed-resource>
```

4. **Check Provider Health:**
```bash
kubectl get providers
kubectl get pods -n crossplane-system
```

5. **Check Logs:**
```bash
# Crossplane controller
kubectl logs -n crossplane-system deployment/crossplane

# Provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=<provider-name>
```

6. **Check Events:**
```bash
kubectl get events -A --sort-by='.lastTimestamp' | grep -i error
```

---

## Getting Help

If you're still stuck:

1. **Check the Crossplane Slack:** https://slack.crossplane.io/
2. **Search GitHub Issues:** https://github.com/crossplane/crossplane/issues
3. **Post in discussions:** https://github.com/crossplane/crossplane/discussions
4. **Open an issue in this repo:** https://github.com/software-journey/fast-infrastructure/issues

When asking for help, include:
- Output of `kubectl get developercombo -A`
- Output of `kubectl describe developercombo <name>`
- Output of `kubectl get providers`
- Relevant logs from Crossplane and providers
- Your claim YAML (with sensitive data removed)

---

## Prevention Tips

1. **Always check provider health before creating claims:**
```bash
kubectl get providers
# Wait for all to show HEALTHY: True
```

2. **Start small:**
- Test with one claim in dev first
- Verify it works before scaling to staging/prod

3. **Use meaningful names:**
- Avoid generic names that might conflict
- Include environment in claim names

4. **Enable verbose logging during setup:**
```bash
kubectl logs -n crossplane-system deployment/crossplane -f
```

5. **Keep Crossplane and providers updated:**
```bash
helm upgrade crossplane crossplane-stable/crossplane -n crossplane-system
```