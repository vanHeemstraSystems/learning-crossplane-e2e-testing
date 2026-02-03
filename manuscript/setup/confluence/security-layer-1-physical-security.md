# Security Layer 1: Physical Security

## Overview

Physical security in Azure focuses on data center location, availability, and disaster recovery planning. While Microsoft manages the physical infrastructure, you control resource placement and redundancy strategies.

## Objectives

- Select appropriate Azure regions for compliance and performance
- Implement availability zones for high availability
- Configure geo-redundancy for disaster recovery
- Ensure data residency requirements are met

## Azure Physical Security

### Microsoft’s Responsibilities

Microsoft Azure provides:

- 24/7 monitored data centers
- Biometric access controls
- Environmental controls (power, cooling, fire suppression)
- Physical network security
- Compliance certifications (ISO 27001, SOC 2, etc.)

### Your Responsibilities

As a cloud customer, you control:

- **Region Selection**: Where your data is stored
- **Availability Zones**: Distribution across fault domains
- **Geo-Replication**: Cross-region backup and DR
- **Resource Tagging**: Compliance and data classification

## Implementation with Crossplane

### 1. Region Selection

Choose regions based on:

- **Compliance**: Data residency requirements (GDPR, industry regulations)
- **Latency**: Proximity to users
- **Features**: Not all Azure services available in all regions
- **Cost**: Regional pricing variations
- **Paired Regions**: For disaster recovery

#### Example: Resource Group with Region

```yaml
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: production-rg
  annotations:
    crossplane.io/external-name: prod-secure-rg
spec:
  forProvider:
    location: westeurope  # Primary region
    tags:
      environment: production
      compliance: gdpr
      data-classification: confidential
      backup-region: northeurope
      business-unit: finance
```

**Compliance Tagging**:

```yaml
tags:
  compliance: "gdpr,iso27001,soc2"
  data-classification: "confidential"  # public, internal, confidential, restricted
  data-residency: "eu-only"
  retention-period: "7-years"
```

### 2. Availability Zones

Azure Availability Zones provide:

- Physically separate locations within a region
- Independent power, cooling, and networking
- <2ms latency between zones
- 99.99% SLA for multi-zone deployments

#### Example: VM with Availability Zones

```yaml
apiVersion: compute.azure.upbound.io/v1beta1
kind: LinuxVirtualMachine
metadata:
  name: web-server-vm
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    size: Standard_D2s_v3
    zones:  # Deploy across multiple zones
      - "1"
      - "2"
      - "3"
    # ... additional configuration
```

#### Example: Zonal Storage

```yaml
apiVersion: storage.azure.upbound.io/v1beta1
kind: Account
metadata:
  name: zoneredundantstorage
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    accountTier: Standard
    accountReplicationType: ZRS  # Zone-Redundant Storage
    # ZRS replicates across 3 availability zones
```

### 3. Geo-Redundancy Strategies

|Replication Type|Description               |Use Case                     |Availability|
|----------------|--------------------------|-----------------------------|------------|
|LRS             |Locally Redundant Storage |Dev/Test, non-critical       |11 nines    |
|ZRS             |Zone-Redundant Storage    |Production, high availability|12 nines    |
|GRS             |Geo-Redundant Storage     |Disaster recovery            |16 nines    |
|GZRS            |Geo-Zone-Redundant Storage|Mission critical             |16 nines    |

#### Example: Geo-Redundant Storage

```yaml
apiVersion: storage.azure.upbound.io/v1beta1
kind: Account
metadata:
  name: georedundantstorage
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    accountTier: Standard
    accountReplicationType: GZRS  # Geo-Zone-Redundant
    tags:
      dr-enabled: "true"
      rpo: "15-minutes"
      rto: "4-hours"
```

### 4. Paired Regions Configuration

Azure region pairs for disaster recovery:

|Primary Region|Paired Region|Distance|
|--------------|-------------|--------|
|West Europe   |North Europe |~2000 km|
|East US       |West US      |~4000 km|
|Southeast Asia|East Asia    |~2500 km|

#### Example: Multi-Region Deployment

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: multi-region-app
spec:
  compositeTypeRef:
    apiVersion: custom.azure.example.com/v1alpha1
    kind: MultiRegionApp
  resources:
    # Primary region
    - name: primary-rg
      base:
        apiVersion: azure.upbound.io/v1beta1
        kind: ResourceGroup
        spec:
          forProvider:
            location: westeurope
            tags:
              region-type: primary
    
    # Secondary region (paired)
    - name: secondary-rg
      base:
        apiVersion: azure.upbound.io/v1beta1
        kind: ResourceGroup
        spec:
          forProvider:
            location: northeurope
            tags:
              region-type: secondary
              failover-priority: "1"
```

## Best Practices

### 1. Region Selection Criteria

**Compliance First:**

```yaml
# Example: GDPR-compliant resource group
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: gdpr-rg
spec:
  forProvider:
    location: westeurope  # EU region for GDPR
    tags:
      compliance: gdpr
      data-residency: eu-only
      legal-hold: "true"
```

**Multi-Region for DR:**

```yaml
# Use Composition to enforce paired regions
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xsecureapps.custom.azure.example.com
spec:
  group: custom.azure.example.com
  names:
    kind: XSecureApp
    plural: xsecureapps
  claimNames:
    kind: SecureApp
    plural: secureapps
  versions:
    - name: v1alpha1
      schema:
        openAPIV3Schema:
          properties:
            spec:
              properties:
                primaryRegion:
                  type: string
                  enum:
                    - westeurope
                    - eastus
                    - southeastasia
                secondaryRegion:
                  type: string
                  # Automatically set based on paired region
```

### 2. Availability Zone Guidelines

**When to Use Availability Zones:**

- ✅ Production workloads requiring 99.99% SLA
- ✅ Stateful applications (databases, storage)
- ✅ Applications sensitive to data loss
- ✅ Regulatory requirements for high availability

**When Single Zone is Acceptable:**

- Development and testing environments
- Batch processing jobs
- Short-lived compute tasks
- Cost-optimized scenarios

### 3. Tag Strategy for Physical Security

```yaml
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: comprehensive-tagged-rg
spec:
  forProvider:
    location: westeurope
    tags:
      # Compliance
      compliance: "gdpr,iso27001,soc2,pci-dss"
      data-classification: "confidential"
      data-residency: "eu-only"
      
      # High Availability
      availability-zones: "true"
      ha-enabled: "true"
      sla-target: "99.99"
      
      # Disaster Recovery
      dr-enabled: "true"
      backup-region: "northeurope"
      rpo: "15-minutes"
      rto: "4-hours"
      
      # Organizational
      environment: "production"
      cost-center: "finance"
      owner: "platform-team"
      project: "secure-banking-app"
```

## Validation and Testing

### 1. Verify Region Configuration

```bash
# Check resource group location
az group show \
  --name production-rg \
  --query location \
  --output tsv

# List all resources by region
az resource list \
  --resource-group production-rg \
  --query "[].{name:name, location:location}" \
  --output table
```

### 2. Validate Availability Zones

```bash
# Check VM availability zones
az vm show \
  --resource-group production-rg \
  --name web-server-vm \
  --query zones \
  --output tsv

# Verify storage replication
az storage account show \
  --name georedundantstorage \
  --resource-group production-rg \
  --query "[sku.name, sku.tier]" \
  --output table
```

### 3. Test Disaster Recovery

```bash
# Simulate regional failover (storage)
az storage account failover \
  --name georedundantstorage \
  --resource-group production-rg \
  --no-wait

# Monitor failover status
az storage account show \
  --name georedundantstorage \
  --resource-group production-rg \
  --query "statusOfPrimary" \
  --output tsv
```

## Compliance Considerations

### Data Residency Requirements

**GDPR (EU):**

- Store data in EU regions only
- Use geo-replication within EU (West Europe ↔ North Europe)
- Tag resources with `data-residency: eu-only`

**CCPA (California):**

- Consider West US or West US 2 regions
- Implement data deletion capabilities
- Tag with `data-residency: us-west`

**APAC Data Protection:**

- Use Southeast Asia or East Asia regions
- Paired region for DR within APAC
- Tag with `data-residency: apac-only`

### Example: Compliance-Enforced Composition

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: gdpr-compliant-storage
spec:
  compositeTypeRef:
    apiVersion: custom.azure.example.com/v1alpha1
    kind: GDPRStorage
  resources:
    - name: storage-account
      base:
        apiVersion: storage.azure.upbound.io/v1beta1
        kind: Account
        spec:
          forProvider:
            # Enforce EU region
            location: westeurope
            accountReplicationType: GZRS  # GRS with zones in EU
            tags:
              compliance: gdpr
              data-residency: eu-only
              retention-policy: "enforced"
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.dataClassification
          toFieldPath: metadata.labels[data-classification]
```

## Monitoring and Alerts

### Physical Security Metrics

**Key Metrics to Monitor:**

- Regional availability status
- Zone health status
- Replication lag (for geo-redundant storage)
- Failover events

**Example Alert Configuration:**

```bash
# Alert on regional outage
az monitor metrics alert create \
  --name regional-availability-alert \
  --resource-group production-rg \
  --condition "avg Availability < 99.99" \
  --description "Alert when regional availability drops below SLA"
```

## Cost Optimization

### Regional Pricing Differences

- **West Europe**: Typically higher cost, better compliance
- **North Europe**: Lower cost, paired with West Europe
- **East US**: Competitive pricing, large service catalog
- **Southeast Asia**: Growing region, moderate pricing

### Storage Replication Cost Comparison

|Type|Cost Multiplier|Use Case         |
|----|---------------|-----------------|
|LRS |1x             |Development      |
|ZRS |1.25x          |Production HA    |
|GRS |2x             |Disaster Recovery|
|GZRS|2.5x           |Mission Critical |

## Troubleshooting

### Common Issues

**Issue 1: Service Not Available in Region**

```bash
# Check service availability by region
az provider show \
  --namespace Microsoft.Compute \
  --query "resourceTypes[?resourceType=='virtualMachines'].locations" \
  --output table
```

**Issue 2: Zone Configuration Fails**

```bash
# Verify availability zones supported
az vm list-skus \
  --location westeurope \
  --size Standard_D2s_v3 \
  --query "[?capabilities[?name=='AvailabilityZonePreviews']].name"
```

**Issue 3: Geo-Replication Not Working**

```bash
# Check replication status
az storage account show \
  --name georedundantstorage \
  --query "secondaryEndpoints" \
  --output json
```

## Summary

**Key Points:**

- ✅ Choose regions based on compliance, latency, and cost
- ✅ Use availability zones for 99.99% SLA
- ✅ Implement geo-redundancy for disaster recovery
- ✅ Tag all resources for data classification and compliance
- ✅ Test failover procedures regularly

**Next Layer:** [Identity & Access Management](./security-layer-2.md)

-----

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Author**: Willem van Heemstra
