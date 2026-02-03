# Security Layer 3: Perimeter Security

## Overview

Perimeter security protects the network boundary between your Azure resources and the internet. This layer includes DDoS protection, firewalls, and web application firewalls.

## Objectives

- Protect against DDoS attacks
- Control inbound/outbound traffic with Azure Firewall
- Defend web applications with WAF
- Implement threat intelligence feeds
- Enable centralized logging

## Core Components

### 1. DDoS Protection

Azure offers two tiers:

- **Basic**: Automatic, no cost, always-on
- **Standard**: Enhanced protection, real-time metrics, attack analytics

### 2. Azure Firewall

Managed, cloud-based network security service:

- Stateful firewall as a service
- Built-in high availability
- Threat intelligence-based filtering
- FQDN filtering for outbound traffic

### 3. Web Application Firewall (WAF)

Protection for web applications:

- OWASP top 10 protection
- Bot protection
- Custom rules
- Rate limiting

## Implementation with Crossplane

### 1. DDoS Protection Plan

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: DDoSProtectionPlan
metadata:
  name: production-ddos
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    tags:
      purpose: perimeter-defense
      cost-center: security
```

### 2. Associate DDoS with VNet

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
    ddosProtectionPlan:
      - idRef:
          name: production-ddos
        enable: true
```

### 3. Azure Firewall

```yaml
# Firewall subnet (must be named AzureFirewallSubnet)
apiVersion: network.azure.upbound.io/v1beta1
kind: Subnet
metadata:
  name: firewall-subnet
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    virtualNetworkNameRef:
      name: production-vnet
    addressPrefixes:
      - "10.0.255.0/26"
    # Name must be AzureFirewallSubnet
---
# Public IP for Firewall
apiVersion: network.azure.upbound.io/v1beta1
kind: PublicIP
metadata:
  name: firewall-pip
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    allocationMethod: Static
    sku: Standard
---
# Azure Firewall
apiVersion: network.azure.upbound.io/v1beta1
kind: Firewall
metadata:
  name: production-firewall
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    skuName: AZFW_VNet
    skuTier: Standard  # or Premium for TLS inspection
    ipConfiguration:
      - name: firewall-config
        publicIpAddressIdRef:
          name: firewall-pip
        subnetIdRef:
          name: firewall-subnet
    threatIntelMode: Alert  # or Deny
```

### 4. Firewall Rules

```yaml
# Network rule collection
apiVersion: network.azure.upbound.io/v1beta1
kind: FirewallNetworkRuleCollection
metadata:
  name: allow-outbound-rules
spec:
  forProvider:
    azureFirewallNameRef:
      name: production-firewall
    resourceGroupNameRef:
      name: production-rg
    priority: 100
    action: Allow
    rule:
      - name: allow-dns
        protocols:
          - UDP
        sourceAddresses:
          - "10.0.0.0/16"
        destinationAddresses:
          - "*"
        destinationPorts:
          - "53"
      - name: allow-https
        protocols:
          - TCP
        sourceAddresses:
          - "10.0.0.0/16"
        destinationAddresses:
          - "*"
        destinationPorts:
          - "443"
---
# Application rule collection
apiVersion: network.azure.upbound.io/v1beta1
kind: FirewallApplicationRuleCollection
metadata:
  name: allow-websites
spec:
  forProvider:
    azureFirewallNameRef:
      name: production-firewall
    resourceGroupNameRef:
      name: production-rg
    priority: 100
    action: Allow
    rule:
      - name: allow-microsoft-sites
        sourceAddresses:
          - "10.0.0.0/16"
        targetFqdns:
          - "*.microsoft.com"
          - "*.azure.com"
        protocol:
          - type: Https
            port: 443
```

### 5. Web Application Firewall

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: WebApplicationFirewallPolicy
metadata:
  name: production-waf-policy
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    policySettings:
      - enabled: true
        mode: Prevention  # Detection or Prevention
        requestBodyCheck: true
        maxRequestBodySizeInKb: 128
        fileUploadLimitInMb: 100
    managedRules:
      - managedRuleSet:
          - type: OWASP
            version: "3.2"
          - type: Microsoft_BotManagerRuleSet
            version: "1.0"
    customRules:
      - name: rate-limit-rule
        priority: 1
        ruleType: RateLimitRule
        rateLimitDuration: OneMin
        rateLimitThreshold: 100
        matchConditions:
          - matchVariables:
              - variableName: RemoteAddr
            operator: IPMatch
            matchValues:
              - "0.0.0.0/0"
        action: Block
```

## WAF Integration Examples

### With Application Gateway

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: ApplicationGateway
metadata:
  name: production-appgw
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    sku:
      - name: WAF_v2
        tier: WAF_v2
        capacity: 2
    webApplicationFirewallConfiguration:
      - enabled: true
        firewallMode: Prevention
        ruleSetType: OWASP
        ruleSetVersion: "3.2"
        disabledRuleGroup: []
        requestBodyCheck: true
        maxRequestBodySizeInKb: 128
        fileUploadLimitInMb: 100
    # ... rest of configuration
```

### With Front Door

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: FrontDoorFirewallPolicy
metadata:
  name: frontdoor-waf
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    enabled: true
    mode: Prevention
    managedRule:
      - type: Microsoft_DefaultRuleSet
        version: "2.0"
        action: Block
    customRule:
      - name: geo-filtering
        priority: 1
        ruleType: MatchRule
        action: Block
        matchCondition:
          - matchVariable: RemoteAddr
            operator: GeoMatch
            matchValue:
              - "CN"  # Block traffic from China (example)
```

## Best Practices

### 1. DDoS Protection

- Enable DDoS Protection Standard for production VNets
- Configure DDoS alerts and notifications
- Review DDoS reports regularly
- Test DDoS response procedures

### 2. Azure Firewall

- Use forced tunneling for hybrid scenarios
- Enable threat intelligence in Deny mode
- Implement least privilege outbound rules
- Use FQDN tags for common Microsoft services
- Enable diagnostic logging

### 3. WAF Configuration

- Start in Detection mode, move to Prevention after tuning
- Review false positives weekly
- Use custom rules for application-specific threats
- Implement rate limiting for APIs
- Enable bot protection

## Advanced Configurations

### Forced Tunneling

```yaml
# Route all internet traffic through on-premises firewall
apiVersion: network.azure.upbound.io/v1beta1
kind: RouteTable
metadata:
  name: forced-tunnel-rt
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    route:
      - name: default-route
        addressPrefix: "0.0.0.0/0"
        nextHopType: VirtualAppliance
        nextHopInIpAddress: "10.0.254.4"  # On-prem firewall
```

### Threat Intelligence Integration

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: Firewall
metadata:
  name: advanced-firewall
spec:
  forProvider:
    # ... base configuration
    threatIntelMode: Deny  # Alert or Deny
    additionalProperties:
      ThreatIntel.Allowlist.IpAddresses:
        - "203.0.113.5"  # Trusted partner IP
      ThreatIntel.Allowlist.FQDNs:
        - "trusted-partner.example.com"
```

## Monitoring and Alerts

### Key Metrics

```bash
# DDoS metrics
az monitor metrics list \
  --resource /subscriptions/${SUB}/resourceGroups/production-rg/providers/Microsoft.Network/publicIPAddresses/firewall-pip \
  --metric "IfUnderDDoSAttack"

# Firewall throughput
az monitor metrics list \
  --resource /subscriptions/${SUB}/resourceGroups/production-rg/providers/Microsoft.Network/azureFirewalls/production-firewall \
  --metric "Throughput"
```

### WAF Logs

```bash
# Query WAF logs
az monitor log-analytics query \
  --workspace ${WORKSPACE_ID} \
  --analytics-query "AzureDiagnostics | where Category == 'ApplicationGatewayFirewallLog' | limit 100"
```

## Testing

### Test DDoS Protection

```bash
# Check DDoS plan association
az network vnet show \
  --name production-vnet \
  --resource-group production-rg \
  --query ddosProtectionPlan
```

### Test Firewall Rules

```bash
# From a VM in the VNet, test outbound access
curl https://www.microsoft.com  # Should work
curl https://blocked-site.com   # Should be blocked
```

### Test WAF

```bash
# Test SQL injection (should be blocked)
curl -X POST "https://app.example.com/login" \
  -d "username=admin&password=' OR '1'='1"

# Expected: 403 Forbidden from WAF
```

## Cost Optimization

### DDoS Protection

- Standard plan: ~$2,944/month base + $29.44/protected resource
- Consider if protection cost < potential DDoS damage

### Azure Firewall

- Standard tier: ~$1.25/hour + $0.016/GB processed
- Stop/Start firewall in non-production environments
- Use Firewall Policy to share rules across firewalls

### WAF

- Application Gateway WAF_v2: ~$0.443/hour + $0.008/GB
- Front Door WAF: ~$0.036/hour + per-rule pricing

## Troubleshooting

### Issue: DDoS False Positives

```bash
# Review DDoS metrics
az network ddos-protection show \
  --resource-group production-rg \
  --name production-ddos

# Adjust thresholds if needed
```

### Issue: Firewall Blocking Legitimate Traffic

```bash
# Check firewall logs
az monitor log-analytics query \
  --workspace ${WORKSPACE_ID} \
  --analytics-query "AzureDiagnostics | where Category == 'AzureFirewallApplicationRule' | where msg_s contains 'Deny'"

# Add allow rule for legitimate traffic
```

### Issue: WAF Blocking Application

```bash
# Identify which rule triggered
az monitor log-analytics query \
  --workspace ${WORKSPACE_ID} \
  --analytics-query "AzureDiagnostics | where Category == 'ApplicationGatewayFirewallLog' | where action_s == 'Blocked'"

# Disable specific rule or add exclusion
```

## Summary

**Key Points:**

- ✅ Enable DDoS Protection Standard for production
- ✅ Deploy Azure Firewall for centralized control
- ✅ Use WAF to protect web applications
- ✅ Enable threat intelligence in Deny mode
- ✅ Monitor and tune WAF rules regularly

**Next Layer:** [Network Security](./security-layer-4.md)

-----

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Author**: Willem van Heemstra
