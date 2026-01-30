#!/bin/bash
set -e

echo "=== Running Crossplane E2E Tests ==="

# Ensure we're in the right context
kubectl config current-context

# Run kuttl tests
kubectl kuttl test \
  --config tests/e2e/kuttl-test.yaml \
  --timeout 2400 \
  --start-kind=false

echo "=== E2E Tests Complete ==="
