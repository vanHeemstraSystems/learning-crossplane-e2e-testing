#!/bin/bash

# 

# Run E2E Tests Script

# This script runs Crossplane E2E tests using kuttl

# 

# Usage: ./scripts/run-e2e-tests.sh [test-directory] [–parallel N] [–timeout SECONDS]

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

# Default configuration

TEST_DIR=”${1:-tests/e2e}”
PARALLEL=“1”
TIMEOUT=“900”
VERBOSE=false

# Parse additional arguments

shift || true
while [[ $# -gt 0 ]]; do
case $1 in
–parallel)
PARALLEL=”$2”
shift 2
;;
–timeout)
TIMEOUT=”$2”
shift 2
;;
–verbose|-v)
VERBOSE=true
shift
;;
–help|-h)
echo “Usage: $0 [test-directory] [options]”
echo “”
echo “Options:”
echo “  –parallel N       Run N tests in parallel (default: 1)”
echo “  –timeout SECONDS  Timeout for tests in seconds (default: 900)”
echo “  –verbose, -v      Enable verbose output”
echo “  –help, -h         Show this help message”
echo “”
echo “Examples:”
echo “  $0                                    # Run all tests”
echo “  $0 tests/e2e/01-storage-account       # Run specific test”
echo “  $0 –parallel 3 –timeout 1200        # Run with custom settings”
exit 0
;;
*)
log_error “Unknown option: $1”
echo “Use –help for usage information”
exit 1
;;
esac
done

echo “========================================================================”
echo “   Crossplane E2E Tests”
echo “========================================================================”
echo “”

# Check prerequisites

log_info “Checking prerequisites…”

# Check kuttl

if ! command -v kubectl-kuttl >/dev/null 2>&1; then
log_error “kubectl-kuttl is not installed”
echo “”
echo “Install with:”
echo “  KUTTL_VERSION=0.15.0”
echo “  wget https://github.com/kudobuilder/kuttl/releases/download/v${KUTTL_VERSION}/kubectl-kuttl_${KUTTL_VERSION}*linux_x86_64”
echo “  chmod +x kubectl-kuttl*${KUTTL_VERSION}*linux_x86_64”
echo “  sudo mv kubectl-kuttl*${KUTTL_VERSION}_linux_x86_64 /usr/local/bin/kubectl-kuttl”
exit 1
fi

# Check kubectl connection

if ! kubectl cluster-info >/dev/null 2>&1; then
log_error “Cannot connect to Kubernetes cluster”
echo “Please configure kubectl to connect to your cluster”
exit 1
fi

# Check Crossplane

CROSSPLANE_NAMESPACE=“crossplane-system”
if ! kubectl get namespace “$CROSSPLANE_NAMESPACE” >/dev/null 2>&1; then
log_error “Crossplane namespace not found”
echo “Please install Crossplane first”
exit 1
fi

log_success “All prerequisites satisfied”

# Check test directory

echo “”
log_info “Checking test directory…”
if [ ! -d “$TEST_DIR” ]; then
log_error “Test directory not found: $TEST_DIR”
exit 1
fi

TEST_SUITES=$(find “$TEST_DIR” -mindepth 1 -maxdepth 1 -type d | wc -l)
if [ “$TEST_SUITES” -eq 0 ]; then
log_error “No test suites found in $TEST_DIR”
exit 1
fi

log_success “Found $TEST_SUITES test suite(s) in $TEST_DIR”

# Display test configuration

echo “”
log_info “Test configuration:”
echo “  Test directory: $TEST_DIR”
echo “  Parallel:       $PARALLEL”
echo “  Timeout:        ${TIMEOUT}s”
echo “  Verbose:        $VERBOSE”
echo “  Cluster:        $(kubectl config current-context)”

# Confirmation

echo “”
read -p “Continue with test execution? (yes/no): “ confirm
if [[ $confirm != “yes” ]]; then
log_info “Test execution cancelled by user”
exit 0
fi

# Pre-test verification

echo “”
log_info “Running pre-test verification…”

# Check Crossplane is healthy

log_info “Verifying Crossplane status…”
if ! kubectl wait –for=condition=ready pod -l app=crossplane -n “$CROSSPLANE_NAMESPACE” –timeout=60s >/dev/null 2>&1; then
log_warning “Crossplane pods are not ready”
fi

# Check providers are healthy

log_info “Verifying providers…”
PROVIDERS=$(kubectl get providers –no-headers 2>/dev/null | wc -l)
if [ “$PROVIDERS” -gt 0 ]; then
HEALTHY_PROVIDERS=$(kubectl get providers -o json | jq -r ‘.items[] | select(.status.conditions[] | select(.type==“Healthy” and .status==“True”)) | .metadata.name’ | wc -l)
if [ “$HEALTHY_PROVIDERS” -eq “$PROVIDERS” ]; then
log_success “All $PROVIDERS provider(s) are healthy”
else
log_warning “Not all providers are healthy ($HEALTHY_PROVIDERS/$PROVIDERS)”
log_info “Providers status:”
kubectl get providers
fi
else
log_warning “No providers found”
fi

# Check ProviderConfig

if kubectl get providerconfig default >/dev/null 2>&1; then
log_success “ProviderConfig ‘default’ exists”
else
log_error “ProviderConfig ‘default’ not found”
exit 1
fi

log_success “Pre-test verification complete”

# Run tests

echo “”
echo “========================================================================”
log_info “Starting E2E tests…”
echo “========================================================================”
echo “”

# Build kuttl command

KUTTL_CMD=“kubectl kuttl test”
KUTTL_CMD=”$KUTTL_CMD –timeout $TIMEOUT”
KUTTL_CMD=”$KUTTL_CMD –parallel $PARALLEL”
KUTTL_CMD=”$KUTTL_CMD –start-kind=false”

if [ “$VERBOSE” = true ]; then
KUTTL_CMD=”$KUTTL_CMD –suppress-log=events”
fi

# Add test directory

KUTTL_CMD=”$KUTTL_CMD $TEST_DIR”

log_info “Executing: $KUTTL_CMD”
echo “”

# Create test results directory

RESULTS_DIR=“test-results/$(date +%Y%m%d-%H%M%S)”
mkdir -p “$RESULTS_DIR”

# Run tests and capture output

if $KUTTL_CMD 2>&1 | tee “$RESULTS_DIR/test-output.log”; then
TEST_RESULT=0
log_success “All tests passed!”
else
TEST_RESULT=$?
log_error “Some tests failed!”
fi

# Post-test summary

echo “”
echo “========================================================================”
log_info “Test Execution Summary”
echo “========================================================================”
echo “”

# Count test results

if [ -f “$RESULTS_DIR/test-output.log” ]; then
PASSED=$(grep -c “PASS” “$RESULTS_DIR/test-output.log” || true)
FAILED=$(grep -c “FAIL” “$RESULTS_DIR/test-output.log” || true)

```
echo "Test Results:"
log_success "Passed: $PASSED"
if [ "$FAILED" -gt 0 ]; then
    log_error "Failed: $FAILED"
else
    echo "Failed: 0"
fi

echo ""
log_info "Full test output saved to: $RESULTS_DIR/test-output.log"
```

fi

# Check for remaining test resources

echo “”
log_info “Checking for remaining test resources…”
REMAINING_XRS=$(kubectl get xstorageaccount -l test=e2e –no-headers 2>/dev/null | wc -l)
if [ “$REMAINING_XRS” -gt 0 ]; then
log_warning “$REMAINING_XRS test XR(s) still exist”
log_info “These should be cleaned up by the test teardown”
log_info “If they persist, run: ./scripts/cleanup-test-resources.sh”
fi

# Display next steps based on result

echo “”
if [ $TEST_RESULT -eq 0 ]; then
log_success “Test execution completed successfully!”
echo “”
log_info “Next steps:”
echo “  - Review test output: $RESULTS_DIR/test-output.log”
echo “  - Create more tests for additional resources”
echo “  - Integrate tests into CI/CD pipeline”
else
log_error “Test execution completed with failures!”
echo “”
log_info “Troubleshooting steps:”
echo “  1. Review test output: $RESULTS_DIR/test-output.log”
echo “  2. Check Crossplane logs:”
echo “     kubectl logs -n crossplane-system deployment/crossplane”
echo “  3. Check provider logs:”
echo “     kubectl logs -n crossplane-system -l pkg.crossplane.io/provider”
echo “  4. Describe failed XRs:”
echo “     kubectl describe xstorageaccount [name]”
echo “  5. Check Azure resources:”
echo “     az resource list –resource-group crossplane-e2e-test-rg”
echo “”
log_info “Clean up test resources:”
echo “  ./scripts/cleanup-test-resources.sh”
fi

echo “”

exit $TEST_RESULT
