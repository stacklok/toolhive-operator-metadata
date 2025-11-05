# Containerfile Contract: OLMv0 Index Image

**Feature**: Registry Database Container Image (Index Image)
**Date**: 2025-10-10
**File**: `Containerfile.index.olmv0` (to be created at repository root)

## Purpose

Define the Containerfile specification for building an OLMv0 SQLite-based index image that references the existing OLMv0 bundle image. This index image is required for legacy OpenShift 4.15-4.18 deployments, as bundle images cannot be used directly in CatalogSource.

## Build Context

**Command**:
```bash
opm index add \
  --bundles ghcr.io/stacklok/toolhive/bundle:v0.2.17 \
  --tag ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17 \
  --mode semver
```

**Notes**:
- `opm index add` generates the index image internally
- No separate Containerfile is created - `opm` handles image building
- The command produces a complete, runnable index image with SQLite database and gRPC server

## Resulting Image Structure

```dockerfile
# Conceptual structure (managed by opm, not a literal Containerfile)

FROM quay.io/operator-framework/opm:latest

# SQLite database created at /database/index.db
# Contains:
# - package table (toolhive-operator)
# - channel table (fast)
# - bundle table (references ghcr.io/stacklok/toolhive/bundle:v0.2.17)
# - operatorbundle table (bundle metadata)
# - related_image table (operator image references)

LABEL operators.operatorframework.io.index.database.v1=/database/index.db

# Optional metadata labels
LABEL org.opencontainers.image.title="ToolHive Operator Index (OLMv0)"
LABEL org.opencontainers.image.description="SQLite-based operator index for legacy OpenShift (4.15-4.18)"
LABEL org.opencontainers.image.vendor="Stacklok"
LABEL org.opencontainers.image.source="https://github.com/RHEcosystemAppEng/toolhive-operator-metadata"
LABEL org.opencontainers.image.version="v0.2.17"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# OLM-specific labels (auto-added by opm)
LABEL operators.operatorframework.io.index.database.v1=/database/index.db

# ENTRYPOINT/CMD managed by opm base image
# Runs gRPC server serving the SQLite database
```

## Label Requirements

### Required Labels (auto-added by opm)

| Label | Value | Purpose |
|-------|-------|---------|
| `operators.operatorframework.io.index.database.v1` | `/database/index.db` | Tells OLM where to find the SQLite database |

### Optional Metadata Labels (can be added via `podman tag` or manual build)

| Label | Value | Purpose |
|-------|-------|---------|
| `org.opencontainers.image.title` | `ToolHive Operator Index (OLMv0)` | Human-readable image title |
| `org.opencontainers.image.description` | `SQLite-based operator index for legacy OpenShift (4.15-4.18)` | Image description |
| `org.opencontainers.image.vendor` | `Stacklok` | Organization name |
| `org.opencontainers.image.source` | `https://github.com/RHEcosystemAppEng/toolhive-operator-metadata` | Source repository |
| `org.opencontainers.image.version` | `v0.2.17` | Image version |
| `org.opencontainers.image.licenses` | `Apache-2.0` | License identifier |

**Note**: `opm index add` does not support adding custom labels. Metadata labels must be added via `podman image label` or by rebuilding with a custom Dockerfile.

## Build Parameters

### Input Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `BUNDLE_IMG` | OLMv0 bundle image to reference | `ghcr.io/stacklok/toolhive/bundle:v0.2.17` |
| `INDEX_OLMV0_IMG` | Target index image name and tag | `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17` |
| `OPM_MODE` | Index build mode | `semver` (recommended) or `replaces` |

### Build Command Template

```bash
opm index add \
  --bundles $(BUNDLE_IMG) \
  --tag $(INDEX_OLMV0_IMG) \
  --mode $(OPM_MODE) \
  --container-tool podman
```

**Flags Explained**:
- `--bundles`: Comma-separated list of bundle images to add to index
- `--tag`: Name and tag for the resulting index image
- `--mode`: How to calculate channel graph (`semver` uses semantic versioning, `replaces` uses CSV replaces field)
- `--container-tool`: Container runtime (podman or docker)

### Optional Flags

| Flag | Purpose | Example |
|------|---------|---------|
| `--from-index` | Base index to build upon (for adding versions) | `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.16` |
| `--binary-image` | Custom opm binary image | `quay.io/operator-framework/opm:v1.35.0` |
| `--permissive` | Allow schema validation errors (not recommended) | N/A |
| `--skip-tls-verify` | Skip TLS verification for bundle pull (not recommended) | N/A |

## Image Content

### Database Schema (SQLite)

The index image contains a SQLite database at `/database/index.db` with the following conceptual structure:

**package table**:
```
name               | default_channel | description
-------------------|-----------------|----------------------------------
toolhive-operator  | fast            | ToolHive Operator manages MCP...
```

**channel table**:
```
package_name       | name  | head_operatorbundle_name
-------------------|-------|---------------------------
toolhive-operator  | fast  | toolhive-operator.v0.2.17
```

**bundle (operatorbundle) table**:
```
name                      | package           | channel | bundlepath                           | csv_name                 | version
--------------------------|-------------------|---------|--------------------------------------|--------------------------|--------
toolhive-operator.v0.2.17 | toolhive-operator | fast    | ghcr.io/.../bundle:v0.2.17           | toolhive-operator.v0.2.17| 0.2.17
```

**related_image table**:
```
operatorbundle_name       | image
--------------------------|----------------------------------
toolhive-operator.v0.2.17 | ghcr.io/stacklok/toolhive/operator:v0.2.17
toolhive-operator.v0.2.17 | ghcr.io/stacklok/toolhive/proxyrunner:v0.2.17
```

### Runtime Behavior

When deployed via CatalogSource:
1. OpenShift/OLM creates a pod from the index image
2. Pod runs `opm` gRPC server serving the SQLite database
3. OLM queries the gRPC server for operator metadata
4. OLM displays the operator in OperatorHub
5. On installation, OLM pulls the bundle image to extract manifests

## Validation

### Pre-Build Validation

Validate the bundle image before adding to index:

```bash
operator-sdk bundle validate ghcr.io/stacklok/toolhive/bundle:v0.2.17
```

**Expected output**:
```
✅ All validation tests have completed successfully
```

### Post-Build Validation

Validate the index image after creation:

```bash
# Method 1: Export package list (proves database is queryable)
opm index export \
  --index=ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17 \
  --package=toolhive-operator

# Expected output: Package manifest YAML
```

```bash
# Method 2: Inspect database content
podman run --rm \
  ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17 \
  /bin/sh -c "ls -lh /database/"

# Expected output: index.db file present
```

## Deprecation Notice

```
⚠️ DEPRECATION NOTICE

SQLite-based index images are DEPRECATED by operator-framework.
Support will be removed in a future release.

Use this index image ONLY for legacy OpenShift 4.15-4.18 deployments.
For modern OpenShift 4.19+, use the File-Based Catalog approach (OLMv1).

Migration path: When OpenShift 4.15-4.18 reach end-of-life, discontinue
building OLMv0 index images and remove from build pipeline.
```

## Example Build Session

```bash
# Set variables
export BUNDLE_IMG=ghcr.io/stacklok/toolhive/bundle:v0.2.17
export INDEX_OLMV0_IMG=ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17

# Validate bundle before indexing
operator-sdk bundle validate $BUNDLE_IMG

# Build index image
opm index add \
  --bundles $BUNDLE_IMG \
  --tag $INDEX_OLMV0_IMG \
  --mode semver \
  --container-tool podman

# Output:
# INFO[0000] building the index                           bundles="[ghcr.io/stacklok/toolhive/bundle:v0.2.17]"
# INFO[0000] running /usr/bin/podman pull ghcr.io/stacklok/toolhive/bundle:v0.2.17
# INFO[0002] running /usr/bin/podman build -f /tmp/... -t ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
# INFO[0005] [podman build output...]
# INFO[0010] successfully built index image ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17

# Validate index
opm index export \
  --index=$INDEX_OLMV0_IMG \
  --package=toolhive-operator

# Output:
# ---
# apiVersion: packages.operators.coreos.com/v1
# kind: PackageManifest
# metadata:
#   name: toolhive-operator
# spec:
#   channels:
#   - name: fast
#     currentCSV: toolhive-operator.v0.2.17
# ...

# Tag as latest
podman tag $INDEX_OLMV0_IMG ghcr.io/stacklok/toolhive/index-olmv0:latest

# Push to registry
podman push $INDEX_OLMV0_IMG
podman push ghcr.io/stacklok/toolhive/index-olmv0:latest
```

## Integration with CatalogSource

The resulting index image is referenced in a CatalogSource:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-catalog-olmv0
  namespace: olm
spec:
  sourceType: grpc
  image: ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
  displayName: ToolHive Operator Catalog (OLMv0)
  publisher: Stacklok
  updateStrategy:
    registryPoll:
      interval: 30m
```

**Behavior**:
1. OpenShift pulls `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17`
2. Creates pod running `opm` gRPC server
3. OLM queries server for operator metadata
4. Operator appears in OperatorHub under "ToolHive Operator Catalog (OLMv0)"

## Multi-Version Support (Future Enhancement)

To add additional operator versions to the index:

```bash
# Build initial index
opm index add \
  --bundles ghcr.io/stacklok/toolhive/bundle:v0.2.17 \
  --tag ghcr.io/stacklok/toolhive/index-olmv0:v1

# Add second version
opm index add \
  --bundles ghcr.io/stacklok/toolhive/bundle:v0.3.0 \
  --from-index ghcr.io/stacklok/toolhive/index-olmv0:v1 \
  --tag ghcr.io/stacklok/toolhive/index-olmv0:v2

# The resulting index contains both v0.2.17 and v0.3.0
```

**Note**: Current scope focuses on single-version index (v0.2.17 only).

## References

- **OLM Index Documentation**: https://github.com/operator-framework/operator-registry/blob/master/docs/design/opm-tooling.md
- **opm CLI Reference**: `opm index add --help`
- **Bundle Image**: [Containerfile.bundle](../../../Containerfile.bundle)
- **CatalogSource Example**: To be created at `examples/catalogsource-olmv0.yaml`

## Summary

This contract defines the **build process** for OLMv0 index images using `opm index add`. Unlike Containerfiles that define image layers explicitly, this contract specifies:

1. The `opm` command that generates the index image
2. Required input variables (bundle image reference)
3. Expected database structure and content
4. Validation procedures
5. CatalogSource integration pattern
6. Deprecation acknowledgment for temporary legacy support

The resulting index image is a complete, runnable container that serves operator metadata via gRPC for legacy OpenShift 4.15-4.18 deployments.
