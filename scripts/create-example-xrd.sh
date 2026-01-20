#!/bin/bash

# 

# Create Example XRD and Composition

# This script creates a sample XStorageAccount XRD and Composition for testing

# 

# Usage: ./scripts/create-example-xrd.sh

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

echo “========================================================================”
echo “   Creating Example XRD and Composition”
echo “========================================================================”
echo “”

# Create directories if they don’t exist

log_info “Creating config directories…”
mkdir -p config/{xrds,compositions}
log_success “Directories created”

# 

# Create XRD for Storage Account

# 

echo “”
log_info “Creating XStorageAccount XRD…”

cat > config/xrds/xstorage-account.yaml <<‘EOF’
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
name: xstorageaccounts.storage.example.io
spec:
group: storage.example.io
names:
kind: XStorageAccount
plural: xstorageaccounts
claimNames:
kind: StorageAccount
plural: storageaccounts
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
  description: Storage account tier (Standard or Premium)
  enum: [Standard, Premium]
  default: Standard
  replicationType:
  type: string
  description: Replication type
  enum: [LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS]
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
  description: The name of the created storage account
  primaryEndpoint:
  type: string
  description: Primary blob endpoint URL
  resourceGroupName:
  type: string
  description: The resource group containing the storage account
  EOF

log_success “XRD created: config/xrds/xstorage-account.yaml”

# 

# Create Composition for Storage Account

# 

echo “”
log_info “Creating Storage Account Composition…”

cat > config/compositions/storage-account.yaml <<‘EOF’
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
name: xstorageaccounts.storage.example.io
labels:
provider: azure
type: standard
environment: dev
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
  
  # Resource Group
  - name: resourcegroup
    base:
    apiVersion: azure.upbound.io/v1beta1
    kind: ResourceGroup
    spec:
    forProvider:
    location: westeurope
    tags:
    managedBy: crossplane
    environment: dev
    patches:
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.location
      toFieldPath: spec.forProvider.location
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.resourceGroupName
      toFieldPath: metadata.name
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.tags
      toFieldPath: spec.forProvider.tags
      policy:
      mergeOptions:
      keepMapValues: true
    - type: ToCompositeFieldPath
      fromFieldPath: metadata.name
      toFieldPath: status.resourceGroupName
  
  # Storage Account
  - name: storageaccount
    base:
    apiVersion: storage.azure.upbound.io/v1beta2
    kind: Account
    metadata:
    labels:
    testing.upbound.io/example-name: storageaccount
    spec:
    forProvider:
    accountReplicationType: LRS
    accountTier: Standard
    location: westeurope
    resourceGroupNameSelector:
    matchControllerRef: true
    tags:
    managedBy: crossplane
    environment: dev
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
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.tags
      toFieldPath: spec.forProvider.tags
      policy:
      mergeOptions:
      keepMapValues: true
    - type: ToCompositeFieldPath
      fromFieldPath: metadata.name
      toFieldPath: status.storageAccountName
    - type: ToCompositeFieldPath
      fromFieldPath: status.atProvider.primaryBlobEndpoint
      toFieldPath: status.primaryEndpoint
      readinessChecks:
    - type: MatchString
      fieldPath: status.atProvider.provisioningState
      matchString: “Succeeded”
- step: auto-ready
  functionRef:
  name: function-auto-ready
  EOF

log_success “Composition created: config/compositions/storage-account.yaml”

# 

# Apply to cluster

# 

echo “”
log_info “Applying XRD and Composition to cluster…”

# Check if kubectl is configured

if ! kubectl cluster-info >/dev/null 2>&1; then
log_error “Cannot connect to Kubernetes cluster”
exit 1
fi

# Apply XRD

log_info “Applying XRD…”
kubectl apply -f config/xrds/xstorage-account.yaml

# Wait for XRD to be established

log_info “Waiting for XRD to be established…”
kubectl wait –for=condition=established xrd/xstorageaccounts.storage.example.io –timeout=60s

log_success “XRD is established”

# Apply Composition

log_info “Applying Composition…”
kubectl apply -f config/compositions/storage-account.yaml

log_success “Composition applied”

# 

# Verify

# 

echo “”
log_info “Verifying installation…”

echo “”
echo “XRDs:”
kubectl get xrd

echo “”
echo “Compositions:”
kubectl get composition

echo “”
echo “========================================================================”
log_success “Example XRD and Composition created successfully!”
echo “========================================================================”
echo “”
log_info “Next steps:”
echo “”
echo “1. Create a test XR instance:”
echo “   cat <<EOFXR | kubectl apply -f -”
echo “   apiVersion: storage.example.io/v1alpha1”
echo “   kind: XStorageAccount”
echo “   metadata:”
echo “     name: test-storage-001”
echo “   spec:”
echo “     parameters:”
echo “       location: westeurope”
echo “       accountTier: Standard”
echo “       replicationType: LRS”
echo “       resourceGroupName: crossplane-e2e-test-rg”
echo “       tags:”
echo “         environment: test”
echo “         purpose: demo”
echo “   EOFXR”
echo “”
echo “2. Watch the XR being created:”
echo “   kubectl get xstorageaccount -w”
echo “”
echo “3. Check the managed resources:”
echo “   kubectl get managed”
echo “”
echo “4. Verify in Azure:”
echo “   az storage account list –resource-group crossplane-e2e-test-rg”
echo “”
echo “5. Delete the test XR:”
echo “   kubectl delete xstorageaccount test-storage-001”
echo “”
