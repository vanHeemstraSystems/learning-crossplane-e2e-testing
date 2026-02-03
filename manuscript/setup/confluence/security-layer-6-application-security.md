# Security Layer 6: Application Security

## Overview

Application security protects web applications, APIs, and application-level communications using HTTPS/TLS, secrets management, and WAF.

## Objectives

- Enforce HTTPS/TLS 1.2+ everywhere
- Implement certificate management
- Secure application secrets
- Protect APIs with authentication
- Add security headers

## Implementation

### 1. Certificate Management

Based on [CNCF HTTPS Best Practices](https://github.com/vanHeemstraSystems/cncf-demo/blob/main/manuscript/https/README.md):

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Certificate
metadata:
  name: app-tls-cert
spec:
  forProvider:
    keyVaultIdRef:
      name: secure-vault
    certificatePolicy:
      - issuerParameters:
          - name: Self  # Or DigiCert, Let's Encrypt
        keyProperties:
          - exportable: true
            keySize: 2048
            keyType: RSA
        lifetimeAction:
          - action:
              - actionType: AutoRenew
            trigger:
              - daysBeforeExpiry: 30
        x509CertificateProperties:
          - subject: CN=app.example.com
            validityInMonths: 12
            subjectAlternativeNames:
              - dnsNames:
                  - app.example.com
                  - www.app.example.com
```

### 2. Application Gateway with TLS

```yaml
apiVersion: network.azure.upbound.io/v1beta1
kind: ApplicationGateway
metadata:
  name: secure-appgw
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    sku:
      - name: WAF_v2
        tier: WAF_v2
    sslPolicy:
      - policyType: Predefined
        policyName: AppGwSslPolicy20220101  # TLS 1.2+
    sslCertificate:
      - name: app-ssl-cert
        keyVaultSecretIdRef:
          name: app-tls-cert
    httpListener:
      - name: https-listener
        protocol: Https
        sslCertificateName: app-ssl-cert
        requireServerNameIndication: true
```

### 3. Security Headers

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
      name: production-rg
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

### 4. API Management Security

```yaml
apiVersion: apimanagement.azure.upbound.io/v1beta1
kind: Service
metadata:
  name: secure-apim
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    publisherName: "Security Team"
    publisherEmail: security@example.com
    skuName: Developer_1
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

### 5. Secrets in Key Vault

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: api-key
spec:
  forProvider:
    keyVaultIdRef:
      name: secure-vault
    value: ${API_KEY_VALUE}
    contentType: api-credential
    expirationDate: "2026-12-31T23:59:59Z"
```

## TLS Best Practices

**Minimum Configuration:**

- TLS 1.2 or higher
- Strong cipher suites only
- Perfect Forward Secrecy (PFS)
- Certificate from trusted CA
- Auto-renewal enabled

**Security Headers:**

- Strict-Transport-Security (HSTS)
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- Content-Security-Policy

## Testing

```bash
# Test TLS version
openssl s_client -connect app.example.com:443 -tls1_2

# Test security headers
curl -I https://app.example.com | grep -i "strict-transport-security"

# Test certificate
echo | openssl s_client -connect app.example.com:443 2>/dev/null | openssl x509 -noout -dates
```

## Summary

✅ Enforce TLS 1.2+ minimum  
✅ Implement HSTS  
✅ Store secrets in Key Vault  
✅ Add comprehensive security headers  
✅ Automate certificate renewal

**Next Layer:** [Data Security](./security-layer-7.md)
