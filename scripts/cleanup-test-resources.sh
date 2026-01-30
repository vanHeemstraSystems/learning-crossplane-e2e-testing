#!/bin/bash
set -e

echo "=== Cleaning up E2E test resources ==="

# Delete all test XRs
echo "Deleting test XRs..."
kubectl delete xpostgresqldatabase -A --all --ignore-not-found=true

# Optional: legacy storage-account example
kubectl delete xstorageaccount --all --ignore-not-found=true || true

# Wait for Crossplane to clean up managed resources
echo "Waiting for managed resources to be deleted..."
sleep 30

# Clean up any orphaned Azure resources
echo "Checking for orphaned Azure resources..."
ORPHANED=$(az resource list \
  --tag purpose=e2e-testing \
  --query "[].id" -o tsv)

if [ -n "$ORPHANED" ]; then
  echo "Found orphaned resources, deleting..."
  echo "$ORPHANED" | xargs -I {} az resource delete --ids {} --verbose
else
  echo "No orphaned resources found"
fi

echo "=== Cleanup complete ==="
