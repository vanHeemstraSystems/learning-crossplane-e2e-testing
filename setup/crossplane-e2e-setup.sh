#!/bin/bash

# 

# Crossplane E2E Setup Script

# This script sets up an AKS cluster with Crossplane v2, Azure providers,

# Flux for GitOps, and E2E testing tools (kuttl)

# 

# Usage: ./setup/crossplane-e2e-setup.sh

# 

set -e

# Colors for output

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions

log_info() {
echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration Variables

RESOURCE_GROUP="${RESOURCE_GROUP:-crossplane-e2e-rg}"
LOCATION="${LOCATION:-westeurope}"
CLUSTER_NAME="${CLUSTER_NAME:-crossplane-e2e-aks}"
NODE_COUNT="${NODE_COUNT:-3}"
NODE_SIZE="${NODE_SIZE:-Standard_D2s_v3}"
CROSSPLANE_NAMESPACE="${CROSSPLANE_NAMESPACE:-crossplane-system}"
CROSSPLANE_VERSION="${CROSSPLANE_VERSION:-2.1.0}"
TEST_RESOURCE_GROUP="${TEST_RESOURCE_GROUP:-crossplane-e2e-test-rg}"
GITHUB_USER="${GITHUB_USER:-vanHeemstraSystems}"
GITHUB_REPO="${GITHUB_REPO:-crossplane-e2e-fleet}"
KUTTL_VERSION="${KUTTL_VERSION:-0.15.0}"

# Banner

echo "========================================================================"
echo "   Crossplane V2 E2E Testing Environment Setup"
echo "========================================================================"
echo ""
log_info "Configuration:"
echo "  Resource Group:     $RESOURCE_GROUP"
echo "  Location:           $LOCATION"
echo "  Cluster Name:       $CLUSTER_NAME"
echo "  Node Count:         $NODE_COUNT"
echo "  Node Size:          $NODE_SIZE"
echo "  Crossplane Version: $CROSSPLANE_VERSION"
echo "  Test RG:            $TEST_RESOURCE_GROUP"
echo ""

# Check prerequisites

log_info "Checking prerequisites..."

command -v az >/dev/null 2>&1 || { log_error "Azure CLI is required but not installed. Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is required but not installed. Aborting."; exit 1; }
command -v helm >/dev/null 2>&1 || { log_error "helm is required but not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { log_error "jq is required but not installed. Aborting."; exit 1; }

log_success "All prerequisites are installed"

# Check Azure login

log_info "Checking Azure authentication..."
if ! az account show >/dev/null 2>&1; then
log_error "Not logged in to Azure. Please run 'az login' first."
exit 1
fi

SUBSCRIPTION_ID=$(az account show -query id -o tsv)
SUBSCRIPTION_NAME=$(az account show -query name -o tsv)
log_success "Authenticated to Azure subscription: $SUBSCRIPTION_NAME"
echo "  Subscription ID: $SUBSCRIPTION_ID"

# Prompt for confirmation

echo ""
read -p "Continue with setup? (yes/no): " confirm
if [[ $confirm != "yes" ]]; then
log_warning "Setup cancelled by user"
exit 0
fi

# 

# Step 1: Create Resource Group

# 

echo ""
log_info "Step 1/16: Creating resource group..."
if az group show -name "$RESOURCE_GROUP" >/dev/null 2>&1; then
log_warning "Resource group $RESOURCE_GROUP already exists, skipping creation"
else
az group create   
-name "$RESOURCE_GROUP"   
-location "$LOCATION"   
-tags environment=development managedBy=crossplane   
-output none
log_success "Resource group created: $RESOURCE_GROUP"
fi

# 

# Step 2: Create AKS Cluster

# 

echo ""
log_info "Step 2/16: Creating AKS cluster (this will take 5-10 minutes)..."
if az aks show -resource-group "$RESOURCE_GROUP" -name "$CLUSTER_NAME" >/dev/null 2>&1; then
log_warning "AKS cluster $CLUSTER_NAME already exists, skipping creation"
else
az aks create   
-resource-group "$RESOURCE_GROUP"   
-name "$CLUSTER_NAME"   
-node-count "$NODE_COUNT"   
-node-vm-size "$NODE_SIZE"   
-enable-managed-identity   
-network-plugin azure   
-network-policy azure   
-generate-ssh-keys   
-tags environment=development purpose=crossplane-testing   
-output none
log_success "AKS cluster created: $CLUSTER_NAME"
fi

# 

# Step 3: Get AKS Credentials

# 

echo ""
log_info "Step 3/16: Getting AKS credentials..."
az aks get-credentials   
-resource-group "$RESOURCE_GROUP"   
-name "$CLUSTER_NAME"   
-overwrite-existing   
-output none
log_success "kubectl configured for cluster: $CLUSTER_NAME"

# Verify connection

kubectl cluster-info >/dev/null 2>&1
log_success "Successfully connected to Kubernetes cluster"

# 

# Step 4: Install Crossplane

# 

echo ""
log_info "Step 4/16: Installing Crossplane..."
helm repo add crossplane-stable https://charts.crossplane.io/stable >/dev/null 2>&1
helm repo update >/dev/null 2>&1

if helm list -n "$CROSSPLANE_NAMESPACE" | grep -q crossplane; then
log_warning "Crossplane already installed, skipping"
else
helm install crossplane   
-namespace "$CROSSPLANE_NAMESPACE"   
-create-namespace   
crossplane-stable/crossplane   
-version "$CROSSPLANE_VERSION"   
-wait   
-timeout 10m
log_success "Crossplane installed successfully"
fi

# Wait for Crossplane to be ready

log_info "Waiting for Crossplane pods to be ready..."
kubectl wait -for=condition=ready pod -l app=crossplane -n "$CROSSPLANE_NAMESPACE" -timeout=300s
log_success "Crossplane is ready"

# 

# Step 5: Install Crossplane CLI

# 

echo ""
log_info "Step 5/16: Installing Crossplane CLI..."
if command -v crossplane >/dev/null 2>&1; then
log_warning "Crossplane CLI already installed, skipping"
else
curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh
sudo mv crossplane /usr/local/bin/
log_success "Crossplane CLI installed"
fi

crossplane -version

# 

# Step 6: Create Azure Service Principal

# 

echo ""
log_info "Step 6/16: Creating Azure Service Principal..."

SP_NAME="crossplane-e2e-${CLUSTER_NAME}"

# Check if service principal already exists

EXISTING_SP=$(az ad sp list -display-name "$SP_NAME" -query "[0].appId" -o tsv)

if [ -n "$EXISTING_SP" ]; then
log_warning "Service Principal $SP_NAME already exists"
log_warning "Please manually retrieve credentials or delete and re-run"

```
# Prompt for credentials
read -p "Enter Client ID (appId): " AZURE_CLIENT_ID
read -p "Enter Tenant ID: " AZURE_TENANT_ID
read -s -p "Enter Client Secret (password): " AZURE_CLIENT_SECRET
echo ""
```

else
# Create new service principal
SP_OUTPUT=$(az ad sp create-for-rbac   
-name "$SP_NAME"   
-role Contributor   
-scopes "/subscriptions/$SUBSCRIPTION_ID"   
-output json)

```
AZURE_CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')
AZURE_CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.password')
AZURE_TENANT_ID=$(echo "$SP_OUTPUT" | jq -r '.tenant')

log_success "Service Principal created: $SP_NAME"
```

fi

# Save credentials to file

CREDS_FILE=".azure-credentials"
cat > "$CREDS_FILE" <<EOF
AZURE_CLIENT_ID=$AZURE_CLIENT_ID
AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET
AZURE_TENANT_ID=$AZURE_TENANT_ID
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
EOF

chmod 600 "$CREDS_FILE"
log_success "Credentials saved to $CREDS_FILE (gitignored)"

echo ""
log_warning "IMPORTANT: Save these credentials securely!"
echo "  Client ID:       $AZURE_CLIENT_ID"
echo "  Tenant ID:       $AZURE_TENANT_ID"
echo "  Subscription ID: $SUBSCRIPTION_ID"
echo "  Client Secret:   [HIDDEN]"

# 

# Step 7: Create Kubernetes Secret

# 

echo ""
log_info "Step 7/16: Creating Kubernetes secret for Azure credentials..."

if kubectl get secret azure-secret -n "$CROSSPLANE_NAMESPACE" >/dev/null 2>&1; then
log_warning "Secret azure-secret already exists, deleting and recreating..."
kubectl delete secret azure-secret -n "$CROSSPLANE_NAMESPACE"
fi

kubectl create secret generic azure-secret   
-namespace "$CROSSPLANE_NAMESPACE"   
-from-literal=creds="[default]
client_id = $AZURE_CLIENT_ID
client_secret = $AZURE_CLIENT_SECRET
tenant_id = $AZURE_TENANT_ID
subscription_id = $SUBSCRIPTION_ID"

log_success "Kubernetes secret created: azure-secret"

# 

# Step 8: Install Azure Providers

# 

echo ""
log_info "Step 8/16: Installing Azure Providers..."

## cat <<EOF | kubectl apply -f -

## apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
name: provider-azure-storage
spec:
package: xpkg.upbound.io/upbound/provider-azure-storage:v1.3.0
packagePullPolicy: IfNotPresent

## apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
name: provider-azure-network
spec:
package: xpkg.upbound.io/upbound/provider-azure-network:v1.3.0
packagePullPolicy: IfNotPresent

## apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
name: provider-azure-postgresql
spec:
package: xpkg.upbound.io/upbound/provider-azure-postgresql:v1.3.0
packagePullPolicy: IfNotPresent

apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
name: provider-azure-compute
spec:
package: xpkg.upbound.io/upbound/provider-azure-compute:v1.3.0
packagePullPolicy: IfNotPresent
EOF

log_success "Provider installation manifests applied"

log_info "Waiting for providers to install (this may take 2-3 minutes)..."
sleep 60

# Wait for providers to be healthy

log_info "Waiting for providers to become healthy..."
kubectl wait provider -all   
-for=condition=Healthy   
-timeout=600s

log_success "All providers are healthy"

# 

# Step 9: Create ProviderConfig

# 

echo ""
log_info "Step 9/16: Creating ProviderConfig..."

cat <<EOF | kubectl apply -f -
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
name: default
spec:
credentials:
source: Secret
secretRef:
namespace: $CROSSPLANE_NAMESPACE
name: azure-secret
key: creds
EOF

log_success "ProviderConfig created: default"

# 

# Step 10: Install Flux

# 

echo ""
log_info "Step 10/16: Installing Flux..."

if command -v flux >/dev/null 2>&1; then
log_warning "Flux CLI already installed, skipping"
else
curl -s https://fluxcd.io/install.sh | sudo bash
log_success "Flux CLI installed"
fi

# Check Flux prerequisites

flux check -pre >/dev/null 2>&1
log_success "Flux prerequisites satisfied"

# Note about Flux bootstrap

log_warning "Flux bootstrap requires GitHub token"
log_info "To bootstrap Flux, run:"
echo ""
echo "  export GITHUB_TOKEN=your-github-token"
echo "  flux bootstrap github \"
echo "    -owner=$GITHUB_USER \"
echo "    -repository=$GITHUB_REPO \"
echo "    -branch=main \"
echo "    -path=./clusters/dev \"
echo "    -personal \"
echo "    -token-auth"
echo ""

# 

# Step 11: Install Kuttl

# 

echo ""
log_info "Step 11/16: Installing Kuttl for E2E testing..."

if command -v kubectl-kuttl >/dev/null 2>&1; then
log_warning "Kuttl already installed, skipping"
else
KUTTL_URL="https://github.com/kudobuilder/kuttl/releases/download/v${KUTTL_VERSION}/kubectl-kuttl_${KUTTL_VERSION}_linux_x86_64"
wget -q "$KUTTL_URL" -O kubectl-kuttl
chmod +x kubectl-kuttl
sudo mv kubectl-kuttl /usr/local/bin/
log_success "Kuttl installed"
fi

kubectl kuttl version

# 

# Step 12: Create Test Resource Group

# 

echo ""
log_info "Step 12/16: Creating test resource group..."

if az group show -name "$TEST_RESOURCE_GROUP" >/dev/null 2>&1; then
log_warning "Test resource group $TEST_RESOURCE_GROUP already exists, skipping"
else
az group create   
-name "$TEST_RESOURCE_GROUP"   
-location "$LOCATION"   
-tags environment=test purpose=e2e-testing auto-cleanup=true   
-output none
log_success "Test resource group created: $TEST_RESOURCE_GROUP"
fi

# 

# Step 13: Create Directory Structure

# 

echo ""
log_info "Step 13/16: Creating project directory structure..."

# Create directories

mkdir -p config/{xrds,compositions,provider-configs}
mkdir -p tests/e2e/{storage-accounts,virtual-networks,postgresql-databases,integrations}
mkdir -p scripts
mkdir -p flux/clusters/dev/{crossplane,compositions,xrs}

# Create subdirectories for tests

for dir in tests/e2e/*/; do
mkdir -p "$dir"/{setup,verify,cleanup}
done

log_success "Directory structure created"

# 

# Step 14: Install Composition Functions

# 

echo ""
log_info "Step 14/16: Installing Composition Functions..."

## cat <<EOF | kubectl apply -f -

## apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
name: function-patch-and-transform
spec:
package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.2.1

apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
name: function-auto-ready
spec:
package: xpkg.upbound.io/crossplane-contrib/function-auto-ready:v0.2.1
EOF

log_info "Waiting for functions to be ready..."
sleep 30
kubectl wait function -all -for=condition=Healthy -timeout=300s

log_success "Composition Functions installed"

# 

# Step 15: Create Helper Scripts

# 

echo ""
log_info "Step 15/16: Creating helper scripts..."

# Create verification script

cat > scripts/verify-setup.sh <<'EOFSCRIPT'
#!/bin/bash

echo "=== Crossplane E2E Setup Verification ==="

echo ""
echo "AKS Cluster:"
kubectl cluster-info
kubectl get nodes

echo ""
echo "Crossplane Components:"
kubectl get pods -n crossplane-system
# NOTE: `kubectl get providers` can resolve to Flux "providers" (namespaced) if Flux is installed.
# Use fully-qualified resource names for Crossplane.
kubectl get providers.pkg.crossplane.io
kubectl get functions.pkg.crossplane.io

echo ""
echo "ProviderConfig:"
kubectl get providerconfig

echo ""
echo "XRDs:"
kubectl get xrd

echo ""
echo "Compositions:"
kubectl get composition

echo ""
echo "Flux Status:"
if command -v flux >/dev/null 2>&1; then
flux check 2>/dev/null || echo "Flux not bootstrapped yet"
else
echo "Flux CLI not installed"
fi

echo ""
echo "Test Directory:"
ls -la tests/e2e/ 2>/dev/null || echo "Test directory not found"

echo ""
echo "=== Verification Complete ==="
EOFSCRIPT

# Create cleanup script

cat > scripts/cleanup-test-resources.sh <<'EOFSCRIPT'
#!/bin/bash
set -e

echo "=== Cleaning up E2E test resources ==="

# Delete all test XRs

echo "Deleting test XRs..."
kubectl delete xstorageaccount -l test=e2e -ignore-not-found=true 2>/dev/null || true

# Wait for managed resources to be deleted

echo "Waiting for managed resources to be deleted..."
sleep 30

# Clean up orphaned Azure resources

echo "Checking for orphaned Azure resources..."
ORPHANED=$(az resource list   
-tag purpose=e2e-testing   
-query "[].id" -o tsv)

if [ -n "$ORPHANED" ]; then
echo "Found orphaned resources, deleting..."
echo "$ORPHANED" | xargs -I {} az resource delete -ids {} -verbose
else
echo "No orphaned resources found"
fi

echo "=== Cleanup complete ==="
EOFSCRIPT

# Create test runner script

cat > scripts/run-e2e-tests.sh <<'EOFSCRIPT'
#!/bin/bash
set -e

echo "=== Running Crossplane E2E Tests ==="

# Ensure we're in the right context

echo "Current context: $(kubectl config current-context)"

# Run kuttl tests

kubectl kuttl test tests/e2e/   
-timeout 900   
-start-kind=false

echo "=== E2E Tests Complete ==="
EOFSCRIPT

chmod +x scripts/*.sh

log_success "Helper scripts created in scripts/"

# 

# Step 16: Create .gitignore

# 

echo ""
log_info "Step 16/16: Creating .gitignore..."

cat > .gitignore <<'EOF'

# Azure credentials

.azure-credentials
*.pem
*.key

# Kubernetes configs

kubeconfig
*.kubeconfig

# Terraform

*.tfstate
*.tfstate.*
.terraform/

# IDE

.vscode/
.idea/
*.swp
*.swo

# OS

.DS_Store
Thumbs.db

# Logs

*.log
EOF

log_success ".gitignore created"

# 

# Setup Complete

# 

echo ""
echo "========================================================================"
log_success "Setup Complete!"
echo "========================================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Review the setup:"
echo "   ./scripts/verify-setup.sh"
echo ""
echo "2. Create your first XRD and Composition (see README.md)"
echo ""
echo "3. Bootstrap Flux (optional):"
echo "   export GITHUB_TOKEN=your-token"
echo "   flux bootstrap github -owner=$GITHUB_USER -repository=$GITHUB_REPO ..."
echo ""
echo "4. Run E2E tests (after creating XRDs):"
echo "   ./scripts/run-e2e-tests.sh"
echo ""
echo "5. Cleanup test resources:"
echo "   ./scripts/cleanup-test-resources.sh"
echo ""
echo "Important files created:"
echo "  - .azure-credentials (KEEP SECURE!)"
echo "  - scripts/verify-setup.sh"
echo "  - scripts/run-e2e-tests.sh"
echo "  - scripts/cleanup-test-resources.sh"
echo ""
echo "For detailed instructions, see README.md"
echo ""
