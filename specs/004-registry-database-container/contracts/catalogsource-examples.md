# CatalogSource Examples Contract

**Feature**: Registry Database Container Image (Index Image)
**Date**: 2025-10-10
**Files**:
- `examples/catalogsource-olmv1.yaml` (rename from `catalogsource.yaml`)
- `examples/catalogsource-olmv0.yaml` (new)

## Purpose

Define CatalogSource manifest specifications for both OLMv1 (File-Based Catalog) and OLMv0 (SQLite Index) deployments. These examples guide administrators in deploying the ToolHive operator on different OpenShift versions.

## File 1: `examples/catalogsource-olmv1.yaml`

### Purpose
CatalogSource for modern OpenShift 4.19+ using OLMv1 File-Based Catalog image.

### Full Manifest

```yaml
---
# CatalogSource for ToolHive Operator (OLMv1 - Modern OpenShift 4.19+)
#
# This CatalogSource references a File-Based Catalog (FBC) image for modern
# OpenShift deployments. FBC is the recommended catalog format for OLM.
#
# Prerequisites:
#   - OpenShift 4.19+ or Kubernetes with OLM v1 installed
#   - Catalog image available: ghcr.io/stacklok/toolhive/catalog:v0.2.17
#
# Usage:
#   kubectl apply -f examples/catalogsource-olmv1.yaml
#
# Verification:
#   kubectl get catalogsource -n olm toolhive-catalog
#   kubectl get packagemanifest | grep toolhive
#   # The operator should appear in the OpenShift OperatorHub UI

apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-catalog
  namespace: olm
spec:
  # Source type: grpc (image-based catalog served via gRPC API)
  sourceType: grpc

  # Catalog image: OLMv1 File-Based Catalog
  # This image contains FBC metadata in /configs directory
  image: ghcr.io/stacklok/toolhive/catalog:v0.2.17

  # Display name shown in OperatorHub
  displayName: ToolHive Operator Catalog

  # Publisher organization
  publisher: Stacklok

  # Update strategy: poll registry every 15 minutes for image updates
  # OLM will automatically pull newer catalog images when available
  updateStrategy:
    registryPoll:
      interval: 15m

  # Optional: icon for OperatorHub (base64-encoded PNG/SVG)
  # icon:
  #   base64data: <base64-encoded-image>
  #   mediatype: image/png

  # Optional: priority for conflict resolution (default: 0, higher = preferred)
  # priority: 100
```

### Key Attributes

| Field | Value | Purpose |
|-------|-------|---------|
| `metadata.name` | `toolhive-catalog` | Unique catalog identifier |
| `metadata.namespace` | `olm` | Standard OLM namespace for catalog sources |
| `spec.sourceType` | `grpc` | Image-based catalog served via gRPC |
| `spec.image` | `ghcr.io/stacklok/toolhive/catalog:v0.2.17` | OLMv1 FBC catalog image |
| `spec.displayName` | `ToolHive Operator Catalog` | Human-readable name in OperatorHub |
| `spec.publisher` | `Stacklok` | Organization name |
| `spec.updateStrategy.registryPoll.interval` | `15m` | Check for updates every 15 minutes |

### Image Reference Explanation

**Image**: `ghcr.io/stacklok/toolhive/catalog:v0.2.17`
- **Registry**: `ghcr.io` (GitHub Container Registry)
- **Organization**: `stacklok`
- **Repository**: `toolhive/catalog`
- **Tag**: `v0.2.17` (operator version)

**Alternative tags**:
- `latest`: Rolling tag, always points to newest release (use with caution in production)
- `v0.2.17`: Specific version, immutable (recommended for production)

### Deployment Instructions

**Step 1: Verify prerequisites**
```bash
# Check OpenShift version (must be 4.19+)
oc version

# Check OLM installation
kubectl get deployment -n olm olm-operator
```

**Step 2: Apply CatalogSource**
```bash
kubectl apply -f examples/catalogsource-olmv1.yaml
```

**Step 3: Verify CatalogSource**
```bash
# Check CatalogSource status
kubectl get catalogsource -n olm toolhive-catalog

# Expected output:
# NAME               DISPLAY                    TYPE   PUBLISHER   AGE
# toolhive-catalog   ToolHive Operator Catalog  grpc   Stacklok    1m

# Verify catalog pod is running
kubectl get pods -n olm | grep toolhive-catalog

# Expected output:
# toolhive-catalog-xxxxx   1/1     Running   0          1m
```

**Step 4: Verify operator availability**
```bash
# Check if operator appears in package manifests
kubectl get packagemanifest | grep toolhive

# Expected output:
# toolhive-operator   ToolHive Operator Catalog   1m
```

**Step 5: Install operator (optional)**
```bash
# Via OpenShift Console:
# - Navigate to OperatorHub
# - Search for "ToolHive"
# - Click "Install"

# Via CLI (create Subscription):
cat <<EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: toolhive-operator
  namespace: opendatahub
spec:
  channel: fast
  name: toolhive-operator
  source: toolhive-catalog
  sourceNamespace: olm
EOF
```

### Troubleshooting

**Issue**: CatalogSource stuck in "Pending" state
```bash
# Check pod events
kubectl describe catalogsource -n olm toolhive-catalog

# Check pod logs
kubectl logs -n olm -l olm.catalogSource=toolhive-catalog
```

**Common causes**:
- Image pull authentication failure (ghcr.io requires auth for private repos)
- Image doesn't exist or tag is incorrect
- Network connectivity issues

**Resolution**:
```bash
# For private images, create pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-token> \
  -n olm

# Reference secret in CatalogSource (add to spec:)
# spec:
#   secrets:
#   - ghcr-secret
```

---

## File 2: `examples/catalogsource-olmv0.yaml`

### Purpose
CatalogSource for legacy OpenShift 4.15-4.18 using OLMv0 SQLite-based index image.

### Full Manifest

```yaml
---
# CatalogSource for ToolHive Operator (OLMv0 - Legacy OpenShift 4.15-4.18)
#
# ⚠️  DEPRECATION NOTICE
# This CatalogSource uses a SQLite-based index image (OLMv0), which is
# deprecated by operator-framework. Use only for legacy OpenShift versions.
# For modern OpenShift 4.19+, use catalogsource-olmv1.yaml instead.
#
# This CatalogSource references an OLMv0 index image that wraps the bundle
# image. Bundle images cannot be used directly in CatalogSource - they must
# be referenced through an index image.
#
# Prerequisites:
#   - OpenShift 4.15-4.18 or Kubernetes with OLM v0
#   - Index image available: ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
#
# Usage:
#   kubectl apply -f examples/catalogsource-olmv0.yaml
#
# Verification:
#   kubectl get catalogsource -n olm toolhive-catalog-olmv0
#   kubectl get packagemanifest | grep toolhive
#   # The operator should appear in the OpenShift OperatorHub UI

apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-catalog-olmv0
  namespace: olm
spec:
  # Source type: grpc (image-based catalog served via gRPC API)
  sourceType: grpc

  # Index image: OLMv0 SQLite-based index (DEPRECATED)
  # This image contains a SQLite database at /database/index.db
  # The database references the bundle image: ghcr.io/stacklok/toolhive/bundle:v0.2.17
  image: ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17

  # Display name shown in OperatorHub (indicates OLMv0 format)
  displayName: ToolHive Operator Catalog (Legacy)

  # Publisher organization
  publisher: Stacklok

  # Update strategy: poll registry every 30 minutes for image updates
  # Longer interval than OLMv1 since this is for legacy deployments
  updateStrategy:
    registryPoll:
      interval: 30m

  # Optional: icon for OperatorHub (base64-encoded PNG/SVG)
  # icon:
  #   base64data: <base64-encoded-image>
  #   mediatype: image/png

  # Optional: priority for conflict resolution (default: 0, higher = preferred)
  # Set lower priority than OLMv1 catalog to prefer modern deployments
  # priority: 50
```

### Key Attributes

| Field | Value | Purpose |
|-------|-------|---------|
| `metadata.name` | `toolhive-catalog-olmv0` | Unique catalog identifier (includes format) |
| `metadata.namespace` | `olm` | Standard OLM namespace for catalog sources |
| `spec.sourceType` | `grpc` | Image-based catalog served via gRPC |
| `spec.image` | `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17` | OLMv0 SQLite index image |
| `spec.displayName` | `ToolHive Operator Catalog (Legacy)` | Indicates legacy format |
| `spec.publisher` | `Stacklok` | Organization name |
| `spec.updateStrategy.registryPoll.interval` | `30m` | Check for updates every 30 minutes |

### Image Reference Explanation

**Image**: `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17`
- **Registry**: `ghcr.io` (GitHub Container Registry)
- **Organization**: `stacklok`
- **Repository**: `toolhive/index-olmv0` (explicit format in name)
- **Tag**: `v0.2.17` (operator version)

**Image contents**:
- SQLite database at `/database/index.db`
- Reference to bundle image: `ghcr.io/stacklok/toolhive/bundle:v0.2.17`
- `opm` binary for serving gRPC API

**Alternative tags**:
- `latest`: Rolling tag (use with caution)
- `v0.2.17`: Specific version (recommended)

### Deployment Instructions

**Step 1: Verify prerequisites**
```bash
# Check OpenShift version (must be 4.15-4.18)
oc version

# Check OLM installation
kubectl get deployment -n olm olm-operator
```

**Step 2: Apply CatalogSource**
```bash
kubectl apply -f examples/catalogsource-olmv0.yaml
```

**Step 3: Verify CatalogSource**
```bash
# Check CatalogSource status
kubectl get catalogsource -n olm toolhive-catalog-olmv0

# Expected output:
# NAME                     DISPLAY                           TYPE   PUBLISHER   AGE
# toolhive-catalog-olmv0   ToolHive Operator Catalog (Legacy)  grpc   Stacklok    1m

# Verify catalog pod is running
kubectl get pods -n olm | grep toolhive-catalog-olmv0

# Expected output:
# toolhive-catalog-olmv0-xxxxx   1/1     Running   0          1m
```

**Step 4: Verify operator availability**
```bash
# Check if operator appears in package manifests
kubectl get packagemanifest | grep toolhive

# Expected output:
# toolhive-operator   ToolHive Operator Catalog (Legacy)   1m
```

**Step 5: Install operator (optional)**
```bash
# Via OpenShift Console:
# - Navigate to OperatorHub
# - Search for "ToolHive"
# - Click "Install"

# Via CLI (create Subscription):
cat <<EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: toolhive-operator
  namespace: opendatahub
spec:
  channel: fast
  name: toolhive-operator
  source: toolhive-catalog-olmv0
  sourceNamespace: olm
EOF
```

### Deprecation Notice

```
⚠️  DEPRECATION NOTICE

SQLite-based index images (OLMv0) are DEPRECATED by operator-framework.
Support will be removed in a future OLM release.

Usage Guidelines:
- Use ONLY for OpenShift 4.15-4.18 (legacy versions)
- Migrate to OLMv1 (catalogsource-olmv1.yaml) for OpenShift 4.19+
- Plan to sunset OLMv0 support when OpenShift 4.18 reaches end-of-life

Migration Timeline:
- OpenShift 4.15: EOL Q2 2025
- OpenShift 4.16: EOL Q3 2025
- OpenShift 4.17: EOL Q4 2025
- OpenShift 4.18: EOL Q1 2026

After EOL, discontinue building OLMv0 index images and remove this example.
```

---

## File Changes Summary

### Rename Existing File

**From**: `examples/catalogsource.yaml`
**To**: `examples/catalogsource-olmv1.yaml`

**Rationale**: Clarify format and distinguish from OLMv0 variant.

**Git command**:
```bash
git mv examples/catalogsource.yaml examples/catalogsource-olmv1.yaml
```

### Create New File

**File**: `examples/catalogsource-olmv0.yaml`

**Purpose**: Provide example for legacy OpenShift deployments using OLMv0 index.

### Update Documentation

Update `README.md` or `VALIDATION.md` to reference:
- `catalogsource-olmv1.yaml` for modern deployments
- `catalogsource-olmv0.yaml` for legacy deployments

---

## Testing

### OLMv1 CatalogSource Testing

```bash
# Apply CatalogSource
kubectl apply -f examples/catalogsource-olmv1.yaml

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod -l olm.catalogSource=toolhive-catalog -n olm --timeout=60s

# Verify package manifest
kubectl get packagemanifest toolhive-operator -o yaml

# Expected: metadata.labels.catalog = "toolhive-catalog"

# Cleanup
kubectl delete -f examples/catalogsource-olmv1.yaml
```

### OLMv0 CatalogSource Testing

```bash
# Apply CatalogSource
kubectl apply -f examples/catalogsource-olmv0.yaml

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod -l olm.catalogSource=toolhive-catalog-olmv0 -n olm --timeout=60s

# Verify package manifest
kubectl get packagemanifest toolhive-operator -o yaml

# Expected: metadata.labels.catalog = "toolhive-catalog-olmv0"

# Cleanup
kubectl delete -f examples/catalogsource-olmv0.yaml
```

### Conflict Testing (Ensure No Mixing)

```bash
# Apply both CatalogSources simultaneously (should work without conflict)
kubectl apply -f examples/catalogsource-olmv1.yaml
kubectl apply -f examples/catalogsource-olmv0.yaml

# Verify both catalogs are running
kubectl get catalogsource -n olm

# Expected:
# NAME                     DISPLAY                           TYPE   PUBLISHER   AGE
# toolhive-catalog         ToolHive Operator Catalog         grpc   Stacklok    1m
# toolhive-catalog-olmv0   ToolHive Operator Catalog (Legacy)  grpc   Stacklok    1m

# Verify operator appears from both catalogs
kubectl get packagemanifest toolhive-operator -o jsonpath='{.status.catalogSource}'

# Expected: One of the catalog names (OLM chooses based on priority/availability)

# Cleanup
kubectl delete -f examples/catalogsource-olmv1.yaml
kubectl delete -f examples/catalogsource-olmv0.yaml
```

---

## References

- **OLM CatalogSource API**: https://olm.operatorframework.io/docs/concepts/crds/catalogsource/
- **OLMv1 Catalog Image**: [Containerfile.catalog](../../../Containerfile.catalog)
- **OLMv0 Index Build**: [contracts/containerfile-index-olmv0.md](./containerfile-index-olmv0.md)
- **Makefile Targets**: [contracts/makefile-targets.md](./makefile-targets.md)

---

## Summary

This contract defines two CatalogSource examples:

1. **catalogsource-olmv1.yaml**: Modern deployment using File-Based Catalog (OpenShift 4.19+)
2. **catalogsource-olmv0.yaml**: Legacy deployment using SQLite index (OpenShift 4.15-4.18)

Key differences:
- **Image reference**: `catalog` vs `index-olmv0`
- **Display name**: Standard vs "Legacy" designation
- **Poll interval**: 15m vs 30m (modern vs legacy)
- **Metadata naming**: Simple vs format-explicit (`toolhive-catalog` vs `toolhive-catalog-olmv0`)

Both examples provide clear documentation, deployment instructions, verification steps, and troubleshooting guidance to help administrators deploy the ToolHive operator on their OpenShift version.
