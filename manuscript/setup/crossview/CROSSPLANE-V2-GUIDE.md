# Crossplane v2 Migration Guide

This toolkit uses **Crossplane v2** which introduced breaking changes from v1. This guide explains the differences and how to adapt.

## Major Changes in Crossplane v2

### 1. API Version Change

**v1:**
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
```

**v2:**
```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
```

**Impact:** All XRDs and Compositions must use v2 API. No automatic migration.

### 2. Claims Removed

The biggest change in Crossplane v2 is the **removal of Claims**.

**v1 Architecture:**
```
Claim (namespace-scoped)
  └─> Composite Resource / XR (cluster-scoped)
      └─> Managed Resources
```

**v2 Architecture:**
```
Composite Resource / XR (cluster-scoped)
  └─> Managed Resources
```

### 3. XRD Specification Changes

**v1 XRD:**
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xstorageaccounts.azure.example.com
spec:
  group: azure.example.com
  names:
    kind: XStorageAccount
    plural: xstorageaccounts
  claimNames:                    # ← Claims configuration
    kind: StorageAccount
    plural: storageaccounts
  versions:
  - name: v1alpha1
    # ...
```

**v2 XRD:**
```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: xstorageaccounts.azure.example.com
spec:
  group: azure.example.com
  names:
    kind: XStorageAccount
    plural: xstorageaccounts
  # No claimNames section!
  versions:
  - name: v1alpha1
    # ...
```

**Changes:**
- ✅ API version updated to v2
- ❌ `claimNames` section removed
- ✅ Everything else remains the same

### 4. Creating Resources

**v1 - Using Claims:**
```yaml
# User creates a Claim (namespace-scoped)
apiVersion: azure.example.com/v1alpha1
kind: StorageAccount              # From claimNames.kind
metadata:
  name: my-storage
  namespace: dev-team             # Namespace-scoped
spec:
  parameters:
    location: westeurope
    # ...
  compositionSelector:
    matchLabels:
      tier: standard
```

**v2 - Using XRs Directly:**
```yaml
# User creates an XR directly (cluster-scoped)
apiVersion: azure.example.com/v1alpha1
kind: XStorageAccount             # From names.kind (the XR)
metadata:
  name: my-storage                # No namespace!
spec:
  id: mystorage01                 # Unique identifier
  parameters:
    location: westeurope
    # ...
  compositionSelector:
    matchLabels:
      tier: standard
```

**Key Differences:**
- Kind changes from `StorageAccount` to `XStorageAccount`
- No namespace - XRs are cluster-scoped
- Add `spec.id` field for unique identification

## Migration Steps

### Step 1: Update XRD to v2

```bash
# Before (v1)
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
spec:
  claimNames:
    kind: StorageAccount
    plural: storageaccounts

# After (v2)
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
spec:
  # Remove claimNames section entirely
```

### Step 2: Update Compositions to v2

```bash
# Before (v1)
apiVersion: apiextensions.crossplane.io/v1
kind: Composition

# After (v2)
apiVersion: apiextensions.crossplane.io/v2
kind: Composition
```

### Step 3: Convert Claims to XRs

**Conversion Pattern:**

```yaml
# OLD v1 Claim
apiVersion: azure.example.com/v1alpha1
kind: StorageAccount         # Claim kind
metadata:
  name: prod-storage
  namespace: production      # Namespaced
spec:
  parameters:
    location: westeurope

# NEW v2 XR
apiVersion: azure.example.com/v1alpha1
kind: XStorageAccount        # XR kind (from XRD names.kind)
metadata:
  name: prod-storage         # Cluster-scoped, no namespace
spec:
  id: prodstorage01          # Add unique ID
  parameters:
    location: westeurope
```

### Step 4: Update Automation

Update scripts, GitOps repos, and CI/CD pipelines:

```bash
# Old kubectl commands
kubectl apply -f claim.yaml
kubectl get storageaccount -n dev-team

# New kubectl commands
kubectl apply -f xr.yaml
kubectl get xstorageaccount  # No namespace flag needed
```

### Step 5: Update RBAC

Since XRs are cluster-scoped, update RBAC:

```yaml
# Grant access to specific XR types
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: storage-admin
rules:
- apiGroups: ["azure.example.com"]
  resources: ["xstorageaccounts"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

## Why Claims Were Removed

Crossplane team removed Claims to:

1. **Simplify Architecture** - One less abstraction layer
2. **Reduce Confusion** - Clear distinction between XRs and managed resources
3. **Improve Performance** - Fewer controllers and reconciliations
4. **Enable New Features** - Cleaner foundation for future enhancements

## Namespace Isolation in v2

Without namespace-scoped Claims, how do you isolate resources?

### Option 1: Naming Conventions

```yaml
# Team A resources
metadata:
  name: team-a-storage-prod
  
# Team B resources  
metadata:
  name: team-b-storage-prod
```

### Option 2: Labels + RBAC

```yaml
apiVersion: azure.example.com/v1alpha1
kind: XStorageAccount
metadata:
  name: storage-001
  labels:
    team: team-a
    environment: production
```

Then use RBAC to restrict access:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: team-a-storage-role
rules:
- apiGroups: ["azure.example.com"]
  resources: ["xstorageaccounts"]
  verbs: ["get", "list", "watch"]
  # Use admission webhooks to enforce label-based access
```

### Option 3: Multiple Clusters

For strict isolation, use separate clusters per team/environment.

## Common Migration Issues

### Issue 1: "No matches for kind StorageAccount"

**Cause:** Trying to create a v1 Claim in v2

**Solution:** Update to use XR kind:
```yaml
# Change from:
kind: StorageAccount
# To:
kind: XStorageAccount
```

### Issue 2: "claimNames not supported"

**Cause:** v2 XRD includes claimNames section

**Solution:** Remove claimNames from XRD:
```yaml
spec:
  names:
    kind: XStorageAccount
    plural: xstorageaccounts
  # Remove this:
  # claimNames:
  #   kind: StorageAccount
  #   plural: storageaccounts
```

### Issue 3: Namespace errors with XRs

**Cause:** Trying to create XR in a namespace

**Solution:** Remove namespace from XR metadata:
```yaml
metadata:
  name: my-storage
  # Don't include namespace - XRs are cluster-scoped
```

### Issue 4: Can't find existing Claims

**Cause:** Claims are v1 concept and don't exist in v2

**Solution:** List XRs instead:
```bash
# Old
kubectl get storageaccount -n dev-team

# New
kubectl get xstorageaccount
```

## Validation in v2

The validation toolkit works identically in v2:

```bash
# Same validation commands
./validate-xrd-composition.sh xstorageaccounts.azure.example.com storageaccount-azure-standard

# Same Crossview usage
minikube service crossview -n crossview
```

**Difference:** Crossview shows XRs directly without a Claims layer.

## Example: Complete v1 to v2 Migration

### Before (v1)

**XRD:**
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xstorageaccounts.azure.example.com
spec:
  group: azure.example.com
  names:
    kind: XStorageAccount
    plural: xstorageaccounts
  claimNames:
    kind: StorageAccount
    plural: storageaccounts
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      # ... schema
```

**Claim:**
```yaml
apiVersion: azure.example.com/v1alpha1
kind: StorageAccount
metadata:
  name: prod-data
  namespace: production
spec:
  parameters:
    location: westeurope
    accountTier: Standard
```

### After (v2)

**XRD:**
```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: xstorageaccounts.azure.example.com
spec:
  group: azure.example.com
  names:
    kind: XStorageAccount
    plural: xstorageaccounts
  # No claimNames!
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      # ... same schema
```

**XR:**
```yaml
apiVersion: azure.example.com/v1alpha1
kind: XStorageAccount
metadata:
  name: prod-data
  # No namespace!
spec:
  id: proddata01
  parameters:
    location: westeurope
    accountTier: Standard
```

## Resources

- [Crossplane v2 Release Notes](https://github.com/crossplane/crossplane/releases)
- [Crossplane v2 Documentation](https://docs.crossplane.io/)
- [Migration Guide (Official)](https://docs.crossplane.io/latest/concepts/composite-resources/)

## Summary

**Key Takeaways:**

1. ✅ Update XRD and Composition APIs to v2
2. ❌ Remove `claimNames` from XRDs
3. ✅ Create XRs directly (cluster-scoped)
4. ❌ Don't create Claims (removed)
5. ✅ Use labels + RBAC for access control
6. ✅ Update all automation and pipelines

The validation toolkit is fully compatible with v2 and demonstrates all best practices!
