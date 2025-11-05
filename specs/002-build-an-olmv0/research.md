# Research: OLMv0 Bundle Container Image Build System

**Feature**: OLMv0 Bundle Container Image Build System
**Branch**: `002-build-an-olmv0`
**Date**: 2025-10-09

## Overview

This document captures research findings for implementing an OLMv0 bundle container image build system. The research focuses on OLM bundle format specifications, container image requirements, validation tooling, and best practices for dual OLMv0/OLMv1 build systems.

## Research Areas

### 1. OLMv0 Bundle Format Specification

**Decision**: Use OLM bundle format with `registry+v1` mediatype

**Rationale**:
- OLMv0 bundles follow the "registry+v1" format defined in the Operator Framework
- Bundle images MUST contain `/manifests/` directory with CSV and CRD YAML files
- Bundle images MUST contain `/metadata/` directory with `annotations.yaml`
- The existing `bundle/` directory already follows this structure correctly

**Key Requirements Identified**:
1. **Directory Structure**:
   ```
   /manifests/               # Operator manifests
   ├── *.clusterserviceversion.yaml
   └── *.crd.yaml (one per CRD)

   /metadata/                # Bundle metadata
   └── annotations.yaml      # OLM annotations
   ```

2. **Required Annotations** (in `/metadata/annotations.yaml`):
   - `operators.operatorframework.io.bundle.mediatype.v1: registry+v1`
   - `operators.operatorframework.io.bundle.manifests.v1: manifests/`
   - `operators.operatorframework.io.bundle.metadata.v1: metadata/`
   - `operators.operatorframework.io.bundle.package.v1: <package-name>`
   - `operators.operatorframework.io.bundle.channels.v1: <channel-list>`
   - `operators.operatorframework.io.bundle.channel.default.v1: <default-channel>`

3. **Container Labels**: Bundle images MUST include labels matching the annotations for OLM discovery

**Alternatives Considered**:
- **Plain format**: Deprecated, not supported in OLMv0 clusters
- **Helm format**: Not applicable for non-Helm operators

**References**:
- https://olm.operatorframework.io/docs/tasks/creating-operator-bundle/
- https://github.com/operator-framework/operator-registry/blob/master/docs/design/operator-bundle.md

---

### 2. Containerfile Best Practices for Bundle Images

**Decision**: Use scratch base image with ADD/COPY for manifests and LABEL directives for OLM metadata

**Rationale**:
- Scratch base minimizes image size (<10MB typical) and attack surface
- Bundle images are data-only (no executable needed)
- OLM reads files directly from the image filesystem
- Pattern matches existing `Containerfile.catalog` approach (consistency)

**Implementation Pattern**:
```dockerfile
FROM scratch

# Copy bundle directories
ADD bundle/manifests /manifests/
ADD bundle/metadata /metadata/

# OLM discovery labels (must match annotations.yaml)
LABEL operators.operatorframework.io.bundle.mediatype.v1=registry+v1
LABEL operators.operatorframework.io.bundle.manifests.v1=manifests/
LABEL operators.operatorframework.io.bundle.metadata.v1=metadata/
LABEL operators.operatorframework.io.bundle.package.v1=toolhive-operator
LABEL operators.operatorframework.io.bundle.channels.v1=fast
LABEL operators.operatorframework.io.bundle.channel.default.v1=fast

# Optional: Metadata labels
LABEL org.opencontainers.image.title="ToolHive Operator Bundle"
LABEL org.opencontainers.image.description="OLMv0 Bundle for ToolHive Operator"
```

**Alternatives Considered**:
- **UBI minimal base**: Adds unnecessary OS layer (~40MB), slower builds
- **Alpine base**: Not needed, bundle has no runtime requirements
- **Distroless**: Overkill for static file delivery

**References**:
- https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
- Existing Containerfile.catalog pattern in this repository

---

### 3. Operator SDK Validation Requirements

**Decision**: Use `operator-sdk bundle validate ./bundle --select-optional suite=operatorframework` for comprehensive validation

**Rationale**:
- `operator-sdk bundle validate` is the authoritative validation tool for OLM bundles
- Checks both bundle structure (directories, files) and content (CSV validity, CRD references, RBAC)
- The `--select-optional suite=operatorframework` flag enables recommended (non-breaking) checks
- Validation must pass with zero errors for successful OLM deployment

**Validation Categories**:
1. **Bundle Structure**:
   - Directories `/manifests/` and `/metadata/` exist
   - `annotations.yaml` is valid YAML with required fields
   - All files are valid YAML/JSON

2. **CSV Validation**:
   - `spec.version` matches bundle metadata
   - `spec.customresourcedefinitions.owned` lists all CRDs in manifests/
   - `spec.install.spec.permissions` and `clusterPermissions` are complete
   - `spec.install.spec.deployments[*].spec.template.spec.containers[*].image` references are valid

3. **CRD Validation**:
   - CRD manifests are valid OpenAPI schemas
   - CRD `metadata.name` matches `<plural>.<group>` pattern

**Expected Validation Output** (success):
```
INFO[0000] All validation tests have completed successfully
```

**Common Validation Errors to Prevent**:
- CSV version mismatch with annotations
- Missing CRD ownership in CSV
- Invalid RBAC permissions
- Malformed image references

**Alternatives Considered**:
- **Manual validation**: Error-prone, not comprehensive
- **opm alpha bundle validate**: Deprecated in favor of operator-sdk

**References**:
- https://sdk.operatorframework.io/docs/cli/operator-sdk_bundle_validate/
- https://olm.operatorframework.io/docs/best-practices/common/

---

### 4. Dual Build System Coexistence Strategy

**Decision**: Maintain separate Containerfiles (Containerfile.bundle and Containerfile.catalog) with isolated Makefile target groups

**Rationale**:
- **File Isolation**: Separate Containerfiles prevent build conflicts (different FROM, COPY, LABEL)
- **Target Isolation**: Separate Makefile target groups (`##@ OLM Bundle Image Targets` vs `##@ OLM Catalog Targets`) clearly distinguish workflows
- **Shared Source**: Both builds use the same `bundle/` directory as input (no duplication)
- **Independent Validation**: `bundle-validate-sdk` (operator-sdk) vs `catalog-validate` (opm) run independently

**Build Flow Comparison**:

| Aspect | OLMv0 Bundle Build | OLMv1 Catalog Build |
|--------|-------------------|---------------------|
| **Containerfile** | Containerfile.bundle | Containerfile.catalog |
| **Input Directory** | bundle/ | catalog/ |
| **Build Tool** | podman/docker | podman/docker |
| **Validation Tool** | operator-sdk bundle validate | opm validate |
| **Image Tag** | ghcr.io/stacklok/toolhive/bundle:v0.2.17 | ghcr.io/stacklok/toolhive/catalog:v0.2.17 |
| **Makefile Targets** | bundle-build, bundle-validate-sdk, bundle-push | catalog-build, catalog-validate, catalog-push |
| **Use Case** | OLMv0 clusters (OpenShift 4.10-4.12, K8s with OLM) | OLMv1 clusters (OpenShift 4.13+) |

**Conflict Prevention**:
- No shared build artifacts (separate image names)
- No overlapping file modifications
- Independent validation passes
- CI/CD can run both builds sequentially without interference

**Alternatives Considered**:
- **Single multi-stage Containerfile**: Complex, harder to maintain, violates separation of concerns
- **Build flag switching**: Error-prone, makes debugging difficult
- **Monorepo-style separation**: Unnecessary file duplication

**References**:
- Existing Makefile structure in this repository
- https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html

---

### 5. Image Tagging and Versioning Strategy

**Decision**: Use semantic version tags (v0.2.17) and latest tag, mirroring existing catalog image strategy

**Rationale**:
- **Version Tag**: Allows deployment of specific operator versions (pinning for stability)
- **Latest Tag**: Simplifies testing and development workflows
- **Consistency**: Matches existing catalog image tagging scheme
- **Registry Compatibility**: Standard approach for ghcr.io and other registries

**Tagging Pattern**:
```bash
# Build and tag versioned image
podman build -f Containerfile.bundle -t ghcr.io/stacklok/toolhive/bundle:v0.2.17 .

# Tag as latest
podman tag ghcr.io/stacklok/toolhive/bundle:v0.2.17 ghcr.io/stacklok/toolhive/bundle:latest
```

**Version Source**: Extract from `bundle/metadata/annotations.yaml` or CSV `spec.version`

**Alternatives Considered**:
- **Git commit SHA tags**: Not user-friendly for deployment
- **Date-based tags**: Doesn't convey version information
- **Major.minor only**: Loses patch version granularity

---

### 6. Makefile Integration Patterns

**Decision**: Add new `##@ OLM Bundle Image Targets` section with targets: `bundle-build`, `bundle-validate-sdk`, `bundle-push`, `bundle-all`

**Rationale**:
- Follows existing Makefile organizational pattern (comment-based sections)
- Mirrors catalog target naming (consistency)
- Integrates with existing `help` target documentation
- Allows selective execution (build-only, validate-only, or full workflow)

**New Makefile Targets**:

```makefile
##@ OLM Bundle Image Targets

.PHONY: bundle-build
bundle-build: bundle-validate-sdk ## Build bundle container image
	@echo "Building bundle container image..."
	podman build -f Containerfile.bundle -t ghcr.io/stacklok/toolhive/bundle:v0.2.17 .
	podman tag ghcr.io/stacklok/toolhive/bundle:v0.2.17 ghcr.io/stacklok/toolhive/bundle:latest
	@echo "✅ Bundle image built: ghcr.io/stacklok/toolhive/bundle:v0.2.17"

.PHONY: bundle-validate-sdk
bundle-validate-sdk: ## Validate OLM bundle with operator-sdk
	@echo "Validating bundle with operator-sdk..."
	operator-sdk bundle validate ./bundle --select-optional suite=operatorframework
	@echo "✅ Bundle validation passed"

.PHONY: bundle-push
bundle-push: ## Push bundle image to registry
	@echo "Pushing bundle image to ghcr.io..."
	podman push ghcr.io/stacklok/toolhive/bundle:v0.2.17
	podman push ghcr.io/stacklok/toolhive/bundle:latest
	@echo "✅ Bundle image pushed"

.PHONY: bundle-all
bundle-all: bundle-validate-sdk bundle-build ## Run complete bundle workflow (validate, build)
	@echo "✅ Complete bundle workflow finished"
```

**Integration with Existing Targets**:
- `validate-all`: Add dependency on `bundle-validate-sdk`
- `help`: Automatically includes new targets (uses awk parser)

**Alternatives Considered**:
- **Inline targets in existing sections**: Confusing, breaks logical grouping
- **Separate Makefile.bundle**: Adds complexity, requires includes

---

## Summary of Decisions

| Area | Decision | Key Benefit |
|------|----------|-------------|
| **Bundle Format** | registry+v1 mediatype | Standard OLMv0 compatibility |
| **Base Image** | scratch | Minimal size, maximum security |
| **Validation** | operator-sdk bundle validate | Authoritative OLM compliance |
| **Build Isolation** | Separate Containerfiles | No conflicts with catalog builds |
| **Tagging** | Semantic version + latest | Deployment flexibility |
| **Makefile** | New ##@ section with bundle-* targets | Consistency, discoverability |

## Implementation Readiness

All research questions resolved. No outstanding unknowns. Ready to proceed to Phase 1 (design artifacts and contracts).