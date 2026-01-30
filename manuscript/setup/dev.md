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
# Crossplane v2.x (pin to the latest patch you want)
export CROSSPLANE_VERSION="v2.1.0"  # On Windows set CROSSPLANE_VERSION="v2.1.0"

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

# Install / upgrade Crossplane *into your Kubernetes cluster* (server-side components).
# Note: `--version` pins the *Helm chart version*, which does not match the Crossplane app version.
# We pin the Crossplane app version via `--set image.tag=...`.
helm upgrade --install crossplane \
  --namespace $CROSSPLANE_NAMESPACE \
  --create-namespace \
  crossplane-stable/crossplane \
  --set image.tag=$CROSSPLANE_VERSION \
  --wait

# Verify Crossplane installation
kubectl get pods -n $CROSSPLANE_NAMESPACE

# Verify the cluster supports the XRD v2 API (required for `apiVersion: apiextensions.crossplane.io/v2` XRDs)
kubectl get crd compositeresourcedefinitions.apiextensions.crossplane.io \
  -o jsonpath='{.spec.versions[*].name}'; echo

# Expected output:
# NAME                                      READY   STATUS    RESTARTS   AGE
# crossplane-xxx                            1/1     Running   0          1m
# crossplane-rbac-manager-xxx               1/1     Running   0          1m
```

### 4.1 Verify Webhook Stability (Recommended)

Crossplane v2 uses webhooks extensively. If you see intermittent `TLS handshake timeout` / `context deadline exceeded` errors while applying providers / functions / compositions, patching webhook timeouts often helps:

```bash
# Wait for Crossplane to be fully ready
kubectl wait --for=condition=available deployment/crossplane \
  -n "$CROSSPLANE_NAMESPACE" --timeout=300s

# Patch validating webhook timeout
kubectl patch validatingwebhookconfigurations \
  crossplane-validating-webhook-configuration \
  --type='json' \
  -p='[{"op": "replace", "path": "/webhooks/0/timeoutSeconds", "value": 30}]'

# Patch mutating webhook timeout
kubectl patch mutatingwebhookconfigurations \
  crossplane-mutating-webhook-configuration \
  --type='json' \
  -p='[{"op": "replace", "path": "/webhooks/0/timeoutSeconds", "value": 30}]'

# Give webhooks time to stabilize
sleep 15
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

# IMPORTANT:
# `AZURE_CLIENT_SECRET` must be the *secret value* (the "password" returned by Azure CLI),
# not a "secret ID". If you get Azure error `AADSTS7000215: Invalid client secret provided`,
# regenerate a new secret value with the steps below.
#
# 1) Make sure your Azure CLI session is in the correct tenant (otherwise `az ad sp ...` may
#    say "Resource ... does not exist"):
#
#   az login --tenant "$AZURE_TENANT_ID"
#
# 2) Confirm the Service Principal exists (by appId / clientId):
#
#   az ad sp show --id "$AZURE_CLIENT_ID" --query id -o tsv
#
# 3) Reset credentials and capture the new *secret value*:
#
#   az ad sp credential reset --id "$AZURE_CLIENT_ID" --append --query password -o tsv
#
# Then update `.azure-credentials` and recreate the Kubernetes `azure-secret` in Step 7.
#
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

# Optional sanity check (recommended): verify the service principal can authenticate
az login --service-principal \
  -u "$AZURE_CLIENT_ID" \
  -p "$AZURE_CLIENT_SECRET" \
  --tenant "$AZURE_TENANT_ID" >/dev/null
```

### 7. Create Kubernetes Secret for Azure Credentials

**NOTE**: Run below instructions from the root of the repository.

```bash
export CROSSPLANE_NAMESPACE="crossplane-system"
set -a; source .azure-credentials; set +a
```

```bash
# Create secret in Crossplane namespace
# IMPORTANT (Upbound Azure providers):
# The `creds` secret value must be **JSON** (not INI, not dotenv). If you use a non-JSON format
# you will get errors like:
#   "cannot unmarshal Azure credentials as JSON: invalid character ..."
cat > azure-credentials.json <<EOF
{
  "clientId": "${AZURE_CLIENT_ID}",
  "clientSecret": "${AZURE_CLIENT_SECRET}",
  "tenantId": "${AZURE_TENANT_ID}",
  "subscriptionId": "${SUBSCRIPTION_ID}"
}
EOF

kubectl create secret generic azure-secret \
  --namespace "$CROSSPLANE_NAMESPACE" \
  --from-file=creds=./azure-credentials.json \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify secret creation
kubectl get secret azure-secret -n "$CROSSPLANE_NAMESPACE"
```

### 8. Install Azure Providers

This PostgreSQL example composes **namespaced** Upbound Azure managed resources:
- `azure.m.upbound.io/...` (e.g. `ResourceGroup`)
- `dbforpostgresql.azure.m.upbound.io/...` (e.g. `FlexibleServer`, `FlexibleServerDatabase`)

Install the Upbound Azure provider family to get the required `.m.upbound.io` CRDs.

```bash
# Install provider-family-azure (includes dbforpostgresql + many other Azure APIs)
# If your apiserver is flaky, skip client-side validation to avoid OpenAPI fetch timeouts.
cat <<EOF | kubectl apply --validate=false -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-family-azure
spec:
  package: xpkg.upbound.io/upbound/provider-family-azure:v2.3.0
  packagePullPolicy: IfNotPresent
EOF

# Wait for providers to install (this may take 2-3 minutes)
echo "Waiting for providers to install..."
sleep 60

# If the above command times out before it completes, your Minikube API server may be
# paused/stopped. Restart Minikube and (optionally) disable auto-pause:
minikube stop
# If you want to start from scratch
minikube delete --profile minikube || true
docker rm -f minikube 2>/dev/null || true

# Use a unique Docker network name to avoid clashes with Docker Desktop extensions
# (some extensions may create and hold onto common names like `minikube-net`).
#
# No manual edits needed: we generate a unique name per run, and pick a non-overlapping private subnet.
# If Docker says "Pool overlaps", it means some other Docker network already uses that subnet.
MINIKUBE_DOCKER_NET="minikube-net-$(date +%Y%m%d%H%M%S)-$RANDOM"
echo "Using MINIKUBE_DOCKER_NET=$MINIKUBE_DOCKER_NET"

for MINIKUBE_DOCKER_SUBNET in \
  172.30.0.0/16 172.29.0.0/16 172.28.0.0/16 172.27.0.0/16 172.26.0.0/16 \
  172.25.0.0/16 172.24.0.0/16 172.23.0.0/16 172.22.0.0/16 172.21.0.0/16 172.20.0.0/16
do
  if docker network create --subnet="$MINIKUBE_DOCKER_SUBNET" "$MINIKUBE_DOCKER_NET" >/dev/null 2>&1; then
    echo "Using MINIKUBE_DOCKER_SUBNET=$MINIKUBE_DOCKER_SUBNET"
    break
  fi
done

if ! docker network inspect "$MINIKUBE_DOCKER_NET" >/dev/null 2>&1; then
  echo "ERROR: could not create a non-overlapping docker network for minikube." >&2
  echo "Tip: list existing subnets with: docker network inspect <network> --format '{{json .IPAM.Config}}'" >&2
  exit 1
fi
# Prevent auto-pause by setting a very large interval (some minikube versions reject `=0`):
# NOTE (macOS + docker driver): Docker Desktop must be running, otherwise you'll see:
#   "PROVIDER_DOCKER_NOT_RUNNING ... Cannot connect to the Docker daemon ..."
# minikube start --auto-pause-interval=8760h
# If you get an error like "can't create with that IP, address already in use" (Docker driver),
# your chosen subnet likely overlaps with your LAN/VPN/Docker networks. Start Minikube on a
# different docker network/subnet (pick one that is unused on your machine):
minikube start \
  --driver=docker \
  --network="$MINIKUBE_DOCKER_NET" \
  --subnet="$MINIKUBE_DOCKER_SUBNET" \
  --container-runtime=containerd \
  --auto-pause-interval=8760h
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

# Optional (recommended): install Uptest (Crossplane provider / managed resource test harness)
#
# Uptest is designed for the Crossplane ecosystem and can complement (or replace) some KUTTL flows,
# especially when you want lifecycle-style tests (create → ready → delete) with sensible timeouts.
#
# Any OS (Go toolchain required):
go install github.com/crossplane/uptest@latest
#
# macOS (Homebrew, if available in your setup):
# brew install uptest
#
# Verify:
uptest --version

# Install Azure CLI (if not already installed)
#
# macOS (recommended if Homebrew `azure-cli` is slow): pipx
brew install pipx
pipx ensurepath
# IMPORTANT: `pipx` installs shims into `~/.local/bin`. You typically need to restart your shell
# (or source the right rc file) so `~/.local/bin` is on your PATH.
# - zsh:  source ~/.zshrc  (or open a new terminal)
# - bash: source ~/.bashrc (or open a new terminal)
#
# Quick sanity checks:
#   ls -la ~/.local/bin/az
#   echo "$PATH" | tr ':' '\n' | grep -n '\.local/bin' || true
#
# Then:
pipx install azure-cli
az version
#
# macOS fallback (Homebrew):
# brew update
# brew install azure-cli
# az version
#
# Linux (Debian/Ubuntu):
# curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
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

Let’s create a simple PostgreSQL example (Azure PostgreSQL Flexible Server + Database) using a **namespaced XR**.

```bash
# Create API directory structure (Upbound-style)
#
# Folder structure:
# apis/v1alpha1/
#   kustomization.yaml
#   postgresql-databases/
#     xrd.yaml
#     composition.yaml
#     kustomization.yaml
mkdir -p apis/v1alpha1/postgresql-databases

# Create PostgreSQL XRD (namespaced XR)
cat <<'EOF' > apis/v1alpha1/postgresql-databases/xrd.yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: xpostgresqldatabases.database.example.io
spec:
  group: database.example.io
  names:
    kind: XPostgreSQLDatabase
    plural: xpostgresqldatabases
  # Crossplane v2 XRDs support `scope` (defaults to Namespaced). We set it explicitly.
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
              crossplane:
                type: object
                properties:
                  compositionSelector:
                    type: object
                    properties:
                      matchLabels:
                        type: object
                        additionalProperties:
                          type: string
              parameters:
                type: object
                properties:
                  location:
                    type: string
                    description: Azure region for the PostgreSQL Flexible Server
                    default: westeurope
                  resourceGroupName:
                    type: string
                    description: Azure resource group name
                  databaseName:
                    type: string
                    description: PostgreSQL database name (Azure external name)
                    default: appdb
                  adminUsername:
                    type: string
                    description: PostgreSQL admin username
                    default: pgadmin
                  adminPasswordSecretName:
                    type: string
                    description: Secret name (same namespace as XR) containing the admin password
                    default: postgres-admin-password
                  adminPasswordSecretKey:
                    type: string
                    description: Secret key containing the admin password
                    default: password
                  postgresVersion:
                    type: string
                    description: PostgreSQL major version
                    default: "16"
                  skuName:
                    type: string
                    description: Azure SKU name for Flexible Server
                    default: B_Standard_B1ms
                  storageMb:
                    type: integer
                    description: Allocated storage in MB
                    default: 32768
                required:
                - resourceGroupName
            required:
            - parameters
          status:
            type: object
            properties:
              serverName:
                type: string
              databaseName:
                type: string
EOF

# Create PostgreSQL Composition (ResourceGroup + FlexibleServer + FlexibleServerDatabase)
cat <<'EOF' > apis/v1alpha1/postgresql-databases/composition.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xpostgresqldatabases.database.example.io
  labels:
    provider: azure
    type: standard
spec:
  compositeTypeRef:
    apiVersion: database.example.io/v1alpha1
    kind: XPostgreSQLDatabase

  mode: Pipeline
  pipeline:
  - step: patch-and-transform
    functionRef:
      name: function-patch-and-transform
    input:
      apiVersion: pt.fn.crossplane.io/v1beta1
      kind: Resources
      resources:
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
            providerConfigRef:
              kind: ProviderConfig
              name: default
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.location
          toFieldPath: spec.forProvider.location
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.resourceGroupName
          toFieldPath: metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.resourceGroupName
          toFieldPath: metadata.annotations[crossplane.io/external-name]

      - name: flexibleserver
        base:
          apiVersion: dbforpostgresql.azure.m.upbound.io/v1beta1
          kind: FlexibleServer
          metadata:
            annotations: {}
          spec:
            forProvider:
              location: westeurope
              skuName: B_Standard_B1ms
              version: "16"
              storageMb: 32768
              backupRetentionDays: 7
              autoGrowEnabled: true
              publicNetworkAccessEnabled: true
              administratorLogin: pgadmin
              administratorPasswordSecretRef:
                name: postgres-admin-password
                key: password
              resourceGroupNameRef:
                name: example
            providerConfigRef:
              kind: ProviderConfig
              name: default
            writeConnectionSecretToRef:
              name: postgres-conn
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.location
          toFieldPath: spec.forProvider.location
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.skuName
          toFieldPath: spec.forProvider.skuName
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.postgresVersion
          toFieldPath: spec.forProvider.version
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.storageMb
          toFieldPath: spec.forProvider.storageMb
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.adminUsername
          toFieldPath: spec.forProvider.administratorLogin
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.adminPasswordSecretName
          toFieldPath: spec.forProvider.administratorPasswordSecretRef.name
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.adminPasswordSecretKey
          toFieldPath: spec.forProvider.administratorPasswordSecretRef.key
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.resourceGroupName
          toFieldPath: spec.forProvider.resourceGroupNameRef.name
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.namespace
          toFieldPath: spec.forProvider.resourceGroupNameRef.namespace
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: metadata.annotations[crossplane.io/external-name]
          transforms:
          - type: string
            string:
              type: Convert
              convert: ToLower
          - type: string
            string:
              type: Regexp
              regexp:
                match: '[^a-z0-9-]'
                replace: '-'
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: metadata.name
          transforms:
          - type: string
            string:
              type: Convert
              convert: ToLower
          - type: string
            string:
              type: Regexp
              regexp:
                match: '[^a-z0-9-]'
                replace: '-'
        - type: ToCompositeFieldPath
          fromFieldPath: metadata.annotations[crossplane.io/external-name]
          toFieldPath: status.serverName
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.namespace
          toFieldPath: spec.writeConnectionSecretToRef.name
          transforms:
          - type: string
            string:
              type: Format
              fmt: postgres-conn-%s

      - name: flexibleserverdatabase
        base:
          apiVersion: dbforpostgresql.azure.m.upbound.io/v1beta1
          kind: FlexibleServerDatabase
          metadata:
            annotations: {}
          spec:
            forProvider:
              charset: UTF8
              collation: en_US.utf8
              serverIdSelector:
                matchControllerRef: true
            providerConfigRef:
              kind: ProviderConfig
              name: default
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.databaseName
          toFieldPath: metadata.annotations[crossplane.io/external-name]
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.databaseName
          toFieldPath: metadata.name
          transforms:
          - type: string
            string:
              type: Convert
              convert: ToLower
          - type: string
            string:
              type: Regexp
              regexp:
                match: '[^a-z0-9-]'
                replace: '-'
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.namespace
          toFieldPath: spec.forProvider.serverIdSelector.namespace
        - type: ToCompositeFieldPath
          fromFieldPath: metadata.annotations[crossplane.io/external-name]
          toFieldPath: status.databaseName

  - step: auto-ready
    functionRef:
      name: function-auto-ready
EOF

# Kustomize (so you can `kubectl apply -k` this API package)
cat <<'EOF' > apis/v1alpha1/postgresql-databases/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - xrd.yaml
  - composition.yaml
EOF

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
kubectl apply -k apis/v1alpha1/postgresql-databases
#
# If you see errors like:
# "failed to download openapi ... TLS handshake timeout / context deadline exceeded"
# your (mini)kube-apiserver is overloaded/flaky. Retry and/or skip client-side validation:
# kubectl apply --validate=false -k apis/v1alpha1/postgresql-databases

# Verify
kubectl get xrd
kubectl get composition
```

### 13.1 Local Composition Rendering (Optional, fastest feedback loop)

The Crossplane CLI `render` command validates your XRD + Composition locally and shows you the managed resources that would be created. This is a great way to catch patch/transform mistakes without waiting on a cluster reconciliation cycle.

```bash
# Create a local example XR (used only for rendering)
mkdir -p apis/v1alpha1/postgresql-databases/examples
cat <<'EOF' > apis/v1alpha1/postgresql-databases/examples/basic.yaml
apiVersion: database.example.io/v1alpha1
kind: XPostgreSQLDatabase
metadata:
  name: render-postgres-example
  namespace: default
spec:
  crossplane:
    compositionSelector:
      matchLabels:
        provider: azure
        type: standard
  parameters:
    location: westeurope
    resourceGroupName: crossplane-e2e-test-rg
    databaseName: appdb
    adminUsername: pgadmin
    adminPasswordSecretName: postgres-admin-password
    adminPasswordSecretKey: password
    postgresVersion: "16"
    skuName: B_Standard_B1ms
    storageMb: 32768
EOF

# Render what would be created (no cluster required)
crossplane render \
  apis/v1alpha1/postgresql-databases/xrd.yaml \
  apis/v1alpha1/postgresql-databases/composition.yaml \
  apis/v1alpha1/postgresql-databases/examples/basic.yaml \
  --include-function-results \
  > rendered-output.yaml

# Inspect output
ls -la rendered-output.yaml
```

### 14. Create Example E2E Test

```bash
# Create test suite configuration (so you can run `kubectl kuttl test --config tests/e2e/kuttl-test.yaml`)
cat <<'EOF' > tests/e2e/kuttl-test.yaml
apiVersion: kuttl.dev/v1beta1
kind: TestSuite
timeout: 2400
parallel: 1
startKIND: false
testDirs:
  - ./tests/e2e/storage-accounts
  - ./tests/e2e/virtual-networks
  - ./tests/e2e/postgresql-databases
  - ./tests/e2e/integrations
EOF

# Create a test case directory (KUTTL discovers test cases as subdirectories)
mkdir -p tests/e2e/postgresql-databases/basic

# IMPORTANT:
# KUTTL only executes files that start with a numeric step prefix (e.g. `00-...yaml`).
# Files without the prefix are ignored by default.

# Create test case - Setup
cat <<'EOF' > tests/e2e/postgresql-databases/basic/00-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-admin-password
  namespace: default
type: Opaque
stringData:
  # Demo-only password for e2e tests.
  # Azure PostgreSQL Flexible Server enforces password complexity requirements.
  password: "P@ssw0rd1234!"
EOF

cat <<'EOF' > tests/e2e/postgresql-databases/basic/00-xr-postgres.yaml
apiVersion: database.example.io/v1alpha1
kind: XPostgreSQLDatabase
metadata:
  name: test-postgres-e2e-001
  namespace: default
spec:
  crossplane:
    compositionSelector:
      matchLabels:
        provider: azure
        type: standard
  parameters:
    location: westeurope
    resourceGroupName: crossplane-e2e-test-rg
    databaseName: appdb
    adminUsername: pgadmin
    adminPasswordSecretName: postgres-admin-password
    adminPasswordSecretKey: password
    postgresVersion: "16"
    skuName: B_Standard_B1ms
    storageMb: 32768
EOF

# Create test case - Assert XR is created
cat <<'EOF' > tests/e2e/postgresql-databases/basic/00-assert.yaml
apiVersion: kuttl.dev/v1beta1
kind: TestAssert
timeout: 2400
commands:
- script: |
    # Wait until the XR reconciles successfully.
    kubectl wait -n default xpostgresqldatabase test-postgres-e2e-001 --for=condition=Synced --timeout=2400s
    kubectl wait -n default xpostgresqldatabase test-postgres-e2e-001 --for=condition=Ready --timeout=2400s
EOF

# Create test case - Verify Managed Resources
cat <<'EOF' > tests/e2e/postgresql-databases/basic/01-assert-postgres.yaml
apiVersion: kuttl.dev/v1beta1
kind: TestAssert
timeout: 2400
commands:
- script: |
    # Wait for the composed managed resources to become Ready.
    kubectl wait -n default resourcegroups.azure.m.upbound.io \
      -l crossplane.io/composite=test-postgres-e2e-001 \
      --for=condition=Ready --timeout=2400s

    kubectl wait -n default flexibleservers.dbforpostgresql.azure.m.upbound.io \
      -l crossplane.io/composite=test-postgres-e2e-001 \
      --for=condition=Ready --timeout=2400s

    kubectl wait -n default flexibleserverdatabases.dbforpostgresql.azure.m.upbound.io \
      -l crossplane.io/composite=test-postgres-e2e-001 \
      --for=condition=Ready --timeout=2400s
EOF

# Create test case - Verify with Azure CLI
cat <<'EOF' > tests/e2e/postgresql-databases/basic/01-verify-azure.yaml
apiVersion: kuttl.dev/v1beta1
kind: TestAssert
commands:
- script: |
    SERVER_NAME=$(kubectl get -n default xpostgresqldatabase test-postgres-e2e-001 \
      -o jsonpath='{.status.serverName}')

    DB_NAME=$(kubectl get -n default xpostgresqldatabase test-postgres-e2e-001 \
      -o jsonpath='{.status.databaseName}')

    # Verify the server exists in Azure
    az postgres flexible-server show \
      --resource-group crossplane-e2e-test-rg \
      --name "$SERVER_NAME" \
      --output none

    # Verify the database exists in Azure
    az postgres flexible-server db show \
      --resource-group crossplane-e2e-test-rg \
      --server-name "$SERVER_NAME" \
      --database-name "$DB_NAME" \
      --output none

    exit $?
EOF

# Create test case - Cleanup
cat <<'EOF' > tests/e2e/postgresql-databases/basic/02-delete.yaml
apiVersion: database.example.io/v1alpha1
kind: XPostgreSQLDatabase
metadata:
  name: test-postgres-e2e-001
  namespace: default
$patch: delete
EOF

# Create test case - Assert cleanup completed
cat <<'EOF' > tests/e2e/postgresql-databases/basic/02-assert.yaml
apiVersion: kuttl.dev/v1beta1
kind: TestAssert
commands:
- script: |
    # Verify XR is deleted
    ! kubectl get -n default xpostgresqldatabase test-postgres-e2e-001 2>/dev/null
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
  --timeout 2400 \
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
kubectl delete xpostgresqldatabase -A --all --ignore-not-found=true
# Optional: if you still have the legacy storage-account example installed
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
    name: xpostgresqldatabases.database.example.io
EOF
```

## Verification Steps

### 0. Pre-Test Health Validation (Recommended)

Before running any tests (KUTTL/Uptest), it helps to confirm the entire Crossplane stack is stable:

```bash
cat <<'EOF' > scripts/check-crossplane-health.sh
#!/bin/bash
set -euo pipefail

CP_NS="${CROSSPLANE_NAMESPACE:-crossplane-system}"

echo "=== Checking Crossplane Core (namespace: ${CP_NS}) ==="
kubectl get deployment -n "${CP_NS}"
kubectl get pods -n "${CP_NS}"

echo -e "\n=== Checking Providers ==="
kubectl get providers.pkg.crossplane.io || true
kubectl get providerrevisions.pkg.crossplane.io || true

echo -e "\n=== Checking Functions ==="
kubectl get functions.pkg.crossplane.io || true

echo -e "\n=== Checking Webhook Configurations ==="
kubectl get validatingwebhookconfigurations | grep crossplane || true
kubectl get mutatingwebhookconfigurations | grep crossplane || true

echo -e "\n=== Checking Provider Health (Upbound Azure family) ==="
kubectl wait --for=condition=healthy provider.pkg.crossplane.io/provider-family-azure \
  --timeout=600s || true

echo -e "\n=== Checking Function Health ==="
kubectl wait --for=condition=healthy function.pkg.crossplane.io/function-patch-and-transform \
  --timeout=600s || true
kubectl wait --for=condition=healthy function.pkg.crossplane.io/function-auto-ready \
  --timeout=600s || true

echo -e "\n✅ Crossplane health check complete!"
EOF

chmod +x scripts/check-crossplane-health.sh
./scripts/check-crossplane-health.sh
```

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

==== WE ARE HERE ON WINDOWS AND MAC ====

### 2. Run Your First E2E Test

```bash
# Run the PostgreSQL database test
# Use the suite config so you get the intended timeout settings:
kubectl kuttl test --config tests/e2e/kuttl-test.yaml tests/e2e/postgresql-databases/

# Note: on Windows use 'kuttl' instead of 'kubectl kuttl'.

# Or run all suites using the config file
kubectl kuttl test --config tests/e2e/kuttl-test.yaml

# Watch the test progress in another terminal
watch kubectl get -n default xpostgresqldatabase,resourcegroups.azure.m.upbound.io,flexibleservers.dbforpostgresql.azure.m.upbound.io,flexibleserverdatabases.dbforpostgresql.azure.m.upbound.io
```

### 3. Monitor with Azure CLI

```bash
# Watch Azure resources being created
watch az resource list \
  --resource-group crossplane-e2e-test-rg \
  --output table
```

### 4. Visualize with Crossview (Optional)

Crossview is a UI dashboard for Crossplane that can help you quickly see the relationships between:
- **XRDs** (e.g. `xpostgresqldatabases.database.example.io`)
- **Compositions** (e.g. `xpostgresqldatabases.database.example.io`)
- **XRs** (e.g. `xpostgresqldatabase default/test-postgres-e2e-001`)
- **Managed resources** (e.g. `resourcegroups.azure.m.upbound.io`, `flexibleservers.dbforpostgresql.azure.m.upbound.io`, `flexibleserverdatabases.dbforpostgresql.azure.m.upbound.io`)

This section uses the **same PostgreSQL example** used throughout this guide:
- **XRD/Composition source**: `apis/v1alpha1/postgresql-databases/`
- **XRD name**: `xpostgresqldatabases.database.example.io`
- **Composition name**: `xpostgresqldatabases.database.example.io`
- **Example XR**: `xpostgresqldatabase default/test-postgres-e2e-001` (from `tests/e2e/postgresql-databases/basic/`)

Install Crossview into your Minikube cluster (recommended upstream install method is Helm):

```bash
# Install Helm (macOS)
brew install helm

# Install Crossview (creates its own namespace + Postgres)
# Repo-based install is typically the most reliable:
helm repo add crossview https://corpobit.github.io/crossview
helm repo update

helm install crossview crossview/crossview \
  --namespace crossview \
  --create-namespace \
  --set secrets.dbPassword=change-me \
  --set secrets.sessionSecret="$(openssl rand -base64 32)" \
  --set service.type=NodePort \
  --version 3.4.0

# Optional (recommended if Postgres "latest" is flaky on Minikube): pin Postgres to a stable major version
# by adding:
#   --set database.image.tag=16

# If you prefer installing from the OCI chart instead, try:
# helm install crossview oci://ghcr.io/corpobit/crossview-chart \
#   --namespace crossview \
#   --create-namespace \
#   --set secrets.dbPassword=change-me \
#   --set secrets.sessionSecret="$(openssl rand -base64 32)" \
#   --set service.type=NodePort \
#   --version 3.4.0

# Wait until Crossview is ready (first install can take a few minutes on Minikube)
kubectl wait -n crossview --for=condition=Available deploy/crossview-postgres --timeout=600s || true
kubectl wait -n crossview --for=condition=Available deploy/crossview --timeout=600s

# Open the UI (Minikube will launch a browser tab)
minikube service -n crossview crossview-service
```

Optional: validate your XRD ↔ Composition matching via CLI before using the UI:

```bash
chmod +x manuscript/setup/crossview/*.sh

# List all Compositions that match this XRD (apiVersion + kind)
./manuscript/setup/crossview/validate-xrd-composition.sh xpostgresqldatabases.database.example.io

# Or validate a specific Composition explicitly
./manuscript/setup/crossview/validate-xrd-composition.sh \
  xpostgresqldatabases.database.example.io \
  xpostgresqldatabases.database.example.io
```

If you see either of these errors:
- `permission denied`: rerun `chmod +x manuscript/setup/crossview/*.sh`
- `env: bash\r: No such file or directory`: your scripts have Windows (CRLF) line endings. Convert them:

```bash
perl -pi -e 's/\r$//' manuscript/setup/crossview/*.sh
```

If the wait times out, quickly identify the blocker (image pull / PVC / DB not ready / crashloop):

```bash
kubectl get pods -n crossview -o wide
kubectl get pvc -n crossview
kubectl describe deploy/crossview -n crossview
kubectl describe deploy/crossview-postgres -n crossview
kubectl get events -n crossview --sort-by=.lastTimestamp | tail -n 30

# Useful logs (pick the one that exists)
kubectl logs -n crossview deploy/crossview --tail=200
kubectl logs -n crossview deploy/crossview-postgres --tail=200
```

Once Crossview is open, look for these resources:

```bash
kubectl get xrd xpostgresqldatabases.database.example.io
kubectl get composition xpostgresqldatabases.database.example.io
kubectl get -n default xpostgresqldatabase test-postgres-e2e-001
kubectl get -n default resourcegroups.azure.m.upbound.io,flexibleservers.dbforpostgresql.azure.m.upbound.io,flexibleserverdatabases.dbforpostgresql.azure.m.upbound.io -o wide
```

If `minikube service` is flaky on your machine, port-forward works everywhere:

```bash
kubectl port-forward -n crossview deploy/crossview 3001:3001
```

Now open `http://localhost:3001`.

If you see `zsh: command not found: #`, it means your shell is treating `#` lines as commands.
Just run the command lines (no `# ...` comment lines) and open the URL in your browser.

### 5. Monitor GitOps with Headlamp + Flux Plugin (Optional)

Headlamp is a modern Kubernetes dashboard. With the Flux plugin enabled, it becomes a handy UI for day-to-day GitOps troubleshooting (Kustomizations, HelmReleases, Sources, reconciliation status).

Prerequisites:
- Flux installed in the cluster (Step 10)

#### Install Headlamp (managed by Flux controllers)

This installs Headlamp via `HelmRepository` + `HelmRelease` resources (reconciled by Flux):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: headlamp
  namespace: flux-system
spec:
  interval: 1h
  url: https://headlamp-k8s.github.io/headlamp/
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: headlamp
  namespace: headlamp
spec:
  interval: 10m
  chart:
    spec:
      chart: headlamp
      sourceRef:
        kind: HelmRepository
        name: headlamp
        namespace: flux-system
  install:
    createNamespace: true
  values:
    # Plugin support: install the Flux plugin via an initContainer.
    # Pin the image tag if you want repeatable installs.
    initContainers:
      - name: flux-plugin
        image: ghcr.io/headlamp-k8s/headlamp-plugin-flux:latest
        command: ["/bin/sh", "-c"]
        args:
          - "mkdir -p /headlamp/plugins && cp -r /plugins/* /headlamp/plugins/"
        volumeMounts:
          - mountPath: /headlamp/plugins
            name: headlamp-plugins
    volumes:
      - name: headlamp-plugins
        emptyDir: {}
    volumeMounts:
      - mountPath: /headlamp/plugins
        name: headlamp-plugins
EOF

# Wait for it to roll out
kubectl rollout status -n headlamp deploy/headlamp --timeout=600s
```

#### Access Headlamp

```bash
kubectl port-forward -n headlamp svc/headlamp 4466:80

# Open browser
open http://localhost:4466
```

In the Headlamp sidebar, open the **Flux** section to inspect Sources/Kustomizations/HelmReleases and see reconciliation status and events.

## Troubleshooting

### Common Issues

**1. Provider not becoming healthy**

```bash
# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider --tail=200

# Check provider config
kubectl describe providerconfig default
```

**2. XR not becoming ready**

```bash
# Check XR events
kubectl describe -n default xpostgresqldatabase test-postgres-e2e-001

# Check managed resource status
kubectl get managed

# Check Crossplane logs
kubectl logs -n crossplane-system deployment/crossplane -f
```

**3. PostgreSQL server name constraints (Azure)**

Azure PostgreSQL Flexible Server names must be DNS-safe (lowercase letters, numbers, and hyphens).
This guide derives the Azure server name from the XR name (e.g. `test-postgres-e2e-001`).

If your `FlexibleServer` managed resource stays `READY=False` with an Azure error indicating the name is invalid or already taken,
delete the XR and re-create it with a different name:

```bash
kubectl delete -n default xpostgresqldatabase test-postgres-e2e-001

cat <<'EOF' | kubectl apply -f -
apiVersion: database.example.io/v1alpha1
kind: XPostgreSQLDatabase
metadata:
  name: test-postgres-e2e-002
  namespace: default
spec:
  crossplane:
    compositionSelector:
      matchLabels:
        provider: azure
        type: standard
  parameters:
    location: westeurope
    resourceGroupName: crossplane-e2e-test-rg
    databaseName: appdb
EOF
```

**4. Azure subscription not registered for Microsoft.DBforPostgreSQL**

If the `FlexibleServer` managed resource shows an error like:
`MissingSubscriptionRegistration ... The subscription is not registered to use namespace 'Microsoft.DBforPostgreSQL'`,
you need to register the Azure Resource Provider in your subscription (one-time per subscription):

```bash
# Make sure you're logged into the correct tenant/subscription
set -a; source .azure-credentials; set +a
az login --tenant "$AZURE_TENANT_ID"
az account set --subscription "$SUBSCRIPTION_ID"

# Register Azure PostgreSQL Resource Provider
az provider register --namespace Microsoft.DBforPostgreSQL

# Wait until it's registered
az provider show --namespace Microsoft.DBforPostgreSQL --query "registrationState" -o tsv
```

Wait until the state is `Registered`, then re-check:

```bash
kubectl get -n default flexibleservers.dbforpostgresql.azure.m.upbound.io -l crossplane.io/composite=test-postgres-e2e-001
kubectl get -n default xpostgresqldatabase test-postgres-e2e-001
```

Crossplane will retry reconciliation automatically once the provider is registered.

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
kubectl delete xpostgresqldatabase -A --all
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
