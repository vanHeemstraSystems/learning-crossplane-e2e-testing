# Updates Required for dev.md - Crossplane v2 with Uptest

This document contains all changes needed for your `manuscript/setup/dev.md` file to align with Crossplane v2 and integrate Uptest for better testing.

**Note:** All directory paths use `apis/v1alpha1` (not `apis/1alpha1`)

---

## 1. CRITICAL CORRECTIONS - Crossplane v2

### Update XRD API Version
**Location:** Anywhere you show XRD examples

**OLD (Incorrect):**
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
```

**NEW (Correct for v2):**
```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
```

### Update XRD Scope
**Location:** All XRD examples

**ADD:** Explicit scope declaration (Namespaced is default in v2)
```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: xstorageaccounts.storage.atlas.io
spec:
  scope: Namespaced  # ✅ ADD THIS
  group: storage.atlas.io
  names:
    kind: XStorageAccount
    plural: xstorageaccounts
```

**REMOVE:** Any `claimNames` section
```yaml
# ❌ DELETE THIS ENTIRE SECTION
spec:
  claimNames:
    kind: StorageAccountClaim
    plural: storageaccountclaims
```

### Update Composite Resource Examples
**Location:** All examples showing how to use XRs

**OLD (v1 style):**
```yaml
apiVersion: storage.atlas.io/v1alpha1
kind: XStorageAccount
metadata:
  name: my-storage
  # No namespace - cluster-scoped
spec:
  parameters:
    accountType: Standard_LRS
```

**NEW (v2 style - Namespaced):**
```yaml
apiVersion: storage.atlas.io/v1alpha1
kind: XStorageAccount
metadata:
  name: my-storage
  namespace: default  # ✅ ADD namespace
spec:
  parameters:
    accountType: Standard_LRS
    location: westeurope
```

### Update Composition API Version
**Location:** All Composition examples

**KEEP:** Composition still uses v1 API
```yaml
apiVersion: apiextensions.crossplane.io/v1  # ✅ Correct - v1 for Composition
kind: Composition
metadata:
  name: xstorageaccounts.azure.storage.atlas.io
spec:
  mode: Pipeline  # ✅ v2 feature
  compositeTypeRef:
    apiVersion: storage.atlas.io/v1alpha1
    kind: XStorageAccount
```

---

## 2. ADD SECTION: Verify Webhook Stability

**Location:** Add AFTER Crossplane installation section, BEFORE provider installation

```markdown
### Verify Webhook Stability

Crossplane v2 uses webhooks extensively. Patch webhook timeouts to prevent handshake failures:

```bash
# Wait for Crossplane to be fully ready
kubectl wait --for=condition=available deployment/crossplane \
  -n crossplane-system --timeout=300s

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
```

---

## 3. ADD SECTION: Install Uptest

**Location:** Add AFTER Kuttl installation

```markdown
## Install Uptest

Uptest is specifically designed for testing Crossplane providers and managed resources.

### macOS Installation

```bash
brew install uptest
```

### Linux/Other Installation

```bash
go install github.com/crossplane/uptest@latest
```

### Verify Installation

```bash
uptest --version
```

### Why Uptest?

- **Provider validation**: Tests that managed resources actually create cloud resources
- **Built-in retry logic**: Designed for slow cloud API operations
- **Lifecycle testing**: Automatically tests create → ready → update → delete
- **Better timeout handling**: Default timeouts suited for cloud resources (300s+)
- **Less configuration**: Auto-generates test cases from provider examples
```

---

## 4. ADD SECTION: Pre-Test Health Validation

**Location:** Add BEFORE any testing sections

```markdown
## Pre-Test Health Validation

Before running any tests, verify the entire Crossplane stack is healthy:

```bash
# Create health check script
cat > check-provider-health.sh <<'EOF'
#!/bin/bash
set -e

echo "=== Checking Crossplane Core ==="
kubectl get deployment -n crossplane-system
kubectl get pods -n crossplane-system

echo -e "\n=== Checking Provider Installation ==="
kubectl get providers
kubectl get providerrevisions

echo -e "\n=== Checking Webhook Configurations ==="
kubectl get validatingwebhookconfigurations | grep crossplane || true
kubectl get mutatingwebhookconfigurations | grep crossplane || true

echo -e "\n=== Checking Provider Pods ==="
kubectl get pods -n crossplane-system -l pkg.crossplane.io/provider=provider-azure

echo -e "\n=== Checking Provider Logs (last 50 lines) ==="
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure --tail=50 || true

echo -e "\n=== Waiting for Provider to be Healthy ==="
kubectl wait --for=condition=healthy provider.pkg.crossplane.io/provider-azure \
  --timeout=600s

echo -e "\n=== All Components Stable - Waiting 20s ==="
sleep 20

echo "✅ Health check complete!"
EOF

chmod +x check-provider-health.sh

# Run the health check
./check-provider-health.sh
```
```

---

## 5. UPDATE SECTION: Testing Strategy

**Location:** Replace or add comprehensive testing section

```markdown
## Testing Strategy

This project uses a layered testing approach:

### Test Layers

0. **Composition Rendering** (`crossplane render`) - CLI
   - Validates composition output locally without a cluster
   - Catches composition errors before deployment
   - Instant feedback (< 1 second)
   - No Kubernetes cluster required

1. **Provider Validation** (`tests/provider/`) - Uptest
   - Validates individual managed resources
   - Tests actual Azure resource creation
   - Fast feedback (2-5 minutes)
   - **Crossview**: Visualize provider installations and health
   - **Headlamp**: Monitor provider pods and health status
   
2. **API Unit Tests** (`apis/v1alpha1/*/tests/unit/`) - Kuttl
   - Tests composition logic without cloud resources
   - Validates field mapping and patching
   - Very fast (< 30 seconds)
   - **Crossview**: Inspect XRD schemas and compositions
   
3. **API Integration Tests** (`apis/v1alpha1/*/tests/integration/`) - Kuttl
   - Tests single API with real Azure resources
   - Validates full lifecycle (create/update/delete)
   - Medium speed (5-10 minutes)
   - **Crossview**: Visualize XR → Managed Resource relationships
   
4. **Cross-API Integration** (`tests/integration/`) - Kuttl
   - Tests multiple APIs working together
   - Validates dependencies between resources
   - Slower (10-15 minutes)
   - **Crossview**: View resource graphs across multiple XRs
   
5. **End-to-End Platform** (`tests/e2e/`) - Kuttl
   - Tests complete platform deployments
   - Business workflow validation
   - Slowest (20-30 minutes)
   - **Crossview**: Monitor complete platform health and relationships

6. **GitOps Deployment** (Flux) - Continuous
   - Continuously reconciles Git state to cluster
   - Automated deployment and drift detection
   - Self-healing infrastructure
   - **Headlamp with Flux Plugin**: Visualize GitOps workflows
   - **Flux CLI**: Monitor reconciliation status

### Testing Pyramid

```
                    Layer 6: GitOps (Flux)
                  (Continuous Reconciliation)
                ⏱️  Continuous | 🔺 Platform-wide
               /   Headlamp: Flux Workflow Viz
              /                              \
          Layer 5: E2E Platform
        (Complete Deployments)
      ⏱️  20-30 min | 🔺 Few tests
     /     Crossview: Full Platform View
    /                              \
  Layer 4: Cross-API Integration
 (Multiple APIs Together)
⏱️  10-15 min | 🔺 Some tests
/   Crossview: Resource Graphs       \
    Layer 3: API Integration Tests
   (Single API + Real Azure)
  ⏱️  5-10 min | 🔺 Moderate tests
 /   Crossview: XR → MR Visualization  \
/                                    \
Layer 2: API Unit Tests
(Composition Logic)
⏱️  < 30 sec | 🔺 Many tests
\   Crossview: XRD/Composition Inspector  /
 \                                      /
  Layer 1: Provider Validation
   (Managed Resources)
    ⏱️  2-5 min | 🔺 Many tests
     \   Crossview & Headlamp: Provider Health  /
      \                            /
       Layer 0: Composition Render
        (Local Validation)
         ⏱️  < 1 sec | 🔺 Most tests

Legend:
🔺 = Number of tests (wider = more tests)
⏱️  = Speed (bottom = fastest)
Crossview = Visual dashboard for Crossplane resources
Headlamp = Kubernetes dashboard with Flux plugin
Flux = GitOps continuous deployment
```

### Development Workflow (with Crossview, Headlamp & Flux)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Write/Modify Composition                            │
│    apis/v1alpha1/storage-accounts/composition.yaml     │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Render Locally (Layer 0)                            │
│    crossplane render xrd.yaml composition.yaml         │
│    ✅ Instant feedback (<1 sec)                         │
│    ✅ No cluster needed                                 │
└──────────────────┬──────────────────────────────────────┘
                   │ If valid
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 3. Commit to Git Repository                            │
│    git add . && git commit -m "Update composition"     │
│    git push origin main                                │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Flux Syncs to Cluster (Layer 6)                     │
│    Flux watches Git, applies changes automatically     │
│    🔍 Headlamp Flux Plugin: Watch sync status           │
│    🔍 Crossview: Inspect applied XRD/Composition        │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 5. Unit Test (Layer 2)                                 │
│    kubectl kuttl test (unit/)                          │
│    ✅ Fast (<30 sec)                                    │
│    ✅ No cloud resources                                │
└──────────────────┬──────────────────────────────────────┘
                   │ If passing
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 6. Provider Validation (Layer 1)                       │
│    uptest run examples/                                │
│    ✅ Real managed resources (2-5 min)                  │
│    🔍 Use Crossview to verify provider health           │
│    🔍 Headlamp: Check provider pods                     │
└──────────────────┬──────────────────────────────────────┘
                   │ If passing
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 7. API Integration (Layer 3)                           │
│    kubectl kuttl test (integration/)                   │
│    ✅ Full lifecycle test (5-10 min)                    │
│    🔍 Crossview: Watch XR → MR relationships            │
└──────────────────┬──────────────────────────────────────┘
                   │ Before merge
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 8. Cross-API + E2E (Layers 4-5)                        │
│    CI/CD runs comprehensive tests                      │
│    ✅ Complete platform validation (30-45 min)          │
│    🔍 Crossview: Monitor full resource graph            │
│    🔍 Headlamp: Overall cluster health                  │
└─────────────────────────────────────────────────────────┘
```

### Cost vs Speed Trade-off

```
Layer | Speed    | Cost      | Cluster | Azure | Crossview | Use Case
------|----------|-----------|---------|-------|-----------|---------------------------
  0   | Instant  | Free      | No      | No    | No        | Dev iteration
  1   | Fast     | Low       | Yes     | Yes   | Yes       | Provider verification
  2   | V. Fast  | Free      | Yes     | No    | Yes       | Composition logic
  3   | Medium   | Medium    | Yes     | Yes   | Yes       | Single API validation
  4   | Slow     | High      | Yes     | Yes   | Yes       | Multi-API integration
  5   | V. Slow  | Highest   | Yes     | Yes   | Yes       | Platform validation

Crossview Benefits per Layer:
- Layer 1: Monitor provider installations, health status
- Layer 2: Inspect XRD schemas, view composition structure
- Layer 3: Visualize XR → Managed Resource relationships
- Layer 4: See resource graphs across multiple XRs
- Layer 5: Complete platform topology and health monitoring
```

### Running Tests

```bash
# Render composition locally (fastest - no cluster needed)
make render

# All tests in order
make test-all

# Individual layers
make test-provider          # Provider validation
make test-unit              # All API unit tests
make test-api-integration   # All API integration tests
make test-cross-integration # Cross-API tests
make test-e2e              # Platform E2E tests

# Specific API tests
make test-storage-accounts-unit
make test-storage-accounts-integration
```
```

---

## 5. ADD SECTION: Install and Use Crossview

**Location:** Add AFTER "Pre-Test Health Validation" section

```markdown
## Install Crossview Dashboard

Crossview is an open-source visual dashboard for Crossplane that helps you understand resource relationships, debug issues, and monitor infrastructure health.

### Why Crossview?

- **Visual Resource Relationships**: See how XRs, Compositions, and Managed Resources connect
- **Real-time Health Monitoring**: Track resource status and conditions
- **Debug Complex Compositions**: Understand what resources are created
- **Multi-cluster Support**: Manage resources across dev, staging, production
- **Provider Health**: Monitor provider installations and status
- **XRD/Composition Browser**: Inspect schemas and composition logic

### Installation via Helm

```bash
# Add Crossview Helm repository
helm repo add crossview https://corpobit.github.io/crossview
helm repo update

# Generate secure session secret
SESSION_SECRET=$(openssl rand -base64 32)

# Install Crossview
helm install crossview crossview/crossview \
  --namespace crossview \
  --create-namespace \
  --set secrets.dbPassword=your-secure-password \
  --set secrets.sessionSecret=$SESSION_SECRET

# Wait for deployment
kubectl wait --for=condition=available deployment/crossview \
  -n crossview --timeout=300s

# Get service URL
kubectl get svc -n crossview
```

### Access Crossview

**Port Forward (Development):**
```bash
# Forward port to access locally
kubectl port-forward -n crossview svc/crossview 3001:3001

# Open in browser
open http://localhost:3001
```

**Ingress (Production):**
```bash
# Install with Ingress enabled
helm upgrade crossview crossview/crossview \
  --namespace crossview \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=crossview.atlas.example.com \
  --set secrets.dbPassword=your-secure-password \
  --set secrets.sessionSecret=$SESSION_SECRET
```

### Using Crossview in Testing Workflow

#### Layer 1: Provider Validation
```bash
# After installing provider-azure
kubectl get providers

# Open Crossview → Providers section
# Verify:
# - Provider is installed and healthy
# - ProviderConfig is properly configured
# - No error conditions
```

#### Layer 2: Unit Tests (XRD/Composition Inspection)
```bash
# After applying XRDs and Compositions
kubectl apply -f apis/v1alpha1/storage-accounts/xrd.yaml
kubectl apply -f apis/v1alpha1/storage-accounts/composition.yaml

# In Crossview:
# 1. Navigate to "XRDs" section
# 2. Click on xstorageaccounts.storage.atlas.io
# 3. View schema definition
# 4. Navigate to "Compositions" section
# 5. Click on composition
# 6. Inspect resources that will be created
```

#### Layer 3: Integration Tests (XR Visualization)
```bash
# After creating a composite resource
kubectl apply -f apis/v1alpha1/storage-accounts/examples/basic.yaml

# In Crossview:
# 1. Navigate to "Composite Resources"
# 2. Find your XStorageAccount
# 3. Click to view details
# 4. See visual graph: XR → Managed Resources
# 5. Check status conditions
# 6. View events and logs
```

#### Layer 4-5: Cross-API and E2E (Resource Graphs)
```bash
# After deploying multiple resources
kubectl apply -f tests/integration/network-storage/

# In Crossview:
# 1. Use "Resource Graph" view
# 2. See all related resources
# 3. Understand dependencies
# 4. Monitor overall health
# 5. Identify bottlenecks or failures
```

### Crossview Features for Testing

**1. Resource Status Dashboard**
- Quick overview of all resources
- Color-coded health indicators
- Filter by namespace, type, status

**2. Relationship Visualization**
```
XStorageAccount (XR)
    ├── ResourceGroup (Managed)
    │   └── Azure Resource Group
    └── Account (Managed)
        └── Azure Storage Account
```

**3. Condition Monitoring**
- View all Crossplane conditions (Ready, Synced, etc.)
- Historical condition changes
- Error message details

**4. YAML Inspector**
- View full resource YAML
- Compare desired vs actual state
- Copy configuration for debugging

**5. Events Timeline**
- Kubernetes events for resources
- Provider reconciliation logs
- Creation/update/deletion history

### Debugging with Crossview

**Problem: XR not becoming Ready**
```bash
# 1. Open Crossview
# 2. Navigate to your XR
# 3. Check Conditions section:
#    - Is "Synced" True? (Composition applied)
#    - Is "Ready" False? (Something wrong)
# 4. Look at child Managed Resources
# 5. Find which one is not Ready
# 6. Click on that resource
# 7. View error conditions and events
# 8. Check provider logs if needed
```

**Problem: Composition not creating expected resources**
```bash
# 1. Open Crossview → Compositions
# 2. Click your composition
# 3. View "Resources" section
# 4. See list of resources that should be created
# 5. Compare with what actually exists
# 6. Check patches and transformations
```

**Problem: Cross-API dependencies not working**
```bash
# 1. Open Crossview → Resource Graph
# 2. Select your primary XR
# 3. View connected resources
# 4. Identify where dependency breaks
# 5. Check references and selectors
```

### Integration with CI/CD

**Screenshot Capture for Failed Tests:**
```yaml
# .github/workflows/test.yml
- name: Capture Crossview state on failure
  if: failure()
  run: |
    # Port forward Crossview
    kubectl port-forward -n crossview svc/crossview 3001:3001 &
    sleep 5
    
    # Capture screenshots or export state
    curl http://localhost:3001/api/export > crossview-state.json
    
- name: Upload Crossview state
  if: failure()
  uses: actions/upload-artifact@v3
  with:
    name: crossview-debug-state
    path: crossview-state.json
```

### Crossview vs kubectl

```
Task                          | kubectl                      | Crossview
------------------------------|------------------------------|------------------------
Check provider health         | kubectl get providers        | Visual dashboard
View XR relationships         | Multiple kubectl commands    | Interactive graph
Debug composition             | kubectl describe + logs      | Visual resource tree
Find error conditions         | kubectl get -o yaml | grep   | Conditions panel
Understand dependencies       | Manual inspection            | Automatic visualization
Monitor multiple clusters     | Switch contexts repeatedly   | Single interface
```

### Configuration

**Custom Resource Types:**
```yaml
# values.yaml for Helm
app:
  # Show custom XRDs in dashboard
  customResourceTypes:
    - apiVersion: storage.atlas.io/v1alpha1
      kind: XStorageAccount
    - apiVersion: network.atlas.io/v1alpha1
      kind: XVirtualNetwork
```

**Authentication:**
```yaml
# Enable SSO (optional)
auth:
  enabled: true
  oidc:
    issuer: https://your-identity-provider.com
    clientId: your-client-id
    clientSecret: your-client-secret
```

### Alternative: Komoplane

If you prefer a simpler tool focused on troubleshooting:

```bash
# Install Komoplane
helm repo add komodorio https://helm-charts.komodor.io
helm repo update
helm install komoplane komodorio/komoplane

# Port forward
kubectl port-forward -n default svc/komoplane 8090:8090

# Open browser
open http://localhost:8090
```

Komoplane is lighter-weight but Crossview has more features for comprehensive platform management.

### Crossview Best Practices

1. **Install in dev/staging first**: Test Crossview setup before production
2. **Use port-forward for security**: Avoid exposing publicly without authentication
3. **Regular backups**: Back up Crossview PostgreSQL database
4. **Monitor resource usage**: Crossview itself needs resources (1-2 GB RAM)
5. **Keep updated**: New releases improve visualizations and fix bugs
```

---

## 6. ADD SECTION: GitOps with Flux and Headlamp Dashboard

**Location:** Add AFTER "Install and Use Crossview" section

```markdown
## GitOps Deployment with Flux

Flux is a CNCF graduated GitOps tool that automatically syncs your cluster state with Git repositories. Combined with Crossplane, Flux enables infrastructure-as-code deployed through Git commits.

### Why Flux + Crossplane?

- **GitOps for Infrastructure**: Manage Azure resources through Git, not kubectl
- **Automated Reconciliation**: Flux continuously ensures cluster matches Git state
- **Audit Trail**: Every infrastructure change is a Git commit
- **Rollback**: Revert infrastructure by reverting Git commits
- **Multi-Environment**: Dev/staging/prod managed through Git branches
- **Self-Healing**: Flux detects and corrects configuration drift

### Install Flux

```bash
# Install Flux CLI
brew install fluxcd/tap/flux

# Or via script
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify
flux --version

# Check cluster compatibility
flux check --pre
```

### Bootstrap Flux (GitHub Example)

```bash
# Export GitHub credentials
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=<your-username>
export GITHUB_REPO=atlas-platform-config

# Bootstrap Flux
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=clusters/development \
  --personal
```

This creates:
- Flux components in `flux-system` namespace
- Git repository for platform configuration
- Automated sync from Git to cluster

### Repository Structure for Atlas IDP

```
atlas-platform-config/
├── clusters/
│   ├── development/
│   │   ├── flux-system/          # Flux config
│   │   ├── crossplane.yaml       # Points to crossplane directory
│   │   └── apps.yaml             # Points to apps directory
│   ├── staging/
│   └── production/
├── infrastructure/
│   └── crossplane/
│       ├── providers/
│       │   ├── provider-azure.yaml
│       │   └── provider-config.yaml
│       ├── apis/
│       │   └── v1alpha1/
│       │       ├── storage-accounts/
│       │       │   ├── xrd.yaml
│       │       │   ├── composition.yaml
│       │       │   └── examples/
│       │       ├── virtual-networks/
│       │       └── databases/
│       └── instances/              # Actual XR instances
│           ├── dev-storage.yaml
│           └── dev-network.yaml
└── apps/
    └── platform-services/
        ├── crossview.yaml
        └── headlamp.yaml
```

### Deploy Crossplane via Flux

```yaml
# infrastructure/crossplane/crossplane-source.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: crossplane
  namespace: flux-system
spec:
  interval: 1h
  url: https://charts.crossplane.io/stable
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: crossplane
  namespace: crossplane-system
spec:
  interval: 10m
  chart:
    spec:
      chart: crossplane
      version: "2.x.x"
      sourceRef:
        kind: HelmRepository
        name: crossplane
        namespace: flux-system
  install:
    createNamespace: true
    crds: CreateReplace
  upgrade:
    crds: CreateReplace
```

### Deploy XRDs and Compositions via Flux

```yaml
# clusters/development/crossplane.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: crossplane-apis
  namespace: flux-system
spec:
  interval: 5m
  path: ./infrastructure/crossplane/apis
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  healthChecks:
    - apiVersion: apiextensions.crossplane.io/v2
      kind: CompositeResourceDefinition
      name: xstorageaccounts.storage.atlas.io
```

### Deploy Composite Resources via Flux

```yaml
# clusters/development/infrastructure-instances.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure-instances
  namespace: flux-system
spec:
  interval: 5m
  path: ./infrastructure/crossplane/instances
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  dependsOn:
    - name: crossplane-apis
  healthChecks:
    - apiVersion: storage.atlas.io/v1alpha1
      kind: XStorageAccount
      name: dev-storage
      namespace: default
```

### Flux Monitoring

```bash
# Watch all Flux resources
flux get all

# Watch specific resource
flux get kustomizations
flux get helmreleases
flux get sources git

# View reconciliation logs
flux logs --follow --all-namespaces

# Force reconciliation
flux reconcile kustomization crossplane-apis --with-source
```

### Flux Notifications

Set up alerts for reconciliation failures:

```yaml
# infrastructure/flux/notifications.yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Provider
metadata:
  name: slack
  namespace: flux-system
spec:
  type: slack
  channel: atlas-platform-alerts
  address: https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: crossplane-alerts
  namespace: flux-system
spec:
  providerRef:
    name: slack
  eventSeverity: error
  eventSources:
    - kind: Kustomization
      name: crossplane-apis
    - kind: Kustomization
      name: infrastructure-instances
```

## Install Headlamp with Flux Plugin

Headlamp is a modern Kubernetes dashboard that provides a visual interface for managing clusters, with a dedicated Flux plugin for GitOps visibility.

### Deploy Headlamp via Flux

```yaml
# apps/platform-services/headlamp.yaml
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
    config:
      pluginsDir: /build/plugins
    initContainers:
      - name: flux-plugin
        image: ghcr.io/headlamp-k8s/headlamp-plugin-flux:latest
        command: ["/bin/sh", "-c"]
        args:
          - cp -r /plugins/* /build/plugins/
        volumeMounts:
          - name: plugins
            mountPath: /build/plugins
    ingress:
      enabled: true
      className: nginx
      hosts:
        - host: headlamp.atlas.example.com
          paths:
            - path: /
              pathType: Prefix
```

### Access Headlamp

**Port Forward (Development):**
```bash
kubectl port-forward -n headlamp svc/headlamp 4466:80

# Open browser
open http://localhost:4466
```

**Using Ingress (Production):**
```bash
# Access via configured domain
open https://headlamp.atlas.example.com
```

### Using Headlamp Flux Plugin

Once Headlamp is running with the Flux plugin:

#### 1. Overview Dashboard
- Navigate to **Flux** section in sidebar
- View all Flux resources: Kustomizations, HelmReleases, Sources
- See sync status at a glance
- Identify reconciliation failures

#### 2. Kustomizations View
```
Shows:
- All Kustomization resources
- Sync status (Ready/Failed/Suspended)
- Last reconciliation time
- Next reconciliation countdown
- Source repository and path

Actions:
- Suspend/Resume reconciliation
- Force immediate sync
- View YAML manifest
- Check events and logs
```

#### 3. HelmReleases View
```
Shows:
- All HelmRelease resources
- Release status
- Chart version installed
- Upgrade status
- Rollback information

Actions:
- Suspend/Resume releases
- Force reconciliation
- View values
- Check release history
```

#### 4. Sources View
```
GitRepositories:
- Repository URL
- Branch/tag/commit
- Authentication status
- Fetch errors

HelmRepositories:
- Chart repository URL
- Index fetch status
- Available charts
```

#### 5. Image Automation
```
Shows:
- Image update automation policies
- Image repositories being scanned
- Latest images detected
- Git commits made by automation
```

### Headlamp Features for Atlas IDP

**Multi-Cluster Management:**
```bash
# Add additional clusters to Headlamp
kubectl config get-contexts

# Headlamp automatically detects all contexts
# Switch between dev/staging/prod from UI
```

**RBAC Viewer:**
- Visualize service account permissions
- See which teams have access to which namespaces
- Audit platform access

**Resource Browser:**
- All Kubernetes resources in one place
- Custom resources (Crossplane XRDs) visible
- Filter by namespace, labels, or type

**Log Viewer:**
- Stream logs from any pod
- Multi-pod log aggregation
- Search and filter capabilities

**Terminal Access:**
- Interactive shell into containers
- Execute debugging commands
- File system navigation

### Headlamp vs Crossview

```
Feature                  | Headlamp                    | Crossview
-------------------------|-----------------------------|--------------------------
Focus                    | General Kubernetes          | Crossplane-specific
Flux Integration         | Dedicated plugin            | No native support
Multi-cluster            | Native support              | Single cluster focus
Resource Graphs          | Basic relationships         | Advanced XR→MR graphs
RBAC Management          | Built-in viewer             | Not available
Logs & Terminal          | Yes                         | No
Extensibility            | Plugin system               | Limited
Installation             | Helm, Desktop app           | Helm only
```

**Recommendation:** Use **both** for complementary capabilities:
- **Headlamp**: Day-to-day cluster operations, Flux monitoring, RBAC
- **Crossview**: Crossplane-specific debugging, composition visualization

### GitOps Workflow with Flux + Crossplane

#### Development Workflow

```bash
# 1. Clone platform config repo
git clone https://github.com/$GITHUB_USER/atlas-platform-config
cd atlas-platform-config

# 2. Create new XR instance
cat > infrastructure/crossplane/instances/staging-storage.yaml <<EOF
apiVersion: storage.atlas.io/v1alpha1
kind: XStorageAccount
metadata:
  name: staging-storage
  namespace: staging
spec:
  parameters:
    accountType: Standard_GRS
    location: westeurope
EOF

# 3. Commit and push
git add infrastructure/crossplane/instances/staging-storage.yaml
git commit -m "Add staging storage account"
git push origin main

# 4. Monitor in Headlamp
# - Open Flux section
# - Watch "infrastructure-instances" Kustomization
# - See reconciliation progress
# - View created XStorageAccount in Crossview

# 5. Verify with Crossview
# - Check XR created
# - View managed resources
# - Verify Azure storage account exists
```

#### Rollback Workflow

```bash
# Infrastructure broken? Revert Git commit
git revert HEAD
git push origin main

# Flux automatically:
# 1. Detects Git change
# 2. Deletes broken resources
# 3. Restores previous state

# Watch rollback in Headlamp Flux plugin
```

### Flux Best Practices for Atlas IDP

1. **Separate Environments by Path:**
   ```
   clusters/dev/        → Development cluster
   clusters/staging/    → Staging cluster
   clusters/prod/       → Production cluster
   ```

2. **Use Dependencies:**
   ```yaml
   spec:
     dependsOn:
       - name: crossplane-providers
       - name: crossplane-apis
   ```

3. **Health Checks:**
   ```yaml
   healthChecks:
     - apiVersion: storage.atlas.io/v1alpha1
       kind: XStorageAccount
   ```

4. **Image Automation (Optional):**
   ```yaml
   # Auto-update composition versions
   apiVersion: image.toolkit.fluxcd.io/v1beta2
   kind: ImageUpdateAutomation
   ```

5. **Notifications:**
   - Alert on reconciliation failures
   - Notify on successful deployments
   - Track drift detection

### Testing Integration

**Layer 6 (GitOps) in CI/CD:**

```yaml
# .github/workflows/test-flux.yml
name: Test Flux Sync
on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Flux CLI
        run: |
          curl -s https://fluxcd.io/install.sh | sudo bash
      
      - name: Validate Flux manifests
        run: |
          flux install --export > /tmp/flux-install.yaml
          kubectl apply --dry-run=client -f /tmp/flux-install.yaml
          
      - name: Validate Kustomizations
        run: |
          for file in clusters/*/*.yaml; do
            kubectl apply --dry-run=server -f $file
          done
```

### Troubleshooting Flux Issues

**Kustomization Not Reconciling:**
```bash
# Check Flux logs
flux logs --kind=Kustomization --name=crossplane-apis

# Check source
flux get sources git

# Force reconciliation
flux reconcile kustomization crossplane-apis --with-source
```

**HelmRelease Stuck:**
```bash
# Check release status
flux get helmreleases

# View Helm-specific logs
kubectl logs -n flux-system deploy/helm-controller

# Suspend and resume
flux suspend helmrelease crossplane
flux resume helmrelease crossplane
```

**Authentication Failures:**
```bash
# Check Git authentication
flux get sources git

# Recreate deploy key
flux create secret git flux-system \
  --url=ssh://git@github.com/$GITHUB_USER/atlas-platform-config
```
```

---

## 7. UPDATE SECTION: Composition Rendering with Crossplane CLI

**Location:** Add as first testing technique section (before Provider Validation)

```markdown
## Local Composition Rendering

The Crossplane CLI `render` command validates compositions locally without requiring a Kubernetes cluster. This is the fastest way to catch composition errors during development.

### Install Crossplane CLI

```bash
# macOS
brew install crossplane/tap/crossplane

# Linux
curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh

# Verify installation
crossplane --version
```

### Basic Rendering

Test a composition with a composite resource claim:

```bash
# Render composition output
crossplane render \
  apis/v1alpha1/storage-accounts/xrd.yaml \
  apis/v1alpha1/storage-accounts/composition.yaml \
  apis/v1alpha1/storage-accounts/examples/basic.yaml

# This shows what managed resources will be created
```

### Advanced Rendering with Functions

For compositions using functions (Pipeline mode):

```bash
# Render with composition functions
crossplane render \
  apis/v1alpha1/storage-accounts/xrd.yaml \
  apis/v1alpha1/storage-accounts/composition.yaml \
  apis/v1alpha1/storage-accounts/examples/basic.yaml \
  --include-function-results

# Save output to file for inspection
crossplane render \
  apis/v1alpha1/storage-accounts/xrd.yaml \
  apis/v1alpha1/storage-accounts/composition.yaml \
  apis/v1alpha1/storage-accounts/examples/basic.yaml \
  > rendered-output.yaml
```

### Common Use Cases

**1. Validate Composition Syntax**
```bash
# Check if composition is valid before applying to cluster
crossplane render \
  apis/v1alpha1/storage-accounts/xrd.yaml \
  apis/v1alpha1/storage-accounts/composition.yaml \
  apis/v1alpha1/storage-accounts/examples/basic.yaml

# If successful, output shows managed resources
# If errors, shows detailed error messages
```

**2. Debug Field Patching**
```bash
# Verify fields are patched correctly
crossplane render \
  apis/v1alpha1/storage-accounts/xrd.yaml \
  apis/v1alpha1/storage-accounts/composition.yaml \
  apis/v1alpha1/storage-accounts/examples/basic.yaml \
  | grep -A 10 "kind: Account"

# Check specific field values in output
```

**3. Test Different Examples**
```bash
# Test basic configuration
crossplane render xrd.yaml composition.yaml examples/basic.yaml

# Test production configuration
crossplane render xrd.yaml composition.yaml examples/production.yaml

# Compare outputs
diff \
  <(crossplane render xrd.yaml composition.yaml examples/basic.yaml) \
  <(crossplane render xrd.yaml composition.yaml examples/production.yaml)
```

**4. Validate All APIs**
```bash
# Create a render test script for all APIs
cat > scripts/render-all.sh <<'EOF'
#!/bin/bash
set -e

for api_dir in apis/v1alpha1/*/; do
  api_name=$(basename "$api_dir")
  echo "=== Rendering $api_name ==="
  
  if [ -f "$api_dir/xrd.yaml" ] && [ -f "$api_dir/composition.yaml" ]; then
    for example in "$api_dir/examples/"*.yaml; do
      echo "  Testing $(basename "$example")..."
      crossplane render \
        "$api_dir/xrd.yaml" \
        "$api_dir/composition.yaml" \
        "$example" > /dev/null
      echo "  ✅ $(basename "$example") renders successfully"
    done
  fi
done

echo "✅ All compositions render successfully!"
EOF

chmod +x scripts/render-all.sh
./scripts/render-all.sh
```

### Integration with Development Workflow

**Pre-commit validation:**
```bash
# Before committing composition changes
crossplane render \
  apis/v1alpha1/storage-accounts/xrd.yaml \
  apis/v1alpha1/storage-accounts/composition.yaml \
  apis/v1alpha1/storage-accounts/examples/basic.yaml \
  && echo "✅ Composition valid" \
  || echo "❌ Composition has errors"
```

**CI/CD integration:**
```yaml
# .github/workflows/validate-compositions.yml
name: Validate Compositions
on: [push, pull_request]

jobs:
  render:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Crossplane CLI
        run: |
          curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh
          sudo mv crossplane /usr/local/bin/
      
      - name: Render all compositions
        run: |
          for api_dir in apis/v1alpha1/*/; do
            api_name=$(basename "$api_dir")
            echo "Rendering $api_name..."
            for example in "$api_dir/examples/"*.yaml; do
              crossplane render \
                "$api_dir/xrd.yaml" \
                "$api_dir/composition.yaml" \
                "$example"
            done
          done
```

### Benefits of Local Rendering

1. **Instant feedback**: No cluster deployment needed
2. **Catch errors early**: Before applying to cluster
3. **Safe experimentation**: Test changes without affecting real resources
4. **Debug tool**: See exact managed resources that will be created
5. **CI/CD friendly**: Fast validation in pipelines
6. **No cloud costs**: Validate locally before Azure deployment

### Common Errors and Solutions

**Error: "cannot resolve patch"**
```bash
# Issue: Field path in patch doesn't exist
# Solution: Check XR schema and patch paths match

# Render with verbose output
crossplane render \
  xrd.yaml composition.yaml example.yaml \
  --verbose
```

**Error: "composition validation failed"**
```bash
# Issue: Composition syntax error
# Solution: Validate YAML syntax first

# Check YAML is valid
yamllint composition.yaml

# Then render
crossplane render xrd.yaml composition.yaml example.yaml
```

**Error: "function not found"**
```bash
# Issue: Composition references functions not available locally
# Solution: Add --include-function-results or mock functions

# Render without function execution
crossplane render \
  xrd.yaml composition.yaml example.yaml \
  --include-function-results
```
```

---

## 8. UPDATE SECTION: Provider Validation with Uptest

**Location:** Add as first testing section

```markdown
## Provider Validation Tests (Uptest)

### Setup Provider Validation

Create the provider validation structure:

```bash
mkdir -p tests/provider/examples/azure
```

Create setup script for Uptest:

```bash
cat > tests/provider/setup.sh <<'EOF'
#!/bin/bash
set -e

echo "Waiting for Crossplane to be ready..."
kubectl wait --for=condition=available deployment/crossplane \
  -n crossplane-system --timeout=300s

echo "Waiting for provider-azure to be healthy..."
kubectl wait --for=condition=healthy provider.pkg.crossplane.io/provider-azure \
  --timeout=600s

echo "Verifying Azure credentials secret..."
kubectl get secret azure-creds -n crossplane-system

echo "Checking provider webhook endpoints..."
kubectl get endpoints -n crossplane-system

# Give webhooks extra time to stabilize
sleep 15

echo "Provider validation setup complete!"
EOF

chmod +x tests/provider/setup.sh
```

### Create Provider Test Examples

```bash
# Create a ResourceGroup test
cat > tests/provider/examples/azure/resourcegroup.yaml <<'EOF'
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: uptest-rg
  annotations:
    uptest.upbound.io/timeout: "600"
spec:
  forProvider:
    location: West Europe
  providerConfigRef:
    name: default
EOF
```

### Run Provider Validation

```bash
cd tests/provider

# Run Uptest with setup script
uptest run examples/azure/*.yaml \
  --setup-script=setup.sh \
  --default-timeout=900 \
  --skip-delete=false

# This will:
# 1. Run setup.sh to ensure provider is ready
# 2. Create each resource
# 3. Wait for it to become Ready
# 4. Test updates (if enabled)
# 5. Delete and verify cleanup
```
```

---

## 10. UPDATE SECTION: Directory Structure

**Location:** Replace any existing structure documentation

```markdown
## Project Structure

```
learning-crossplane-e2e-testing/
├── manuscript/
│   └── setup/
│       └── dev.md
├── apis/
│   └── v1alpha1/
│       └── storage-accounts/
│           ├── xrd.yaml              # XRD definition (v2)
│           ├── composition.yaml      # Composition
│           ├── examples/
│           │   ├── basic.yaml       # Simple XR example
│           │   └── production.yaml  # Complex XR example
│           └── tests/
│               ├── unit/            # Fast, no cloud resources
│               │   ├── README.md
│               │   └── kuttl-test.yaml
│               └── integration/     # Real Azure resources
│                   ├── README.md
│                   └── kuttl-test.yaml
└── tests/
    ├── provider/                    # Uptest - managed resources
    │   ├── README.md
    │   ├── setup.sh
    │   └── examples/
    │       └── azure/
    │           ├── resourcegroup.yaml
    │           └── storageaccount.yaml
    ├── integration/                 # Kuttl - cross-API
    │   ├── README.md
    │   └── network-storage/
    └── e2e/                        # Kuttl - platform
        └── README.md
```

### File Naming Conventions

- `xrd.yaml` - CompositeResourceDefinition (not `definition.yaml`)
- `composition.yaml` - Composition
- No numbered directory prefixes (e.g., use `unit/` not `01-unit/`)
- Semantic names over numbers for maintainability
```

---

## 11. ADD SECTION: Makefile

**Location:** Replace any existing structure documentation

```markdown
## Project Structure

```
learning-crossplane-e2e-testing/
├── manuscript/
│   └── setup/
│       └── dev.md
├── apis/
│   └── v1alpha1/
│       └── storage-accounts/
│           ├── xrd.yaml              # XRD definition (v2)
│           ├── composition.yaml      # Composition
│           ├── examples/
│           │   ├── basic.yaml       # Simple XR example
│           │   └── production.yaml  # Complex XR example
│           └── tests/
│               ├── unit/            # Fast, no cloud resources
│               │   ├── README.md
│               │   └── kuttl-test.yaml
│               └── integration/     # Real Azure resources
│                   ├── README.md
│                   └── kuttl-test.yaml
└── tests/
    ├── provider/                    # Uptest - managed resources
    │   ├── README.md
    │   ├── setup.sh
    │   └── examples/
    │       └── azure/
    │           ├── resourcegroup.yaml
    │           └── storageaccount.yaml
    ├── integration/                 # Kuttl - cross-API
    │   ├── README.md
    │   └── network-storage/
    └── e2e/                        # Kuttl - platform
        └── README.md
```

### File Naming Conventions

- `xrd.yaml` - CompositeResourceDefinition (not `definition.yaml`)
- `composition.yaml` - Composition
- No numbered directory prefixes (e.g., use `unit/` not `01-unit/`)
- Semantic names over numbers for maintainability
```

---

## 10. ADD SECTION: Makefile

**Location:** Add near end of document

```markdown
## Makefile for Test Automation

Create a Makefile in the repository root:

```makefile
.PHONY: test-all render test-provider test-unit test-api-integration test-cross-integration test-e2e

# Render all compositions locally (no cluster needed)
render:
	@echo "=== Rendering All Compositions ==="
	@./scripts/render-all.sh

# Run all tests in logical order
test-all: render test-provider test-unit test-api-integration test-cross-integration test-e2e

# 1. Provider-level managed resource validation (fastest)
test-provider:
	@echo "=== Provider Validation Tests (Uptest) ==="
	cd tests/provider && uptest run examples/azure/*.yaml --setup-script=setup.sh

# 2. Unit tests for all APIs (fast, no cloud resources)
test-unit:
	@echo "=== API Unit Tests ==="
	@for api_tests in apis/v1alpha1/*/tests/unit; do \
		if [ -d "$$api_tests" ]; then \
			echo "Testing $$api_tests..."; \
			(cd $$api_tests && kubectl kuttl test) || exit 1; \
		fi \
	done

# 3. Integration tests for individual APIs (medium speed, real Azure)
test-api-integration:
	@echo "=== API Integration Tests ==="
	@for api_tests in apis/v1alpha1/*/tests/integration; do \
		if [ -d "$$api_tests" ]; then \
			echo "Testing $$api_tests..."; \
			(cd $$api_tests && kubectl kuttl test) || exit 1; \
		fi \
	done

# 4. Cross-API integration tests (slower, multiple resources)
test-cross-integration:
	@echo "=== Cross-API Integration Tests ==="
	cd tests/integration && kubectl kuttl test

# 5. Full platform E2E tests (slowest, complete deployments)
test-e2e:
	@echo "=== E2E Platform Tests ==="
	cd tests/e2e && kubectl kuttl test

# Individual API test targets
test-storage-accounts-unit:
	cd apis/v1alpha1/storage-accounts/tests/unit && kubectl kuttl test

test-storage-accounts-integration:
	cd apis/v1alpha1/storage-accounts/tests/integration && kubectl kuttl test

# Render individual APIs
render-storage-accounts:
	@echo "=== Rendering StorageAccount API ==="
	@for example in apis/v1alpha1/storage-accounts/examples/*.yaml; do \
		echo "  Testing $$(basename $$example)..."; \
		crossplane render \
			apis/v1alpha1/storage-accounts/xrd.yaml \
			apis/v1alpha1/storage-accounts/composition.yaml \
			$$example > /dev/null && echo "  ✅ $$(basename $$example) valid" || echo "  ❌ $$(basename $$example) failed"; \
	done

# Health check before testing
health-check:
	./check-provider-health.sh

# Setup everything
setup: health-check
	@echo "Setup complete - ready for testing"
```

### Using the Makefile

```bash
# Render compositions locally (fastest validation)
make render

# Render specific API
make render-storage-accounts

# Run health check first
make health-check

# Run all tests
make test-all

# Run specific test layer
make test-provider
make test-unit
make test-api-integration
```
```

---

## 12. UPDATE: kubectl Commands for v2

**Location:** Replace anywhere showing kubectl get/describe commands

**OLD:**
```bash
# Get claims
kubectl get storageaccountclaim

# Cluster-scoped XRs
kubectl get xstorageaccount
```

**NEW (v2 with Namespaced scope):**
```bash
# XRs are now namespaced
kubectl get xstorageaccount -n default

# Get all XRs across namespaces
kubectl get xstorageaccount -A

# Get managed resources (still cluster-scoped)
kubectl get managed

# Get connection secrets (in namespace)
kubectl get secret storage-connection -n default
```

---

## 13. ADD: Troubleshooting Section

**Location:** Add near end of document

```markdown
## Troubleshooting

### Handshake Failures / Timeout Issues

If you see handshake failures or timeouts:

1. **Increase webhook timeouts** (see "Verify Webhook Stability" section above)

2. **Reduce Minikube resources**:
   ```bash
   # Don't allocate ALL resources to Minikube
   # Leave some for host OS
   # Recommended: 3 CPUs, 6GB RAM instead of 4 CPUs, 8GB RAM
   ```

3. **Check provider health**:
   ```bash
   ./check-provider-health.sh
   ```

4. **Switch to Uptest for provider testing**:
   - Uptest has better timeout handling for cloud resources
   - Built-in retry logic
   - More patient with slow Azure APIs

### Provider Not Becoming Healthy

```bash
# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure

# Verify credentials
kubectl get secret azure-creds -n crossplane-system -o yaml

# Check provider revision
kubectl get providerrevision

# Manually wait with longer timeout
kubectl wait --for=condition=healthy provider.pkg.crossplane.io/provider-azure \
  --timeout=900s
```

### Tests Timing Out

1. **For Uptest tests**: Increase timeout in annotations
   ```yaml
   metadata:
     annotations:
       uptest.upbound.io/timeout: "900"  # 15 minutes
   ```

2. **For Kuttl tests**: Increase in kuttl-test.yaml
   ```yaml
   apiVersion: kuttl.dev/v1beta1
   kind: TestSuite
   timeout: 900
   ```

3. **Switch to AKS**: For reliable testing, consider using Azure Kubernetes Service instead of Minikube

### XRD Schema Changes Not Taking Effect

After modifying an XRD schema:

```bash
# Restart Crossplane pod
kubectl rollout restart deployment/crossplane -n crossplane-system

# Wait for it to be ready
kubectl wait --for=condition=available deployment/crossplane \
  -n crossplane-system --timeout=300s
```
```

---

## 14. ADD: Cloud Alternative Section

**Location:** Add after troubleshooting

```markdown
## Cloud-Based Testing Alternative

For more reliable testing, especially if experiencing persistent timeout issues with Minikube, consider using Azure Kubernetes Service (AKS).

### Why AKS for Testing?

- **Direct Azure integration**: Optimal for testing Azure providers
- **No local resource constraints**: No handshake failures from resource contention
- **Aligns with certifications**: Hands-on AKS supports AZ-700/AZ-305 study
- **Cost-effective**: Use small clusters, start/stop when not testing

### Quick AKS Setup

```bash
# Create minimal AKS cluster for testing
az aks create \
  --resource-group crossplane-dev-rg \
  --name crossplane-test \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group crossplane-dev-rg --name crossplane-test

# Install Crossplane (follow same steps as Minikube)
```

### Cost Management

```bash
# Stop cluster when not testing (minimal cost)
az aks stop --name crossplane-test --resource-group crossplane-dev-rg

# Start when needed
az aks start --name crossplane-test --resource-group crossplane-dev-rg

# Delete when done
az aks delete --name crossplane-test --resource-group crossplane-dev-rg --yes
```

**Estimated cost**: €50-70/month if running continuously, much less with stop/start pattern.
```

---

## Summary of Key Changes

1. ✅ **XRD API Version**: `apiextensions.crossplane.io/v2` (not v1)
2. ✅ **XRD Scope**: Add `scope: Namespaced` to all XRDs
3. ✅ **Remove Claims**: Delete all `claimNames` sections
4. ✅ **Namespace XRs**: Add `namespace` to all XR metadata
5. ✅ **Add Crossplane CLI**: Install for local composition rendering
6. ✅ **Add Crossview**: Install visual dashboard for Crossplane resources
7. ✅ **Add Flux**: GitOps deployment for infrastructure-as-code
8. ✅ **Add Headlamp**: Kubernetes dashboard with Flux plugin
9. ✅ **Add Uptest**: New tool for provider validation
10. ✅ **Webhook Timeouts**: Patch before testing
11. ✅ **Health Checks**: Add pre-test validation script
12. ✅ **Directory Structure**: Use semantic names (no number prefixes)
13. ✅ **File Names**: Use `xrd.yaml` not `definition.yaml`
14. ✅ **Makefile**: Add test automation with render target
15. ✅ **Testing Layers**: 7-layer approach with full GitOps integration

---

## Implementation Checklist

- [ ] Update all XRD examples to use `apiVersion: v2`
- [ ] Add `scope: Namespaced` to all XRDs
- [ ] Remove all `claimNames` sections
- [ ] Add namespace to all XR examples
- [ ] Install Crossplane CLI section
- [ ] Add local rendering section with examples
- [ ] Create render-all.sh script
- [ ] Install Crossview section
- [ ] Add Crossview usage examples for each test layer
- [ ] Install Flux section
- [ ] Bootstrap Flux with GitHub/GitLab
- [ ] Create Flux repository structure
- [ ] Deploy Crossplane via Flux HelmRelease
- [ ] Configure Flux Kustomizations for XRDs/Compositions
- [ ] Set up Flux notifications (Slack/email)
- [ ] Install Headlamp section
- [ ] Deploy Headlamp via Flux
- [ ] Install Headlamp Flux plugin
- [ ] Install Uptest section
- [ ] Add webhook timeout patching section
- [ ] Create health check script section
- [ ] Add provider validation with Uptest section
- [ ] Update directory structure documentation
- [ ] Add Makefile with render target
- [ ] Add troubleshooting section (include Crossview, Headlamp, Flux debugging)
- [ ] Add cloud alternative section (AKS)
- [ ] Update all kubectl commands for namespaced XRs
- [ ] Add CI/CD composition validation workflow
- [ ] Update testing pyramid diagram with all 7 layers
- [ ] Add GitOps workflow documentation
