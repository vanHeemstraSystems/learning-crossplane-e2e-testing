# Security Layer 2: Identity & Access Management

## Overview

Identity and Access Management (IAM) is the foundation of cloud security. This layer controls who (identity) can do what (access) to which resources.

## Objectives

- Eliminate passwords and service principals
- Implement managed identities for all workloads
- Apply least privilege access with RBAC
- Secure secrets in Azure Key Vault
- Enable Multi-Factor Authentication (MFA)

## Core Concepts

### Azure AD Components

1. **Users**: Human identities
1. **Service Principals**: Application identities (legacy)
1. **Managed Identities**: Preferred for Azure resources
1. **Groups**: Collections of users/service principals
1. **Roles**: Sets of permissions

### Managed Identity Types

|Type           |Use Case          |Lifecycle       |
|---------------|------------------|----------------|
|System-Assigned|Single resource   |Tied to resource|
|User-Assigned  |Multiple resources|Independent     |

## Implementation with Crossplane

### 1. User-Assigned Managed Identity

```yaml
apiVersion: managedidentity.azure.upbound.io/v1beta1
kind: UserAssignedIdentity
metadata:
  name: app-identity
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    tags:
      purpose: application-workload
      environment: production
```

### 2. RBAC Role Assignment

```yaml
apiVersion: authorization.azure.upbound.io/v1beta1
kind: RoleAssignment
metadata:
  name: storage-contributor
spec:
  forProvider:
    principalIdRef:
      name: app-identity
    roleDefinitionId: /subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe  # Storage Blob Data Contributor
    scope: /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/production-rg/providers/Microsoft.Storage/storageAccounts/prodst orage
```

**Common Azure Roles:**

|Role                         |ID                                  |Use Case                  |
|-----------------------------|------------------------------------|--------------------------|
|Reader                       |acdd72a7-3385-48ef-bd42-f606fba81ae7|Read-only access          |
|Contributor                  |b24988ac-6180-42a0-ab88-20f7382dd24c|Manage resources (no RBAC)|
|Owner                        |8e3af657-a8ff-443c-a75c-2fe8c4bcb635|Full access               |
|Storage Blob Data Contributor|ba92f5b4-2d11-453d-a403-e96b0029c9fe|Storage read/write        |

### 3. Azure Key Vault

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Vault
metadata:
  name: secure-vault
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    skuName: premium
    tenantId: ${TENANT_ID}
    enabledForDiskEncryption: true
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enablePurgeProtection: true
    softDeleteRetentionDays: 90
    networkAcls:
      - bypass: AzureServices
        defaultAction: Deny
        ipRules:
          - value: ${ADMIN_IP}/32
        virtualNetworkRules:
          - subnetIdRef:
              name: app-subnet
```

### 4. Key Vault Access Policy

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: AccessPolicy
metadata:
  name: app-secrets-access
spec:
  forProvider:
    keyVaultIdRef:
      name: secure-vault
    tenantId: ${TENANT_ID}
    objectId: ${MANAGED_IDENTITY_PRINCIPAL_ID}
    secretPermissions:
      - Get
      - List
    certificatePermissions:
      - Get
    keyPermissions:
      - Get
      - UnwrapKey
      - WrapKey
```

### 5. Storing Secrets

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: database-connection-string
spec:
  forProvider:
    keyVaultIdRef:
      name: secure-vault
    value: "Server=tcp:prodserver.database.windows.net;Database=proddb;User ID=app-identity"
    contentType: connection-string
    expirationDate: "2026-12-31T23:59:59Z"
```

## Best Practices

### 1. Never Use Passwords

❌ **Bad: Service Principal with Secret**

```yaml
# DON'T DO THIS
kind: Secret
data:
  AZURE_CLIENT_SECRET: base64encodedpassword
```

✅ **Good: Managed Identity**

```yaml
apiVersion: managedidentity.azure.upbound.io/v1beta1
kind: UserAssignedIdentity
# No secrets needed!
```

### 2. Least Privilege Access

```yaml
# Minimal permissions example
apiVersion: authorization.azure.upbound.io/v1beta1
kind: RoleAssignment
metadata:
  name: read-only-monitoring
spec:
  forProvider:
    principalIdRef:
      name: monitoring-identity
    # Reader role instead of Contributor
    roleDefinitionId: /subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7
    scope: /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/production-rg
```

### 3. Key Vault Best Practices

- Enable purge protection (prevent permanent deletion)
- Use private endpoints (no public access)
- Implement network restrictions
- Enable soft delete with 90-day retention
- Use RBAC instead of access policies (when possible)
- Rotate secrets regularly

## Validation

```bash
# Check managed identity
az identity show \
  --name app-identity \
  --resource-group production-rg

# Verify RBAC assignments
az role assignment list \
  --assignee ${PRINCIPAL_ID} \
  --output table

# Test Key Vault access
az keyvault secret show \
  --vault-name secure-vault \
  --name database-connection-string
```

## Common Patterns

### Pattern 1: Application with Database Access

```yaml
# 1. Create identity
apiVersion: managedidentity.azure.upbound.io/v1beta1
kind: UserAssignedIdentity
metadata:
  name: webapp-identity

---
# 2. Grant SQL access
apiVersion: authorization.azure.upbound.io/v1beta1
kind: RoleAssignment
metadata:
  name: sql-access
spec:
  forProvider:
    principalIdRef:
      name: webapp-identity
    roleDefinitionId: /.../SQL DB Contributor
    scope: /subscriptions/.../providers/Microsoft.Sql/servers/prodserver

---
# 3. Assign to VM
apiVersion: compute.azure.upbound.io/v1beta1
kind: LinuxVirtualMachine
metadata:
  name: webapp-vm
spec:
  forProvider:
    identity:
      - type: UserAssigned
        identityIdsRefs:
          - name: webapp-identity
```

### Pattern 2: Cross-Resource Access

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: secure-app-with-storage
spec:
  resources:
    - name: identity
      base:
        apiVersion: managedidentity.azure.upbound.io/v1beta1
        kind: UserAssignedIdentity
    
    - name: storage
      base:
        apiVersion: storage.azure.upbound.io/v1beta1
        kind: Account
    
    - name: storage-access
      base:
        apiVersion: authorization.azure.upbound.io/v1beta1
        kind: RoleAssignment
        spec:
          forProvider:
            principalIdRef:
              name: identity
            scope: # Reference storage account
```

## Troubleshooting

### Issue: Identity Not Found

```bash
# Check identity exists
az identity list \
  --resource-group production-rg \
  --output table

# Get principal ID
az identity show \
  --name app-identity \
  --resource-group production-rg \
  --query principalId \
  --output tsv
```

### Issue: Access Denied to Key Vault

```bash
# Check access policies
az keyvault show \
  --name secure-vault \
  --query properties.accessPolicies

# Verify network rules
az keyvault network-rule list \
  --name secure-vault
```

### Issue: RBAC Assignment Fails

```bash
# Verify role definition ID
az role definition list \
  --query "[?roleName=='Contributor'].{name:name, id:id}"

# Check scope syntax
# Should be: /subscriptions/{sub-id}/resourceGroups/{rg-name}/...
```

## Summary

**Key Points:**

- ✅ Use managed identities instead of passwords
- ✅ Apply least privilege RBAC
- ✅ Store secrets in Key Vault
- ✅ Enable purge protection
- ✅ Use private endpoints for Key Vault

**Next Layer:** [Perimeter Security](./security-layer-3.md)

-----

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Author**: Willem van Heemstra
