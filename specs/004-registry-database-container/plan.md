# Implementation Plan: Registry Database Container Image (Index Image)

**Branch**: `004-registry-database-container` | **Date**: 2025-10-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-registry-database-container/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Create operator registry database container images (index images) that properly reference either OLMv1 catalog images or OLMv0 bundle images. Index images serve as the correct architectural layer for CatalogSource references, with the registry-server serving the operator metadata to OpenShift's OperatorHub. This feature adds Makefile targets for building and validating index images for both modern (4.19+) and legacy (4.15-4.18) OpenShift versions while preventing mixed-format content.

## Technical Context

**Language/Version**: Container builds using Podman/Docker, Makefile for build orchestration
**Primary Dependencies**: `opm` tool from operator-framework/operator-registry, `podman` for container builds, `kustomize` for manifest validation
**Storage**: Container registry (ghcr.io) for storing index images
**Testing**: `opm validate` for index validation, `kustomize build` for manifest integrity, manual deployment testing via CatalogSource
**Target Platform**: Container images compatible with OpenShift 4.15-4.19+ (registry-server runtime)
**Project Type**: Container metadata repository (Makefile-based build system, no application source code)
**Performance Goals**: Index image validation in <30 seconds, CatalogSource discovery within 2 minutes of deployment
**Constraints**: Index images must be compatible with operator-registry registry-server, must not mix OLMv0/OLMv1 formats, must reference existing catalog/bundle images
**Scale/Scope**: 2 index image variants (OLMv0, OLMv1), support for multiple operator versions per index, integration with existing Makefile workflow (13 existing targets)

**Additional Context**:
- Existing OLMv1 catalog image: `ghcr.io/stacklok/toolhive/catalog:v0.2.17` (from spec 001)
- Existing OLMv0 bundle image: `ghcr.io/stacklok/toolhive/bundle:v0.2.17` (from spec 002)
- Current CatalogSource incorrectly references catalog image directly at line 21 of `examples/catalogsource.yaml`
- Makefile structure: organized sections with `##@` headers, uses `.PHONY` targets
- Build tool: Podman (used throughout existing Makefile)
- Registry: ghcr.io/stacklok/toolhive namespace

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Evaluation (Phase 0)

**I. Manifest Integrity** ✅ PASS
- This feature adds Makefile targets and Containerfiles, does not modify existing kustomize manifests
- Existing `kustomize-validate` target will continue to ensure `config/base` and `config/default` build successfully
- No risk to manifest integrity

**II. Kustomize-Based Customization** ✅ PASS
- This feature does not modify kustomize manifests, only adds build infrastructure for index images
- No impact on existing kustomize overlay architecture

**III. CRD Immutability** ✅ PASS (NON-NEGOTIABLE)
- This feature does not touch CRDs in `config/crd/`
- CRDs remain unchanged and compatible with upstream ToolHive operator

**IV. OpenShift Compatibility** ✅ PASS
- Index images support both modern (4.19+) and legacy (4.15-4.18) OpenShift versions
- Separate index images for OLMv0 and OLMv1 ensure compatibility across OpenShift version ranges
- No changes to `config/base` or `config/default` overlays

**V. Namespace Awareness** ✅ PASS
- Index images are namespace-agnostic (referenced by CatalogSource, served by registry-server)
- CatalogSource examples may update namespace references but maintain existing namespace placement strategy
- No impact on operator deployment namespaces

**Kustomize Build Standards** ✅ PASS
- This feature does not modify kustomize manifests
- No impact on existing kustomize build standards

**OpenDataHub Integration Requirements** ✅ PASS
- Index images enhance OpenDataHub integration by providing proper registry architecture
- No changes to `opendatahub` namespace placement or security contexts
- Improves integration reliability by correcting CatalogSource references

**Compliance Verification Checklist**:
1. ✅ `kustomize build config/base` succeeds (no manifest changes)
2. ✅ `kustomize build config/default` succeeds (no manifest changes)
3. ✅ CRD files remain unchanged (no CRD modifications planned)
4. ✅ New patches documented (N/A - no new patches)
5. ✅ Namespace placement correct (N/A - index images are namespace-agnostic)

**GATE RESULT**: ✅ **PASS** - All constitutional principles satisfied, proceed to Phase 0 research

## Project Structure

### Documentation (this feature)

```
specs/004-registry-database-container/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - opm tooling research, index image patterns
├── data-model.md        # Phase 1 output - index image structure, metadata schemas
├── quickstart.md        # Phase 1 output - building and deploying index images
├── contracts/           # Phase 1 output - Containerfile specs, Makefile target contracts
│   ├── containerfile-index-olmv0.md    # OLMv0 index Containerfile specification
│   ├── containerfile-index-olmv1.md    # OLMv1 index Containerfile specification
│   └── makefile-targets.md             # New Makefile target specifications
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

This is a container metadata repository with no application source code. The structure is organized around operator lifecycle management (OLM) artifacts and build infrastructure:

```
toolhive-operator-metadata/
├── Makefile                           # BUILD TARGETS ADDED HERE
│   └── [NEW] ##@ Index Image Targets section with:
│       - index-olmv1-build           # Build OLMv1 index image
│       - index-olmv1-validate        # Validate OLMv1 index image
│       - index-olmv1-push            # Push OLMv1 index to registry
│       - index-olmv0-build           # Build OLMv0 index image
│       - index-olmv0-validate        # Validate OLMv0 index image
│       - index-olmv0-push            # Push OLMv0 index to registry
│       - index-validate-all          # Validate both index images
│
├── Containerfile.index.olmv1         # NEW - OLMv1 index image build
├── Containerfile.index.olmv0         # NEW - OLMv0 index image build
│
├── Containerfile.catalog             # Existing - OLMv1 catalog image (spec 001)
├── Containerfile.bundle              # Existing - OLMv0 bundle image (spec 002)
│
├── examples/
│   ├── catalogsource-olmv1.yaml      # UPDATED - references OLMv1 index
│   └── catalogsource-olmv0.yaml      # NEW - references OLMv0 index
│   └── catalogsource.yaml            # DEPRECATED - old direct catalog reference
│
├── catalog/                          # Existing - OLMv1 FBC metadata
│   └── toolhive-operator/
│       └── catalog.yaml
│
├── bundle/                           # Existing - OLMv0 bundle metadata
│   ├── manifests/
│   └── metadata/
│
└── config/                           # Existing - kustomize manifests (unchanged)
    ├── base/                         # OpenShift overlay
    ├── default/                      # Standard Kubebuilder
    ├── crd/                          # CRDs (immutable per constitution)
    ├── manager/
    ├── rbac/
    ├── prometheus/
    └── network-policy/
```

**Structure Decision**:

This feature adds **build infrastructure only** - no source code directories. The repository is a metadata-only project using Makefile-based orchestration for container image builds.

**Key Additions**:
1. **2 new Containerfiles**: `Containerfile.index.olmv1` and `Containerfile.index.olmv0` for building index images
2. **6+ new Makefile targets**: Organized under `##@ Index Image Targets` section following existing Makefile conventions
3. **1-2 updated CatalogSource examples**: Corrected to reference index images instead of catalog/bundle images directly

**Unchanged Components**:
- No modifications to `config/` directory (kustomize manifests)
- No modifications to `catalog/` or `bundle/` directories (existing metadata)
- No modifications to existing Containerfiles (catalog, bundle)
- CRDs remain immutable (constitution requirement)

## Constitution Check - Post-Design Re-Evaluation

*Re-checked after Phase 1 design completion*

### Design Summary

Phase 1 design produced:
- **research.md**: Analysis showing OLMv1 catalog images need no changes, OLMv0 requires new index image
- **data-model.md**: Data structures for OLMv1 catalog (existing), OLMv0 index (new), and CatalogSource resources
- **contracts/**: Specifications for OLMv0 index build, Makefile targets, CatalogSource examples
- **quickstart.md**: Deployment guide for both OLMv1 and OLMv0 formats

### Post-Design Constitutional Review

**I. Manifest Integrity** ✅ PASS
- **Design impact**: No changes to kustomize manifests
- **Deliverables**: Only Makefile targets, CatalogSource examples
- **Compliance**: `kustomize build config/base` and `config/default` remain unaffected

**II. Kustomize-Based Customization** ✅ PASS
- **Design impact**: No kustomize modifications
- **Deliverables**: Build infrastructure only (Makefile, `opm` commands)
- **Compliance**: No impact on overlay architecture

**III. CRD Immutability** ✅ PASS (NON-NEGOTIABLE)
- **Design impact**: Zero CRD modifications
- **Deliverables**: Index images reference existing operator; CRDs unchanged
- **Compliance**: CRDs remain immutable per constitution requirement

**IV. OpenShift Compatibility** ✅ PASS
- **Design impact**: **Enhanced** compatibility via proper index architecture
- **OLMv1**: Existing catalog image for OpenShift 4.19+
- **OLMv0**: New index image for OpenShift 4.15-4.18
- **Compliance**: Maintains and improves multi-version support

**V. Namespace Awareness** ✅ PASS
- **Design impact**: CatalogSource examples reference `olm` namespace (standard)
- **Index images**: Namespace-agnostic (served by registry-server)
- **Compliance**: No changes to operator deployment namespaces (`opendatahub` or `toolhive-operator-system`)

**Kustomize Build Standards** ✅ PASS
- **Design impact**: N/A - no kustomize changes
- **Compliance**: Existing standards remain in effect

**OpenDataHub Integration Requirements** ✅ PASS
- **Design impact**: **Improved** integration via corrected CatalogSource references
- **Current issue**: CatalogSource directly references catalog image (correct for OLMv1, but clarification needed)
- **Design solution**: Separate examples for OLMv1 and OLMv0, clear documentation
- **Compliance**: No changes to `opendatahub` namespace or security contexts

**Compliance Verification Checklist** (Post-Design):
1. ✅ `kustomize build config/base` succeeds (no manifest changes in design)
2. ✅ `kustomize build config/default` succeeds (no manifest changes in design)
3. ✅ CRD files remain unchanged (design does not touch CRDs)
4. ✅ New patches documented (N/A - no new kustomize patches)
5. ✅ Namespace placement correct (CatalogSource uses `olm`, operator deploys to existing namespaces)

### Additional Design Insights

**Key Finding from Research**: "Index image" and "catalog image" are the same concept in OLM terminology. The original specification assumed we needed to create index wrapper images for OLMv1, but research shows:

- **OLMv1**: Existing catalog image from spec 001 **IS** the index/catalog image - no wrapper needed
- **OLMv0**: Bundle images **require** an index wrapper - new build process needed

**Design Scope Adjustment**: Original spec called for index images for both formats. Actual design:
- ✅ OLMv1: No new images needed, update documentation and examples
- ✅ OLMv0: New index image build using `opm index add` (deprecated but necessary for legacy support)

**Constitutional Impact**: The scope reduction (no OLMv1 index wrapper) **further reduces** constitutional risk by minimizing new artifacts.

### GATE RESULT: ✅ **PASS** - All constitutional principles satisfied post-design

**Justification**: Design adds only build infrastructure (Makefile targets, `opm` commands) and documentation. Zero impact on kustomize manifests, CRDs, or namespace configurations. All constitutional requirements remain satisfied.

**Proceed to**: Phase 2 task generation via `/speckit.tasks`

## Complexity Tracking

*No constitutional violations - this section not needed*
