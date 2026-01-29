# AKS Setup for Crossplane V2 with End-to-End Testing

This guide will help you set up an Azure Kubernetes Service (AKS) cluster with Crossplane v2, Flux for GitOps, and end-to-end testing capabilities.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&pivots=winget) installed and authenticated
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/) installed
- [Helm 3](https://helm.sh/docs/intro/install/) installed
- [Git](https://git-scm.com/install/windows) installed
- [jq](https://bobbyhadz.com/blog/install-and-use-jq-on-windows) installed (for JSON parsing)
- [Flux](https://fluxcd.io/flux/installation/) installed
- [Crossplane Client](https://docs.crossplane.io/latest/cli/) installed
- [wget](https://www.techbloat.com/how-to-install-wget-on-windows-11.html) installed
- GitHub account and personal access token
- [Minikube](https://minikube.sigs.k8s.io/docs/start/) or [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) installed: Optional

## Quick Start

```bash
# Clone the repository
git clone https://github.com/vanHeemstraSystems/learning-crossplane-e2e-testing.git
cd learning-crossplane-e2e-testing

# Make the setup script executable
chmod +x setup/crossplane-e2e-setup.sh

# Run the automated setup
./setup/crossplane-e2e-setup.sh
```

Or follow the manual steps below for more control.

## Manual Setup Steps

### 0. Install prerequisites (macOS)

If you're on macOS, you can install the prerequisites using Homebrew:

```bash
brew update
brew install azure-cli kubectl helm jq wget tree k9s
brew install fluxcd/tap/flux
# Install the Crossplane CLI (client only).
# Note: this does NOT install Crossplane into your Kubernetes cluster.
brew install crossplane
```

Alternative (often faster): install Azure CLI via pipx (recommended if Homebrew `azure-cli` is slow):

```bash
brew install pipx
pipx ensurepath

# Restart your shell after ensurepath, then:
pipx install azure-cli
```

Verify the installations:

```bash
az version
kubectl version --client
helm version
jq --version
flux --version
k9s version
wget --version
minikube version # Optional
kind version # Optional
# Client-only version check (no cluster required):
crossplane version # On Windows crossplane --version
# NOTE: `crossplane version` prints the CLI version and then tries to contact
# your *current* Kubernetes context to detect the installed Crossplane version.
# If your cluster isn't reachable (common when the current context points to an
# old/local cluster IP), you'll see a timeout like:
# "unable to get crossplane version ... context deadline exceeded".
#
# Remedy: verify/switch your kubectl context, then retry.
# If your current cluster is Docker-backed (Docker Desktop Kubernetes / kind / k3d),
# make sure Docker Desktop is running first.
# If your current context is `minikube` and the cluster is stopped, start it:
# minikube status
# minikube start
# If the API server IP changed, refresh kubeconfig:
# minikube update-context
kubectl config current-context
kubectl config get-contexts
# kubectl config use-context <your-intended-context>
kubectl cluster-info
kubectl get nodes
crossplane version # On Windows crossplane --version
```

If any of these fail, look at the output to fix it.

### 1. Set Environment Variables

```bash
# Azure Configuration
export RESOURCE_GROUP="crossplane-e2e-rg" # On Windows set RESOURCE_GROUP="crossplane-e2e-rg"
export LOCATION="westeurope"              # On Windows set LOCATION="westeurope"
export CLUSTER_NAME="crossplane-e2e-aks"  # On Windows set CLUSTER_NAME="crossplane-e2e-aks"
export NODE_COUNT=3                       # On Windows set NODE_COUNT=3
export NODE_SIZE="Standard_D2s_v3"        # On Windows set NODE_SIZE="Standard_D2s_v3"

# Crossplane Configuration
export CROSSPLANE_NAMESPACE="crossplane-system" # On Windows set CROSSPLANE_NAMESPACE="crossplane-system"
export CROSSPLANE_VERSION="2.1.0"  # Crossplane v2.x (pin to the latest patch) # On Windows set CROSSPLANE_VERSION="2.1.0"

# Testing Configuration
export TEST_RESOURCE_GROUP="crossplane-e2e-test-rg"  # On Windows set TEST_RESOURCE_GROUP="crossplane-e2e-test-rg"
export TEST_TAG="purpose=e2e-testing"                # On Windows set TEST_TAG="purpose=e2e-testing"
```

Verify the exported values:

```bash
echo "RESOURCE_GROUP=$RESOURCE_GROUP"                # On Windows echo %RESOURCE_GROUP=$RESOURCE_GROUP%
echo "LOCATION=$LOCATION"                            # On Windows echo %LOCATION=$LOCATION%
echo "CLUSTER_NAME=$CLUSTER_NAME"                    # On Windows echo %CLUSTER_NAME=$CLUSTER_NAME%
echo "NODE_COUNT=$NODE_COUNT"                        # On Windows echo %NODE_COUNT=$NODE_COUNT%
echo "NODE_SIZE=$NODE_SIZE"                          # On Windows echo %NODE_SIZE=$NODE_SIZE%
echo "CROSSPLANE_NAMESPACE=$CROSSPLANE_NAMESPACE"    # On Windows echo %CROSSPLANE_NAMESPACE=$CROSSPLANE_NAMESPACE%
echo "CROSSPLANE_VERSION=$CROSSPLANE_VERSION"        # On Windows echo %CROSSPLANE_VERSION=$CROSSPLANE_VERSION%
echo "TEST_RESOURCE_GROUP=$TEST_RESOURCE_GROUP"      # On Windows echo %TEST_RESOURCE_GROUP=$TEST_RESOURCE_GROUP%
echo "TEST_TAG=$TEST_TAG"                            # On Windows echo %TEST_TAG=$TEST_TAG%
```

Tip: if your shell shows `dquote>` you likely started a command with an unclosed `"`. Press `Ctrl+C` to cancel and re-run the exports.

### 2. Create Azure Resources

```bash
# Login to Azure
az login        # If you want to login into an existing tenant, use az login --tenant TENANT_ID, where TENANT_ID is one of your tenant ids (a hash like 1db3a***-**-***-***-****)

# Set your subscription (if you have multiple)
az account set --subscription "YOUR_SUBSCRIPTION_NAME_OR_ID" (here: Subscription Name: Pay-As-You-Go, Subscription ID: b94dca1d-3277-4aa8-b826-1b4324072838)

# Verify current subscription
az account show

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --tags environment=development managedBy=crossplane

# Create AKS cluster with managed identity
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_SIZE \
  --enable-managed-identity \
  --network-plugin azure \
  --network-policy azure \
  --generate-ssh-keys \
  --tags environment=development purpose=crossplane-testing

# This will take 5-10 minutes...
```

Troubleshooting:

- If `az aks create` fails with `(MissingSubscriptionRegistration) The subscription is not registered to use namespace 'Microsoft.ContainerService'`, register the AKS resource provider and retry:

```bash
az provider register --namespace Microsoft.ContainerService
az provider show --namespace Microsoft.ContainerService --query "registrationState" -o tsv
```

Wait until the state is `Registered`, then re-run `az aks create`.

- If you see a warning like `docker_bridge_cidr is not a known attribute ... and will be ignored`, you can ignore it.

### 3. Configure kubectl

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Verify connection
kubectl cluster-info
kubectl get nodes

# Optional (visual alternative to many kubectl "get" commands):
# k9s
```

### 4. Install Crossplane

```bash
# Add Crossplane Helm repository
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane *into your Kubernetes cluster* (server-side components)
helm install crossplane \
  --namespace $CROSSPLANE_NAMESPACE \
  --create-namespace \
  crossplane-stable/crossplane \
  --version $CROSSPLANE_VERSION \
  --wait

# Verify Crossplane installation
kubectl get pods -n $CROSSPLANE_NAMESPACE

# Expected output:
# NAME                                      READY   STATUS    RESTARTS   AGE
# crossplane-xxx                            1/1     Running   0          1m
# crossplane-rbac-manager-xxx               1/1     Running   0          1m
```

### 5. Install Crossplane CLI (client)

```bash
# On macOS, prefer Homebrew (client only):
# brew install crossplane
#
# Alternative (any OS): download and install Crossplane CLI
curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh
sudo mv crossplane /usr/local/bin/

# Verify installation
crossplane version  # On Windows crossplane --version
```

### 6. Create Azure Service Principal for Crossplane

**NOTE**: This step is **Azure-side** (it creates a Service Principal in your Azure tenant/subscription). If you are going through these steps on more than one computer, you can do this step once, then copy the output (the `.azure-credentials` file) to the other computer(s) and **skip this step** there. 

However, next steps like creating the Kubernetes `azure-secret` (Step 7) and the `ProviderConfig` (Step 8 & 9) are **cluster-local** and must be applied to **each Kubernetes cluster / kubectl context** (e.g., your Windows Minikube vs your Mac Minikube are separate clusters).

```bash
# Get your subscription ID
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal with Contributor role
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "crossplane-e2e-${CLUSTER_NAME}" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --output json)

# NOTE: If you get an error like "ERROR: (MissingSubscription) The request did not have a subscription or a valid tenant level resource provider.", in Bash remove the leading slash in front of subscriptions (so --scopes subscriptions/$SUBSCRIPTION_ID \)

# Extract credentials
export AZURE_CLIENT_ID=$(echo $SP_OUTPUT | jq -r '.appId')
export AZURE_CLIENT_SECRET=$(echo $SP_OUTPUT | jq -r '.password')
export AZURE_TENANT_ID=$(echo $SP_OUTPUT | jq -r '.tenant')

# IMPORTANT: Save these credentials securely!
echo "Azure Service Principal Credentials:"
echo "Client ID: $AZURE_CLIENT_ID"
echo "Client Secret: $AZURE_CLIENT_SECRET"
echo "Tenant ID: $AZURE_TENANT_ID"
echo "Subscription ID: $SUBSCRIPTION_ID"

# NOTE: Run below instructions from the root of the repository.

# Save to file (gitignored)
cat > .azure-credentials <<EOF
AZURE_CLIENT_ID=$AZURE_CLIENT_ID
AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET
AZURE_TENANT_ID=$AZURE_TENANT_ID
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
EOF

chmod 600 .azure-credentials
```

### 7. Create Kubernetes Secret for Azure Credentials

**NOTE**: Run below instructions from the root of the repository.

```bash
export CROSSPLANE_NAMESPACE="crossplane-system"
set -a; source .azure-credentials; set +a
```

```bash
# Create secret in Crossplane namespace
kubectl create secret generic azure-secret \
  --namespace "$CROSSPLANE_NAMESPACE" \
  --from-literal=creds="[default]
client_id = $AZURE_CLIENT_ID
client_secret = $AZURE_CLIENT_SECRET
tenant_id = $AZURE_TENANT_ID
subscription_id = $SUBSCRIPTION_ID" \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify secret creation
kubectl get secret azure-secret -n "$CROSSPLANE_NAMESPACE"
```

### 8. Install Azure Providers

Crossplane v2 uses modular providers. Install the ones you need:

```bash
# Create provider installation manifest
cat <<EOF | kubectl apply -f -
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-storage
spec:
  package: xpkg.upbound.io/upbound/provider-azure-storage:v1.3.0
  packagePullPolicy: IfNotPresent
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-network
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v1.3.0
  packagePullPolicy: IfNotPresent
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-dbforpostgresql
spec:
  # Azure Database for PostgreSQL (Flexible Server, etc.)
  # Note: Use a version that exists in the Upbound registry / marketplace.
  # At the time of writing, v2.3.0 is part of provider-family-azure v2.3.0.
  package: xpkg.upbound.io/upbound/provider-azure-dbforpostgresql:v2.3.0
  packagePullPolicy: IfNotPresent
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-compute
spec:
  package: xpkg.upbound.io/upbound/provider-azure-compute:v1.3.0
  packagePullPolicy: IfNotPresent
EOF

# Wait for providers to install (this may take 2-3 minutes)
echo "Waiting for providers to install..."
sleep 60

# If the above command times out before it completes, your Minikube API server may be
# paused/stopped. Restart Minikube and (optionally) disable auto-pause:
minikube stop
# Prevent auto-pause by setting a very large interval (some minikube versions reject `=0`):
minikube start --auto-pause-interval=8760h
# If you get an error like "can't create with that IP, address already in use" (Docker driver),
# your chosen subnet likely overlaps with your LAN/VPN/Docker networks. Start Minikube on a
# different docker network/subnet (pick one that is unused on your machine):
# minikube start --driver=docker --network=minikube-net --subnet=172.30.0.0/16 --auto-pause-interval=8760h
minikube update-context
kubectl get --raw='/healthz'
# Only if the health check returns OK rerun previous command again.
#
# Quickest recovery loop (when you see TLS handshake timeouts / API server flakiness):
#
# minikube stop
# # If Docker feels sluggish, restart Docker Desktop here.
# minikube start --auto-pause-interval=8760h
# minikube update-context
# kubectl get nodes
# ./scripts/verify-setup.sh

# Check provider status
kubectl get providers.pkg.crossplane.io

# Note: If you previously used `provider-azure-postgresql`, it may show `INSTALLED=False`
# due to an upstream package pull/unpack error. The correct Upbound provider is
# `provider-azure-dbforpostgresql` (configured above).

# Wait for all providers to be healthy
kubectl wait provider --all \
  --for=condition=Healthy \
  --timeout=600s

# Verify provider pods are running
kubectl get pods -n $CROSSPLANE_NAMESPACE
```

### 9. Create ProviderConfig

```bash
# Create default ProviderConfig for Azure
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

# Verify ProviderConfig
kubectl get providerconfigs.azure.upbound.io
```

### 10. Install Flux for GitOps

```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify Flux prerequisites
flux check --pre

# Set your GitHub details
export GITHUB_USER="organization-for-demos"
export GITHUB_REPO="crossplane-e2e-fleet"
export GITHUB_TOKEN="your-github-token"  # Create at https://github.com/settings/tokens

# Bootstrap Flux (this creates the repo if it doesn't exist)
#
# IMPORTANT (multi-computer / multi-cluster):
# Flux reconciles ONLY the Kubernetes cluster it is installed into, but it will reconcile
# whatever is in the Git repo path you point it at. If you bootstrap Flux on multiple
# clusters (e.g., Windows Minikube and Mac Minikube) and use the SAME `--path`, then BOTH
# clusters will apply the SAME manifests from that path, which can cause conflicts.
#
# Recommendation: use a unique path per cluster, for example:
# - Windows Minikube: --path=./clusters/dev-win
# - Mac Minikube:     --path=./clusters/dev-mac
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/dev \
  --personal \
  --token-auth

# Verify Flux installation
flux check

# View Flux components
kubectl get pods -n flux-system
```

### 11. Install E2E Testing Tools

```bash
# Install kuttl (Kubernetes Test Tool)

# For installation instruction for Windows, see https://github.com/kudobuilder/kuttl
# First install go: choco install golang
# Then run: git clone https://github.com/kudobuilder/kuttl.git
# cd kuttl
# go build -o kuttl.exe ./cmd/kubectl-kuttl
# Move-Item kuttl.exe C:\Users\<YourUsername>\bin\
# Open the Environment Variables Editor: Press the ⊞ Win key, type Edit environment variables for your account, and select it.
# Alternatively, run: rundll32 sysdm.cpl,EditEnvironmentVariables in Command Prompt.
# Add the Kuttl binary folder to the PATH: Under User variables, find or create the variable PATH.
# Append: %USERPROFILE%\bin. 
# Open a new Command Prompt or PowerShell window to apply the changes.
# Verify the installation by running: kuttl version.
# You should see the installed kuttl version, e.g.,
# KUTTL Version: version.Info{GitVersion:"dev", GitCommit:"dev", BuildDate:"1970-01-01T00:00:00Z", GoVersion:"go1.25.6", Compiler:"gc", Platform:"windows/amd64"}

# Installing Go (Golang) Without Admin Rights on Windows
# Download the Go ZIP archive from the official [Go download page](https://go.dev/doc/install).
# Create a folder for Go installation in your user directory.
# For example: Open Command Prompt and run: mkdir %USERPROFILE%\AppData\Local\Programs\Go
# Navigate to the newly created folder: Run: cd %USERPROFILE%\AppData\Local\Programs\Go
# Extract the contents of the downloaded ZIP archive into this folder.
# Open the Environment Variables Editor: Press the ⊞ Win key, type Edit environment variables for your account, and select it.
# Alternatively, run: rundll32 sysdm.cpl,EditEnvironmentVariables in Command Prompt.
# Add the Go binary folder to the PATH: Under User variables, find or create the variable PATH.
# Append: %USERPROFILE%\AppData\Local\Programs\Go\bin.
# Create a new environment variable GOROOT: Set its value to: %USERPROFILE%\AppData\Local\Programs\Go.
# Open a new Command Prompt or PowerShell window to apply the changes.
# Verify the installation by running: go version.
# You should see the installed Go version, e.g., go version go1.x.x windows/amd64.

KUTTL_VERSION=0.15.0

# macOS (Darwin): download the correct darwin binary for your CPU architecture
ARCH="$(uname -m)" # arm64 or x86_64
if [ "$ARCH" = "arm64" ]; then
  FILE="kubectl-kuttl_${KUTTL_VERSION}_darwin_arm64"
else
  FILE="kubectl-kuttl_${KUTTL_VERSION}_darwin_x86_64"
fi
curl -sSL -o kubectl-kuttl "https://github.com/kudobuilder/kuttl/releases/download/v${KUTTL_VERSION}/${FILE}"
chmod +x kubectl-kuttl
sudo mv kubectl-kuttl /usr/local/bin/kubectl-kuttl

# Linux (x86_64): download the linux binary
# wget -q https://github.com/kudobuilder/kuttl/releases/download/v${KUTTL_VERSION}/kubectl-kuttl_${KUTTL_VERSION}_linux_x86_64
# chmod +x kubectl-kuttl_${KUTTL_VERSION}_linux_x86_64
# sudo mv kubectl-kuttl_${KUTTL_VERSION}_linux_x86_64 /usr/local/bin/kubectl-kuttl

# Verify kuttl installation
kubectl kuttl version  # or kuttl version

# Install Azure CLI (if not already installed)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### 12. Create Test Directory Structure

```bash
# Create E2E test directory structure
mkdir -p tests/e2e/{storage-accounts,virtual-networks,postgresql-databases,integrations}

# Create an initial test-case directory per suite.
# KUTTL expects test *cases* to be subdirectories containing numbered step files (00-*.yaml, 01-*.yaml, ...).
for dir in tests/e2e/*/; do
  mkdir -p "$dir"/basic
done

# Create test resource group for E2E tests
az group create \
  --name $TEST_RESOURCE_GROUP \
  --location $LOCATION \
  --tags environment=test purpose=e2e-testing auto-cleanup=true

echo "Test directory structure created!"
tree tests/e2e/
```

### 13. Create Example XRD and Composition

Let’s create a simple storage account example:

```bash
# Create API directory structure (Upbound-style)
#
# Folder structure:
# apis/v1alpha1/
#   kustomization.yaml
#   storage-accounts/
#     xrd.yaml
#     composition.yaml
#     kustomization.yaml
mkdir -p apis/v1alpha1/storage-accounts

# Create Storage Account XRD
cat <<'EOF' > apis/v1alpha1/storage-accounts/xrd.yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: xstorageaccounts.storage.example.io
spec:
  group: storage.example.io
  names:
    kind: XStorageAccount
    plural: xstorageaccounts
  # NOTE (Crossplane v2):
  # - In Crossplane v2.x, XRDs use `apiVersion: apiextensions.crossplane.io/v2`.
  # - This `apiVersion` is the CRD API version for the XRD type (not the XR's API version).
  # - Crossplane v2 uses XRs (Composite Resources). Claims are not used in this guide.
  scope: Namespaced
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              parameters:
                type: object
                properties:
                  location:
                    type: string
                    description: Azure region for the storage account
                    default: westeurope
                  accountTier:
                    type: string
                    description: Storage account tier
                    enum: [Standard, Premium]
                    default: Standard
                  replicationType:
                    type: string
                    description: Replication type
                    enum: [LRS, GRS, RAGRS, ZRS]
                    default: LRS
                  resourceGroupName:
                    type: string
                    description: Azure resource group name
                  tags:
                    type: object
                    description: Additional tags for the storage account
                    additionalProperties:
                      type: string
                required:
                - resourceGroupName
            required:
            - parameters
          status:
            type: object
            properties:
              storageAccountName:
                type: string
              primaryEndpoint:
                type: string
EOF

# Create Storage Account Composition
cat <<'EOF' > apis/v1alpha1/storage-accounts/composition.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xstorageaccounts.storage.example.io
  labels:
    provider: azure
    type: standard
spec:
  compositeTypeRef:
    apiVersion: storage.example.io/v1alpha1
    kind: XStorageAccount
  
  mode: Pipeline
  pipeline:
  - step: patch-and-transform
    functionRef:
      name: function-patch-and-transform
    input:
      apiVersion: pt.fn.crossplane.io/v1beta1
      kind: Resources
      resources:
      # Crossplane v2: use namespaced Managed Resources (the `.m.` API groups).

      - name: resourcegroup
        base:
          apiVersion: azure.m.upbound.io/v1beta1
          kind: ResourceGroup
          spec:
            forProvider:
              location: westeurope
              tags:
                managedBy: crossplane
                environment: test
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.location
          toFieldPath: spec.forProvider.location
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.resourceGroupName
          toFieldPath: metadata.name

      - name: storageaccount
        base:
          apiVersion: storage.azure.m.upbound.io/v1beta2
          kind: Account
          spec:
            forProvider:
              accountReplicationType: LRS
              accountTier: Standard
              resourceGroupNameSelector:
                matchControllerRef: true
              tags:
                managedBy: crossplane
                environment: test
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.location
          toFieldPath: spec.forProvider.location
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.accountTier
          toFieldPath: spec.forProvider.accountTier
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.replicationType
          toFieldPath: spec.forProvider.accountReplicationType
        - type: ToCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: status.storageAccountName
        - type: ToCompositeFieldPath
          fromFieldPath: status.atProvider.primaryBlobEndpoint
          toFieldPath: status.primaryEndpoint
        readinessChecks:
        - type: MatchString
          fieldPath: status.atProvider.provisioningState
          matchString: Succeeded
  
  - step: auto-ready
    functionRef:
      name: function-auto-ready
EOF

# Kustomize (so you can `kubectl apply -k` this API package)
cat <<'EOF' > apis/v1alpha1/storage-accounts/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- xrd.yaml
- composition.yaml
EOF

cat <<'EOF' > apis/v1alpha1/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- storage-accounts
EOF

==== WE ARE HERE ON WINDOWS ====

# Install required Composition Functions
cat <<EOF | kubectl apply -f -
---
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.2.1
---
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-auto-ready
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-auto-ready:v0.2.1
EOF

# Wait for functions to be ready
sleep 30
kubectl wait function --all --for=condition=Healthy --timeout=300s

# Apply XRD and Composition
kubectl apply -k apis/v1alpha1/storage-accounts

# Verify
kubectl get xrd
kubectl get composition
```

### 14. Create Example E2E Test

```bash
# Create test suite configuration (so you can run `kubectl kuttl test --config tests/e2e/kuttl-test.yaml`)
cat <<'EOF' > tests/e2e/kuttl-test.yaml
apiVersion: kuttl.dev/v1beta1
kind: TestSuite
timeout: 600
parallel: 1
testDirs:
  - ./tests/e2e/storage-accounts
  - ./tests/e2e/virtual-networks
  - ./tests/e2e/postgresql-databases
  - ./tests/e2e/integrations
EOF

# Create a test case directory (KUTTL discovers test cases as subdirectories)
mkdir -p tests/e2e/storage-accounts/basic

# IMPORTANT:
# KUTTL only executes files that start with a numeric step prefix (e.g. `00-...yaml`).
# Files without the prefix are ignored by default.

# Create test case - Setup
cat <<'EOF' > tests/e2e/storage-accounts/basic/00-xr-storage.yaml
apiVersion: storage.example.io/v1alpha1
kind: XStorageAccount
metadata:
  name: test-storage-e2e-001
  namespace: default
spec:
  parameters:
    location: westeurope
    accountTier: Standard
    replicationType: LRS
    resourceGroupName: crossplane-e2e-test-rg
  compositionSelector:
    matchLabels:
      provider: azure
      type: standard
EOF

# Create test case - Assert XR is created
cat <<'EOF' > tests/e2e/storage-accounts/basic/00-assert.yaml
apiVersion: storage.example.io/v1alpha1
kind: XStorageAccount
metadata:
  name: test-storage-e2e-001
  namespace: default
status:
  conditions:
  - type: Ready
    status: "True"
  - type: Synced
    status: "True"
EOF

# Create test case - Verify Managed Resources
cat <<'EOF' > tests/e2e/storage-accounts/basic/01-assert-storage.yaml
apiVersion: storage.azure.m.upbound.io/v1beta2
kind: Account
metadata:
  name: test-storage-e2e-001
  namespace: default
  ownerReferences:
  - apiVersion: storage.example.io/v1alpha1
    kind: XStorageAccount
    name: test-storage-e2e-001
status:
  conditions:
  - type: Ready
    status: "True"
EOF

# Create test case - Verify with Azure CLI
cat <<'EOF' > tests/e2e/storage-accounts/basic/01-verify-azure.yaml
apiVersion: kuttl.dev/v1beta1
kind: TestAssert
commands:
- script: |
    # Get the storage account name from the XR
    STORAGE_NAME=$(kubectl get xstorageaccount test-storage-e2e-001 \
      -n default \
      -o jsonpath='{.status.storageAccountName}')
    
    # Verify the storage account exists in Azure
    az storage account show \
      --name $STORAGE_NAME \
      --resource-group crossplane-e2e-test-rg \
      --query "provisioningState" \
      --output tsv | grep -q "Succeeded"
    
    exit $?
EOF

# Create test case - Cleanup
cat <<'EOF' > tests/e2e/storage-accounts/basic/02-delete.yaml
apiVersion: storage.example.io/v1alpha1
kind: XStorageAccount
metadata:
  name: test-storage-e2e-001
  namespace: default
$patch: delete
EOF

# Create test case - Assert cleanup completed
cat <<'EOF' > tests/e2e/storage-accounts/basic/02-assert.yaml
apiVersion: kuttl.dev/v1beta1
kind: TestAssert
commands:
- script: |
    # Verify XR is deleted
    ! kubectl get xstorageaccount test-storage-e2e-001 -n default 2>/dev/null
    exit $?
EOF
```

### 15. Create Helper Scripts

```bash
# Create scripts directory
mkdir -p scripts

# Create test runner script
cat <<'EOF' > scripts/run-e2e-tests.sh
#!/bin/bash
set -e

echo "=== Running Crossplane E2E Tests ==="

# Ensure we're in the right context
kubectl config current-context

# Run kuttl tests
kubectl kuttl test \
  --config tests/e2e/kuttl-test.yaml \
  --timeout 900 \
  --start-kind=false

echo "=== E2E Tests Complete ==="
EOF

# Create cleanup script
cat <<'EOF' > scripts/cleanup-test-resources.sh
#!/bin/bash
set -e

echo "=== Cleaning up E2E test resources ==="

# Delete all test XRs
echo "Deleting test XRs..."
kubectl delete xstorageaccount -l test=e2e --ignore-not-found=true

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
EOF

# Make scripts executable
chmod +x scripts/*.sh
```

### 16. Create Flux GitOps Structure

```bash
# Create Flux directory structure
mkdir -p flux/clusters/dev/{crossplane,compositions,xrs}

# Create Flux Kustomization for Crossplane configs
cat <<EOF > flux/clusters/dev/crossplane/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../apis/v1alpha1
EOF

# Create Flux Kustomization for Compositions
cat <<EOF > flux/clusters/dev/compositions/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../apis/v1alpha1
EOF

# Create Flux GitRepository
cat <<EOF > flux/clusters/dev/crossplane-repo.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: crossplane-configs
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/$GITHUB_USER/$GITHUB_REPO
  ref:
    branch: main
EOF

# Create Flux Kustomizations
cat <<EOF > flux/clusters/dev/crossplane-kustomizations.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: crossplane-apis
  namespace: flux-system
spec:
  interval: 5m
  path: ./apis/v1alpha1
  prune: true
  sourceRef:
    kind: GitRepository
    name: crossplane-configs
  healthChecks:
  - apiVersion: apiextensions.crossplane.io/v2
    kind: CompositeResourceDefinition
    name: xstorageaccounts.storage.example.io
EOF
```

## Verification Steps

### 1. Verify Complete Installation

```bash
# Run complete verification
cat <<'EOF' > scripts/verify-setup.sh
#!/bin/bash

echo "=== Crossplane E2E Setup Verification ==="

# Check AKS
echo "Checking AKS cluster..."
kubectl cluster-info
kubectl get nodes

# Check Crossplane
echo "Checking Crossplane..."
kubectl get pods -n crossplane-system
kubectl get providers.pkg.crossplane.io
kubectl get functions.pkg.crossplane.io

# Check ProviderConfig
echo "Checking ProviderConfig..."
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
EOF

chmod +x scripts/verify-setup.sh
./scripts/verify-setup.sh
```

==== WE ARE HERE ON MAC ====

### 2. Run Your First E2E Test

```bash
# Run the storage account test
kubectl kuttl test tests/e2e/storage-accounts/

# Or run all suites using the config file
kubectl kuttl test --config tests/e2e/kuttl-test.yaml

# Watch the test progress in another terminal
watch kubectl get xstorageaccount,account,resourcegroup
```

### 3. Monitor with Azure CLI

```bash
# Watch Azure resources being created
watch az resource list \
  --resource-group crossplane-e2e-test-rg \
  --output table
```

## Troubleshooting

### Common Issues

**1. Provider not becoming healthy**

```bash
# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-storage

# Check provider config
kubectl describe providerconfig default
```

**2. XR not becoming ready**

```bash
# Check XR events
kubectl describe xstorageaccount test-storage-e2e-001

# Check managed resource status
kubectl get managed

# Check Crossplane logs
kubectl logs -n crossplane-system deployment/crossplane -f
```

**3. Azure authentication issues**

```bash
# Verify secret exists
kubectl get secret azure-secret -n crossplane-system

# Test service principal manually
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

az account show
```

**4. Flux not syncing**

```bash
# Check Flux status
flux get all

# Force reconciliation
flux reconcile source git crossplane-configs
flux reconcile kustomization crossplane-xrds

# Check Flux logs
kubectl logs -n flux-system deployment/source-controller
```

## Cleanup

### Temporary Cleanup (Keep Cluster)

```bash
# Run cleanup script
./scripts/cleanup-test-resources.sh

# Or manual cleanup
kubectl delete xstorageaccount --all
kubectl delete composition --all
kubectl delete xrd --all
```

### Complete Cleanup (Remove Everything)

```bash
# Delete test resource group
az group delete --name $TEST_RESOURCE_GROUP --yes --no-wait

# Delete AKS cluster and main resource group
az group delete --name $RESOURCE_GROUP --yes --no-wait

# Delete service principal
SP_ID=$(az ad sp list --display-name "crossplane-e2e-${CLUSTER_NAME}" --query "[0].id" -o tsv)
az ad sp delete --id $SP_ID

# Remove local kubectl context
kubectl config delete-context $CLUSTER_NAME
```

## Next Steps

1. **Create more XRDs and Compositions** for your use cases (databases, networks, etc.)
1. **Integrate with Backstage** to generate XRs from templates
1. **Set up CI/CD pipeline** to run E2E tests on every PR
1. **Create monitoring dashboards** for Crossplane resources
1. **Implement cost tracking** for test resources
1. **Document your compositions** for platform users

## Additional Resources

- [Crossplane Documentation](https://docs.crossplane.io/)
- [Upbound Testing Guide](https://blog.upbound.io/crossplane-testing-deep-dive)
- [Flux Documentation](https://fluxcd.io/docs/)
- [Kuttl Documentation](https://kuttl.dev/)
- [Azure Provider Documentation](https://marketplace.upbound.io/providers/upbound/provider-azure)

## Support

For issues or questions:

- Check the [troubleshooting section](#troubleshooting) above
- Review Crossplane logs: `kubectl logs -n crossplane-system deployment/crossplane`
- Check provider logs: `kubectl logs -n crossplane-system -l pkg.crossplane.io/provider`
- Consult the [Crossplane Slack](https://slack.crossplane.io/)

-----

**Note**: This setup is configured for development and testing. For production deployments, consider:

- Using Azure Key Vault for secrets
- Implementing network policies
- Setting up monitoring and alerting
- Configuring backup and disaster recovery
- Implementing proper RBAC
- Using separate subscriptions for different environments
