# Research: Creating Operator Registry Index Images with `opm`

**Feature**: Registry Database Container Image (Index Image)
**Date**: 2025-10-10
**Status**: Research Complete

## Overview

This document consolidates research findings on creating operator registry index/catalog images using the `opm` tool from operator-framework/operator-registry. The research addresses the specific needs of the ToolHive operator metadata repository for building proper index images that reference existing OLMv1 catalog and OLMv0 bundle images.

## Key Finding: Terminology Clarification

**"Index Image" and "Catalog Image" are the same concept** in modern OLM terminology:

- **Index Image**: Legacy term associated with deprecated SQLite-based catalogs
- **Catalog Image**: Current term associated with File-Based Catalogs (FBC)
- **Both**: Container images referenced by CatalogSource to make operators available in OperatorHub

The operator-framework documentation and tools use these terms interchangeably, with "catalog image" becoming the preferred term as SQLite-based approaches are deprecated.

## Decision 1: OLMv1 Catalog Image Approach

### Decision
**Use File-Based Catalog (FBC) images as-is** - the existing `Containerfile.catalog` already creates a proper catalog image that can be referenced directly by CatalogSource. **No additional index/wrapper image needed**.

### Rationale
1. **File-Based Catalogs ARE catalog images**: The `Containerfile.catalog` creates a complete, self-contained catalog image with:
   - FBC metadata in `/configs` directory
   - Label `operators.operatorframework.io.index.configs.v1=/configs` for OLM discovery
   - Immutable, scratch-based image with catalog data

2. **CatalogSource compatibility**: OLM expects a catalog image for the `sourceType: grpc` with `image:` reference. The existing catalog image (`ghcr.io/stacklok/toolhive/catalog:v0.2.17`) is exactly what CatalogSource needs.

3. **No wrapper needed**: Unlike OLMv0 bundles (which require an index), OLMv1 FBC images are complete catalog images ready for direct CatalogSource consumption.

4. **Officially recommended**: File-Based Catalogs are the current OLM recommendation, with SQLite-based approaches explicitly deprecated.

### What This Means for Our Implementation

**The current architecture for OLMv1 is CORRECT**:
- ✅ `Containerfile.catalog` builds a FBC catalog image
- ✅ This image can be referenced directly in CatalogSource
- ✅ No additional "index" wrapper image needed

**What needs to change**:
- Update terminology in documentation from "index image" to "catalog image" for OLMv1
- The CatalogSource example at `examples/catalogsource.yaml` line 21 **IS** correct for OLMv1 deployments
- Create a separate OLMv0-specific example for legacy deployments

### Command Summary (OLMv1 - Already Implemented)

```bash
# Existing workflow (from spec 001)
opm validate catalog/                          # Validate FBC structure
podman build -f Containerfile.catalog \        # Build catalog image
  -t ghcr.io/stacklok/toolhive/catalog:v0.2.17 .
podman push ghcr.io/stacklok/toolhive/catalog:v0.2.17

# CatalogSource directly references this image
# examples/catalogsource.yaml:
#   spec:
#     sourceType: grpc
#     image: ghcr.io/stacklok/toolhive/catalog:v0.2.17
```

**No additional index creation needed for OLMv1.**

---

## Decision 2: OLMv0 Bundle Image Approach

### Decision
**Create an OLMv0 index image using `opm index add`** (deprecated but necessary for legacy OpenShift compatibility). This index image will reference the existing OLMv0 bundle image created in spec 002.

### Rationale
1. **Bundle images cannot be used directly**: Unlike FBC catalog images, OLMv0 bundle images **must** be wrapped in an index image before being referenced by CatalogSource.

2. **SQLite index required for OLMv0**: Legacy OLM (OpenShift 4.15-4.18) expects SQLite-based index images for bundle-based operators.

3. **Temporary necessity**: While `opm index` commands are deprecated, they remain necessary for supporting legacy OpenShift versions until those versions reach end-of-life.

4. **Isolated usage**: We'll use SQLite index only for OLMv0 compatibility, keeping OLMv1 (modern) deployments on FBC.

### Implementation Approach

**Create a SQLite-based index image** that references the existing bundle image:

```bash
# Build OLMv0 index image referencing the bundle
opm index add \
  --bundles ghcr.io/stacklok/toolhive/bundle:v0.2.17 \
  --tag ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17 \
  --mode semver

# Validate (optional, requires running container)
# This starts a temporary registry server
opm index export \
  --index=ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17 \
  --package=toolhive-operator

# Push to registry
podman push ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
```

**CatalogSource references the index image**:

```yaml
# examples/catalogsource-olmv0.yaml (NEW)
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-catalog-olmv0
  namespace: olm
spec:
  sourceType: grpc
  image: ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17  # INDEX image, not bundle
  displayName: ToolHive Operator Catalog (OLMv0)
  publisher: Stacklok
```

### Why Not Migrate OLMv0 to FBC?

**Considered**: Using `opm migrate` to convert the bundle into FBC format.

**Rejected because**:
- OLMv0 bundle images are **already built** and distributed (spec 002)
- Legacy OpenShift (4.15-4.18) may have better compatibility with SQLite indexes
- Migration adds complexity without clear benefit for legacy deployments
- The goal is **temporary support** until legacy versions are deprecated, not long-term maintenance

### Deprecation Warning Acknowledgment

The `opm index` commands display this warning:

```
DEPRECATION NOTICE:
Sqlite-based catalogs and their related subcommands are deprecated. Support for
them will be removed in a future release. Please migrate your catalog workflows
to the new file-based catalog format.
```

**We accept this risk** because:
- OLMv0 support is **explicitly for legacy OpenShift versions** (4.15-4.18)
- Once these versions reach EOL, we'll sunset OLMv0 index images
- Modern deployments use OLMv1 FBC (not deprecated)
- The warning applies to creating new SQLite catalogs, which we're doing minimally and temporarily

---

## Decision 3: Validation Strategy

### Decision
Use format-specific validation commands for each index/catalog type:

**OLMv1 (FBC Catalog)**:
```bash
opm validate catalog/
```
- Validates: Package structure, channels, bundle references, schema format
- Does NOT validate: Upgrade graph logic (manual review needed)
- Exit code: 0 on success, non-zero on failure

**OLMv0 (SQLite Index)**:
```bash
# Method 1: Export package list (proves index is queryable)
opm index export \
  --index=ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17 \
  --package=toolhive-operator

# Method 2: Use operator-sdk to validate the referenced bundle
operator-sdk bundle validate ghcr.io/stacklok/toolhive/bundle:v0.2.17
```

### Rationale
- Different index formats require different validation approaches
- FBC validation is file-based and fast (`opm validate`)
- SQLite index validation requires querying the database (export or inspect)
- Combining both ensures comprehensive coverage

---

## Decision 4: Preventing Mixed OLMv0/OLMv1 Content

### Decision
**Use separate image names and Makefile targets** to ensure OLMv0 and OLMv1 never mix:

**Image Naming Convention**:
- OLMv1 catalog: `ghcr.io/stacklok/toolhive/catalog:v0.2.17` (existing, no change)
- OLMv0 index: `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17` (new, explicit format in name)

**Makefile Target Isolation**:
- OLMv1 targets: `catalog-validate`, `catalog-build`, `catalog-push` (existing)
- OLMv0 targets: `index-olmv0-build`, `index-olmv0-validate`, `index-olmv0-push` (new)

### Rationale
1. **Clear naming prevents confusion**: `catalog` vs `index-olmv0` makes it obvious which format each image uses
2. **Separate targets prevent accidental mixing**: You can't accidentally build OLMv0 when running OLMv1 targets
3. **Version coupling**: Both images use the same version tag (v0.2.17) but different repositories
4. **Documentation clarity**: Examples can clearly reference the appropriate image for each OpenShift version

### Implementation Pattern

```makefile
##@ OLM Index Targets (OLMv0 - Legacy OpenShift 4.15-4.18)

.PHONY: index-olmv0-build
index-olmv0-build: ## Build OLMv0 index image (SQLite-based, deprecated)
	@echo "Building OLMv0 index image (SQLite-based)..."
	opm index add \
		--bundles $(BUNDLE_IMG) \
		--tag $(INDEX_OLMV0_IMG) \
		--mode semver
	@echo "✅ OLMv0 index image built: $(INDEX_OLMV0_IMG)"

.PHONY: index-olmv0-validate
index-olmv0-validate: ## Validate OLMv0 index image
	@echo "Validating OLMv0 index image..."
	opm index export --index=$(INDEX_OLMV0_IMG) --package=toolhive-operator
	@echo "✅ OLMv0 index validation passed"

# Separate workflow - no mixing possible
```

---

## Decision 5: Supporting Multiple Operator Versions

### Decision
**Support multi-version catalogs differently for each format**:

**OLMv1 (FBC)**: Use `opm render` to add multiple bundle references to `catalog.yaml`:
```bash
opm render quay.io/stacklok/toolhive/bundle:v0.2.17 --output=yaml >> catalog/toolhive-operator/catalog.yaml
opm render quay.io/stacklok/toolhive/bundle:v0.3.0 --output=yaml >> catalog/toolhive-operator/catalog.yaml
```

**OLMv0 (SQLite Index)**: Use `opm index add` with `--from-index` to build incrementally:
```bash
# First version
opm index add --bundles ...bundle:v0.2.17 --tag ...index-olmv0:v1

# Add second version
opm index add --bundles ...bundle:v0.3.0 --from-index ...index-olmv0:v1 --tag ...index-olmv0:v2
```

### Rationale
- Each format has its own multi-version pattern
- FBC is file-based (append to YAML)
- SQLite is database-based (add to existing index)
- Both support multiple versions without mixing formats

### Current Scope
**For this specification**: Focus on **single-version** index/catalog images (v0.2.17 only). Multi-version support is a future enhancement documented here for reference.

---

## Decision 6: Image Naming and Tagging Conventions

### Decision
**Use semantic versioning with format-specific naming**:

| Format | Image Name | Tag | Example |
|--------|-----------|-----|---------|
| OLMv1 FBC Catalog | `ghcr.io/stacklok/toolhive/catalog` | `v{version}` | `ghcr.io/stacklok/toolhive/catalog:v0.2.17` |
| OLMv0 SQLite Index | `ghcr.io/stacklok/toolhive/index-olmv0` | `v{version}` | `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17` |
| OLMv0 Bundle | `ghcr.io/stacklok/toolhive/bundle` | `v{version}` | `ghcr.io/stacklok/toolhive/bundle:v0.2.17` |

**Also tag with `latest`** for convenience:
```bash
podman tag ghcr.io/stacklok/toolhive/catalog:v0.2.17 ghcr.io/stacklok/toolhive/catalog:latest
podman tag ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17 ghcr.io/stacklok/toolhive/index-olmv0:latest
```

### Rationale
1. **Semantic versioning**: Aligns with operator version (v0.2.17)
2. **Format in name**: `index-olmv0` clearly indicates deprecated format
3. **Registry organization**: All under `ghcr.io/stacklok/toolhive/` namespace
4. **Latest tag**: Enables rolling updates via CatalogSource `updateStrategy.registryPoll`

---

## Alternatives Considered

### Alternative 1: Create FBC Index Wrapper for OLMv1

**Approach**: Build a separate index image that references the FBC catalog image.

**Why NOT chosen**:
- **Unnecessary layer**: FBC catalog images ARE already index/catalog images
- **No benefit**: Would just wrap an already-complete catalog image
- **Adds complexity**: Extra build step, extra image to maintain
- **Not OLM pattern**: OLM documentation never shows this pattern

### Alternative 2: Migrate OLMv0 Bundle to FBC

**Approach**: Use `opm migrate` to convert bundle metadata to FBC format.

**Why NOT chosen**:
- **Bundle images already distributed**: Spec 002 already published bundle images
- **Legacy compatibility unclear**: OpenShift 4.15-4.18 may expect SQLite indexes
- **Temporary support**: OLMv0 is for EOL versions, not worth migration effort
- **Adds complexity**: Migration + validation + testing burden for short-term support

### Alternative 3: Use `opm alpha render-template` for FBC

**Approach**: Use semver template for automatic channel management.

**Why NOT chosen**:
- **Already have FBC**: Spec 001 created FBC manually with full control
- **Alpha status**: Templates are still alpha, may change
- **Less control**: Raw FBC gives more explicit control over channels/upgrades
- **Not needed**: Current FBC structure is working and validated

---

## Implementation Summary

### What This Feature Actually Needs

Based on research findings, this feature needs to:

1. **OLMv1 (Modern OpenShift 4.19+)**:
   - ✅ **No new images needed** - existing catalog image is correct
   - ✅ **No new builds needed** - spec 001 already creates the catalog image
   - ✨ **Update documentation** - clarify that catalog image = index image
   - ✨ **Rename CatalogSource example** - `catalogsource.yaml` → `catalogsource-olmv1.yaml` for clarity

2. **OLMv0 (Legacy OpenShift 4.15-4.18)**:
   - ✨ **Create OLMv0 index image** - using `opm index add` referencing bundle image
   - ✨ **Add Makefile targets** - `index-olmv0-build`, `index-olmv0-validate`, `index-olmv0-push`
   - ✨ **Create CatalogSource example** - `catalogsource-olmv0.yaml` referencing index image
   - ✨ **Document deprecation** - acknowledge SQLite deprecation, explain temporary usage

3. **Validation**:
   - ✨ **Add validation targets** - separate for FBC (`opm validate`) and SQLite (`opm index export`)
   - ✨ **Integrate into CI** - ensure both formats validate before release

### Revised Scope

**IMPORTANT**: The original specification assumed we needed to create index wrapper images for OLMv1. Research shows this is unnecessary.

**Updated deliverables**:
- ~~Containerfile.index.olmv1~~ **NOT NEEDED** - catalog image is already an index
- ✅ **Containerfile.index.olmv0** - NEW, creates SQLite index referencing bundle
- ✅ **Makefile targets** - For OLMv0 index build/validate/push
- ✅ **CatalogSource examples** - Separate for OLMv1 and OLMv0, correctly referencing appropriate images
- ✅ **Documentation updates** - Clarify terminology, explain format differences

---

## References

### Official Documentation
- [OLM File-Based Catalogs](https://olm.operatorframework.io/docs/tasks/creating-a-catalog/)
- [operator-registry GitHub](https://github.com/operator-framework/operator-registry)
- [Channel Naming Best Practices](https://olm.operatorframework.io/docs/best-practices/channel-naming/)

### Repository Context
- Existing OLMv1 catalog: [Containerfile.catalog](../../../Containerfile.catalog)
- Existing OLMv0 bundle: [Containerfile.bundle](../../../Containerfile.bundle)
- Current CatalogSource: [examples/catalogsource.yaml](../../../examples/catalogsource.yaml)
- Makefile: [Makefile](../../../Makefile)

### Tool Versions
- `opm` version: `e42f5c260` (Built: 2025-09-23)
- Location: `/opt/operator-sdk/bin/opm`

---

## Next Steps

Proceed to **Phase 1: Design & Contracts** to:
1. Define data model for index image structure and metadata
2. Create Containerfile specification for `Containerfile.index.olmv0`
3. Define Makefile target contracts for index image workflow
4. Generate quickstart guide for building and deploying index images
