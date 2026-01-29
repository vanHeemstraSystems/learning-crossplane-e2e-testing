# Azure Storage Account Validation - Refactored Toolkit (Crossplane v2)

This toolkit has been refactored from the original network-focused example to demonstrate **Azure Storage Account** XRD and Composition validation using **Crossplane v2**.

## Crossplane v2 Changes

This toolkit uses **Crossplane v2** specifications:

- ✅ **API Version**: `apiextensions.crossplane.io/v2` (not v1)
- ✅ **No Claims**: Crossplane v2 uses XRs (Composite Resources) directly
- ✅ **No claimNames**: XRD specs don't include claimNames section
- ✅ **Cluster-scoped XRs**: All composite resources are cluster-scoped

### v1 vs v2 Comparison

| Aspect | Crossplane v1 | Crossplane v2 |
|--------|---------------|---------------|
| XRD API | apiextensions.crossplane.io/v1 | apiextensions.crossplane.io/v2 |
| Composition API | apiextensions.crossplane.io/v1 | apiextensions.crossplane.io/v2 |
| Claims | Yes (namespace-scoped) | No (removed) |
| XRD claimNames | Required for claims | Not used |
| User interface | Create Claims | Create XRs directly |
| Resource scope | Claims: namespaced, XRs: cluster | XRs: cluster-scoped |

## What Changed

### Sample Resources

**Before (Network Focus):**
- XRD: `xnetworks.example.com`
- Kind: `XNetwork`
- Managed Resources: VPC, Internet Gateway
- Provider: AWS

**After (Storage Focus):**
- XRD: `xstorageaccounts.azure.example.com`
- Kind: `XStorageAccount`
- Managed Resources: ResourceGroup, Storage Account, Blob Container
- Provider: Azure

### XRD Specifications (Crossplane v2)

The new XRD (`sample-xrd.yaml`) uses Crossplane v2 and defines an Azure Storage Account with:

**API Version:** `apiextensions.crossplane.io/v2` (Crossplane v2)

**No Claims:** The XRD does not include `claimNames` - users create XRs directly

**Key Parameters:**
- `location` - Azure region (westeurope, eastus, etc.)
- `accountTier` - Standard or Premium
- `accountReplicationType` - LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS
- `accountKind` - StorageV2, BlobStorage, etc.
- `enableHttpsTrafficOnly` - Force HTTPS (default: true)
- `minimumTlsVersion` - TLS1_0, TLS1_1, TLS1_2
- `allowBlobPublicAccess` - Allow public blob access (default: false)
- `networkRules` - Network access controls
- `tags` - Resource tags

**Status Fields:**
- `storageAccountId` - Azure resource ID
- `storageAccountName` - Generated storage account name
- `primaryEndpoints` - Blob, File, Queue, Table endpoints
- `provisioningState` - Azure provisioning state

### Composition Structure (Crossplane v2)

The new Composition (`sample-composition.yaml`) uses:
- **API Version:** `apiextensions.crossplane.io/v2`
- **Creates three resources:**

1. **Azure Resource Group** (`azure.upbound.io/v1beta1/ResourceGroup`)
   - Container for all storage resources
   - Location-aware

2. **Azure Storage Account** (`storage.azure.upbound.io/v1beta1/Account`)
   - Main storage account resource
   - Configurable tier, replication, security settings
   - Network rules for access control
   - Unique name generation (3-24 lowercase alphanumeric)

3. **Blob Container** (`storage.azure.upbound.io/v1beta1/Container`)
   - Default private container
   - References parent storage account

### Patch Configuration

The Composition includes **15+ patches** to:
- Map XRD parameters to Azure resource properties
- Transform storage account names (Azure naming constraints)
- Propagate status information back to the claim
- Set secure defaults (HTTPS-only, TLS 1.2, private access)

### Updated Documentation

All documentation has been updated to reflect Azure Storage Account examples:

| File | Key Changes |
|------|-------------|
| README.md | Quick start commands, validation examples |
| QUICK-START.md | Step-by-step guide with Azure resources |
| VISUAL-REFERENCE.md | Visual diagrams showing Azure hierarchy |
| crossview-setup-guide.md | Azure-specific deployment examples |
| TROUBLESHOOTING.md | Azure provider and resource debugging |

## Usage Examples

### Deploy the Azure Storage Account XRD and Composition

```bash
# Deploy XRD
kubectl apply -f sample-xrd.yaml

# Deploy Composition
kubectl apply -f sample-composition.yaml

# Validate
./validate-xrd-composition.sh xstorageaccounts.azure.example.com storageaccount-azure-standard
```

### Create a Storage Account XR (Composite Resource)

**Note:** In Crossplane v2, you create XRs directly - no Claims!

```bash
kubectl apply -f - <<EOF
apiVersion: azure.example.com/v1alpha1
kind: XStorageAccount
metadata:
  name: production-data
spec:
  id: proddata01
  parameters:
    location: westeurope
    accountTier: Standard
    accountReplicationType: GRS
    accountKind: StorageV2
    enableHttpsTrafficOnly: true
    minimumTlsVersion: TLS1_2
    allowBlobPublicAccess: false
    networkRules:
      defaultAction: Deny
      bypass:
      - AzureServices
    tags:
      environment: production
      team: data-platform
      cost-center: engineering
  compositionSelector:
    matchLabels:
      tier: standard
EOF
```

### Expected Resources Created

When the XR is processed, Crossplane will create:

1. **Composite Resource (XR)**
   - Kind: XStorageAccount
   - Name: production-data
   - Cluster-scoped (not namespaced)

2. **Azure Resource Group**
   - Name: rg-production-data
   - Location: westeurope

3. **Azure Storage Account**
   - Name: saproddata01 (sanitized from ID)
   - Account Tier: Standard
   - Replication: GRS
   - HTTPS Only: true
   - Min TLS: 1.2

4. **Blob Container**
   - Name: container-production-data
   - Access: Private

### Validate with Crossview

```bash
# Start Crossview
minikube service crossview -n crossview
```

In Crossview, you should see:
- **Green connection** from XRD to Composition
- **Resource hierarchy** showing the XR and all managed Azure resources
- **Status indicators** for each resource
- **Endpoint information** in the status panel

**Note:** No Claims layer in Crossplane v2 - XRs are created directly.

## Key Differences: Azure vs AWS, v1 vs v2

| Aspect | AWS (Original, v1) | Azure (Refactored, v2) |
|--------|-------------------|------------------------|
| Main Resource | VPC | Storage Account |
| API Group | example.com | azure.example.com |
| Crossplane Version | v1 | v2 |
| XRD API | apiextensions.crossplane.io/v1 | apiextensions.crossplane.io/v2 |
| Claims Support | Yes | No (removed in v2) |
| claimNames in XRD | Yes | No |
| Provider Package | provider-aws-ec2 | provider-azure-storage |
| Naming Constraints | Flexible | 3-24 lowercase alphanumeric |
| Primary Focus | Networking | Storage |
| Resource Count | 2 (VPC, IGW) | 3 (RG, Account, Container) |
| User Interface | Create Claims | Create XRs directly |

## Crossplane v2 Specifics

### What's New in v2

**API Changes:**
- XRD and Composition use `apiextensions.crossplane.io/v2`
- No backward compatibility with v1 APIs

**Claims Removed:**
- No more namespace-scoped Claims
- Users create XRs (Composite Resources) directly
- XRDs don't have `claimNames` section
- All XRs are cluster-scoped

**Migration Impact:**
- Existing v1 Claims won't work
- Must recreate as v2 XRs
- Update automation/GitOps pipelines
- No namespace isolation (use RBAC instead)

### Why v2 Removed Claims

Crossplane v2 simplified the architecture:
- **One less abstraction layer** - XRs serve the same purpose
- **Clearer mental model** - Direct XR creation
- **Consistent scoping** - Everything cluster-scoped
- **Simplified RBAC** - No namespace considerations

### XR Creation Pattern

```yaml
# Crossplane v1 (old)
apiVersion: azure.example.com/v1alpha1
kind: StorageAccount              # Claim
metadata:
  name: my-storage
  namespace: team-a               # Namespace-scoped
spec:
  # ... parameters

# Crossplane v2 (new)
apiVersion: azure.example.com/v1alpha1
kind: XStorageAccount             # XR directly
metadata:
  name: my-storage                # Cluster-scoped, no namespace
spec:
  # ... parameters
```

## Prerequisites for Live Testing

To actually create Azure resources (not just validate the XRD-Composition match):

1. **Install Azure Providers**
   ```bash
   # Core Azure provider
   kubectl apply -f - <<EOF
   apiVersion: pkg.crossplane.io/v1
   kind: Provider
   metadata:
     name: provider-azure-upbound
   spec:
     package: xpkg.upbound.io/upbound/provider-azure:v1.3.0
   EOF
   
   # Storage provider
   kubectl apply -f - <<EOF
   apiVersion: pkg.crossplane.io/v1
   kind: Provider
   metadata:
     name: provider-azure-storage
   spec:
     package: xpkg.upbound.io/upbound/provider-azure-storage:v1.3.0
   EOF
   ```

2. **Configure Azure Credentials**
   ```bash
   # Create Azure service principal credentials secret
   kubectl create secret generic azure-secret \
     -n crossplane-system \
     --from-file=creds=/path/to/azure-credentials.json
   
   # Create ProviderConfig
   kubectl apply -f - <<EOF
   apiVersion: azure.upbound.io/v1beta1
   kind: ProviderConfig
   metadata:
     name: default
   spec:
     credentials:
       source: Secret
       secretRef:
         namespace: crossplane-system
         name: azure-secret
         key: creds
   EOF
   ```

3. **Install Function (for Pipeline mode)**
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: pkg.crossplane.io/v1beta1
   kind: Function
   metadata:
     name: function-patch-and-transform
   spec:
     package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.2.1
   EOF
   ```

## Validation Without Azure Credentials

**Important:** You can validate the XRD-Composition relationship without Azure credentials!

The validation toolkit checks:
- ✅ XRD structure and establishment
- ✅ Composition `compositeTypeRef` matching
- ✅ API version compatibility
- ✅ Kind matching
- ✅ Visual relationship in Crossview

You do **NOT** need:
- ❌ Azure subscription
- ❌ Azure credentials
- ❌ Azure providers installed
- ❌ Actual resource creation

The validation focuses on the **correctness of the XRD-Composition contract**, not on cloud resource provisioning.

## Learning Objectives

This refactored toolkit demonstrates:

1. **XRD Design Patterns** - How to model complex cloud resources
2. **Composition Best Practices** - Multi-resource compositions with dependencies
3. **Patch Strategies** - Field mapping, transformations, status propagation
4. **Security Defaults** - Secure-by-default configurations
5. **Azure-Specific Constraints** - Resource naming, location handling
6. **Validation Workflows** - Both CLI and visual validation

## Extending the Toolkit

You can extend this toolkit by:

### Adding More Compositions

```yaml
# Premium tier with ZRS
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: storageaccount-azure-premium
  labels:
    tier: premium
    provider: azure
spec:
  compositeTypeRef:
    apiVersion: azure.example.com/v1alpha1
    kind: XStorageAccount
  # ... with Premium tier and ZRS replication
```

### Adding More Managed Resources

Extend the composition to include:
- Azure Key Vault (for encryption keys)
- Private Endpoints (for network isolation)
- Diagnostic Settings (for monitoring)
- Lifecycle Management Policies

### Multi-Cloud Variations

Create equivalent compositions for other providers:
- AWS: S3 Bucket composition
- GCP: Cloud Storage composition
- Keep the same XRD, different implementations

## Troubleshooting Azure-Specific Issues

### Storage Account Name Already Exists

**Error:** "StorageAccountAlreadyExists"

**Cause:** Azure storage account names are globally unique

**Solution:** Ensure your ID transformation creates unique names:
```yaml
transforms:
- type: string
  string:
    type: Format
    fmt: "sa%s%s"  # Add timestamp or random suffix
```

### Location Mismatch

**Error:** "The specified location is not valid"

**Cause:** Resource Group and Storage Account in different regions

**Solution:** Verify patches propagate location consistently

### Network Rules Blocking Access

**Error:** Cannot access storage account endpoints

**Cause:** networkRules.defaultAction = Deny without proper bypass

**Solution:** Review bypass settings and add necessary exceptions

## Summary

The toolkit now provides:
- ✅ Complete Azure Storage Account example
- ✅ All validation scripts updated
- ✅ Full documentation refactored
- ✅ Visual reference guides updated
- ✅ Troubleshooting guide enhanced
- ✅ Works with or without Azure credentials

Use this toolkit to:
1. Learn Crossplane XRD and Composition patterns
2. Validate your own Azure compositions
3. Understand visual validation with Crossview
4. Develop platform abstractions for Azure Storage
