# Contract: Example Files Updates

**Feature**: 007-fix-operatorhub-availability
**Purpose**: Define required updates to example deployment manifests

## Overview

Example files in the `examples/` directory must be updated to:
1. Reference development registry (quay.io/roddiekieley) instead of production (ghcr.io/stacklok)
2. Use correct namespace references for OpenShift deployment
3. Remain deployable without modifications

---

## File 1: examples/catalogsource-olmv1.yaml

**Purpose**: Deploy File-Based Catalog to OpenShift cluster

### Required Changes

#### Change 1: Update Catalog Image

**Field**: `spec.image`
**Current Value**:
```yaml
spec:
  image: ghcr.io/stacklok/toolhive/catalog:v0.2.17
```

**Target Value**:
```yaml
spec:
  image: quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17
```

**Rationale**: Development builds push to quay.io/roddiekieley registry. Examples should reflect actual build artifacts.

**Impact**: Users deploying from this repository will pull the correct development image.

### No Changes Required

These fields are already correct:
- ✅ `metadata.namespace: openshift-marketplace` - Correct for OpenShift community catalogs
- ✅ `spec.displayName: ToolHive Operator Catalog` - Appropriate display name
- ✅ `spec.sourceType: grpc` - Correct for FBC with registry-server
- ✅ `spec.publisher: Stacklok` - Correct publisher

### Validation

```bash
# Extract image reference
grep "image:" examples/catalogsource-olmv1.yaml | grep -v "^#"

# Expected output:
#   image: quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17
```

### Full Expected Content (spec section)

```yaml
spec:
  # Source type for executable catalog with registry-server
  sourceType: grpc

  # Catalog image with integrated registry-server
  # This image runs 'opm serve /configs --cache-dir=/tmp/cache'
  image: quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17

  # Display name shown in OperatorHub UI
  displayName: ToolHive Operator Catalog

  # Publisher information
  publisher: Stacklok

  # Update strategy - poll registry for new versions
  updateStrategy:
    registryPoll:
      interval: 30m  # Check for updates every 30 minutes

  # Priority for catalog (higher priority = preferred)
  # Default: 0, range: -100 to 100
  priority: 0
```

---

## File 2: examples/subscription.yaml

**Purpose**: Install ToolHive Operator from deployed catalog

### Required Changes

#### Change 1: Fix Source Namespace

**Field**: `spec.sourceNamespace`
**Current Value**:
```yaml
spec:
  sourceNamespace: olm
```

**Target Value**:
```yaml
spec:sourceNamespace: openshift-marketplace
```

**Rationale**:
- The CatalogSource is deployed to `openshift-marketplace` namespace (per catalogsource-olmv1.yaml)
- The Subscription must reference the same namespace where the CatalogSource exists
- The value "olm" is incorrect and causes subscription failures

**Impact**: Subscription will successfully locate and install the operator.

**Error Without Fix**:
```
status:
  conditions:
  - message: CatalogSource toolhive-catalog in namespace olm not found
    reason: NoCatalogSourcesFound
    status: "True"
    type: CatalogSourcesUnhealthy
```

### No Changes Required

These fields are already correct:
- ✅ `metadata.namespace: toolhive-system` - Appropriate target namespace for operator
- ✅ `spec.channel: fast` - Matches channel defined in catalog
- ✅ `spec.name: toolhive-operator` - Matches package name
- ✅ `spec.source: toolhive-catalog` - Matches CatalogSource name
- ✅ `spec.installPlanApproval: Automatic` - Appropriate default

### Validation

```bash
# Extract sourceNamespace
grep "sourceNamespace:" examples/subscription.yaml | grep -v "^#"

# Expected output:
#   sourceNamespace: openshift-marketplace
```

### Full Expected Content (spec section)

```yaml
spec:
  channel: fast
  name: toolhive-operator
  source: toolhive-catalog
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
```

---

## File 3: examples/catalogsource-olmv0.yaml

**Purpose**: Deploy legacy OLMv0 index for older OpenShift versions (4.15-4.18)

### Scope

This file is out of scope for the current feature. Changes:
- ⚠️ **Consider updating** image reference to quay.io/roddiekieley registry for consistency
- ❌ **Not required** for fixing OperatorHub availability (OLMv1 focus)

### Recommended Future Update

```yaml
spec:
  image: quay.io/roddiekieley/toolhive-operator-index-olmv0:v0.2.17
```

---

## Contract Summary

### Files Modified: 2

1. **examples/catalogsource-olmv1.yaml**
   - Change `spec.image` to quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17

2. **examples/subscription.yaml**
   - Change `spec.sourceNamespace` to openshift-marketplace

### Files Unchanged: 1

1. **examples/catalogsource-olmv0.yaml** - Out of scope (legacy OLMv0)

### Validation Commands

```bash
# Verify no ghcr.io references in OLMv1 examples
grep -E "ghcr\.io|stacklok" examples/catalogsource-olmv1.yaml
# Expected: no matches

# Verify correct sourceNamespace
grep "sourceNamespace: openshift-marketplace" examples/subscription.yaml
# Expected: match found

# Verify examples deploy successfully (requires cluster)
kubectl apply -f examples/catalogsource-olmv1.yaml
kubectl apply -f examples/subscription.yaml
# Expected: resources created
```

### Success Criteria

The example files are considered correct when:

1. ✅ catalogsource-olmv1.yaml references quay.io/roddiekieley registry
2. ✅ subscription.yaml has sourceNamespace: openshift-marketplace
3. ✅ No ghcr.io/stacklok references remain in OLMv1 example files
4. ✅ Deployment succeeds without manual file edits
5. ✅ Subscription successfully locates and installs operator

### Breaking Changes

- **None**: These are documentation/example files, not deployed resources
- Users who previously copied examples and deployed must update their deployments manually
- New users get correct examples immediately

### Backward Compatibility

- ✅ **API compatibility**: No changes to Kubernetes API contracts
- ✅ **Deployment compatibility**: Updated examples work on same OpenShift versions
- ⚠️ **Image availability**: Requires images to exist in quay.io/roddiekieley registry
- ⚠️ **Registry access**: Users must have network access to quay.io (not ghcr.io)

### Testing Strategy

1. **Linting**: YAML syntax validation
   ```bash
   yamllint examples/catalogsource-olmv1.yaml examples/subscription.yaml
   ```

2. **Deployment test** (requires OpenShift cluster):
   ```bash
   # Deploy catalog
   oc apply -f examples/catalogsource-olmv1.yaml

   # Wait for catalog ready
   oc wait --for=condition=Ready catalogsource/toolhive-catalog -n openshift-marketplace --timeout=60s

   # Verify PackageManifest created
   oc get packagemanifest toolhive-operator -n openshift-marketplace

   # Deploy subscription
   oc create namespace toolhive-system
   oc apply -f examples/subscription.yaml

   # Wait for operator installation
   oc wait --for=jsonpath='{.status.state}'=AtLatestKnown subscription/toolhive-operator -n toolhive-system --timeout=300s

   # Verify CSV created
   oc get csv -n toolhive-system
   ```

3. **OperatorHub UI verification**:
   - Navigate to OperatorHub in OpenShift Console
   - Click "Sources" tab
   - Verify "ToolHive Operator Catalog" shows with "(1)"
   - Search for "toolhive"
   - Verify operator appears with description and icon

### Edge Cases Handled

- **Registry authentication**: Examples assume public image pulls (adjust with imagePullSecrets if needed)
- **Namespace pre-creation**: Subscription example assumes toolhive-system namespace exists
- **Multiple catalog versions**: CatalogSource name includes version, allowing side-by-side deployment
- **Namespace mismatch**: Correcting sourceNamespace prevents "catalog not found" errors
