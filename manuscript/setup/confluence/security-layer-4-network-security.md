# Security Layer 4: Network Security

## Overview

Network security controls traffic flow between resources, implements network segmentation, and restricts access using subnets, NSGs, and private endpoints.

## Objectives

- Segment networks with VNets and subnets
- Control traffic with Network Security Groups (NSGs)
- Implement private connectivity with Private Endpoints
- Use Service Endpoints for Azure PaaS services
- Enable network monitoring and flow logs

## Implementation

### 1. Virtual Network Segmentation

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: VirtualNetwork
metadata:
  name: production-vnet
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    addressSpace:
      - "10.0.0.0/16"
    tags:
      security-zone: production
      network-tier: private
```

### 2. Subnets with Delegation

```yaml
# Web tier subnet
apiVersion: network.azure.upbound.io/v1beta1
kind: Subnet
metadata:
  name: web-subnet
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    virtualNetworkNameRef:
      name: production-vnet
    addressPrefixes:
      - "10.0.1.0/24"
    serviceEndpoints:
      - Microsoft.Storage
      - Microsoft.KeyVault
---
# Data tier subnet
apiVersion: network.azure.upbound.io/v1beta1
kind: Subnet
metadata:
  name: data-subnet
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    virtualNetworkNameRef:
      name: production-vnet
    addressPrefixes:
      - "10.0.2.0/24"
    privateEndpointNetworkPolicies: Disabled  # Required for private endpoints
```

### 3. Network Security Groups (NSGs)

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: SecurityGroup
metadata:
  name: web-tier-nsg
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    securityRule:
      # Allow HTTPS from internet
      - name: allow-https-inbound
        priority: 100
        direction: Inbound
        access: Allow
        protocol: Tcp
        sourcePortRange: "*"
        destinationPortRange: "443"
        sourceAddressPrefix: Internet
        destinationAddressPrefix: "*"
      # Allow database access from web tier
      - name: allow-sql-to-data-tier
        priority: 110
        direction: Outbound
        access: Allow
        protocol: Tcp
        sourcePortRange: "*"
        destinationPortRange: "1433"
        sourceAddressPrefix: "10.0.1.0/24"
        destinationAddressPrefix: "10.0.2.0/24"
      # Deny all other inbound
      - name: deny-all-inbound
        priority: 4096
        direction: Inbound
        access: Deny
        protocol: "*"
        sourcePortRange: "*"
        destinationPortRange: "*"
        sourceAddressPrefix: "*"
        destinationAddressPrefix: "*"
```

### 4. Private Endpoints

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: PrivateEndpoint
metadata:
  name: storage-private-endpoint
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    subnetIdRef:
      name: data-subnet
    privateLinkServiceConnection:
      - name: storage-connection
        privateLinkServiceIdRef:
          name: production-storage
        groupIds:
          - blob
        requestMessage: "Private endpoint for secure storage access"
```

### 5. NSG Flow Logs

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: NetworkWatcherFlowLog
metadata:
  name: web-nsg-flow-logs
spec:
  forProvider:
    networkWatcherName: NetworkWatcher_westeurope
    resourceGroupName: NetworkWatcherRG
    networkSecurityGroupIdRef:
      name: web-tier-nsg
    storageAccountIdRef:
      name: flow-logs-storage
    enabled: true
    retentionPolicy:
      - enabled: true
        days: 90
    format:
      - type: JSON
        version: 2
    trafficAnalytics:
      - enabled: true
        workspaceIdRef:
          name: security-logs-workspace
```

## Best Practices

**NSG Rules:**

- Deny by default, allow explicitly
- Use service tags instead of IP ranges
- Document business justification for each rule
- Review rules quarterly

**Network Segmentation:**

- Separate tiers (web, app, data)
- Use dedicated subnets for management
- Implement jump boxes for admin access

**Private Connectivity:**

- Use private endpoints for all PaaS services
- Disable public endpoints where possible
- Implement DNS for private endpoint resolution

## Summary

✅ Segment networks by tier and function  
✅ Apply deny-by-default NSG rules  
✅ Use private endpoints for PaaS services  
✅ Enable NSG flow logs for monitoring

**Next Layer:** [Compute Security](./security-layer-5.md)
