# Security Layer 5: Compute Security

## Overview

Compute security focuses on hardening virtual machines, containers, and compute resources against attacks and vulnerabilities.

## Objectives

- Harden VMs and containers
- Implement disk encryption
- Enable security monitoring
- Automate patch management
- Use secure baseline images

## Implementation

### 1. Secure VM Configuration

```yaml
apiVersion: compute.azure.upbound.io/v1beta1
kind: LinuxVirtualMachine
metadata:
  name: secure-vm
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    size: Standard_D2s_v3
    adminUsername: azureuser
    disablePasswordAuthentication: true  # SSH keys only
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
          - name: vm-identity
    zones:
      - "1"
      - "2"
```

### 2. Azure Disk Encryption

```yaml
apiVersion: compute.azure.upbound.io/v1beta1
kind: DiskEncryptionSet
metadata:
  name: disk-encryption-set
spec:
  forProvider:
    resourceGroupNameRef:
      name: production-rg
    location: westeurope
    identity:
      - type: SystemAssigned
    keyVaultKeyIdRef:
      name: disk-encryption-key
    encryptionType: EncryptionAtRestWithPlatformAndCustomerKeys
```

### 3. Update Management

```yaml
apiVersion: automation.azure.upbound.io/v1beta1
kind: SoftwareUpdateConfiguration
metadata:
  name: critical-updates
spec:
  forProvider:
    automationAccountNameRef:
      name: update-automation
    resourceGroupNameRef:
      name: production-rg
    schedule:
      - frequency: Weekly
        interval: 1
        startTime: "2026-01-05T02:00:00Z"
        timeZone: Europe/Amsterdam
        advancedSchedule:
          - weekDays:
              - Sunday
    operatingSystem: Linux
    linux:
      - includedPackageClassifications:
          - Critical
          - Security
        rebootSetting: IfRequired
```

### 4. Security Center Integration

```yaml
apiVersion: security.azure.upbound.io/v1beta1
kind: SecurityCenterSubscriptionPricing
metadata:
  name: defender-for-servers
spec:
  forProvider:
    tier: Standard
    resourceType: VirtualMachines
---
apiVersion: security.azure.upbound.io/v1beta1
kind: SecurityCenterAutoProvisioning
metadata:
  name: auto-provision-agents
spec:
  forProvider:
    autoProvision: "On"
```

## Best Practices

**VM Hardening:**

- Disable password authentication
- Use latest OS versions
- Minimal installed software
- Regular security updates

**Encryption:**

- Enable disk encryption for all VMs
- Use customer-managed keys
- Encrypt temporary disks

**Monitoring:**

- Enable Microsoft Defender for Servers
- Configure vulnerability assessments
- Implement file integrity monitoring

## Summary

✅ Disable password authentication  
✅ Encrypt all disks  
✅ Automate patch management  
✅ Enable Defender for Servers

**Next Layer:** [Application Security](./security-layer-6.md)
