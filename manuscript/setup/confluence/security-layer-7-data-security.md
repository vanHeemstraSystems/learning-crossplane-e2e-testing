# Security Layer 7: Data Security

## Overview

Data security protects information at rest and in transit through encryption, access controls, backup, and threat detection.

## Objectives

- Encrypt data at rest with customer-managed keys
- Enable Transparent Data Encryption (TDE) for databases
- Implement backup and disaster recovery
- Configure threat detection
- Ensure data is encrypted in transit

## Implementation

### 1. Storage Account Encryption

```yaml
apiVersion: storage.azure.upbound.io/v1beta1
kind: Account
metadata:
  name: secure-storage
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    accountTier: Standard
    accountReplicationType: GRS  # Geo-redundant
    enableHttpsTrafficOnly: true  # Enforce HTTPS
    minTlsVersion: TLS1_2
    allowBlobPublicAccess: false
    infrastructureEncryptionEnabled: true  # Double encryption
    networkRules:
      - defaultAction: Deny
        bypass:
          - AzureServices
        virtualNetworkSubnetIdsRefs:
          - name: app-subnet
    identity:
      - type: SystemAssigned
    customerManagedKey:
      - keyVaultKeyIdRef:
          name: storage-encryption-key
        userAssignedIdentityIdRef:
          name: storage-identity
```

### 2. SQL Database with TDE

```yaml
apiVersion: sql.azure.upbound.io/v1beta1
kind: MSSQLServer
metadata:
  name: secure-sql-server
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    version: "12.0"
    administratorLogin: sqladmin
    administratorLoginPasswordSecretRef:
      name: sql-admin-password
      namespace: security
      key: password
    publicNetworkAccessEnabled: false
    minimumTlsVersion: "1.2"
---
apiVersion: sql.azure.upbound.io/v1beta1
kind: MSSQLDatabase
metadata:
  name: secure-db
spec:
  forProvider:
    serverIdRef:
      name: secure-sql-server
    collation: SQL_Latin1_General_CP1_CI_AS
    maxSizeGb: 100
    skuName: S1
    zoneRedundant: true
    threatDetectionPolicy:
      - state: Enabled
        emailAddresses:
          - security@example.com
        retentionDays: 90
---
apiVersion: sql.azure.upbound.io/v1beta1
kind: MSSQLServerTransparentDataEncryption
metadata:
  name: db-tde
spec:
  forProvider:
    serverIdRef:
      name: secure-sql-server
    keyVaultKeyIdRef:
      name: tde-encryption-key
```

### 3. Backup Configuration

```yaml
apiVersion: recoveryservices.azure.upbound.io/v1beta1
kind: Vault
metadata:
  name: backup-vault
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    sku: Standard
    softDeleteEnabled: true
    immutability: Locked  # Prevent ransomware deletion
---
apiVersion: recoveryservices.azure.upbound.io/v1beta1
kind: BackupPolicyVM
metadata:
  name: daily-backup
spec:
  forProvider:
    recoveryVaultNameRef:
      name: backup-vault
    resourceGroupNameRef:
      name: production-rg
    timezone: "Europe/Amsterdam"
    backup:
      - frequency: Daily
        time: "23:00"
    retentionDaily:
      - count: 30
    retentionWeekly:
      - count: 12
        weekdays:
          - Sunday
    retentionMonthly:
      - count: 12
        weekdays:
          - Sunday
        weeks:
          - First
    retentionYearly:
      - count: 7
        weekdays:
          - Sunday
        weeks:
          - First
        months:
          - January
```

### 4. Data Classification

```yaml
apiVersion: storage.azure.upbound.io/v1beta1
kind: Account
metadata:
  name: classified-storage
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    tags:
      data-classification: "confidential"
      data-owner: "finance-team"
      retention-period: "7-years"
      compliance: "gdpr,sox"
      encryption: "customer-managed-keys"
    # ... rest of configuration
```

## Encryption Strategies

### At Rest

**Azure Storage:**

- Platform-managed keys (default)
- Customer-managed keys (recommended)
- Infrastructure encryption (double encryption)

**SQL Database:**

- Transparent Data Encryption (TDE)
- Customer-managed TDE keys
- Always Encrypted for column-level encryption

### In Transit

**Requirements:**

- TLS 1.2 or higher
- Strong cipher suites
- Certificate-based authentication where possible

## Backup Best Practices

**3-2-1 Rule:**

- 3 copies of data
- 2 different media types
- 1 copy off-site

**Retention:**

- Daily: 30 days
- Weekly: 12 weeks
- Monthly: 12 months
- Yearly: 7 years (or per compliance)

**Testing:**

- Test restore monthly
- Document restore procedures
- Measure RTO/RPO metrics

## Threat Detection

```yaml
# Enable Advanced Threat Protection for Storage
apiVersion: security.azure.upbound.io/v1beta1
kind: AdvancedThreatProtection
metadata:
  name: storage-atp
spec:
  forProvider:
    targetResourceIdRef:
      name: secure-storage
    enabled: true

# SQL Advanced Threat Protection
apiVersion: sql.azure.upbound.io/v1beta1
kind: MSSQLServerSecurityAlertPolicy
metadata:
  name: sql-threat-detection
spec:
  forProvider:
    serverIdRef:
      name: secure-sql-server
    state: Enabled
    emailAddresses:
      - security@example.com
    emailAccountAdmins: true
    retentionDays: 90
```

## Data Loss Prevention

**Key Controls:**

- Disable public blob access
- Use private endpoints
- Implement RBAC for data access
- Enable soft delete (90 days)
- Configure immutable storage for compliance

## Validation

```bash
# Check encryption status
az storage account show \
  --name securestorage \
  --query "encryption" \
  --output json

# Verify TDE
az sql db tde show \
  --server secure-sql-server \
  --database secure-db \
  --resource-group production-rg

# Check backup status
az backup item list \
  --resource-group production-rg \
  --vault-name backup-vault \
  --output table
```

## Summary

✅ Encrypt all data at rest with customer-managed keys  
✅ Enable TDE for databases  
✅ Implement comprehensive backup strategy  
✅ Configure threat detection  
✅ Enforce TLS 1.2+ for data in transit  
✅ Test disaster recovery procedures

**Congratulations!** You’ve completed all 7 defense-in-depth layers.

-----

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Author**: Willem van Heemstra
