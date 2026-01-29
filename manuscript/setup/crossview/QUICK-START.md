# Quick Start Guide: Crossview Validation

This guide provides a complete workflow for graphically validating XRD-Composition relationships using Crossview.

**Example:** This guide uses an Azure Storage Account XRD and Composition to demonstrate the validation process.

## Prerequisites

Ensure you have:
- Minikube running
- Crossplane v2 installed in your cluster
- kubectl configured and working
- Azure Provider for Crossplane installed (optional, for creating actual resources)

## Step-by-Step Workflow

### 1. Install Crossview

```bash
# Run the installation script
./install-crossview.sh
```

This will:
- Create the crossview namespace
- Deploy Crossview with proper RBAC permissions
- Set up a NodePort service for access
- Wait for the pod to be ready

### 2. Deploy Sample XRD and Composition (Optional)

If you want to test with our sample Azure Storage Account resources first:

```bash
# Deploy the sample XRD
kubectl apply -f sample-xrd.yaml

# Wait for XRD to be established
kubectl wait --for=condition=established xrd/xstorageaccounts.azure.example.com --timeout=60s

# Deploy the sample Composition
kubectl apply -f sample-composition.yaml

# Verify resources are created
kubectl get xrd
kubectl get composition
```

### 3. Deploy Your Own XRD and Composition

Replace the sample files with your own:

```bash
# Deploy your XRD
kubectl apply -f your-xrd.yaml

# Deploy your Composition
kubectl apply -f your-composition.yaml
```

### 4. Validate Using CLI (Optional but Recommended)

Before using Crossview, verify with the CLI tool:

```bash
# List all XRDs
kubectl get xrd

# Validate a specific XRD-Composition pair
./validate-xrd-composition.sh <xrd-name> <composition-name>

# Or let the script find all matching compositions
./validate-xrd-composition.sh <xrd-name>
```

Example output for matching resources:
```
=== Crossplane XRD-Composition Validation ===

Checking XRD: xstorageaccounts.azure.example.com
✓ XRD found

XRD Details:
  Name:        xstorageaccounts.azure.example.com
  API Version: azure.example.com/v1alpha1
  Kind:        XStorageAccount
  Status:      Established

Checking Composition: storageaccount-azure-standard
✓ Composition found

Composition Details:
  Name:        storageaccount-azure-standard
  API Version: azure.example.com/v1alpha1
  Kind:        XStorageAccount

Validation Results:
  ✓ API Version matches
  ✓ Kind matches

=== VALIDATION PASSED ===
```

### 5. Access Crossview

Choose one of these methods:

**Method A: Minikube Service (Easiest)**
```bash
minikube service crossview -n crossview
```

**Method B: Port Forward**
```bash
kubectl port-forward -n crossview svc/crossview 8080:3000
# Then open: http://localhost:8080
```

**Method C: NodePort (if minikube IP is accessible)**
```bash
# Get minikube IP
minikube ip

# Access at: http://<minikube-ip>:30080
```

### 6. Navigate Crossview Interface

Once Crossview opens:

1. **Home Page**: You should see a dashboard with Crossplane resources
2. **Navigate to XRDs**: Click on "Composite Resource Definitions" or similar menu
3. **View Your XRD**: Find and click on your XRD (e.g., `xstorageaccounts.azure.example.com`)
4. **Visual Validation**: Look for:
   - **Green lines/connections**: Indicates matching Composition
   - **Resource tree**: Shows the XRD-Composition-Managed Resources hierarchy
   - **Metadata panel**: Displays API version, kind, and other details

### 7. What to Look For in Crossview

✅ **Successful Match Indicators:**
- XRD and Composition appear connected with lines/arrows
- No warning or error icons
- Composition shows under the XRD in the hierarchy
- API versions and kinds match in the detail panels

❌ **Mismatch Indicators:**
- Red warning icons or error messages
- Broken connections or no connection lines
- API version or kind differences highlighted
- Composition appears orphaned (not connected to any XRD)

### 8. Test with a Composite Resource (XR)

Create an XR instance to see the full workflow:

```bash
# Create a composite resource (XR) directly - no claims in Crossplane v2
kubectl apply -f - <<EOF
apiVersion: azure.example.com/v1alpha1
kind: XStorageAccount
metadata:
  name: my-test-storage
spec:
  id: mytestsa01
  parameters:
    location: westeurope
    accountTier: Standard
    accountReplicationType: LRS
    accountKind: StorageV2
    enableHttpsTrafficOnly: true
    minimumTlsVersion: TLS1_2
    allowBlobPublicAccess: false
    networkRules:
      defaultAction: Deny
      bypass:
      - AzureServices
    tags:
      environment: test
      team: platform
  compositionSelector:
    matchLabels:
      tier: standard
EOF

# Watch the resources being created
kubectl get xstorageaccount,resourcegroup,account,container
```

In Crossview, you should now see:
- Your XStorageAccount composite resource (XR)
- The managed resources (ResourceGroup, Account, Container)
- All connected in a visual hierarchy

### 9. Troubleshooting

**Crossview not loading:**
```bash
# Check pod status
kubectl get pods -n crossview

# Check logs
kubectl logs -n crossview deployment/crossview

# Restart if needed
kubectl rollout restart deployment/crossview -n crossview
```

**Resources not appearing in Crossview:**
```bash
# Verify RBAC permissions
kubectl auth can-i list xrd --as=system:serviceaccount:crossview:crossview

# Should return: yes
```

**XRD-Composition mismatch:**
```bash
# Use the validation script for detailed output
./validate-xrd-composition.sh <xrd-name> <composition-name>

# Check for common issues:
# 1. API version mismatch (e.g., v1alpha1 vs v1beta1)
# 2. Kind mismatch (case-sensitive!)
# 3. XRD not established
```

## Common Issues and Solutions

### Issue: Composition appears but shows no connection to XRD

**Solution:**
- Check that `spec.compositeTypeRef.apiVersion` exactly matches XRD's `spec.group/spec.versions[].name`
- Verify `spec.compositeTypeRef.kind` exactly matches XRD's `spec.names.kind`

### Issue: XRD shows as "Not Established"

**Solution:**
```bash
# Check XRD status
kubectl describe xrd <xrd-name>

# Look for errors in status.conditions
# Common causes:
# - Invalid OpenAPI schema
# - Missing required fields
# - Syntax errors in the XRD
```

### Issue: Managed resources not created

**Solution:**
- Verify the Composition's mode (Pipeline requires function-patch-and-transform)
- Check that required Crossplane providers are installed
- Verify patches are correctly defined

## Next Steps

1. **Explore Crossview Features**: Navigate through different views and resource types
2. **Deploy Multiple Compositions**: Create AWS, Azure, and GCP compositions for the same XRD
3. **Monitor Resource Status**: Watch resources transition from creating to ready state
4. **Export Diagrams**: Some Crossview versions support exporting visual diagrams

## Additional CLI Commands

```bash
# List all XRDs
kubectl get xrd

# List all Compositions
kubectl get composition

# Get detailed info about XRD
kubectl describe xrd <xrd-name>

# Get detailed info about Composition
kubectl describe composition <composition-name>

# Check Crossplane status
kubectl get pods -n crossplane-system

# View Crossplane providers
kubectl get providers

# View all Crossplane-related CRDs
kubectl api-resources | grep crossplane
```

## Clean Up

To remove the test resources:

```bash
# Delete the sample claim (if created)
kubectl delete network my-test-network

# Delete sample Composition
kubectl delete -f sample-composition.yaml

# Delete sample XRD
kubectl delete -f sample-xrd.yaml

# Uninstall Crossview (optional)
kubectl delete namespace crossview
kubectl delete clusterrole crossview-reader
kubectl delete clusterrolebinding crossview-reader-binding
```

## Resources

- [Crossplane Documentation](https://docs.crossplane.io/)
- [XRD Specification](https://docs.crossplane.io/latest/concepts/composite-resource-definitions/)
- [Composition Specification](https://docs.crossplane.io/latest/concepts/compositions/)
- [Crossview GitHub](https://github.com/smoeidheidari/crossview)
