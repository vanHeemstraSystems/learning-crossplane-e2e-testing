#!/bin/bash
set -e

echo "=== Running Crossplane E2E Tests ==="

# Ensure we're in the right context
kubectl config current-context

# Run kuttl tests
kubectl kuttl test \
  tests/e2e \
  --timeout 900 \
  --start-kind=false

echo "=== E2E Tests Complete ==="
