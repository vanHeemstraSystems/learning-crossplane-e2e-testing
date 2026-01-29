# Crossplane XRD-Composition Validation Toolkit

A comprehensive toolkit for validating and visualizing the relationship between Crossplane XRDs (CompositeResourceDefinitions) and Compositions using Crossview.

This toolkit demonstrates validation using an **Azure Storage Account** example with **Crossplane v2**.

## ⚡ Crossplane v2 Ready

This toolkit uses **Crossplane v2** specifications:
- ✅ `apiextensions.crossplane.io/v2` API
- ✅ No Claims (removed in v2)
- ✅ Direct XR (Composite Resource) creation
- ✅ Cluster-scoped resources

See [CROSSPLANE-V2-GUIDE.md](CROSSPLANE-V2-GUIDE.md) for migration details.

## Overview

This toolkit provides:

1. **Automated Crossview Installation** - One-command setup for Crossview in your minikube cluster
2. **CLI Validation Scripts** - Command-line tools to verify XRD-Composition matching
3. **Sample Resources** - Example Azure Storage Account XRD and Composition for testing
4. **Comprehensive Documentation** - Step-by-step guides and troubleshooting

## Quick Start

```bash
# 1. Install Crossview
./install-crossview.sh

# 2. Deploy sample Azure Storage Account XRD and Composition
kubectl apply -f sample-xrd.yaml
kubectl apply -f sample-composition.yaml

# 3. Validate the match
./validate-xrd-composition.sh xstorageaccounts.azure.example.com storageaccount-azure-standard

# 4. Open Crossview for graphical validation
minikube service crossview -n crossview
```

## What's Included

### Scripts

- **install-crossview.sh** - Automated Crossview installation for minikube
- **validate-xrd-composition.sh** - CLI tool for validating XRD-Composition relationships

### Sample Resources

- **sample-xrd.yaml** - Example CompositeResourceDefinition for Azure Storage Account
- **sample-composition.yaml** - Example Composition that references the XRD and creates Azure resources

### Documentation

- **QUICK-START.md** - Step-by-step guide to get started quickly
- **crossview-setup-guide.md** - Detailed Crossview installation and usage guide

## Features

### Crossview Installation
- ✅ Automated deployment to minikube
- ✅ Proper RBAC configuration for read-only access
- ✅ NodePort service for easy access
- ✅ Health checks and readiness probes
- ✅ Multiple access methods (service, port-forward, NodePort)

### Validation Tools
- ✅ Verify XRD existence and establishment status
- ✅ Check Composition-XRD reference matching
- ✅ Validate API version compatibility
- ✅ Verify kind matching (case-sensitive)
- ✅ Auto-discovery of matching Compositions
- ✅ Color-coded output for easy reading

### Visual Validation with Crossview
- ✅ Graphical representation of XRD-Composition relationships
- ✅ Resource hierarchy visualization
- ✅ Connection status indicators
- ✅ Interactive exploration of Crossplane resources

## Use Cases

### 1. Development
Verify your XRD and Composition are correctly matched before deploying to production:

```bash
# Deploy to dev cluster
kubectl apply -f my-xrd.yaml
kubectl apply -f my-composition.yaml

# Validate
./validate-xrd-composition.sh my-xrd my-composition

# Visual verification
# Open Crossview and inspect the relationship
```

### 2. Debugging
Troubleshoot why a Composition isn't being used:

```bash
# Find all compositions for an XRD
./validate-xrd-composition.sh my-xrd

# Check for API version or kind mismatches
# Crossview will show broken connections visually
```

### 3. Documentation
Generate visual diagrams of your Crossplane platform:

```bash
# Access Crossview
minikube service crossview -n crossview

# Use screenshots for documentation
# Export diagrams (if supported by Crossview version)
```

### 4. Learning
Understand Crossplane resource relationships:

```bash
# Deploy sample resources
kubectl apply -f sample-xrd.yaml
kubectl apply -f sample-composition.yaml

# Explore in Crossview
# Create claims and watch managed resources appear
```

## Prerequisites

- Minikube (or any Kubernetes cluster)
- **Crossplane v2** installed (required)
- kubectl configured
- bash shell
- jq (for validation script)
- Azure Provider for Crossplane (optional - for creating actual resources)

**Important:** This toolkit requires Crossplane v2. For migration from v1, see [CROSSPLANE-V2-GUIDE.md](CROSSPLANE-V2-GUIDE.md).

## Installation

### Install Crossview Only

```bash
./install-crossview.sh
```

### Deploy Sample Resources

```bash
kubectl apply -f sample-xrd.yaml
kubectl apply -f sample-composition.yaml
```

### Full Setup

```bash
# Install Crossview
./install-crossview.sh

# Deploy samples
kubectl apply -f sample-xrd.yaml
kubectl apply -f sample-composition.yaml

# Validate
./validate-xrd-composition.sh xstorageaccounts.azure.example.com storageaccount-azure-standard

# Access Crossview
minikube service crossview -n crossview
```

## Access Methods

### Method 1: Minikube Service (Recommended)
```bash
minikube service crossview -n crossview
```

### Method 2: Port Forward
```bash
kubectl port-forward -n crossview svc/crossview 8080:3000
# Open http://localhost:8080
```

### Method 3: NodePort
```bash
# Get minikube IP
minikube ip
# Access http://<minikube-ip>:30080
```

## Validation Examples

### Validate Specific Pair
```bash
./validate-xrd-composition.sh xstorageaccounts.azure.example.com storageaccount-azure-standard
```

### Find All Matching Compositions
```bash
./validate-xrd-composition.sh xstorageaccounts.azure.example.com
```

### Expected Output (Success)
```
=== Crossplane XRD-Composition Validation ===

Checking XRD: xstorageaccounts.azure.example.com
✓ XRD found

XRD Details:
  Name:        xstorageaccounts.azure.example.com
  API Version: azure.example.com/v1alpha1
  Kind:        XStorageAccount
  Status:      Established

Checking Composition: storageaccount-azure-standard
✓ Composition found

Composition Details:
  Name:        storageaccount-azure-standard
  API Version: azure.example.com/v1alpha1
  Kind:        XStorageAccount

Validation Results:
  ✓ API Version matches
  ✓ Kind matches

=== VALIDATION PASSED ===
```

## Troubleshooting

### Crossview Pod Not Starting

```bash
# Check pod status
kubectl get pods -n crossview

# View logs
kubectl logs -n crossview deployment/crossview

# Verify image pull
kubectl describe pod -n crossview -l app=crossview
```

### Validation Script Errors

```bash
# Ensure jq is installed
which jq || echo "jq not found - install with: brew install jq (macOS) or apt-get install jq (Ubuntu)"

# Check kubectl connectivity
kubectl cluster-info

# Verify Crossplane is installed
kubectl get namespace crossplane-system
```

### XRD-Composition Mismatch

Common causes and solutions:

| Issue | Cause | Solution |
|-------|-------|----------|
| API version mismatch | `compositeTypeRef.apiVersion` doesn't match XRD | Update Composition to use correct group/version |
| Kind mismatch | `compositeTypeRef.kind` doesn't match XRD | Verify exact kind name (case-sensitive) |
| XRD not established | Schema validation errors | Check `kubectl describe xrd <name>` for errors |
| No managed resources created | Missing provider or incorrect patches | Verify provider installation and patch syntax |

## Cleanup

### Remove Sample Resources
```bash
kubectl delete -f sample-composition.yaml
kubectl delete -f sample-xrd.yaml
```

### Uninstall Crossview
```bash
kubectl delete namespace crossview
kubectl delete clusterrole crossview-reader
kubectl delete clusterrolebinding crossview-reader-binding
```

## Advanced Usage

### Custom XRD-Composition Patterns

Create multiple Compositions for one XRD:

```yaml
# standard-composition.yaml
spec:
  compositeTypeRef:
    apiVersion: azure.example.com/v1alpha1
    kind: XStorageAccount
  metadata:
    labels:
      tier: standard
---
# premium-composition.yaml
spec:
  compositeTypeRef:
    apiVersion: azure.example.com/v1alpha1
    kind: XStorageAccount
  metadata:
    labels:
      tier: premium
```

Use composition selectors:

```yaml
# In your claim
spec:
  compositionSelector:
    matchLabels:
      tier: standard  # or premium
```

### Integration with CI/CD

```bash
# In your pipeline
kubectl apply -f xrd.yaml
kubectl apply -f composition.yaml

# Validate before promoting
./validate-xrd-composition.sh my-xrd my-composition || exit 1

# Continue with claim creation...
```

## Contributing

This toolkit is designed to be extended. You can:

- Add more sample XRDs and Compositions
- Enhance validation scripts with additional checks
- Create alternative visualization tools
- Add support for other Crossplane features

## Resources

- [Crossplane Documentation](https://docs.crossplane.io/)
- [XRD API Reference](https://doc.crds.dev/github.com/crossplane/crossplane)
- [Crossview GitHub](https://github.com/smoeidheidari/crossview)
- [Crossplane Slack](https://slack.crossplane.io/)

## License

This toolkit is provided as-is for educational and development purposes.

## Support

For issues related to:
- **This toolkit**: Create scripts or documentation improvements as needed
- **Crossview**: See [Crossview GitHub issues](https://github.com/smoeidheidari/crossview/issues)
- **Crossplane**: See [Crossplane documentation](https://docs.crossplane.io/) and [Slack community](https://slack.crossplane.io/)
