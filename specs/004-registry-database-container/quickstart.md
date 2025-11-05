# Quickstart Guide: Building and Deploying Index Images

**Feature**: Registry Database Container Image (Index Image)
**Date**: 2025-10-10
**Audience**: Build engineers, release managers, OpenShift administrators

## Overview

This guide walks you through building, validating, and deploying operator registry index/catalog images for the ToolHive operator. Based on research findings, the approach differs for modern (OpenShift 4.19+) vs legacy (OpenShift 4.15-4.18) deployments.

## Prerequisites

### Required Tools

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| `opm` | v1.35.0+ | Build and validate index/catalog images | [Install guide](https://github.com/operator-framework/operator-registry/releases) |
| `podman` | 4.0+ | Container builds and registry operations | `dnf install podman` (Fedora/RHEL) |
| `yq` | 4.0+ | YAML parsing (optional, for validation output) | `pip install yq` |
| `kubectl` | 1.21+ | Kubernetes cluster operations | [Install guide](https://kubernetes.io/docs/tasks/tools/) |

**Verify installation**:
```bash
opm version        # Should show version info
podman --version   # Should show 4.x+
yq --version       # Should show 4.x+
kubectl version    # Should show client version
```

### Access Requirements

- **Container registry**: Write access to `ghcr.io/stacklok/toolhive/` namespace
- **Kubernetes cluster**: OpenShift 4.15+ or Kubernetes with OLM installed
- **Cluster permissions**: Ability to create CatalogSource resources in `olm` namespace

### Existing Images (from previous specs)

- **OLMv1 catalog**: `ghcr.io/stacklok/toolhive/catalog:v0.2.17` (spec 001)
- **OLMv0 bundle**: `ghcr.io/stacklok/toolhive/bundle:v0.2.17` (spec 002)

---

## Scenario 1: Modern OpenShift (4.19+) - OLMv1 File-Based Catalog

### Summary

**Good news**: The OLMv1 catalog image from spec 001 is **already a complete catalog/index image**. No additional wrapper needed!

### What You Already Have

```bash
# The existing catalog image IS the index/catalog image
IMAGE=ghcr.io/stacklok/toolhive/catalog:v0.2.17
```

This image contains:
- File-Based Catalog (FBC) metadata in `/configs/` directory
- Label `operators.operatorframework.io.index.configs.v1=/configs`
- Everything needed for CatalogSource consumption

### Validation (Optional)

Validate the existing catalog image:

```bash
# Validate FBC structure
opm validate catalog/

# Expected output:
# Validation successful
```

### Deployment

**Step 1: Create CatalogSource**

```bash
# Use the provided example
kubectl apply -f examples/catalogsource-olmv1.yaml
```

**Step 2: Verify CatalogSource**

```bash
# Check CatalogSource status
kubectl get catalogsource -n olm toolhive-catalog

# Expected output:
# NAME               DISPLAY                    TYPE   PUBLISHER   AGE
# toolhive-catalog   ToolHive Operator Catalog  grpc   Stacklok    30s

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod \
  -l olm.catalogSource=toolhive-catalog \
  -n olm --timeout=2m
```

**Step 3: Verify operator availability**

```bash
# Check package manifest
kubectl get packagemanifest toolhive-operator

# Expected output:
# NAME                CATALOG                    AGE
# toolhive-operator   ToolHive Operator Catalog  1m
```

**Step 4: View in OperatorHub**

- Navigate to OpenShift Console → OperatorHub
- Search for "ToolHive"
- Operator should appear with description and install button

### Installation

**Option A: Via OpenShift Console**
1. OperatorHub → Search "ToolHive" → Click "Install"
2. Select update channel: `fast`
3. Select install namespace: `opendatahub`
4. Click "Install"

**Option B: Via CLI**

```bash
# Create Subscription
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
  installPlanApproval: Automatic
EOF

# Monitor installation
kubectl get csv -n opendatahub -w
```

### Cleanup

```bash
# Remove CatalogSource
kubectl delete -f examples/catalogsource-olmv1.yaml

# Remove Subscription (if installed)
kubectl delete subscription toolhive-operator -n opendatahub

# Remove CSV (if installed)
kubectl delete csv -n opendatahub -l operators.coreos.com/toolhive-operator.opendatahub
```

---

## Scenario 2: Legacy OpenShift (4.15-4.18) - OLMv0 SQLite Index

### Summary

For legacy OpenShift, you need to create an OLMv0 index image that wraps the existing bundle image. This uses **deprecated** `opm index add` commands but is necessary for backward compatibility.

### Step 1: Build OLMv0 Index Image

**Set variables**:
```bash
export BUNDLE_IMG=ghcr.io/stacklok/toolhive/bundle:v0.2.17
export INDEX_OLMV0_IMG=ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
```

**Build using Makefile**:
```bash
make index-olmv0-build
```

**Or build manually**:
```bash
opm index add \
  --bundles $BUNDLE_IMG \
  --tag $INDEX_OLMV0_IMG \
  --mode semver \
  --container-tool podman
```

**Expected output**:
```
⚠️  Building OLMv0 index image (SQLite-based, deprecated)
   Use only for legacy OpenShift 4.15-4.18 compatibility

Building index referencing bundle: ghcr.io/stacklok/toolhive/bundle:v0.2.17
INFO[0000] building the index                           bundles="[...]"
INFO[0000] running /usr/bin/podman pull ghcr.io/stacklok/toolhive/bundle:v0.2.17
INFO[0002] running /usr/bin/podman build...
INFO[0010] successfully built index image ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17

✅ OLMv0 index image built: ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
```

### Step 2: Validate Index Image

**Using Makefile**:
```bash
make index-olmv0-validate
```

**Or validate manually**:
```bash
# Export package manifest from index
opm index export \
  --index=$INDEX_OLMV0_IMG \
  --package=toolhive-operator > /tmp/index-export.yaml

# Inspect package manifest
yq eval '.metadata.name, .spec.channels[].name, .spec.channels[].currentCSV' \
  /tmp/index-export.yaml
```

**Expected output**:
```
Validating OLMv0 index image...
✅ OLMv0 index validation passed

Package summary:
toolhive-operator
fast
toolhive-operator.v0.2.17
```

### Step 3: Push Index Image

**Authenticate to registry**:
```bash
# Using GitHub token
echo $GITHUB_TOKEN | podman login ghcr.io -u $GITHUB_USERNAME --password-stdin
```

**Push using Makefile**:
```bash
make index-olmv0-push
```

**Or push manually**:
```bash
podman push $INDEX_OLMV0_IMG
podman tag $INDEX_OLMV0_IMG ghcr.io/stacklok/toolhive/index-olmv0:latest
podman push ghcr.io/stacklok/toolhive/index-olmv0:latest
```

**Expected output**:
```
Pushing OLMv0 index image to ghcr.io...
Getting image source signatures
Copying blob abc123def456 done
Writing manifest to image destination
✅ OLMv0 index image pushed
```

### Step 4: Deploy to Legacy OpenShift

**Create CatalogSource**:
```bash
kubectl apply -f examples/catalogsource-olmv0.yaml
```

**Verify CatalogSource**:
```bash
# Check status
kubectl get catalogsource -n olm toolhive-catalog-olmv0

# Wait for pod
kubectl wait --for=condition=Ready pod \
  -l olm.catalogSource=toolhive-catalog-olmv0 \
  -n olm --timeout=2m

# Verify package manifest
kubectl get packagemanifest toolhive-operator
```

### Step 5: Install Operator

Same as OLMv1, but use `source: toolhive-catalog-olmv0`:

```bash
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
  installPlanApproval: Automatic
EOF
```

### Complete Workflow (All Steps)

Use the `index-olmv0-all` target for the complete workflow:

```bash
# Build, validate, and push in one command
make index-olmv0-all
```

---

## Scenario 3: Validate Both Formats

### Cross-Format Validation

Validate both OLMv1 (catalog) and OLMv0 (index) images:

```bash
make index-validate-all
```

**Expected output**:
```
Validating FBC catalog...
✅ FBC catalog validation passed

Validating OLMv0 index image...
✅ OLMv0 index validation passed

=========================================
✅ All index/catalog validations passed
=========================================

Validated:
  ✅ OLMv1 FBC Catalog (modern OpenShift 4.19+)
  ✅ OLMv0 SQLite Index (legacy OpenShift 4.15-4.18)
```

---

## Troubleshooting

### Issue: `opm: command not found`

**Solution**:
```bash
# Download opm binary
OPM_VERSION=v1.35.0
OS=linux
ARCH=amd64

curl -L https://github.com/operator-framework/operator-registry/releases/download/${OPM_VERSION}/${OS}-${ARCH}-opm \
  -o /usr/local/bin/opm

chmod +x /usr/local/bin/opm
opm version
```

### Issue: `Error: error adding bundle: unauthorized`

**Solution**:
```bash
# Authenticate to ghcr.io
podman login ghcr.io
# Enter GitHub username and personal access token
```

### Issue: CatalogSource pod in CrashLoopBackOff

**Diagnosis**:
```bash
# Check pod logs
kubectl logs -n olm -l olm.catalogSource=toolhive-catalog

# Check events
kubectl describe catalogsource -n olm toolhive-catalog
```

**Common causes**:
- Image pull failure (authentication)
- Corrupted catalog/index image
- Resource limits too low

**Solution**:
```bash
# For image pull errors, add pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_TOKEN \
  -n olm

# Update CatalogSource to reference secret (edit and add):
# spec:
#   secrets:
#   - ghcr-secret
```

### Issue: Operator not appearing in OperatorHub

**Diagnosis**:
```bash
# Check if CatalogSource is ready
kubectl get catalogsource -n olm

# Check if package manifest exists
kubectl get packagemanifest | grep toolhive

# Check catalog pod logs
kubectl logs -n olm -l olm.catalogSource=toolhive-catalog
```

**Solution**:
1. Ensure CatalogSource pod is running and ready
2. Wait 1-2 minutes for OLM to sync catalog
3. Refresh OperatorHub UI
4. Check OLM operator logs: `kubectl logs -n olm -l app=olm-operator`

### Issue: Bundle validation fails

**Error**:
```
Error: error adding bundle: bundle validation failed
```

**Solution**:
```bash
# Validate bundle before indexing
operator-sdk bundle validate ghcr.io/stacklok/toolhive/bundle:v0.2.17

# Fix any reported errors in bundle manifests
# Rebuild bundle image
# Retry index build
```

---

## Quick Reference

### Makefile Targets Summary

| Target | Purpose | Format |
|--------|---------|--------|
| `catalog-validate` | Validate OLMv1 FBC catalog | OLMv1 |
| `catalog-build` | Build OLMv1 catalog image | OLMv1 |
| `catalog-push` | Push OLMv1 catalog image | OLMv1 |
| `index-olmv0-build` | Build OLMv0 index image | OLMv0 |
| `index-olmv0-validate` | Validate OLMv0 index image | OLMv0 |
| `index-olmv0-push` | Push OLMv0 index image | OLMv0 |
| `index-olmv0-all` | Complete OLMv0 workflow | OLMv0 |
| `index-validate-all` | Validate both formats | Both |
| `index-clean` | Remove local index images | Both |

### Image Reference Quick Guide

| Image | Purpose | OpenShift Version |
|-------|---------|-------------------|
| `ghcr.io/stacklok/toolhive/catalog:v0.2.17` | OLMv1 FBC catalog (ready to use) | 4.19+ |
| `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17` | OLMv0 SQLite index (build required) | 4.15-4.18 |
| `ghcr.io/stacklok/toolhive/bundle:v0.2.17` | OLMv0 bundle (referenced by index) | N/A (not used directly) |

### CatalogSource Examples

| File | Format | Use Case |
|------|--------|----------|
| `examples/catalogsource-olmv1.yaml` | OLMv1 FBC | Modern OpenShift 4.19+ |
| `examples/catalogsource-olmv0.yaml` | OLMv0 SQLite | Legacy OpenShift 4.15-4.18 |

---

## Best Practices

### 1. Use OLMv1 for New Deployments

**DO**:
- ✅ Use `catalogsource-olmv1.yaml` for OpenShift 4.19+
- ✅ Use existing catalog image (no new build needed)
- ✅ Leverage File-Based Catalog benefits (version control, easy updates)

**DON'T**:
- ❌ Build OLMv0 index for modern OpenShift
- ❌ Mix OLMv0 and OLMv1 in the same cluster (use one or the other)

### 2. Version Consistency

Ensure all images use the same operator version:
```bash
# All should reference v0.2.17
ghcr.io/stacklok/toolhive/operator:v0.2.17        # Operator
ghcr.io/stacklok/toolhive/catalog:v0.2.17         # OLMv1 catalog
ghcr.io/stacklok/toolhive/bundle:v0.2.17          # OLMv0 bundle
ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17     # OLMv0 index
```

### 3. Registry Authentication

**For private registries**:
```bash
# Create pull secret in each namespace
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_TOKEN \
  -n olm

# Reference in CatalogSource
spec:
  secrets:
  - ghcr-secret
```

### 4. Update Strategy

**OLMv1 (recommended)**:
```yaml
spec:
  updateStrategy:
    registryPoll:
      interval: 15m  # Check for updates frequently
```

**OLMv0 (legacy)**:
```yaml
spec:
  updateStrategy:
    registryPoll:
      interval: 30m  # Longer interval for stability
```

### 5. Deprecation Timeline

Plan to sunset OLMv0 support:

| OpenShift Version | EOL Date | Action |
|-------------------|----------|--------|
| 4.15 | Q2 2025 | Monitor usage, prepare migration |
| 4.16 | Q3 2025 | Encourage upgrades |
| 4.17 | Q4 2025 | Final warnings |
| 4.18 | Q1 2026 | Discontinue OLMv0 index builds |

After OpenShift 4.18 EOL:
- Remove `index-olmv0-*` Makefile targets
- Delete `examples/catalogsource-olmv0.yaml`
- Update documentation to reflect OLMv1-only support

---

## Next Steps

After deploying the catalog/index:

1. **Install the operator**: Use OperatorHub UI or CLI Subscription
2. **Create MCPRegistry**: Deploy registry custom resources
3. **Create MCPServer**: Deploy MCP server instances
4. **Monitor operator**: Check logs, metrics, and health endpoints

For operator usage documentation, refer to the main ToolHive operator repository.

---

## References

- **Research Findings**: [research.md](./research.md)
- **Data Model**: [data-model.md](./data-model.md)
- **Containerfile Contract**: [contracts/containerfile-index-olmv0.md](./contracts/containerfile-index-olmv0.md)
- **Makefile Targets**: [contracts/makefile-targets.md](./contracts/makefile-targets.md)
- **CatalogSource Specs**: [contracts/catalogsource-examples.md](./contracts/catalogsource-examples.md)
- **OLM Documentation**: https://olm.operatorframework.io/docs/

---

## Summary

This quickstart guide covers:

✅ **OLMv1 (Modern)**: Use existing catalog image, deploy via `catalogsource-olmv1.yaml`
✅ **OLMv0 (Legacy)**: Build index with `make index-olmv0-build`, deploy via `catalogsource-olmv0.yaml`
✅ **Validation**: Cross-format validation with `make index-validate-all`
✅ **Troubleshooting**: Common issues and resolutions
✅ **Best Practices**: Version consistency, deprecation timeline, registry authentication

The key insight: **OLMv1 catalog images require no additional work** - they're already complete and ready for deployment. Only OLMv0 deployments require building a new index image wrapper.
