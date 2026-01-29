#!/bin/bash

echo "=== Crossplane E2E Setup Verification ==="

# Check AKS
echo "Checking AKS cluster..."
kubectl cluster-info
kubectl get nodes

# Check Crossplane
echo "Checking Crossplane..."
kubectl get pods -n crossplane-system
# NOTE: `kubectl get providers` can resolve to Flux "providers" (namespaced) if Flux is installed.
# Use fully-qualified resource names for Crossplane.
kubectl get providers.pkg.crossplane.io
kubectl get functions.pkg.crossplane.io

# Check ProviderConfig
echo "Checking ProviderConfig..."
# NOTE: `kubectl get providerconfig` may resolve to a namespaced resource depending on installed CRDs.
# Use the fully-qualified resource name for the Upbound Azure ProviderConfig.
kubectl get providerconfigs.azure.upbound.io

# Check XRDs and Compositions
echo "Checking XRDs..."
kubectl get xrd

echo "Checking Compositions..."
kubectl get composition

# Check Flux
echo "Checking Flux..."
flux check
kubectl get gitrepository -n flux-system
kubectl get kustomization -n flux-system

# Check E2E test structure
echo "Checking test structure..."
ls -la tests/e2e/

echo "=== Verification Complete ==="
