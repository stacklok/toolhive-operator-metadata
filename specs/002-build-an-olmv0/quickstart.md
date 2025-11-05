# Quickstart: OLMv0 Bundle Container Image Build System

**Feature**: OLMv0 Bundle Container Image Build System
**Branch**: `002-build-an-olmv0`
**Audience**: Developers, platform engineers, CI/CD integrators
**Time to Complete**: ~10 minutes

## What You'll Build

A complete build system for packaging the ToolHive Operator as an OLMv0 bundle container image, enabling deployment to legacy Kubernetes and OpenShift clusters (v4.10-v4.12).

## Prerequisites

**Required Tools**:
- `podman` or `docker` (container build tool)
- `operator-sdk` v1.30.0 or later
- `make`

**Verify Installation**:
```bash
# Check podman
podman version
# Expected: version 4.0+

# Check operator-sdk
operator-sdk version
# Expected: version 1.30.0+

# Check make
make --version
# Expected: GNU Make 4.0+
```

**Install Missing Tools** (if needed):
```bash
# Install podman (Fedora/RHEL/CentOS)
sudo dnf install podman

# Install podman (Ubuntu/Debian)
sudo apt install podman

# Install operator-sdk (any Linux)
# See: https://sdk.operatorframework.io/docs/installation/
curl -LO https://github.com/operator-framework/operator-sdk/releases/download/v1.30.0/operator-sdk_linux_amd64
chmod +x operator-sdk_linux_amd64
sudo mv operator-sdk_linux_amd64 /usr/local/bin/operator-sdk
```

## Step 1: Understand the Repository Structure

This feature adds build tooling without modifying existing manifests:

```
toolhive-operator-metadata/
├── bundle/                           # Existing (DO NOT MODIFY)
│   ├── manifests/
│   │   ├── toolhive-operator.clusterserviceversion.yaml
│   │   ├── mcpregistries.crd.yaml
│   │   └── mcpservers.crd.yaml
│   └── metadata/
│       └── annotations.yaml
├── Containerfile.bundle              # NEW - Bundle image definition
├── Makefile                          # MODIFIED - Add bundle-* targets
└── Containerfile.catalog             # Existing - OLMv1 catalog (unchanged)
```

## Step 2: Create the Containerfile

Create `Containerfile.bundle` at the repository root:

```dockerfile
# Containerfile.bundle
FROM scratch

ADD bundle/manifests /manifests/
ADD bundle/metadata /metadata/

LABEL operators.operatorframework.io.bundle.mediatype.v1=registry+v1
LABEL operators.operatorframework.io.bundle.manifests.v1=manifests/
LABEL operators.operatorframework.io.bundle.metadata.v1=metadata/
LABEL operators.operatorframework.io.bundle.package.v1=toolhive-operator
LABEL operators.operatorframework.io.bundle.channels.v1=fast
LABEL operators.operatorframework.io.bundle.channel.default.v1=fast

LABEL org.opencontainers.image.title="ToolHive Operator Bundle"
LABEL org.opencontainers.image.description="OLMv0 Bundle for ToolHive Operator"
LABEL org.opencontainers.image.vendor="Stacklok"
LABEL org.opencontainers.image.source="https://github.com/RHEcosystemAppEng/toolhive-operator-metadata"
LABEL org.opencontainers.image.version="v0.2.17"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL com.redhat.openshift.versions="v4.10-v4.19"
```

**Why scratch base?** Bundle images are data-only (no executables), so we use the minimal `scratch` base to reduce size and attack surface.

## Step 3: Add Makefile Targets

Add this section to `Makefile` (after the existing `##@ OLM Catalog Targets` section):

```makefile
##@ OLM Bundle Image Targets

.PHONY: bundle-validate-sdk
bundle-validate-sdk: ## Validate OLM bundle with operator-sdk
	@echo "Validating bundle with operator-sdk..."
	operator-sdk bundle validate ./bundle --select-optional suite=operatorframework
	@echo "✅ Bundle validation passed"

.PHONY: bundle-build
bundle-build: bundle-validate-sdk ## Build bundle container image
	@echo "Building bundle container image..."
	podman build -f Containerfile.bundle -t ghcr.io/stacklok/toolhive/bundle:v0.2.17 .
	podman tag ghcr.io/stacklok/toolhive/bundle:v0.2.17 ghcr.io/stacklok/toolhive/bundle:latest
	@echo "✅ Bundle image built: ghcr.io/stacklok/toolhive/bundle:v0.2.17"
	@podman images ghcr.io/stacklok/toolhive/bundle

.PHONY: bundle-push
bundle-push: ## Push bundle image to registry
	@echo "Pushing bundle image to ghcr.io..."
	podman push ghcr.io/stacklok/toolhive/bundle:v0.2.17
	podman push ghcr.io/stacklok/toolhive/bundle:latest
	@echo "✅ Bundle image pushed"

.PHONY: bundle-all
bundle-all: bundle-validate-sdk bundle-build ## Run complete bundle workflow (validate, build)
	@echo ""
	@echo "========================================="
	@echo "✅ Complete bundle workflow finished"
	@echo "========================================="
	@echo ""
	@echo "Next steps:"
	@echo "  1. Push bundle image: make bundle-push"
	@echo "  2. Deploy to cluster: create CatalogSource referencing bundle image"
	@echo ""
```

Also update the `validate-all` target to include bundle validation:

```makefile
.PHONY: validate-all
validate-all: constitution-check bundle-validate bundle-validate-sdk catalog-validate
	# ... (rest of target unchanged)
```

## Step 4: Validate the Bundle

Before building, ensure the bundle passes OLM validation:

```bash
make bundle-validate-sdk
```

**Expected output**:
```
Validating bundle with operator-sdk...
INFO[0000] All validation tests have completed successfully
✅ Bundle validation passed
```

**If validation fails**, check:
- `bundle/metadata/annotations.yaml` has all required OLM annotations
- `bundle/manifests/toolhive-operator.clusterserviceversion.yaml` owns both CRDs
- All YAML files are well-formed

## Step 5: Build the Bundle Image

Build the bundle container image:

```bash
make bundle-build
```

**Expected output**:
```
Validating bundle with operator-sdk...
INFO[0000] All validation tests have completed successfully
✅ Bundle validation passed
Building bundle container image...
STEP 1/3: FROM scratch
STEP 2/3: ADD bundle/manifests /manifests/
STEP 3/3: ADD bundle/metadata /metadata/
... (LABEL steps)
COMMIT ghcr.io/stacklok/toolhive/bundle:v0.2.17
✅ Bundle image built: ghcr.io/stacklok/toolhive/bundle:v0.2.17
REPOSITORY                              TAG         IMAGE ID      CREATED         SIZE
ghcr.io/stacklok/toolhive/bundle        v0.2.17     abc123def456  5 seconds ago   15.2 kB
ghcr.io/stacklok/toolhive/bundle        latest      abc123def456  5 seconds ago   15.2 kB
```

**Note**: Build time is <30 seconds; image size is <20MB (typically 10-15MB).

## Step 6: Verify the Image

Inspect the built image to confirm labels and contents:

```bash
# Check labels
podman inspect ghcr.io/stacklok/toolhive/bundle:v0.2.17 \
  --format '{{index .Labels "operators.operatorframework.io.bundle.mediatype.v1"}}'
# Expected: registry+v1

# Check filesystem
podman run --rm ghcr.io/stacklok/toolhive/bundle:v0.2.17 ls -la /manifests/
# Expected: Error (no shell in scratch image)

# Alternative: export and examine
podman save ghcr.io/stacklok/toolhive/bundle:v0.2.17 | tar -xf - -O '*/layer.tar' | tar -tzf - | grep manifests
# Expected: manifests/, manifests/*.yaml files
```

## Step 7: Push to Registry (Optional)

If deploying to a cluster, push the image to a registry:

```bash
# Authenticate to GitHub Container Registry
podman login ghcr.io
# Username: <your-github-username>
# Password: <github-personal-access-token>

# Push the image
make bundle-push
```

**Expected output**:
```
Pushing bundle image to ghcr.io...
Getting image source signatures
Copying blob abc123def456 done
Copying config 123abc456def done
Writing manifest to image destination
✅ Bundle image pushed
```

## Step 8: Verify Dual Build Coexistence

Ensure the new bundle build doesn't interfere with existing catalog builds:

```bash
# Build catalog image (existing workflow)
make catalog-build

# Build bundle image (new workflow)
make bundle-build

# Verify both images exist
podman images | grep toolhive
```

**Expected output** (showing both images):
```
ghcr.io/stacklok/toolhive/catalog     v0.2.17    ...    ...    ...
ghcr.io/stacklok/toolhive/catalog     latest     ...    ...    ...
ghcr.io/stacklok/toolhive/bundle      v0.2.17    ...    ...    ...
ghcr.io/stacklok/toolhive/bundle      latest     ...    ...    ...
```

## Common Issues and Solutions

### Issue: `operator-sdk: command not found`

**Solution**: Install operator-sdk:
```bash
curl -LO https://github.com/operator-framework/operator-sdk/releases/download/v1.30.0/operator-sdk_linux_amd64
chmod +x operator-sdk_linux_amd64
sudo mv operator-sdk_linux_amd64 /usr/local/bin/operator-sdk
```

### Issue: Validation fails with "owned CRD not found"

**Solution**: Verify CSV declares both CRDs in `spec.customresourcedefinitions.owned`:
```bash
yq eval '.spec.customresourcedefinitions.owned' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
```
Expected: MCPRegistry and MCPServer listed.

### Issue: Build fails with "error building at STEP 2: ADD bundle/manifests"

**Solution**: Ensure you're running `make bundle-build` from the repository root (not from a subdirectory).

### Issue: Image size is unexpectedly large (>50MB)

**Solution**: Verify you're using `FROM scratch` (not a larger base image like `ubi8`).

## Testing the Bundle on a Cluster

To deploy the bundle to an OLMv0 cluster:

1. **Create a CatalogSource**:
   ```yaml
   apiVersion: operators.coreos.com/v1alpha1
   kind: CatalogSource
   metadata:
     name: toolhive-bundle
     namespace: olm
   spec:
     sourceType: grpc
     image: ghcr.io/stacklok/toolhive/bundle:v0.2.17
     displayName: ToolHive Operator Bundle
   ```

2. **Apply to cluster**:
   ```bash
   kubectl apply -f catalogsource.yaml
   ```

3. **Verify PackageManifest**:
   ```bash
   kubectl get packagemanifests -n olm | grep toolhive
   # Expected: toolhive-operator listed
   ```

4. **Create Subscription** (to install the operator):
   ```yaml
   apiVersion: operators.coreos.com/v1alpha1
   kind: Subscription
   metadata:
     name: toolhive-operator
     namespace: operators
   spec:
     channel: fast
     name: toolhive-operator
     source: toolhive-bundle
     sourceNamespace: olm
   ```

## Next Steps

- **CI/CD Integration**: Add `make bundle-all` to your CI pipeline
- **Version Updates**: When releasing a new version, update version in Containerfile.bundle and Makefile targets
- **Documentation**: Update project README to mention bundle build capability
- **Registry Automation**: Configure GitHub Actions to push bundle images on release tags

## Summary

You've successfully:
- ✅ Created a Containerfile for building OLMv0 bundle images
- ✅ Added Makefile targets for automated build workflows
- ✅ Validated the bundle with operator-sdk
- ✅ Built and tagged a bundle container image
- ✅ Verified coexistence with existing OLMv1 catalog builds

**Total time**: ~10 minutes
**Files modified**: 2 (Containerfile.bundle created, Makefile updated)
**Lines added**: ~60 lines total
