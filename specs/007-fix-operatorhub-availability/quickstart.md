# Quickstart: Fix OperatorHub Availability

**Feature**: 007-fix-operatorhub-availability
**Target Users**: Developers maintaining the ToolHive operator metadata repository
**Time to Complete**: ~15 minutes (excluding image builds/pushes)

## Overview

This quickstart guides you through fixing the OperatorHub availability issue by:
1. Regenerating catalog.yaml with embedded CSV
2. Updating example files to use development registry
3. Validating and testing the changes

---

## Prerequisites

### Required Tools

```bash
# Verify required tools are installed
opm version          # Operator Package Manager - v1.30.0 or later
podman version       # Container tool - any recent version
kustomize version    # v3.0.0 or later
kubectl version      # Or 'oc' for OpenShift CLI
```

### Required Access

- ✅ Read access to bundle/ directory (contains CSV and CRDs)
- ✅ Write access to catalog/ and examples/ directories
- ✅ Podman/Docker permissions for building images
- ⚠️ Push access to quay.io/roddiekieley registry (for deploying changes)
- ⚠️ OpenShift cluster access (for verification testing - optional but recommended)

### Before You Start

```bash
# Ensure you're on the correct branch
git checkout 007-fix-operatorhub-availability

# Verify branch status
git status

# Verify bundle directory exists
ls -la bundle/manifests/toolhive-operator.clusterserviceversion.yaml
# Expected: CSV file exists
```

---

## Step 1: Regenerate catalog.yaml with Embedded CSV

### Current Problem

The existing catalog.yaml is missing the ClusterServiceVersion (CSV) embedded as base64 data. This causes OperatorHub to show no operator name and zero count.

### Solution

Use `opm render` to automatically generate catalog.yaml with the CSV embedded:

```bash
# Generate complete catalog from bundle
opm render bundle/ > catalog/toolhive-operator/catalog.yaml

# Verify the CSV is embedded
grep -c "olm.bundle.object" catalog/toolhive-operator/catalog.yaml
# Expected output: 3 (1 CSV + 2 CRDs)

# Check file size increase
wc -l catalog/toolhive-operator/catalog.yaml
# Expected: 500-800 lines (was ~53 lines before)
```

### Update Bundle Image Reference

The generated catalog will reference the bundle image from bundle metadata. Update it to use the development registry:

```bash
# Replace ghcr.io with quay.io
sed -i 's|ghcr.io/stacklok/toolhive/bundle:v0.2.17|quay.io/roddiekieley/toolhive-operator-bundle:v0.2.17|g' \
  catalog/toolhive-operator/catalog.yaml

# Verify the change
grep "image:" catalog/toolhive-operator/catalog.yaml | grep bundle
# Expected: quay.io/roddiekieley/toolhive-operator-bundle:v0.2.17
```

### Alternative: Use Makefile (if catalog-generate target exists)

```bash
# Generate catalog with custom registry
make catalog-generate \
  BUNDLE_REGISTRY=quay.io \
  BUNDLE_ORG=roddiekieley \
  BUNDLE_NAME=toolhive-operator-bundle \
  BUNDLE_TAG=v0.2.17
```

### Validate Catalog

```bash
# Validate FBC structure
opm validate catalog/toolhive-operator

# Expected output:
# (no errors - exits silently with return code 0)
```

**✅ Checkpoint**: catalog.yaml is now ~15-25 KB with embedded CSV

---

## Step 2: Update Example Files

### Update CatalogSource Example

Edit `examples/catalogsource-olmv1.yaml`:

```bash
# Update catalog image reference
sed -i 's|ghcr.io/stacklok/toolhive/catalog:v0.2.17|quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17|g' \
  examples/catalogsource-olmv1.yaml

# Verify the change
grep "image:" examples/catalogsource-olmv1.yaml | grep catalog
# Expected: quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17
```

### Update Subscription Example

Edit `examples/subscription.yaml`:

```bash
# Fix sourceNamespace
sed -i 's|sourceNamespace: olm|sourceNamespace: openshift-marketplace|g' \
  examples/subscription.yaml

# Verify the change
grep "sourceNamespace:" examples/subscription.yaml
# Expected: sourceNamespace: openshift-marketplace
```

### Verify No Production Registry References Remain

```bash
# Check for any ghcr.io/stacklok references in examples
grep -r "ghcr.io" examples/

# Expected: Only catalogsource-olmv0.yaml should have ghcr.io (legacy OLMv0)
# catalogsource-olmv1.yaml and subscription.yaml should NOT have ghcr.io
```

**✅ Checkpoint**: Example files reference quay.io/roddiekieley and correct namespaces

---

## Step 3: Validate Constitutional Compliance

The changes must pass constitutional checks before committing:

```bash
# Validate kustomize builds (Constitution: Manifest Integrity)
kustomize build config/default > /dev/null && echo "✅ config/default valid"
kustomize build config/base > /dev/null && echo "✅ config/base valid"

# Verify CRDs unchanged (Constitution: CRD Immutability)
git diff config/crd/
# Expected: No output (CRDs unchanged)

# Run Makefile validation target
make kustomize-validate
# Expected: Both builds pass
```

**✅ Checkpoint**: Constitutional principles satisfied

---

## Step 4: Build and Push Updated Catalog Image

### Build Catalog Image

```bash
# Build catalog image with updated catalog.yaml
podman build \
  -f Containerfile.catalog \
  -t quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17 \
  .

# Verify image was built
podman images | grep toolhive-operator-catalog
# Expected: Image listed with CREATED = "Just now"
```

### Test Catalog Locally (Optional)

```bash
# Run catalog image locally to test gRPC server
podman run --rm -p 50051:50051 \
  quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17

# In another terminal, test gRPC service
grpcurl -plaintext localhost:50051 api.Registry/ListPackages

# Expected: Package list containing "toolhive-operator"
# Press Ctrl+C to stop the container
```

### Push to Registry

```bash
# Log in to quay.io (if not already authenticated)
podman login quay.io

# Push catalog image
podman push quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17

# Verify image is accessible
podman pull quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17
# Expected: Image pulled successfully
```

**✅ Checkpoint**: Updated catalog image is available in quay.io

---

## Step 5: Deploy and Verify (OpenShift Cluster Required)

### Deploy CatalogSource

```bash
# Apply CatalogSource to cluster
kubectl apply -f examples/catalogsource-olmv1.yaml

# Wait for CatalogSource to become ready
kubectl wait --for=condition=Ready \
  catalogsource/toolhive-catalog \
  -n openshift-marketplace \
  --timeout=60s

# Check CatalogSource status
kubectl get catalogsource -n openshift-marketplace toolhive-catalog -o yaml | grep -A5 "connectionState:"
# Expected: lastObservedState: "READY"
```

### Verify PackageManifest Creation

This is the critical test - if the CSV is properly embedded, OLM will create a PackageManifest:

```bash
# Check for PackageManifest
kubectl get packagemanifest -n openshift-marketplace toolhive-operator

# Expected output:
# NAME                CATALOG                     AGE
# toolhive-operator   ToolHive Operator Catalog   30s

# Inspect PackageManifest details
kubectl get packagemanifest -n openshift-marketplace toolhive-operator -o yaml | grep -A10 "channels:"
# Expected: Channel info with "fast" channel listed
```

**🎯 Key Success Indicator**: If PackageManifest exists with proper name and catalog, the CSV is correctly embedded!

### Verify OperatorHub UI Display

**Web UI Verification**:

1. Open OpenShift Console
2. Navigate to **Operators** → **OperatorHub**
3. Click **Sources** tab at the top
4. Look for **"ToolHive Operator Catalog"**

**Expected Results**:
- ✅ Catalog name shows as "ToolHive Operator Catalog" (NOT blank)
- ✅ Operator count shows as **(1)** (NOT 0)
- ✅ Catalog status shows as "Healthy" or similar

5. Return to **OperatorHub** search
6. Search for **"toolhive"**

**Expected Results**:
- ✅ "ToolHive Operator" appears in search results
- ✅ Operator has description text
- ✅ Operator has icon displayed

### Test Operator Installation (Optional)

```bash
# Create target namespace
kubectl create namespace toolhive-system

# Apply subscription
kubectl apply -f examples/subscription.yaml

# Wait for subscription to install operator
kubectl wait --for=jsonpath='{.status.state}'=AtLatestKnown \
  subscription/toolhive-operator \
  -n toolhive-system \
  --timeout=300s

# Verify ClusterServiceVersion created
kubectl get csv -n toolhive-system
# Expected: CSV shows SUCCEEDED status

# Verify operator pod running
kubectl get pods -n toolhive-system
# Expected: Operator pod in Running state
```

**✅ Checkpoint**: Operator installs successfully from updated catalog

---

## Step 6: Commit Changes

```bash
# Review changes
git status
git diff catalog/toolhive-operator/catalog.yaml | head -50
git diff examples/

# Stage changes
git add catalog/toolhive-operator/catalog.yaml
git add examples/catalogsource-olmv1.yaml
git add examples/subscription.yaml

# Commit with descriptive message
git commit -m "Fix OperatorHub availability by embedding CSV in catalog

- Regenerate catalog.yaml using 'opm render bundle/' to include CSV
- Update bundle image reference to quay.io/roddiekieley registry
- Update catalogsource-olmv1.yaml to use quay.io/roddiekieley catalog image
- Fix subscription.yaml sourceNamespace from 'olm' to 'openshift-marketplace'

Fixes OperatorHub display to show catalog name and operator count.
Resolves issue where catalog appeared with no name and zero operators.

Tested:
- opm validate passes
- PackageManifest created in openshift-marketplace
- OperatorHub UI shows 'ToolHive Operator Catalog' with '(1)' count
- Operator installs successfully via Subscription"

# Push branch
git push origin 007-fix-operatorhub-availability
```

**✅ Complete**: Changes committed and pushed

---

## Verification Checklist

Use this checklist to verify the fix is complete:

### Build/Validation
- [ ] `opm validate catalog/toolhive-operator` passes with no errors
- [ ] `grep -c "olm.bundle.object" catalog/toolhive-operator/catalog.yaml` returns 3
- [ ] `grep "quay.io/roddiekieley" catalog/toolhive-operator/catalog.yaml` finds bundle image
- [ ] `kustomize build config/default` succeeds
- [ ] `kustomize build config/base` succeeds
- [ ] `git diff config/crd/` shows no changes (CRDs immutable)

### Example Files
- [ ] `examples/catalogsource-olmv1.yaml` references `quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17`
- [ ] `examples/subscription.yaml` has `sourceNamespace: openshift-marketplace`
- [ ] No `ghcr.io/stacklok` references in `catalogsource-olmv1.yaml` or `subscription.yaml`

### Deployment (if cluster available)
- [ ] CatalogSource deploys and shows READY status
- [ ] PackageManifest `toolhive-operator` exists in openshift-marketplace namespace
- [ ] OperatorHub Sources shows "ToolHive Operator Catalog" with "(1)"
- [ ] OperatorHub search finds "ToolHive Operator" with description and icon
- [ ] Subscription installs operator successfully

---

## Troubleshooting

### Issue: opm validate fails

**Error**: `opm validate catalog/toolhive-operator` reports errors

**Solution**:
```bash
# Re-generate catalog from scratch
opm render bundle/ > catalog/toolhive-operator/catalog.yaml

# Update bundle image
sed -i 's|ghcr.io/stacklok/toolhive/bundle:v0.2.17|quay.io/roddiekieley/toolhive-operator-bundle:v0.2.17|g' \
  catalog/toolhive-operator/catalog.yaml

# Validate again
opm validate catalog/toolhive-operator
```

### Issue: PackageManifest not created

**Symptom**: `kubectl get packagemanifest toolhive-operator` returns "not found"

**Debugging**:
```bash
# Check catalog pod logs
kubectl logs -n openshift-marketplace -l olm.catalogSource=toolhive-catalog

# Look for errors like:
# - "Failed to decode CSV" → CSV encoding issue
# - "Invalid bundle" → Missing required fields

# Test catalog locally
podman run --rm -p 50051:50051 quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17
grpcurl -plaintext localhost:50051 api.Registry/ListPackages
# Should return toolhive-operator package
```

### Issue: OperatorHub shows zero operators

**Symptom**: Catalog appears in Sources but shows "(0)" operators

**Cause**: CSV not properly embedded in catalog.yaml

**Verification**:
```bash
# Check if olm.bundle.object exists
grep "olm.bundle.object" catalog/toolhive-operator/catalog.yaml
# If no match, CSV is missing

# Check file size
wc -l catalog/toolhive-operator/catalog.yaml
# If <100 lines, CSV is likely missing (should be 500-800 lines)
```

**Solution**: Regenerate catalog using Step 1

### Issue: Subscription fails with "catalog not found"

**Error**: Subscription status shows "NoCatalogSourcesFound"

**Cause**: Incorrect `sourceNamespace` in subscription.yaml

**Verification**:
```bash
# Check subscription sourceNamespace
kubectl get subscription toolhive-operator -n toolhive-system -o yaml | grep sourceNamespace

# Check where CatalogSource actually exists
kubectl get catalogsource --all-namespaces | grep toolhive
```

**Solution**: Update `sourceNamespace` to match CatalogSource namespace (openshift-marketplace)

---

## Next Steps

After completing this quickstart:

1. **Create Pull Request** with changes to main branch
2. **Document in README** how to regenerate catalog.yaml
3. **Add Makefile target** for automated catalog generation
4. **Update CI/CD** to validate catalog structure in tests
5. **Consider** adding pre-commit hooks for catalog validation

---

## Additional Resources

- **OLM v1 File-Based Catalog Spec**: https://olm.operatorframework.io/docs/reference/file-based-catalogs/
- **OPM CLI Reference**: https://olm.operatorframework.io/docs/reference/opm/
- **CatalogSource API**: https://olm.operatorframework.io/docs/concepts/crds/catalogsource/
- **Debugging Catalogs**: https://olm.operatorframework.io/docs/tasks/troubleshooting/olm-and-opm/

## Related Specifications

- [spec.md](spec.md) - Feature specification
- [research.md](research.md) - Technical research findings
- [data-model.md](data-model.md) - YAML structure definitions
- [contracts/catalog-yaml-structure.md](contracts/catalog-yaml-structure.md) - catalog.yaml contract
- [contracts/example-files-updates.md](contracts/example-files-updates.md) - Example files contract
