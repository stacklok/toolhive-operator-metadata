# Makefile Targets Contract: Index Image Build & Validation

**Feature**: Registry Database Container Image (Index Image)
**Date**: 2025-10-10
**File**: `Makefile` (to be updated at repository root)

## Purpose

Define new Makefile targets for building, validating, and pushing OLMv0 index images. These targets integrate with the existing Makefile structure and follow established conventions.

## Variables

### New Variables (to be added to Makefile)

```makefile
# OLMv0 Index Image Configuration
BUNDLE_IMG ?= ghcr.io/stacklok/toolhive/bundle:v0.2.17
INDEX_OLMV0_IMG ?= ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
OPM_MODE ?= semver
CONTAINER_TOOL ?= podman
```

**Variable Descriptions**:

| Variable | Description | Default Value | Override Example |
|----------|-------------|---------------|------------------|
| `BUNDLE_IMG` | OLMv0 bundle image to index | `ghcr.io/stacklok/toolhive/bundle:v0.2.17` | `make index-olmv0-build BUNDLE_IMG=...` |
| `INDEX_OLMV0_IMG` | Target OLMv0 index image | `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17` | `make index-olmv0-build INDEX_OLMV0_IMG=...` |
| `OPM_MODE` | Index build mode (semver/replaces) | `semver` | `make index-olmv0-build OPM_MODE=replaces` |
| `CONTAINER_TOOL` | Container runtime (podman/docker) | `podman` | `make index-olmv0-build CONTAINER_TOOL=docker` |

### Version Synchronization

**Important**: `BUNDLE_IMG` and `INDEX_OLMV0_IMG` versions should match:
- Bundle: `ghcr.io/stacklok/toolhive/bundle:v0.2.17`
- Index: `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17`

Both use the same operator version tag (`v0.2.17`) for consistency.

## Target Specifications

### Section Header

Insert the following section in the Makefile after the `##@ OLM Bundle Image Targets` section:

```makefile
##@ OLM Index Targets (OLMv0 - Legacy OpenShift 4.15-4.18)
```

### Target: `index-olmv0-build`

**Purpose**: Build OLMv0 SQLite-based index image using `opm index add`.

**Dependencies**: None (bundle image assumed to exist)

**Implementation**:
```makefile
.PHONY: index-olmv0-build
index-olmv0-build: ## Build OLMv0 index image (SQLite-based, deprecated)
	@echo "⚠️  Building OLMv0 index image (SQLite-based, deprecated)"
	@echo "   Use only for legacy OpenShift 4.15-4.18 compatibility"
	@echo ""
	@echo "Building index referencing bundle: $(BUNDLE_IMG)"
	opm index add \
		--bundles $(BUNDLE_IMG) \
		--tag $(INDEX_OLMV0_IMG) \
		--mode $(OPM_MODE) \
		--container-tool $(CONTAINER_TOOL)
	@echo ""
	@echo "✅ OLMv0 index image built: $(INDEX_OLMV0_IMG)"
	@$(CONTAINER_TOOL) images $(INDEX_OLMV0_IMG)
	@echo ""
	@echo "Tagging as latest..."
	$(CONTAINER_TOOL) tag $(INDEX_OLMV0_IMG) ghcr.io/stacklok/toolhive/index-olmv0:latest
	@echo "✅ Also tagged: ghcr.io/stacklok/toolhive/index-olmv0:latest"
```

**Expected Output**:
```
⚠️  Building OLMv0 index image (SQLite-based, deprecated)
   Use only for legacy OpenShift 4.15-4.18 compatibility

Building index referencing bundle: ghcr.io/stacklok/toolhive/bundle:v0.2.17
INFO[0000] building the index                           bundles="[ghcr.io/stacklok/toolhive/bundle:v0.2.17]"
INFO[0000] running /usr/bin/podman pull ghcr.io/stacklok/toolhive/bundle:v0.2.17
...
INFO[0010] successfully built index image ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17

✅ OLMv0 index image built: ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
REPOSITORY                            TAG       IMAGE ID      CREATED        SIZE
ghcr.io/stacklok/toolhive/index-olmv0 v0.2.17   abc123def456  1 minute ago   150 MB

Tagging as latest...
✅ Also tagged: ghcr.io/stacklok/toolhive/index-olmv0:latest
```

**Error Handling**:
- If `opm` is not installed: Command fails with "opm: command not found"
- If bundle image doesn't exist: `opm` fails to pull bundle, exits with error
- If container tool not available: Command fails immediately

**Usage**:
```bash
# Build with defaults
make index-olmv0-build

# Build with custom bundle
make index-olmv0-build BUNDLE_IMG=ghcr.io/stacklok/toolhive/bundle:v0.3.0

# Build with custom index tag
make index-olmv0-build INDEX_OLMV0_IMG=ghcr.io/stacklok/toolhive/index-olmv0:v0.3.0
```

---

### Target: `index-olmv0-validate`

**Purpose**: Validate OLMv0 index image by exporting package manifest.

**Dependencies**: `index-olmv0-build` (index image must exist)

**Implementation**:
```makefile
.PHONY: index-olmv0-validate
index-olmv0-validate: ## Validate OLMv0 index image
	@echo "Validating OLMv0 index image..."
	@echo "Exporting package manifest from index..."
	@opm index export \
		--index=$(INDEX_OLMV0_IMG) \
		--package=toolhive-operator > /tmp/toolhive-index-olmv0-export.yaml
	@echo ""
	@echo "✅ OLMv0 index validation passed"
	@echo "   Package manifest exported to /tmp/toolhive-index-olmv0-export.yaml"
	@echo ""
	@echo "Package summary:"
	@yq eval '.metadata.name, .spec.channels[].name, .spec.channels[].currentCSV' /tmp/toolhive-index-olmv0-export.yaml
```

**Expected Output**:
```
Validating OLMv0 index image...
Exporting package manifest from index...

✅ OLMv0 index validation passed
   Package manifest exported to /tmp/toolhive-index-olmv0-export.yaml

Package summary:
toolhive-operator
fast
toolhive-operator.v0.2.17
```

**Error Handling**:
- If index image doesn't exist: `opm index export` fails with "image not found"
- If package doesn't exist in index: `opm` exits with error
- If `yq` not installed: Summary step fails (non-critical, validation still passed)

**Usage**:
```bash
# Validate default index
make index-olmv0-validate

# Validate custom index
make index-olmv0-validate INDEX_OLMV0_IMG=ghcr.io/stacklok/toolhive/index-olmv0:v0.3.0
```

---

### Target: `index-olmv0-push`

**Purpose**: Push OLMv0 index image to container registry.

**Dependencies**: `index-olmv0-build` (index image must be built first)

**Implementation**:
```makefile
.PHONY: index-olmv0-push
index-olmv0-push: ## Push OLMv0 index image to registry
	@echo "Pushing OLMv0 index image to ghcr.io..."
	$(CONTAINER_TOOL) push $(INDEX_OLMV0_IMG)
	$(CONTAINER_TOOL) push ghcr.io/stacklok/toolhive/index-olmv0:latest
	@echo "✅ OLMv0 index image pushed"
	@echo "   - $(INDEX_OLMV0_IMG)"
	@echo "   - ghcr.io/stacklok/toolhive/index-olmv0:latest"
```

**Expected Output**:
```
Pushing OLMv0 index image to ghcr.io...
Getting image source signatures
Copying blob abc123def456 done
Copying config 789ghi012jkl done
Writing manifest to image destination
Storing signatures

Getting image source signatures
Copying blob abc123def456 skipped: already exists
Copying config 789ghi012jkl done
Writing manifest to image destination
Storing signatures

✅ OLMv0 index image pushed
   - ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
   - ghcr.io/stacklok/toolhive/index-olmv0:latest
```

**Error Handling**:
- If not authenticated: Push fails with authentication error
- If image doesn't exist locally: Push fails with "image not found"
- If registry is unreachable: Push fails with network error

**Prerequisites**:
```bash
# Authenticate to ghcr.io before pushing
podman login ghcr.io
# Enter GitHub username and personal access token
```

**Usage**:
```bash
# Push default index
make index-olmv0-push

# Push custom index
make index-olmv0-push INDEX_OLMV0_IMG=ghcr.io/stacklok/toolhive/index-olmv0:v0.3.0
```

---

### Target: `index-olmv0-all`

**Purpose**: Run complete OLMv0 index workflow (build, validate, push).

**Dependencies**: `index-olmv0-build`, `index-olmv0-validate`, `index-olmv0-push`

**Implementation**:
```makefile
.PHONY: index-olmv0-all
index-olmv0-all: index-olmv0-build index-olmv0-validate index-olmv0-push ## Run complete OLMv0 index workflow
	@echo ""
	@echo "========================================="
	@echo "✅ Complete OLMv0 index workflow finished"
	@echo "========================================="
	@echo ""
	@echo "⚠️  REMINDER: SQLite-based indexes are deprecated"
	@echo "   Use only for legacy OpenShift 4.15-4.18 deployments"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Deploy CatalogSource: kubectl apply -f examples/catalogsource-olmv0.yaml"
	@echo "  2. Verify catalog: kubectl get catalogsource -n olm toolhive-catalog-olmv0"
	@echo "  3. Check OperatorHub for ToolHive Operator"
	@echo ""
```

**Expected Output**:
```
[Output from index-olmv0-build]
[Output from index-olmv0-validate]
[Output from index-olmv0-push]

=========================================
✅ Complete OLMv0 index workflow finished
=========================================

⚠️  REMINDER: SQLite-based indexes are deprecated
   Use only for legacy OpenShift 4.15-4.18 deployments

Next steps:
  1. Deploy CatalogSource: kubectl apply -f examples/catalogsource-olmv0.yaml
  2. Verify catalog: kubectl get catalogsource -n olm toolhive-catalog-olmv0
  3. Check OperatorHub for ToolHive Operator
```

**Usage**:
```bash
# Run entire workflow
make index-olmv0-all
```

---

### Target: `index-validate-all`

**Purpose**: Validate both OLMv1 (catalog) and OLMv0 (index) images.

**Dependencies**: `catalog-validate`, `index-olmv0-validate`

**Implementation**:
```makefile
.PHONY: index-validate-all
index-validate-all: catalog-validate index-olmv0-validate ## Validate both OLMv1 catalog and OLMv0 index
	@echo ""
	@echo "========================================="
	@echo "✅ All index/catalog validations passed"
	@echo "========================================="
	@echo ""
	@echo "Validated:"
	@echo "  ✅ OLMv1 FBC Catalog (modern OpenShift 4.19+)"
	@echo "  ✅ OLMv0 SQLite Index (legacy OpenShift 4.15-4.18)"
	@echo ""
```

**Expected Output**:
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

**Usage**:
```bash
# Validate all formats
make index-validate-all
```

---

### Target: `index-clean`

**Purpose**: Remove local OLMv0 index images.

**Dependencies**: None

**Implementation**:
```makefile
.PHONY: index-clean
index-clean: ## Remove local OLMv0 index images
	@echo "Removing OLMv0 index images..."
	-$(CONTAINER_TOOL) rmi ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
	-$(CONTAINER_TOOL) rmi ghcr.io/stacklok/toolhive/index-olmv0:latest
	@echo "✅ OLMv0 index images removed"
```

**Expected Output**:
```
Removing OLMv0 index images...
Untagged: ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
Deleted: abc123def456...
Untagged: ghcr.io/stacklok/toolhive/index-olmv0:latest
✅ OLMv0 index images removed
```

**Note**: The `-` prefix on `podman rmi` commands makes errors non-fatal (e.g., if image doesn't exist).

**Usage**:
```bash
# Clean index images
make index-clean
```

---

## Target Summary Table

| Target | Purpose | Dependencies | Output |
|--------|---------|--------------|--------|
| `index-olmv0-build` | Build OLMv0 index image | None | Index image locally |
| `index-olmv0-validate` | Validate index structure | `index-olmv0-build` | Package manifest export |
| `index-olmv0-push` | Push index to registry | `index-olmv0-build` | Pushed images |
| `index-olmv0-all` | Complete workflow | All above | Built, validated, pushed index |
| `index-validate-all` | Validate all formats | `catalog-validate`, `index-olmv0-validate` | Validation summary |
| `index-clean` | Remove local images | None | Deleted images |

## Integration with Existing Targets

### Updated `validate-all` Target

Modify the existing `validate-all` target to include index validation:

```makefile
.PHONY: validate-all
validate-all: constitution-check bundle-validate bundle-validate-sdk catalog-validate index-olmv0-validate ## Run all validation checks
	@echo ""
	@echo "========================================="
	@echo "✅ All validations passed"
	@echo "========================================="
```

**Rationale**: Ensures CI/CD validates both OLMv1 and OLMv0 artifacts.

### Updated `clean-images` Target

Modify the existing `clean-images` target to include index images:

```makefile
.PHONY: clean-images
clean-images: ## Remove local catalog and index container images
	@echo "Removing catalog and index images..."
	-$(CONTAINER_TOOL) rmi ghcr.io/stacklok/toolhive/catalog:v0.2.17
	-$(CONTAINER_TOOL) rmi ghcr.io/stacklok/toolhive/catalog:latest
	-$(CONTAINER_TOOL) rmi ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
	-$(CONTAINER_TOOL) rmi ghcr.io/stacklok/toolhive/index-olmv0:latest
	@echo "✅ Catalog and index images removed"
```

## Makefile Organization

### Recommended Section Order

```makefile
##@ Kustomize Targets
# ... existing targets ...

##@ OLM Bundle Targets
# ... existing targets ...

##@ OLM Catalog Targets
# ... existing targets ...

##@ OLM Bundle Image Targets
# ... existing targets ...

##@ OLM Index Targets (OLMv0 - Legacy OpenShift 4.15-4.18)  ← NEW SECTION
# index-olmv0-build
# index-olmv0-validate
# index-olmv0-push
# index-olmv0-all
# index-validate-all
# index-clean

##@ Complete OLM Workflow
# ... existing targets ...

##@ Validation & Compliance
# ... existing targets (update validate-all) ...

##@ Cleanup
# ... existing targets (update clean-images) ...

##@ Documentation
# ... existing targets ...

##@ Quick Reference
# ... existing targets ...
```

## Help Output

The `make help` command will display new targets:

```
OLM Index Targets (OLMv0 - Legacy OpenShift 4.15-4.18):
  index-olmv0-build          Build OLMv0 index image (SQLite-based, deprecated)
  index-olmv0-validate       Validate OLMv0 index image
  index-olmv0-push           Push OLMv0 index image to registry
  index-olmv0-all            Run complete OLMv0 index workflow
  index-validate-all         Validate both OLMv1 catalog and OLMv0 index
  index-clean                Remove local OLMv0 index images
```

## Error Messages

### Common Errors and Resolutions

**Error**: `opm: command not found`
**Resolution**:
```bash
# Install opm (method varies by OS)
# For Linux:
curl -L https://github.com/operator-framework/operator-registry/releases/latest/download/linux-amd64-opm -o /usr/local/bin/opm
chmod +x /usr/local/bin/opm
```

**Error**: `Error: error adding bundle ghcr.io/stacklok/toolhive/bundle:v0.2.17: error getting bundle from image: GET https://ghcr.io/...: unauthorized`
**Resolution**:
```bash
# Authenticate to container registry
podman login ghcr.io
# Enter credentials
```

**Error**: `Error: error adding bundle: bundle validation failed`
**Resolution**:
```bash
# Validate bundle before indexing
operator-sdk bundle validate ghcr.io/stacklok/toolhive/bundle:v0.2.17
# Fix validation errors in bundle, rebuild, then retry
```

## Testing

### Manual Testing Checklist

- [ ] `make index-olmv0-build` completes successfully
- [ ] `podman images | grep index-olmv0` shows both `v0.2.17` and `latest` tags
- [ ] `make index-olmv0-validate` exports package manifest without errors
- [ ] `/tmp/toolhive-index-olmv0-export.yaml` contains valid PackageManifest
- [ ] `make index-olmv0-push` pushes to registry (requires authentication)
- [ ] `make index-olmv0-all` runs complete workflow
- [ ] `make index-validate-all` validates both catalog and index
- [ ] `make index-clean` removes local images
- [ ] `make help` displays new targets with descriptions

### CI/CD Integration

Add to CI pipeline (e.g., GitHub Actions):

```yaml
- name: Build and validate OLMv0 index
  run: |
    make index-olmv0-build
    make index-olmv0-validate

- name: Push index (on release only)
  if: github.event_name == 'release'
  run: |
    echo "${{ secrets.GHCR_TOKEN }}" | podman login ghcr.io -u ${{ github.actor }} --password-stdin
    make index-olmv0-push
```

## References

- **Existing Makefile**: [Makefile](../../../Makefile)
- **Bundle Build Targets**: `bundle-validate-sdk`, `bundle-build`, `bundle-push`
- **Catalog Build Targets**: `catalog-validate`, `catalog-build`, `catalog-push`
- **opm Documentation**: https://github.com/operator-framework/operator-registry

## Summary

This contract defines 6 new Makefile targets for OLMv0 index image management:

1. **index-olmv0-build**: Build index using `opm index add`
2. **index-olmv0-validate**: Validate using `opm index export`
3. **index-olmv0-push**: Push to ghcr.io registry
4. **index-olmv0-all**: Complete build-validate-push workflow
5. **index-validate-all**: Cross-format validation (OLMv1 + OLMv0)
6. **index-clean**: Remove local index images

These targets follow existing Makefile conventions (`.PHONY`, `##` comments, `@echo` output) and integrate with existing validation and cleanup workflows.
