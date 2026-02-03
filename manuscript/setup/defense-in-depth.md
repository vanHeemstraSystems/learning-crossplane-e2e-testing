# Defense in Depth for Crossplane Azure Deployments

**Based on:** [Crossplane Dev Setup](./dev.md)  
**Security Framework:** [Defense in Depth of Cyber Carrots](https://github.com/vanHeemstraPublications/dev-to/blob/main/articles/defense-in-depth-of-cyber-carrots.md)  
**CNCF Best Practices:** [CNCF Demo Repository](https://github.com/vanHeemstraSystems/cncf-demo)

## Overview

This guide extends the basic Crossplane deployment instructions with comprehensive defense-in-depth security controls. Each layer builds upon the previous one to create a robust security posture for your Azure infrastructure.

## Prerequisites

- Completed [dev.md setup](./dev.md)
- Azure subscription with appropriate permissions
- Understanding of [defense-in-depth principles](https://github.com/vanHeemstraPublications/dev-to/blob/main/articles/defense-in-depth-of-cyber-carrots.md)

## Security Layers

### Layer 1: Physical Security

While Azure manages physical data center security, you control resource placement and redundancy.

#### 1.1 Region Selection

```yaml
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: secure-rg
  annotations:
    crossplane.io/external-name: secure-production-rg
spec:
  forProvider:
    location: westeurope  # Choose region based on compliance requirements
    tags:
      environment: production
      compliance: iso27001
      data-classification: confidential
```

#### 1.2 Availability Zones

```yaml
apiVersion: compute.azure.upbound.io/v1beta1
kind: LinuxVirtualMachine
metadata:
  name: secure-vm
spec:
  forProvider:
    zones:
      - "1"
      - "2"
      - "3"
    # Additional configuration...
```

### Layer 2: Identity & Access Management

Implement Azure AD integration and RBAC controls.

#### 2.1 Managed Identity

```yaml
apiVersion: managedidentity.azure.upbound.io/v1beta1
kind: UserAssignedIdentity
metadata:
  name: workload-identity
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    tags:
      purpose: crossplane-workload
```

#### 2.2 RBAC Role Assignment

```yaml
apiVersion: authorization.azure.upbound.io/v1beta1
kind: RoleAssignment
metadata:
  name: workload-contributor
spec:
  forProvider:
    principalIdRef:
      name: workload-identity
    roleDefinitionId: /subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c  # Contributor
    scope: /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/secure-rg
```

#### 2.3 Key Vault for Secrets

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Vault
metadata:
  name: secure-vault
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
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
          - value: ${ALLOWED_IP}/32
```

### Layer 3: Perimeter Security

Protect the network boundary with firewalls and DDoS protection.

#### 3.1 DDoS Protection Plan

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: DDoSProtectionPlan
metadata:
  name: ddos-protection
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
```

#### 3.2 Azure Firewall

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: Firewall
metadata:
  name: perimeter-firewall
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    skuName: AZFW_VNet
    skuTier: Standard
    ipConfiguration:
      - name: firewall-config
        publicIpAddressIdRef:
          name: firewall-pip
        subnetIdRef:
          name: AzureFirewallSubnet
```

#### 3.3 Web Application Firewall (WAF)

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: WebApplicationFirewallPolicy
metadata:
  name: waf-policy
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    policySettings:
      - enabled: true
        mode: Prevention
        requestBodyCheck: true
        maxRequestBodySizeInKb: 128
    managedRules:
      - managedRuleSet:
          - type: OWASP
            version: "3.2"
```

### Layer 4: Network Security

Segment networks and control traffic flow.

#### 4.1 Virtual Network with Segmentation

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: VirtualNetwork
metadata:
  name: secure-vnet
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    addressSpace:
      - 10.0.0.0/16
    ddosProtectionPlan:
      - id: ${DDOS_PLAN_ID}
        enable: true
    tags:
      security-zone: production
```

#### 4.2 Network Security Groups (NSG)

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: SecurityGroup
metadata:
  name: web-tier-nsg
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    securityRule:
      - name: allow-https
        priority: 100
        direction: Inbound
        access: Allow
        protocol: Tcp
        sourcePortRange: "*"
        destinationPortRange: "443"
        sourceAddressPrefix: Internet
        destinationAddressPrefix: "*"
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

#### 4.3 Private Endpoints

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: PrivateEndpoint
metadata:
  name: storage-private-endpoint
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    subnetIdRef:
      name: private-endpoint-subnet
    privateLinkServiceConnection:
      - name: storage-connection
        privateLinkServiceIdRef:
          name: secure-storage
        groupIds:
          - blob
        requestMessage: "Private endpoint for secure storage"
```

#### 4.4 Service Endpoints

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: Subnet
metadata:
  name: app-subnet
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    virtualNetworkNameRef:
      name: secure-vnet
    addressPrefixes:
      - 10.0.1.0/24
    serviceEndpoints:
      - Microsoft.Storage
      - Microsoft.KeyVault
      - Microsoft.Sql
```

### Layer 5: Compute Security

Harden virtual machines and container hosts.

#### 5.1 VM with Security Extensions

```yaml
apiVersion: compute.azure.upbound.io/v1beta1
kind: LinuxVirtualMachine
metadata:
  name: secure-vm
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    size: Standard_D2s_v3
    adminUsername: azureuser
    disablePasswordAuthentication: true
    adminSshKey:
      - username: azureuser
        publicKey: ${SSH_PUBLIC_KEY}
    osDisk:
      - caching: ReadWrite
        storageAccountType: Premium_LRS
        diskEncryptionSetIdRef:
          name: disk-encryption-set
    sourceImageReference:
      - publisher: Canonical
        offer: 0001-com-ubuntu-server-jammy
        sku: 22_04-lts-gen2
        version: latest
    identity:
      - type: UserAssigned
        identityIdsRefs:
          - name: workload-identity
    bootDiagnostics:
      - storageAccountUriRef:
          name: diagnostics-storage
```

#### 5.2 Azure Disk Encryption

```yaml
apiVersion: compute.azure.upbound.io/v1beta1
kind: DiskEncryptionSet
metadata:
  name: disk-encryption-set
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    identity:
      - type: SystemAssigned
    keyVaultKeyIdRef:
      name: disk-encryption-key
    encryptionType: EncryptionAtRestWithPlatformAndCustomerKeys
```

#### 5.3 Azure Security Center Integration

```yaml
apiVersion: security.azure.upbound.io/v1beta1
kind: SecurityCenterSubscriptionPricing
metadata:
  name: vm-pricing
spec:
  forProvider:
    tier: Standard
    resourceType: VirtualMachines
```

#### 5.4 Update Management

```yaml
apiVersion: automation.azure.upbound.io/v1beta1
kind: SoftwareUpdateConfiguration
metadata:
  name: monthly-updates
spec:
  forProvider:
    automationAccountNameRef:
      name: update-automation
    resourceGroupNameRef:
      name: secure-rg
    schedule:
      - frequency: Month
        interval: 1
        startTime: "2026-01-01T02:00:00Z"
        timeZone: Europe/Amsterdam
    operatingSystem: Linux
    linux:
      - includedPackageClassifications:
          - Critical
          - Security
        rebootSetting: IfRequired
```

### Layer 6: Application Security

Secure applications with HTTPS, secrets management, and WAF.

#### 6.1 HTTPS/TLS Configuration

Based on [CNCF HTTPS Best Practices](https://github.com/vanHeemstraSystems/cncf-demo/blob/main/manuscript/https/README.md):

##### 6.1.1 Certificate Management with Key Vault

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Certificate
metadata:
  name: app-tls-cert
spec:
  forProvider:
    keyVaultIdRef:
      name: secure-vault
    certificate:
      - contents: ${CERT_CONTENTS}  # PFX format
        password: ${CERT_PASSWORD}
    certificatePolicy:
      - issuerParameters:
          - name: Self  # Or use Let's Encrypt/DigiCert
        keyProperties:
          - exportable: true
            keySize: 2048
            keyType: RSA
            reuseKey: true
        lifetimeAction:
          - action:
              - actionType: AutoRenew
            trigger:
              - daysBeforeExpiry: 30
        secretProperties:
          - contentType: application/x-pkcs12
        x509CertificateProperties:
          - keyUsage:
              - cRLSign
              - dataEncipherment
              - digitalSignature
              - keyAgreement
              - keyCertSign
              - keyEncipherment
            subject: CN=app.example.com
            validityInMonths: 12
            subjectAlternativeNames:
              - dnsNames:
                  - app.example.com
                  - www.app.example.com
```

##### 6.1.2 Application Gateway with SSL/TLS

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: ApplicationGateway
metadata:
  name: secure-appgw
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    sku:
      - name: WAF_v2
        tier: WAF_v2
        capacity: 2
    gatewayIpConfiguration:
      - name: gateway-ip-config
        subnetIdRef:
          name: appgw-subnet
    frontendIpConfiguration:
      - name: frontend-ip
        publicIpAddressIdRef:
          name: appgw-pip
    frontendPort:
      - name: https-port
        port: 443
      - name: http-port
        port: 80
    backendAddressPool:
      - name: backend-pool
        ipAddresses:
          - ${BACKEND_IP}
    backendHttpSettings:
      - name: https-settings
        port: 443
        protocol: Https
        cookieBasedAffinity: Disabled
        requestTimeout: 30
        pickHostNameFromBackendAddress: false
        hostName: app.example.com
        probe:
          - id: ${HEALTH_PROBE_ID}
    sslCertificate:
      - name: app-ssl-cert
        keyVaultSecretIdRef:
          name: app-tls-cert
    httpListener:
      - name: https-listener
        frontendIpConfigurationName: frontend-ip
        frontendPortName: https-port
        protocol: Https
        sslCertificateName: app-ssl-cert
        requireServerNameIndication: true
        hostName: app.example.com
      - name: http-listener
        frontendIpConfigurationName: frontend-ip
        frontendPortName: http-port
        protocol: Http
    redirectConfiguration:
      - name: http-to-https
        redirectType: Permanent
        targetListenerName: https-listener
        includePath: true
        includeQueryString: true
    requestRoutingRule:
      - name: https-rule
        ruleType: Basic
        httpListenerName: https-listener
        backendAddressPoolName: backend-pool
        backendHttpSettingsName: https-settings
        priority: 100
      - name: http-redirect-rule
        ruleType: Basic
        httpListenerName: http-listener
        redirectConfigurationName: http-to-https
        priority: 200
    sslPolicy:
      - policyType: Predefined
        policyName: AppGwSslPolicy20220101  # TLS 1.2+
    webApplicationFirewallConfiguration:
      - enabled: true
        firewallMode: Prevention
        ruleSetType: OWASP
        ruleSetVersion: "3.2"
        disabledRuleGroup: []
        requestBodyCheck: true
        maxRequestBodySizeInKb: 128
        fileUploadLimitInMb: 100
```

##### 6.1.3 TLS Best Practices Configuration

Create a Composition for TLS best practices:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: secure-tls-configuration
spec:
  compositeTypeRef:
    apiVersion: custom.azure.example.com/v1alpha1
    kind: SecureTLSConfig
  resources:
    - name: ssl-policy
      base:
        apiVersion: network.azure.upbound.io/v1beta1
        kind: ApplicationGatewaySslPolicy
        spec:
          forProvider:
            minProtocolVersion: TLSv1_2  # Minimum TLS 1.2
            cipherSuites:
              - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
              - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
              - TLS_DHE_RSA_WITH_AES_256_GCM_SHA384
              - TLS_DHE_RSA_WITH_AES_128_GCM_SHA256
            policyType: Custom
```

##### 6.1.4 HSTS (HTTP Strict Transport Security)

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: ApplicationGatewayRewriteRuleSet
metadata:
  name: security-headers
spec:
  forProvider:
    applicationGatewayNameRef:
      name: secure-appgw
    resourceGroupNameRef:
      name: secure-rg
    rewriteRule:
      - name: add-hsts
        ruleSequence: 100
        responseHeaderConfiguration:
          - headerName: Strict-Transport-Security
            headerValue: max-age=31536000; includeSubDomains; preload
      - name: add-security-headers
        ruleSequence: 101
        responseHeaderConfiguration:
          - headerName: X-Content-Type-Options
            headerValue: nosniff
          - headerName: X-Frame-Options
            headerValue: DENY
          - headerName: X-XSS-Protection
            headerValue: "1; mode=block"
```

##### 6.1.5 Certificate Auto-Renewal with Let’s Encrypt

For automated certificate management, integrate with cert-manager (Kubernetes) or Azure App Service Managed Certificates:

```yaml
# For AKS workloads - cert-manager configuration
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-tls
  namespace: production
spec:
  secretName: app-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - app.example.com
    - www.app.example.com
  renewBefore: 720h  # 30 days
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: security@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
```

#### 6.2 Application Secrets Management

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: db-connection-string
spec:
  forProvider:
    keyVaultIdRef:
      name: secure-vault
    value: ${DB_CONNECTION_STRING}
    contentType: text/plain
    expirationDate: "2026-12-31T23:59:59Z"
```

#### 6.3 API Management Security

```yaml
apiVersion: apimanagement.azure.upbound.io/v1beta1
kind: Service
metadata:
  name: secure-apim
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    publisherName: "Your Organization"
    publisherEmail: security@example.com
    skuName: Developer_1
    identity:
      - type: SystemAssigned
    virtualNetworkType: Internal
    virtualNetworkConfiguration:
      - subnetIdRef:
          name: apim-subnet
    protocols:
      - enableHttp2: true
    security:
      - enableBackendSsl30: false
        enableBackendTls10: false
        enableBackendTls11: false
        enableFrontendSsl30: false
        enableFrontendTls10: false
        enableFrontendTls11: false
```

### Layer 7: Data Security

Protect data at rest and in transit.

#### 7.1 Storage Account Encryption

```yaml
apiVersion: storage.azure.upbound.io/v1beta1
kind: Account
metadata:
  name: secure-storage
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    accountTier: Standard
    accountReplicationType: GRS
    enableHttpsTrafficOnly: true
    minTlsVersion: TLS1_2
    allowBlobPublicAccess: false
    infrastructureEncryptionEnabled: true
    networkRules:
      - defaultAction: Deny
        bypass:
          - AzureServices
        ipRules:
          - value: ${ALLOWED_IP}/32
            action: Allow
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

#### 7.2 SQL Database Encryption

```yaml
apiVersion: sql.azure.upbound.io/v1beta1
kind: MSSQLDatabase
metadata:
  name: secure-db
spec:
  forProvider:
    serverIdRef:
      name: secure-sql-server
    collation: SQL_Latin1_General_CP1_CI_AS
    licenseType: LicenseIncluded
    maxSizeGb: 100
    skuName: S1
    zoneRedundant: true
    encryptionEnabled: true
    threatDetectionPolicy:
      - state: Enabled
        emailAddresses:
          - security@example.com
        retentionDays: 90
```

#### 7.3 Transparent Data Encryption (TDE)

```yaml
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

#### 7.4 Backup and Disaster Recovery

```yaml
apiVersion: recoveryservices.azure.upbound.io/v1beta1
kind: Vault
metadata:
  name: backup-vault
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    sku: Standard
    softDeleteEnabled: true
    immutability: Locked
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
      name: secure-rg
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

## Security Monitoring & Compliance

### Azure Monitor & Log Analytics

```yaml
apiVersion: operationalinsights.azure.upbound.io/v1beta1
kind: Workspace
metadata:
  name: security-logs
spec:
  forProvider:
    resourceGroupNameRef:
      name: secure-rg
    location: westeurope
    sku: PerGB2018
    retentionInDays: 90
    dailyQuotaGb: 10
```

### Azure Sentinel (SIEM)

```yaml
apiVersion: securityinsights.azure.upbound.io/v1beta1
kind: SentinelOnboardingState
metadata:
  name: enable-sentinel
spec:
  forProvider:
    workspaceIdRef:
      name: security-logs
    resourceGroupNameRef:
      name: secure-rg
```

### Azure Policy for Compliance

```yaml
apiVersion: authorization.azure.upbound.io/v1beta1
kind: SubscriptionPolicyAssignment
metadata:
  name: enforce-https
spec:
  forProvider:
    policyDefinitionId: /providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9
    displayName: "Storage accounts should use HTTPS only"
    description: "Enforce HTTPS for storage accounts"
    enforcementMode: Default
```

## Testing Defense in Depth

### Security Validation Checklist

1. **Identity & Access**
- [ ] All resources use managed identities
- [ ] RBAC roles follow least privilege
- [ ] Key Vault access policies are restrictive
- [ ] No passwords in code or configuration
1. **Network Security**
- [ ] NSG rules deny by default
- [ ] Private endpoints configured for PaaS services
- [ ] DDoS protection enabled
- [ ] WAF rules active and monitoring
1. **Encryption**
- [ ] TLS 1.2+ enforced everywhere
- [ ] Storage encryption with customer-managed keys
- [ ] Database TDE enabled
- [ ] Disk encryption configured
1. **Monitoring**
- [ ] Log Analytics collecting security events
- [ ] Azure Sentinel alerts configured
- [ ] Security Center recommendations reviewed
- [ ] Audit logs retained for compliance period

### Automated Security Testing

```bash
# Test NSG rules
az network nsg rule list \
  --resource-group secure-rg \
  --nsg-name web-tier-nsg \
  --output table

# Verify encryption status
az storage account show \
  --name securestorage \
  --resource-group secure-rg \
  --query "[encryption, minimumTlsVersion]"

# Check Key Vault access
az keyvault show \
  --name secure-vault \
  --query "[properties.enablePurgeProtection, properties.softDeleteRetentionInDays]"

# Test HTTPS enforcement
curl -I http://app.example.com
# Should return 301/302 redirect to HTTPS

curl -I https://app.example.com
# Should return 200 with security headers
```

## Deployment Workflow

### 1. Create Base Infrastructure

```bash
kubectl apply -f compositions/base-infrastructure.yaml
```

### 2. Apply Security Controls Layer by Layer

```bash
# Layer 2: Identity
kubectl apply -f security/identity/

# Layer 3: Perimeter
kubectl apply -f security/perimeter/

# Layer 4: Network
kubectl apply -f security/network/

# Layer 5: Compute
kubectl apply -f security/compute/

# Layer 6: Application
kubectl apply -f security/application/

# Layer 7: Data
kubectl apply -f security/data/
```

### 3. Enable Monitoring

```bash
kubectl apply -f monitoring/
```

### 4. Verify Security Posture

```bash
# Run security validation
./scripts/validate-security.sh

# Check compliance status
az policy state list \
  --resource-group secure-rg \
  --filter "ComplianceState eq 'NonCompliant'"
```

## Best Practices

### General Security

1. **Least Privilege**: Grant minimum permissions required
1. **Defense in Depth**: Multiple security layers
1. **Encryption Everywhere**: At rest and in transit
1. **Zero Trust**: Verify explicitly, use least privilege access, assume breach
1. **Regular Updates**: Keep systems patched and current

### Crossplane-Specific

1. **Use Compositions**: Encapsulate security patterns
1. **External Names**: Use meaningful names for Azure resources
1. **DeletionPolicy**: Set to `Orphan` for critical resources
1. **Provider Config**: Use workload identity, not service principals
1. **Health Checks**: Implement readiness and liveness probes

### Azure-Specific

1. **Resource Locks**: Prevent accidental deletion
1. **Tags**: Enforce tagging for cost allocation and compliance
1. **Private Endpoints**: Avoid public exposure of PaaS services
1. **Managed Identities**: Eliminate credential management
1. **Azure Policy**: Enforce organizational standards

## Troubleshooting

### Common Issues

#### Certificate Issues

```bash
# Check certificate in Key Vault
az keyvault certificate show \
  --vault-name secure-vault \
  --name app-tls-cert

# Verify Application Gateway SSL binding
az network application-gateway ssl-cert show \
  --gateway-name secure-appgw \
  --resource-group secure-rg \
  --name app-ssl-cert
```

#### Network Connectivity

```bash
# Test NSG rules
az network watcher test-ip-flow \
  --vm vm-name \
  --direction Inbound \
  --protocol TCP \
  --local 10.0.1.4:443 \
  --remote 0.0.0.0:*

# Check effective routes
az network nic show-effective-route-table \
  --name vm-nic \
  --resource-group secure-rg
```

#### Encryption Problems

```bash
# Verify disk encryption
az vm encryption show \
  --name secure-vm \
  --resource-group secure-rg

# Check storage encryption
az storage account encryption-scope list \
  --account-name securestorage \
  --resource-group secure-rg
```

## Additional Resources

- [CNCF HTTPS Documentation](https://github.com/vanHeemstraSystems/cncf-demo/blob/main/manuscript/https/README.md)
- [Azure Security Baseline](https://docs.microsoft.com/en-us/security/benchmark/azure/)
- [Crossplane Security Best Practices](https://docs.crossplane.io/latest/security/)
- [Defense in Depth Article](https://github.com/vanHeemstraPublications/dev-to/blob/main/articles/defense-in-depth-of-cyber-carrots.md)
- [Implementation Repository](https://github.com/software-journey/crossplane-defense-in-depth)

## Next Steps

1. Review each security layer and adapt to your requirements
1. Implement automated security testing in CI/CD
1. Set up security monitoring dashboards
1. Establish incident response procedures
1. Schedule regular security reviews
1. Update the [crossplane-defense-in-depth](https://github.com/software-journey/crossplane-defense-in-depth) repository with working examples

-----

**Last Updated:** February 2026  
**Maintained By:** Willem van Heemstra  
**License:** MIT
