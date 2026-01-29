#!/bin/bash

# Crossview Installation Script for Minikube

# This script installs Crossview for visualizing Crossplane resources

set -e

echo “=== Crossview Installation for Crossplane Validation ===”
echo “”

# Colors for output

RED=’\033[0;31m’
GREEN=’\033[0;32m’
YELLOW=’\033[1;33m’
NC=’\033[0m’ # No Color

# Check if kubectl is available

if ! command -v kubectl &> /dev/null; then
echo -e “${RED}Error: kubectl is not installed${NC}”
exit 1
fi

# Check if minikube is running

if ! kubectl cluster-info &> /dev/null; then
echo -e “${RED}Error: Cannot connect to Kubernetes cluster. Is minikube running?${NC}”
exit 1
fi

echo -e “${GREEN}✓ Kubernetes cluster is accessible${NC}”

# Check if Crossplane is installed

if ! kubectl get namespace crossplane-system &> /dev/null; then
echo -e “${YELLOW}Warning: crossplane-system namespace not found${NC}”
echo “Please ensure Crossplane is installed before proceeding”
read -p “Continue anyway? (y/n) “ -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
exit 1
fi
fi

echo “”
echo “Step 1: Creating crossview namespace…”
kubectl create namespace crossview –dry-run=client -o yaml | kubectl apply -f -

## echo “”
echo “Step 2: Creating ServiceAccount and RBAC permissions…”
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
name: crossview
namespace: crossview

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
name: crossview-reader
rules:

- apiGroups: [”*”]
  resources: [”*”]
  verbs: [“get”, “list”, “watch”]

-----

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
name: crossview-reader-binding
roleRef:
apiGroup: rbac.authorization.k8s.io
kind: ClusterRole
name: crossview-reader
subjects:

- kind: ServiceAccount
  name: crossview
  namespace: crossview
  EOF

## echo “”
echo “Step 3: Deploying Crossview application…”
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
name: crossview
namespace: crossview
labels:
app: crossview
spec:
replicas: 1
selector:
matchLabels:
app: crossview
template:
metadata:
labels:
app: crossview
spec:
serviceAccountName: crossview
containers:
- name: crossview
image: smoeidheidari/crossview:latest
ports:
- containerPort: 3000
name: http
env:
- name: PORT
value: “3000”
resources:
requests:
memory: “256Mi”
cpu: “100m”
limits:
memory: “512Mi”
cpu: “500m”
livenessProbe:
httpGet:
path: /
port: 3000
initialDelaySeconds: 30
periodSeconds: 10
readinessProbe:
httpGet:
path: /
port: 3000
initialDelaySeconds: 5
periodSeconds: 5

apiVersion: v1
kind: Service
metadata:
name: crossview
namespace: crossview
spec:
type: NodePort
selector:
app: crossview
ports:

- port: 3000
  targetPort: 3000
  nodePort: 30080
  protocol: TCP
  name: http
  EOF

echo “”
echo “Step 4: Waiting for Crossview pod to be ready…”
kubectl wait –for=condition=ready pod -l app=crossview -n crossview –timeout=120s

echo “”
echo -e “${GREEN}✓ Crossview installed successfully!${NC}”
echo “”
echo “=== Access Crossview ===”
echo “”
echo “Option 1: Using minikube service (recommended):”
echo -e “  ${YELLOW}minikube service crossview -n crossview${NC}”
echo “”
echo “Option 2: Using port-forward:”
echo -e “  ${YELLOW}kubectl port-forward -n crossview svc/crossview 8080:3000${NC}”
echo “  Then open: http://localhost:8080”
echo “”
echo “Option 3: Using NodePort (if minikube IP is accessible):”
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo “MINIKUBE_IP”)
echo “  http://${MINIKUBE_IP}:30080”
echo “”

# Offer to open Crossview automatically

read -p “Would you like to open Crossview now? (y/n) “ -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
echo “Opening Crossview…”
minikube service crossview -n crossview
fi

echo “”
echo -e “${GREEN}Installation complete!${NC}”
echo “Check the crossview-setup-guide.md for usage instructions.”
