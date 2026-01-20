#!/bin/bash

# 

# Cleanup E2E Test Resources Script

# This script cleans up Crossplane test resources and orphaned Azure resources

# 

# Usage: ./scripts/cleanup-test-resources.sh [–force]

# 

set -e

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
echo -e “${GREEN}[SUCCESS]${NC} $1”
}

log_warning() {
echo -e “${YELLOW}[WARNING]${NC} $1”
}

log_error() {
echo -e “${RED}[ERROR]${NC} $1”
}

# Configuration

CROSSPLANE_NAMESPACE=“crossplane-system”
TEST_RESOURCE_GROUP=“crossplane-e2e-test-rg”

# Check for force flag

FORCE=false
if [ “$1” == “–force” ]; then
FORCE=true
log_warning “Running in FORCE mode - skipping confirmations”
fi

echo “========================================================================”
echo “   Crossplane E2E Test Resources Cleanup”
echo “========================================================================”
echo “”

# Confirmation prompt unless force flag is set

if [ “$FORCE” = false ]; then
log_warning “This will delete all E2E test resources!”
echo “”
echo “Resources to be deleted:”
echo “  - All XRs with label test=e2e”
echo “  - Azure resources tagged with purpose=e2e-testing”
echo “”
read -p “Continue with cleanup? (yes/no): “ confirm
if [[ $confirm != “yes” ]]; then
log_info “Cleanup cancelled by user”
exit 0
fi
fi

# 

# Step 1: Delete XStorageAccount resources

# 

echo “”
log_info “Step 1/7: Deleting XStorageAccount test resources…”
XSTORAGE_COUNT=$(kubectl get xstorageaccount -l test=e2e –no-headers 2>/dev/null | wc -l)

if [ “$XSTORAGE_COUNT” -gt 0 ]; then
log_info “Found $XSTORAGE_COUNT XStorageAccount(s) to delete”
kubectl delete xstorageaccount -l test=e2e –timeout=300s
log_success “XStorageAccount resources deleted”
else
log_info “No XStorageAccount resources with label test=e2e found”
fi

# 

# Step 2: Delete all XRs with test label

# 

echo “”
log_info “Step 2/7: Deleting all other XR test resources…”
XR_TYPES=$(kubectl api-resources –api-group=’*.example.io’ -o name 2>/dev/null)

if [ -n “$XR_TYPES” ]; then
for xr_type in $XR_TYPES; do
XR_COUNT=$(kubectl get “$xr_type” -l test=e2e –no-headers 2>/dev/null | wc -l)
if [ “$XR_COUNT” -gt 0 ]; then
log_info “Deleting $XR_COUNT $xr_type resource(s)…”
kubectl delete “$xr_type” -l test=e2e –timeout=300s 2>/dev/null || true
fi
done
log_success “All labeled XR resources deleted”
else
log_info “No custom XR types found”
fi

# 

# Step 3: Wait for managed resources to be deleted

# 

echo “”
log_info “Step 3/7: Waiting for Crossplane to clean up managed resources…”
log_info “This may take 2-3 minutes…”

# Wait for a reasonable time

sleep 60

# Check if any managed resources remain

MANAGED_COUNT=$(kubectl get managed –no-headers 2>/dev/null | grep -c “test-” || true)
if [ “$MANAGED_COUNT” -gt 0 ]; then
log_warning “$MANAGED_COUNT managed resource(s) still exist”
log_info “Waiting additional 60 seconds…”
sleep 60
else
log_success “All managed resources cleaned up”
fi

# 

# Step 4: Check for orphaned Azure resources

# 

echo “”
log_info “Step 4/7: Checking for orphaned Azure resources…”

if ! command -v az >/dev/null 2>&1; then
log_warning “Azure CLI not installed, skipping Azure cleanup”
else
if ! az account show >/dev/null 2>&1; then
log_warning “Not authenticated to Azure, skipping Azure cleanup”
else
# Find resources tagged for testing
ORPHANED=$(az resource list   
–tag purpose=e2e-testing   
–query “[].{id:id, name:name, type:type, resourceGroup:resourceGroup}”   
-o json)

```
    ORPHANED_COUNT=$(echo "$ORPHANED" | jq '. | length')
    
    if [ "$ORPHANED_COUNT" -gt 0 ]; then
        log_warning "Found $ORPHANED_COUNT orphaned Azure resource(s):"
        echo "$ORPHANED" | jq -r '.[] | "  - \(.name) (\(.type)) in \(.resourceGroup)"'
        
        echo ""
        if [ "$FORCE" = false ]; then
            read -p "Delete these orphaned resources? (yes/no): " delete_confirm
            if [[ $delete_confirm != "yes" ]]; then
                log_info "Skipping orphaned resource deletion"
            else
                log_info "Deleting orphaned resources..."
                echo "$ORPHANED" | jq -r '.[].id' | while read -r resource_id; do
                    log_info "Deleting: $resource_id"
                    az resource delete --ids "$resource_id" --verbose
                done
                log_success "Orphaned resources deleted"
            fi
        else
            log_info "Force mode: Deleting orphaned resources..."
            echo "$ORPHANED" | jq -r '.[].id' | while read -r resource_id; do
                log_info "Deleting: $resource_id"
                az resource delete --ids "$resource_id" --verbose
            done
            log_success "Orphaned resources deleted"
        fi
    else
        log_success "No orphaned Azure resources found"
    fi
fi
```

fi

# 

# Step 5: Clean up test namespaces (if any)

# 

echo “”
log_info “Step 5/7: Checking for test namespaces…”
TEST_NS=$(kubectl get namespaces -l test=e2e –no-headers 2>/dev/null | awk ‘{print $1}’)

if [ -n “$TEST_NS” ]; then
log_info “Found test namespace(s): $TEST_NS”
if [ “$FORCE” = false ]; then
read -p “Delete test namespaces? (yes/no): “ ns_confirm
if [[ $ns_confirm == “yes” ]]; then
echo “$TEST_NS” | xargs kubectl delete namespace
log_success “Test namespaces deleted”
else
log_info “Skipping namespace deletion”
fi
else
echo “$TEST_NS” | xargs kubectl delete namespace
log_success “Test namespaces deleted”
fi
else
log_info “No test namespaces found”
fi

# 

# Step 6: Clean up test files (optional)

# 

echo “”
log_info “Step 6/7: Checking for temporary test files…”

TEST_TEMP_DIRS=(
“tests/e2e/.kuttl”
“.kuttl-test”
)

for dir in “${TEST_TEMP_DIRS[@]}”; do
if [ -d “$dir” ]; then
log_info “Removing temporary directory: $dir”
rm -rf “$dir”
fi
done

log_success “Temporary test files cleaned up”

# 

# Step 7: Verify cleanup

# 

echo “”
log_info “Step 7/7: Verifying cleanup…”

# Check for remaining test XRs

REMAINING_XRS=$(kubectl get xstorageaccount -l test=e2e –no-headers 2>/dev/null | wc -l)
if [ “$REMAINING_XRS” -eq 0 ]; then
log_success “No test XRs remaining”
else
log_warning “$REMAINING_XRS test XR(s) still exist”
fi

# Check for remaining managed resources

REMAINING_MANAGED=$(kubectl get managed –no-headers 2>/dev/null | grep -c “test-” || true)
if [ “$REMAINING_MANAGED” -eq 0 ]; then
log_success “No test managed resources remaining”
else
log_warning “$REMAINING_MANAGED managed resource(s) still exist”
log_info “These may still be deleting. Run this script again in a few minutes.”
fi

# Final Azure check

if command -v az >/dev/null 2>&1 && az account show >/dev/null 2>&1; then
FINAL_ORPHANED=$(az resource list –tag purpose=e2e-testing –query “[].id” -o tsv | wc -l)
if [ “$FINAL_ORPHANED” -eq 0 ]; then
log_success “No orphaned Azure resources remaining”
else
log_warning “$FINAL_ORPHANED Azure resource(s) still tagged for testing”
fi
fi

# 

# Summary

# 

echo “”
echo “========================================================================”
echo “   Cleanup Summary”
echo “========================================================================”
echo “”
log_success “Cleanup complete!”
echo “”
log_info “What was cleaned:”
echo “  ✓ XR test resources”
echo “  ✓ Managed resources”
echo “  ✓ Orphaned Azure resources”
echo “  ✓ Temporary test files”
echo “”
log_info “What was preserved:”
echo “  ✓ Crossplane installation”
echo “  ✓ Providers and Functions”
echo “  ✓ XRDs and Compositions”
echo “  ✓ Test directory structure”
echo “  ✓ Test resource group: $TEST_RESOURCE_GROUP”
echo “”
log_info “To run tests again:”
echo “  ./scripts/run-e2e-tests.sh”
echo “”
