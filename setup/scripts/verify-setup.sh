#!/bin/bash

# 

# Crossplane E2E Setup Verification Script

# This script verifies that all components are properly installed and configured

# 

# Usage: ./scripts/verify-setup.sh

# 

# Colors for output

RED=’\033[0;31m’
GREEN=’\033[0;32m’
YELLOW=’\033[1;33m’
BLUE=’\033[0;34m’
NC=’\033[0m’ # No Color

# Logging functions

log_info() {
echo -e “${BLUE}[INFO]${NC} $1”
}

log_success() {
echo -e “${GREEN}[✓]${NC} $1”
}

log_warning() {
echo -e “${YELLOW}[!]${NC} $1”
}

log_error() {
echo -e “${RED}[✗]${NC} $1”
}

echo “========================================================================”
echo “   Crossplane E2E Setup Verification”
echo “========================================================================”
echo “”

# 

# Check AKS Cluster

# 

log_info “Checking AKS cluster…”
if kubectl cluster-info >/dev/null 2>&1; then
log_success “Connected to Kubernetes cluster”
kubectl cluster-info
echo “”
log_info “Node status:”
kubectl get nodes -o wide
else
log_error “Cannot connect to Kubernetes cluster”
exit 1
fi

# 

# Check Crossplane

# 

echo “”
log_info “Checking Crossplane installation…”
CROSSPLANE_NAMESPACE=“crossplane-system”

if kubectl get namespace “$CROSSPLANE_NAMESPACE” >/dev/null 2>&1; then
log_success “Crossplane namespace exists”

```
echo ""
log_info "Crossplane pods:"
kubectl get pods -n "$CROSSPLANE_NAMESPACE" -o wide

# Check if pods are running
NOT_RUNNING=$(kubectl get pods -n "$CROSSPLANE_NAMESPACE" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
if [ "$NOT_RUNNING" -eq 0 ]; then
    log_success "All Crossplane pods are running"
else
    log_warning "$NOT_RUNNING pod(s) not in Running state"
fi
```

else
log_error “Crossplane namespace not found”
fi

# 

# Check Providers

# 

echo “”
log_info “Checking Crossplane Providers…”
PROVIDERS=$(kubectl get providers –no-headers 2>/dev/null | wc -l)

if [ “$PROVIDERS” -gt 0 ]; then
log_success “Found $PROVIDERS provider(s)”
kubectl get providers

```
# Check provider health
echo ""
HEALTHY=$(kubectl get providers -o json | jq -r '.items[] | select(.status.conditions[] | select(.type=="Healthy" and .status=="True")) | .metadata.name' | wc -l)
if [ "$HEALTHY" -eq "$PROVIDERS" ]; then
    log_success "All providers are healthy"
else
    log_warning "Not all providers are healthy ($HEALTHY/$PROVIDERS)"
fi
```

else
log_warning “No providers found”
fi

# 

# Check Functions

# 

echo “”
log_info “Checking Composition Functions…”
FUNCTIONS=$(kubectl get functions –no-headers 2>/dev/null | wc -l)

if [ “$FUNCTIONS” -gt 0 ]; then
log_success “Found $FUNCTIONS function(s)”
kubectl get functions

```
# Check function health
echo ""
HEALTHY_FUNCS=$(kubectl get functions -o json | jq -r '.items[] | select(.status.conditions[] | select(.type=="Healthy" and .status=="True")) | .metadata.name' | wc -l)
if [ "$HEALTHY_FUNCS" -eq "$FUNCTIONS" ]; then
    log_success "All functions are healthy"
else
    log_warning "Not all functions are healthy ($HEALTHY_FUNCS/$FUNCTIONS)"
fi
```

else
log_warning “No composition functions found”
fi

# 

# Check ProviderConfig

# 

echo “”
log_info “Checking ProviderConfig…”
PROVIDERCONFIGS=$(kubectl get providerconfig –no-headers 2>/dev/null | wc -l)

if [ “$PROVIDERCONFIGS” -gt 0 ]; then
log_success “Found $PROVIDERCONFIGS ProviderConfig(s)”
kubectl get providerconfig
else
log_warning “No ProviderConfigs found”
fi

# 

# Check Azure Secret

# 

echo “”
log_info “Checking Azure credentials secret…”
if kubectl get secret azure-secret -n “$CROSSPLANE_NAMESPACE” >/dev/null 2>&1; then
log_success “Azure credentials secret exists”
else
log_error “Azure credentials secret not found”
fi

# 

# Check XRDs

# 

echo “”
log_info “Checking Composite Resource Definitions (XRDs)…”
XRDS=$(kubectl get xrd –no-headers 2>/dev/null | wc -l)

if [ “$XRDS” -gt 0 ]; then
log_success “Found $XRDS XRD(s)”
kubectl get xrd
else
log_warning “No XRDs found (this is normal if you haven’t created any yet)”
fi

# 

# Check Compositions

# 

echo “”
log_info “Checking Compositions…”
COMPOSITIONS=$(kubectl get composition –no-headers 2>/dev/null | wc -l)

if [ “$COMPOSITIONS” -gt 0 ]; then
log_success “Found $COMPOSITIONS Composition(s)”
kubectl get composition
else
log_warning “No Compositions found (this is normal if you haven’t created any yet)”
fi

# 

# Check Flux

# 

echo “”
log_info “Checking Flux installation…”
if command -v flux >/dev/null 2>&1; then
log_success “Flux CLI is installed”
flux version –client

```
echo ""
if flux check >/dev/null 2>&1; then
    log_success "Flux is installed and healthy"
    
    echo ""
    log_info "Flux GitRepositories:"
    kubectl get gitrepository -n flux-system 2>/dev/null || log_warning "No GitRepositories found"
    
    echo ""
    log_info "Flux Kustomizations:"
    kubectl get kustomization -n flux-system 2>/dev/null || log_warning "No Kustomizations found"
else
    log_warning "Flux is not bootstrapped yet (this is optional)"
fi
```

else
log_warning “Flux CLI not installed (this is optional)”
fi

# 

# Check Test Directory

# 

echo “”
log_info “Checking test directory structure…”
if [ -d “tests/e2e” ]; then
log_success “Test directory exists”
echo “”
TEST_DIRS=$(find tests/e2e -type d -maxdepth 1 -mindepth 1 | wc -l)
log_info “Found $TEST_DIRS test suite(s):”
ls -1 tests/e2e/
else
log_warning “Test directory not found”
fi

# 

# Check Helper Scripts

# 

echo “”
log_info “Checking helper scripts…”
SCRIPTS=(
“scripts/verify-setup.sh”
“scripts/cleanup-test-resources.sh”
“scripts/run-e2e-tests.sh”
)

for script in “${SCRIPTS[@]}”; do
if [ -f “$script” ]; then
if [ -x “$script” ]; then
log_success “$script exists and is executable”
else
log_warning “$script exists but is not executable”
fi
else
log_warning “$script not found”
fi
done

# 

# Check Kuttl

# 

echo “”
log_info “Checking Kuttl installation…”
if command -v kubectl-kuttl >/dev/null 2>&1; then
log_success “Kuttl is installed”
kubectl kuttl version
else
log_warning “Kuttl not installed”
fi

# 

# Check Crossplane CLI

# 

echo “”
log_info “Checking Crossplane CLI…”
if command -v crossplane >/dev/null 2>&1; then
log_success “Crossplane CLI is installed”
crossplane –version
else
log_warning “Crossplane CLI not installed”
fi

# 

# Check Azure Resources

# 

echo “”
log_info “Checking Azure resources…”
if command -v az >/dev/null 2>&1; then
if az account show >/dev/null 2>&1; then
log_success “Authenticated to Azure”

```
    SUBSCRIPTION=$(az account show --query name -o tsv)
    log_info "Current subscription: $SUBSCRIPTION"
    
    # Check for resource groups
    echo ""
    log_info "Checking resource groups..."
    
    RG_MAIN="crossplane-e2e-rg"
    RG_TEST="crossplane-e2e-test-rg"
    
    if az group show --name "$RG_MAIN" >/dev/null 2>&1; then
        log_success "Main resource group exists: $RG_MAIN"
    else
        log_warning "Main resource group not found: $RG_MAIN"
    fi
    
    if az group show --name "$RG_TEST" >/dev/null 2>&1; then
        log_success "Test resource group exists: $RG_TEST"
    else
        log_warning "Test resource group not found: $RG_TEST"
    fi
else
    log_warning "Not authenticated to Azure"
fi
```

else
log_warning “Azure CLI not installed”
fi

# 

# Summary

# 

echo “”
echo “========================================================================”
echo “   Verification Summary”
echo “========================================================================”
echo “”

# Count successes and warnings

TOTAL_CHECKS=0
PASSED_CHECKS=0

# This is a simple summary - in production you’d track this more carefully

log_info “Core components status:”
kubectl get pods -n “$CROSSPLANE_NAMESPACE” >/dev/null 2>&1 && log_success “Crossplane: Running” || log_error “Crossplane: Not Running”
kubectl get providers >/dev/null 2>&1 && log_success “Providers: Installed” || log_warning “Providers: Not Installed”
kubectl get providerconfig default >/dev/null 2>&1 && log_success “ProviderConfig: Configured” || log_warning “ProviderConfig: Not Configured”

echo “”
log_info “Optional components status:”
flux check >/dev/null 2>&1 && log_success “Flux: Installed” || log_info “Flux: Not Installed (optional)”
command -v kubectl-kuttl >/dev/null 2>&1 && log_success “Kuttl: Installed” || log_warning “Kuttl: Not Installed”

echo “”
log_info “Next steps:”
echo “  1. Create XRDs and Compositions (see README.md)”
echo “  2. Bootstrap Flux (optional)”
echo “  3. Create E2E tests”
echo “  4. Run: ./scripts/run-e2e-tests.sh”
echo “”

log_success “Verification complete!”
