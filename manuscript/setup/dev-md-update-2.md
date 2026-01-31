# Development Environment Setup for Crossplane E2E Testing

## Setting Up Your Testing Environment

First, we need a Kubernetes cluster to test our Crossplane compositions. You have two options depending on your needs and available resources:

### Option 1: Azure Kubernetes Service (AKS) - Cloud-Based Testing

**Use this for:** Production-like testing with real Azure resources and integration testing.

```bash
# Set up your environment variables
export RESOURCE_GROUP="crossplane-e2e-rg"
export LOCATION="westeurope"
export CLUSTER_NAME="crossplane-e2e-aks"
export CROSSPLANE_VERSION="2.1.0"

# Log into Azure
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create AKS cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count 3 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --tier free

# Connect to the cluster
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME

# Verify connection
kubectl get nodes
```

**Expected output:**
```
NAME                                STATUS   ROLES   AGE   VERSION
aks-nodepool1-xxxxx-vmss000000     Ready    agent   2m    v1.28.x
aks-nodepool1-xxxxx-vmss000001     Ready    agent   2m    v1.28.x
aks-nodepool1-xxxxx-vmss000002     Ready    agent   2m    v1.28.x
```

> **⚠️ Important:** AKS clusters incur costs even when idle. Remember to delete resources when done testing!
>
> ```bash
> # Cleanup when done
> az group delete --name $RESOURCE_GROUP --yes --no-wait
> ```

### Option 2: Local Development Cluster - Free Testing

**Use this for:** Local testing, development iteration, and composition rendering without cloud costs.

Choose either Minikube or Kind based on your preference:

#### Using Minikube

```bash
# Start Minikube cluster with adequate resources
minikube start \
  --cpus=4 \
  --memory=8192 \
  --driver=docker

# Verify connection
kubectl get nodes
```

**Expected output:**
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   1m    v1.28.x
```

#### Using Kind (Kubernetes in Docker)

```bash
# Create Kind cluster with multiple nodes
cat <<EOF | kind create cluster --name crossplane-e2e --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Verify connection
kubectl get nodes
```

**Expected output:**
```
NAME                          STATUS   ROLES           AGE   VERSION
crossplane-e2e-control-plane  Ready    control-plane   1m    v1.28.x
crossplane-e2e-worker         Ready    <none>          1m    v1.28.x
crossplane-e2e-worker2        Ready    <none>          1m    v1.28.x
```

> **💡 Note:** Local clusters are great for development and testing composition logic, but they won't create real cloud resources. For full integration testing with actual Azure resources, use the AKS option.
>
> **Cleanup for local clusters:**
> ```bash
> # For Minikube
> minikube delete
> 
> # For Kind
> kind delete cluster --name crossplane-e2e
> ```

---

## Installing Crossplane

Regardless of which cluster option you chose above, the Crossplane installation process is identical:

```bash
# Add the Crossplane Helm repository
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane v2
helm install crossplane \
  --namespace crossplane-system \
  --create-namespace \
  crossplane-stable/crossplane \
  --version ${CROSSPLANE_VERSION:-2.1.0} \
  --wait

# Check that Crossplane is running
kubectl get pods -n crossplane-system
```

**Expected output:**
```
NAME                                       READY   STATUS    RESTARTS   AGE
crossplane-xxx-yyy                         1/1     Running   0          1m
crossplane-rbac-manager-xxx-yyy            1/1     Running   0          1m
```

You can also verify the Crossplane installation:

```bash
# Check Crossplane version
kubectl get deployment crossplane -n crossplane-system -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check if Crossplane is healthy
kubectl get deployment crossplane -n crossplane-system
```

---

## Quick Comparison: AKS vs Local Clusters

| Feature | AKS | Minikube/Kind |
|---------|-----|---------------|
| **Cost** | 💰 Pay per use (~$100-200/month for basic cluster) | ✅ Free |
| **Setup Time** | ~5-10 minutes | ~2 minutes |
| **Real Azure Resources** | ✅ Yes - creates actual cloud infrastructure | ❌ No - mock/simulated only |
| **Internet Required** | ✅ Yes - constant connection needed | ⚠️ Only for pulling images initially |
| **Best For** | Integration testing, staging, production validation | Development, composition rendering, unit testing |
| **Cleanup Required** | ⚠️ **Critical!** Must delete to avoid charges | ✅ Simple - just delete the cluster |
| **Multi-tenancy** | ✅ Full RBAC and namespace isolation | ⚠️ Limited - single-user development |
| **Persistence** | ✅ Survives machine reboots | ❌ Must be recreated |
| **Resource Limits** | ✅ Scales with Azure quotas | ⚠️ Limited by local machine resources |

### Decision Guide

**Choose AKS when you need to:**
- Test actual Azure resource creation (storage accounts, databases, networks)
- Validate end-to-end integration with Azure services
- Test production-like scenarios
- Share a test environment with team members
- Test with real authentication and authorization flows

**Choose Minikube/Kind when you need to:**
- Iterate quickly on composition logic
- Test rendering and validation of Crossplane resources
- Develop without incurring cloud costs
- Work offline (after initial setup)
- Test locally before pushing to cloud environments
- Learn Crossplane basics and experiment safely

---

## Next Steps

Now that you have a cluster ready and Crossplane installed, you can proceed with:

1. **Installing Azure Provider** - Configure Crossplane to manage Azure resources
2. **Creating Compositions** - Define your infrastructure templates
3. **Writing E2E Tests** - Validate your compositions work as expected

Continue to the next section in the manuscript to set up the Azure provider and start testing!