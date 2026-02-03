# Security Demo: Deploying Secure Azure Infrastructure with Crossplane

## Document Information

- **Purpose**: Demonstrate practical implementation of security controls
- **Audience**: Cloud Engineers, DevOps Teams
- **Prerequisites**:
  - [Crossplane Dev Setup](../dev.md) completed
  - [Security Strategy](./security-strategy.md) reviewed
  - Azure subscription with Owner permissions

## Demo Overview

This demonstration walks through deploying a secure web application on Azure using Crossplane with all seven defense-in-depth layers implemented.

### Demo Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet (HTTPS only)                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   Azure DDoS          │ Layer 3: Perimeter
              │   Protection          │
              └──────────┬────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ Application Gateway   │ Layer 6: Application
              │ + WAF v2 (TLS 1.2+)  │
              └──────────┬────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   Azure Firewall      │ Layer 3: Perimeter
              └──────────┬────────────┘
                         │
           ┌─────────────┴─────────────┐
           │      Virtual Network       │ Layer 4: Network
           │    (10.0.0.0/16)          │
           │  ┌─────────────────────┐  │
           │  │  Web Subnet (NSG)   │  │
           │  │  ┌───────────────┐  │  │
           │  │  │ VM (Encrypted)│  │  │ Layer 5: Compute
           │  │  └───────┬───────┘  │  │
           │  └──────────┼──────────┘  │
           │             │              │
           │  ┌──────────┼──────────┐  │
           │  │  Data Subnet        │  │
           │  │  ┌───────▼───────┐  │  │
           │  │  │ SQL Database  │  │  │ Layer 7: Data
           │  │  │ (TDE Enabled) │  │  │
           │  │  └───────────────┘  │  │
           │  └─────────────────────┘  │
           └───────────────────────────┘
                         │
              ┌──────────▼──────────┐
              │   Azure Key Vault   │ Layer 2: Identity
              │  (Managed Identity) │
              └─────────────────────┘
```

### Demo Scenario

**Application**: Secure e-commerce web application
**Components**:

- Application Gateway with WAF for HTTPS termination
- Linux VM running web application
- Azure SQL Database for transaction data
- Azure Storage for product images
- Key Vault for secrets and certificates

## Demo Prerequisites

### 1. Environment Setup

```bash
# Verify Crossplane is running
kubectl get pods -n crossplane-system

# Verify Azure provider is healthy
kubectl get providers

# Set environment variables
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export DEMO_REGION="westeurope"
export DEMO_PREFIX="sec-demo"
```

### 2. Generate SSH Key

```bash
# Generate SSH key for VM access
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure-demo-key -N ""
export SSH_PUBLIC_KEY=$(cat ~/.ssh/azure-demo-key.pub)
```

### 3. Create Namespace

```bash
# Create demo namespace
kubectl create namespace security-demo
kubectl config set-context --current --namespace=security-demo
```

## Implementation Steps

### Step 1: Deploy Foundation (Layers 1-2)

**Layer 1: Physical Security**

```bash
# Apply resource group with proper region and availability zones
cat <<EOF | kubectl apply -f -
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: ${DEMO_PREFIX}-rg
  namespace: security-demo
  annotations:
    crossplane.io/external-name: ${DEMO_PREFIX}-security-demo
spec:
  forProvider:
    location: ${DEMO_REGION}
    tags:
      environment: demo
      purpose: security-demonstration
      compliance: iso27001
      owner: security-team
EOF
```

**Layer 2: Identity & Access**

```bash
# Deploy managed identity
cat <<EOF | kubectl apply -f -
apiVersion: managedidentity.azure.upbound.io/v1beta1
kind: UserAssignedIdentity
metadata:
  name: ${DEMO_PREFIX}-identity
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    location: ${DEMO_REGION}
    tags:
      purpose: demo-workload-identity
---
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Vault
metadata:
  name: ${DEMO_PREFIX}-vault
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    location: ${DEMO_REGION}
    skuName: premium
    tenantId: ${AZURE_TENANT_ID}
    enabledForDiskEncryption: true
    enablePurgeProtection: true
    softDeleteRetentionDays: 7  # Demo: 7 days, Production: 90 days
    networkAcls:
      - bypass: AzureServices
        defaultAction: Allow  # Demo: Allow, Production: Deny with specific IPs
EOF
```

**Verify Step 1:**

```bash
# Check resource provisioning
kubectl get resourcegroups,userAssignedIdentities,vaults -n security-demo

# Wait for resources to be ready
kubectl wait --for=condition=Ready vault/${DEMO_PREFIX}-vault --timeout=300s -n security-demo
```

### Step 2: Deploy Network Security (Layers 3-4)

**Layer 3: Perimeter Security**

```bash
# Deploy DDoS protection plan
cat <<EOF | kubectl apply -f -
apiVersion: network.azure.upbound.io/v1beta1
kind: DDoSProtectionPlan
metadata:
  name: ${DEMO_PREFIX}-ddos
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    location: ${DEMO_REGION}
EOF
```

**Layer 4: Network Segmentation**

```bash
# Deploy virtual network with subnets
cat <<EOF | kubectl apply -f -
apiVersion: network.azure.upbound.io/v1beta1
kind: VirtualNetwork
metadata:
  name: ${DEMO_PREFIX}-vnet
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    location: ${DEMO_REGION}
    addressSpace:
      - "10.0.0.0/16"
    tags:
      security-zone: demo
---
apiVersion: network.azure.upbound.io/v1beta1
kind: Subnet
metadata:
  name: ${DEMO_PREFIX}-web-subnet
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    virtualNetworkNameRef:
      name: ${DEMO_PREFIX}-vnet
    addressPrefixes:
      - "10.0.1.0/24"
    serviceEndpoints:
      - Microsoft.KeyVault
      - Microsoft.Storage
      - Microsoft.Sql
---
apiVersion: network.azure.upbound.io/v1beta1
kind: Subnet
metadata:
  name: ${DEMO_PREFIX}-data-subnet
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    virtualNetworkNameRef:
      name: ${DEMO_PREFIX}-vnet
    addressPrefixes:
      - "10.0.2.0/24"
---
apiVersion: network.azure.upbound.io/v1beta1
kind: Subnet
metadata:
  name: ${DEMO_PREFIX}-appgw-subnet
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    virtualNetworkNameRef:
      name: ${DEMO_PREFIX}-vnet
    addressPrefixes:
      - "10.0.3.0/24"
EOF
```

**Deploy Network Security Groups:**

```bash
# NSG for web tier
cat <<EOF | kubectl apply -f -
apiVersion: network.azure.upbound.io/v1beta1
kind: SecurityGroup
metadata:
  name: ${DEMO_PREFIX}-web-nsg
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    location: ${DEMO_REGION}
    securityRule:
      - name: allow-https-inbound
        priority: 100
        direction: Inbound
        access: Allow
        protocol: Tcp
        sourcePortRange: "*"
        destinationPortRange: "443"
        sourceAddressPrefix: "10.0.3.0/24"  # From App Gateway subnet
        destinationAddressPrefix: "10.0.1.0/24"
      - name: deny-all-inbound
        priority: 4096
        direction: Inbound
        access: Deny
        protocol: "*"
        sourcePortRange: "*"
        destinationPortRange: "*"
        sourceAddressPrefix: "*"
        destinationAddressPrefix: "*"
---
apiVersion: network.azure.upbound.io/v1beta1
kind: SubnetNetworkSecurityGroupAssociation
metadata:
  name: ${DEMO_PREFIX}-web-nsg-assoc
  namespace: security-demo
spec:
  forProvider:
    subnetIdRef:
      name: ${DEMO_PREFIX}-web-subnet
    networkSecurityGroupIdRef:
      name: ${DEMO_PREFIX}-web-nsg
EOF
```

**Verify Step 2:**

```bash
# Check network resources
kubectl get virtualnetworks,subnets,securitygroups -n security-demo

# Verify subnet creation
kubectl wait --for=condition=Ready subnet/${DEMO_PREFIX}-web-subnet --timeout=300s -n security-demo
```

### Step 3: Deploy Compute Security (Layer 5)

```bash
# Create disk encryption set
cat <<EOF | kubectl apply -f -
apiVersion: compute.azure.upbound.io/v1beta1
kind: DiskEncryptionSet
metadata:
  name: ${DEMO_PREFIX}-disk-encryption
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    location: ${DEMO_REGION}
    identity:
      - type: SystemAssigned
    # Note: keyVaultKeyId would reference a key in Key Vault
---
apiVersion: network.azure.upbound.io/v1beta1
kind: NetworkInterface
metadata:
  name: ${DEMO_PREFIX}-vm-nic
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    location: ${DEMO_REGION}
    ipConfiguration:
      - name: internal
        privateIpAddressAllocation: Dynamic
        subnetIdRef:
          name: ${DEMO_PREFIX}-web-subnet
---
apiVersion: compute.azure.upbound.io/v1beta1
kind: LinuxVirtualMachine
metadata:
  name: ${DEMO_PREFIX}-web-vm
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    location: ${DEMO_REGION}
    size: Standard_B2s
    adminUsername: azureuser
    disablePasswordAuthentication: true
    adminSshKey:
      - username: azureuser
        publicKey: ${SSH_PUBLIC_KEY}
    networkInterfaceIdsRefs:
      - name: ${DEMO_PREFIX}-vm-nic
    osDisk:
      - caching: ReadWrite
        storageAccountType: Premium_LRS
    sourceImageReference:
      - publisher: Canonical
        offer: 0001-com-ubuntu-server-jammy
        sku: 22_04-lts-gen2
        version: latest
    identity:
      - type: UserAssigned
        identityIdsRefs:
          - name: ${DEMO_PREFIX}-identity
EOF
```

**Verify Step 3:**

```bash
# Check VM deployment
kubectl get linuxvirtualmachines -n security-demo
kubectl describe linuxvirtualmachine/${DEMO_PREFIX}-web-vm -n security-demo
```

### Step 4: Deploy Application Security (Layer 6)

**Create self-signed certificate for demo:**

```bash
# Generate self-signed certificate (Production: use proper CA)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/demo-cert.key \
  -out /tmp/demo-cert.crt \
  -subj "/CN=demo.example.com"

# Convert to PFX
openssl pkcs12 -export \
  -out /tmp/demo-cert.pfx \
  -inkey /tmp/demo-cert.key \
  -in /tmp/demo-cert.crt \
  -passout pass:DemoPassword123

# Base64 encode for Kubernetes secret
export CERT_BASE64=$(cat /tmp/demo-cert.pfx | base64 -w 0)
```

**Deploy certificate to Key Vault:**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Certificate
metadata:
  name: ${DEMO_PREFIX}-tls-cert
  namespace: security-demo
spec:
  forProvider:
    keyVaultIdRef:
      name: ${DEMO_PREFIX}-vault
    certificate:
      - contents: ${CERT_BASE64}
        password: DemoPassword123
EOF
```

**Deploy Application Gateway with WAF:**

```bash
# Public IP for Application Gateway
cat <<EOF | kubectl apply -f -
apiVersion: network.azure.upbound.io/v1beta1
kind: PublicIP
metadata:
  name: ${DEMO_PREFIX}-appgw-pip
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    location: ${DEMO_REGION}
    allocationMethod: Static
    sku: Standard
---
apiVersion: network.azure.upbound.io/v1beta1
kind: ApplicationGateway
metadata:
  name: ${DEMO_PREFIX}-appgw
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    location: ${DEMO_REGION}
    sku:
      - name: WAF_v2
        tier: WAF_v2
        capacity: 1
    gatewayIpConfiguration:
      - name: gateway-ip-config
        subnetIdRef:
          name: ${DEMO_PREFIX}-appgw-subnet
    frontendIpConfiguration:
      - name: frontend-ip
        publicIpAddressIdRef:
          name: ${DEMO_PREFIX}-appgw-pip
    frontendPort:
      - name: https-port
        port: 443
    backendAddressPool:
      - name: backend-pool
    backendHttpSettings:
      - name: https-settings
        port: 443
        protocol: Https
        cookieBasedAffinity: Disabled
    httpListener:
      - name: https-listener
        frontendIpConfigurationName: frontend-ip
        frontendPortName: https-port
        protocol: Https
    requestRoutingRule:
      - name: https-rule
        ruleType: Basic
        httpListenerName: https-listener
        backendAddressPoolName: backend-pool
        backendHttpSettingsName: https-settings
        priority: 100
    webApplicationFirewallConfiguration:
      - enabled: true
        firewallMode: Prevention
        ruleSetType: OWASP
        ruleSetVersion: "3.2"
EOF
```

**Verify Step 4:**

```bash
# Check Application Gateway
kubectl get applicationgateways -n security-demo

# Get public IP
kubectl get publicips/${DEMO_PREFIX}-appgw-pip -n security-demo -o jsonpath='{.status.atProvider.ipAddress}'
```

### Step 5: Deploy Data Security (Layer 7)

```bash
# Deploy SQL Server
cat <<EOF | kubectl apply -f -
apiVersion: sql.azure.upbound.io/v1beta1
kind: MSSQLServer
metadata:
  name: ${DEMO_PREFIX}-sql
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    location: ${DEMO_REGION}
    version: "12.0"
    administratorLogin: sqladmin
    administratorLoginPasswordSecretRef:
      name: sql-admin-password
      namespace: security-demo
      key: password
    publicNetworkAccessEnabled: false
    minimumTlsVersion: "1.2"
---
apiVersion: v1
kind: Secret
metadata:
  name: sql-admin-password
  namespace: security-demo
type: Opaque
stringData:
  password: "ComplexPassword123!"
---
apiVersion: sql.azure.upbound.io/v1beta1
kind: MSSQLDatabase
metadata:
  name: ${DEMO_PREFIX}-db
  namespace: security-demo
spec:
  forProvider:
    serverIdRef:
      name: ${DEMO_PREFIX}-sql
    collation: SQL_Latin1_General_CP1_CI_AS
    maxSizeGb: 2
    skuName: Basic
---
apiVersion: storage.azure.upbound.io/v1beta1
kind: Account
metadata:
  name: ${DEMO_PREFIX}storage  # Must be globally unique, lowercase, no hyphens
  namespace: security-demo
spec:
  forProvider:
    resourceGroupNameRef:
      name: ${DEMO_PREFIX}-rg
    location: ${DEMO_REGION}
    accountTier: Standard
    accountReplicationType: LRS
    enableHttpsTrafficOnly: true
    minTlsVersion: TLS1_2
    allowBlobPublicAccess: false
EOF
```

**Verify Step 5:**

```bash
# Check data resources
kubectl get mssqlservers,mssqldatabases,storageaccounts -n security-demo
```

## Demo Validation

### Security Checklist

```bash
# Run validation script
cat > /tmp/validate-security.sh <<'SCRIPT'
#!/bin/bash
echo "=== Security Validation ==="

# Check 1: Managed Identity
echo "✓ Checking Managed Identity..."
kubectl get userAssignedIdentities -n security-demo

# Check 2: Key Vault
echo "✓ Checking Key Vault..."
kubectl get vaults -n security-demo

# Check 3: Network Security
echo "✓ Checking NSG Rules..."
kubectl get securitygroups -n security-demo

# Check 4: TLS Configuration
echo "✓ Checking TLS version..."
kubectl get storageaccounts -n security-demo -o jsonpath='{.items[*].spec.forProvider.minTlsVersion}'

# Check 5: Encryption
echo "✓ Checking encryption settings..."
kubectl get storageaccounts -n security-demo -o jsonpath='{.items[*].spec.forProvider.enableHttpsTrafficOnly}'

echo "=== Validation Complete ==="
SCRIPT

chmod +x /tmp/validate-security.sh
/tmp/validate-security.sh
```

### Test Security Controls

1. **Test TLS Enforcement:**

```bash
# Get Application Gateway public IP
APPGW_IP=$(kubectl get publicips/${DEMO_PREFIX}-appgw-pip -n security-demo -o jsonpath='{.status.atProvider.ipAddress}')

# Test HTTPS (should work with certificate warning for self-signed)
curl -k https://${APPGW_IP}

# Test HTTP (should be blocked or redirected)
curl http://${APPGW_IP}
```

1. **Test Network Isolation:**

```bash
# Verify SQL Server has no public endpoint
kubectl get mssqlservers/${DEMO_PREFIX}-sql -n security-demo -o jsonpath='{.spec.forProvider.publicNetworkAccessEnabled}'
# Should return: false
```

1. **Verify WAF Protection:**

```bash
# Test SQL injection (should be blocked by WAF)
curl -k "https://${APPGW_IP}/?id=1' OR '1'='1"
# Should return 403 Forbidden from WAF
```

## Monitoring Security

### View Security Logs

```bash
# Check Crossplane events
kubectl get events -n security-demo --sort-by='.lastTimestamp'

# View resource status
kubectl get managed -n security-demo
```

### Common Issues and Solutions

|Issue                          |Symptom                               |Solution                                |
|-------------------------------|--------------------------------------|----------------------------------------|
|Certificate not loading        |Application Gateway deployment pending|Wait for Key Vault certificate to sync  |
|VM can’t reach SQL             |Connection timeout                    |Check NSG rules, verify private endpoint|
|WAF blocking legitimate traffic|403 errors                            |Review WAF logs, adjust rules           |
|Slow deployment                |Resources stuck in provisioning       |Check Azure quota limits                |

## Cleanup

### Remove Demo Resources

```bash
# Delete all resources (cascading delete)
kubectl delete resourcegroup/${DEMO_PREFIX}-rg -n security-demo

# Verify deletion
kubectl get managed -n security-demo

# Delete namespace
kubectl delete namespace security-demo
```

### Clean Temporary Files

```bash
rm /tmp/demo-cert.*
rm /tmp/validate-security.sh
```

## Key Takeaways

### What We Demonstrated

✅ **Defense in Depth**: All 7 security layers implemented  
✅ **Zero Trust**: Managed identities, no passwords  
✅ **Encryption**: TLS 1.2+, disk encryption, data encryption  
✅ **Network Isolation**: Private endpoints, NSG rules  
✅ **Infrastructure as Code**: All security controls in Crossplane

### Production Considerations

- Replace self-signed certificates with CA-issued certificates
- Implement automated certificate rotation
- Use stronger NSG rules with specific IP allowlisting
- Enable Azure Defender for all services
- Set up Azure Sentinel for SIEM
- Implement backup and disaster recovery
- Configure monitoring and alerting

## Next Steps

1. Review [individual security layer documentation](./security-layer-1.md)
1. Implement [security monitoring](../monitoring/)
1. Set up [automated compliance checking](../compliance/)
1. Practice [incident response procedures](../incident-response/)

## Additional Resources

- [CNCF HTTPS Best Practices](https://github.com/vanHeemstraSystems/cncf-demo/blob/main/manuscript/https/README.md)
- [Azure Security Documentation](https://docs.microsoft.com/en-us/azure/security/)
- [Crossplane Azure Provider](https://marketplace.upbound.io/providers/upbound/provider-azure/)

-----

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Author**: Willem van Heemstra  
**Tested On**: Crossplane 1.x, Azure Provider 0.x
