# Implementation Plan: OLMv0 Bundle Container Image Build System

**Branch**: `002-build-an-olmv0` | **Date**: 2025-10-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-build-an-olmv0/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Create a complete build system for OLMv0 bundle container images that packages the ToolHive Operator manifests (CSV, CRDs) and metadata for deployment to legacy Kubernetes and OpenShift clusters (v4.10-v4.12). The system must coexist with the existing OLMv1 File-Based Catalog build system without conflicts, providing automated build, validation, and tagging capabilities through Makefile targets and Containerfile definitions.

## Technical Context

**Language/Version**: N/A (Container image build system using Containerfile/Dockerfile syntax)
**Primary Dependencies**:
- `podman` or `docker` (container build tools)
- `operator-sdk` (bundle validation)
- `make` (build automation)
- `yq` (YAML processing for manifests, already in use)

**Storage**: N/A (builds container images from existing filesystem bundle/ directory)
**Testing**:
- `operator-sdk bundle validate` (OLM compliance validation)
- Manual inspection with `podman inspect` (label verification)
- Container registry push/pull tests (deployment verification)

**Target Platform**:
- Container images for multi-architecture (linux/amd64, linux/arm64)
- Deployment targets: Kubernetes 1.20+, OpenShift 4.10-4.19 (OLMv0 clusters)

**Project Type**: Build system addition (infrastructure/tooling for existing manifest repository)

**Performance Goals**:
- Bundle image build completes in <2 minutes
- Bundle image size <50MB
- Validation completes in <30 seconds

**Constraints**:
- MUST NOT modify existing bundle/ directory structure (used by OLMv1 catalog builds)
- MUST NOT break existing `make catalog-build` or catalog validation workflows
- Bundle images MUST pass `operator-sdk bundle validate` with zero errors
- Containerfile MUST be compatible with both podman and docker

**Scale/Scope**:
- Single bundle image per operator version (currently v0.2.17)
- 3 manifest files (1 CSV, 2 CRDs) plus 1 metadata file (annotations.yaml)
- Support for versioned and latest image tags
- Integration with existing Makefile (currently ~155 lines, adding ~50 lines for bundle builds)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Manifest Integrity (NON-NEGOTIABLE)

**Status**: ✅ COMPLIANT

This feature does NOT modify any manifests in config/base or config/default. It only adds a new Containerfile and Makefile targets to build container images from the existing bundle/ directory. The bundle/ directory is independent of the kustomize build system.

**Verification**: Existing `kustomize build config/base` and `kustomize build config/default` will remain unaffected.

### II. Kustomize-Based Customization

**Status**: ✅ NOT APPLICABLE

This feature does not customize manifests—it packages existing manifests into container images. The bundle/ directory contains final manifests (already processed, not kustomize sources).

### III. CRD Immutability (NON-NEGOTIABLE)

**Status**: ✅ COMPLIANT

This feature will NOT modify CRD files. The Containerfile will copy existing CRD manifests from bundle/manifests/ into the container image without changes. CRDs remain upstream-controlled.

**Verification**: CRD files in bundle/manifests/ are read-only inputs to the build process.

### IV. OpenShift Compatibility

**Status**: ✅ COMPLIANT

The bundle container image contains manifests that already declare OpenShift compatibility via annotations (com.redhat.openshift.versions: "v4.10-v4.19" in bundle/metadata/annotations.yaml). The Containerfile build process preserves this metadata without modification.

### V. Namespace Awareness

**Status**: ✅ NOT APPLICABLE

Bundle images are namespace-agnostic—they contain operator manifests that OLM deploys according to the CatalogSource and Subscription configurations. Namespace placement is determined at deployment time, not in the bundle image itself.

### Constitution Compliance Summary

**Result**: ✅ ALL GATES PASSED

No constitutional violations. This feature is purely additive (new build tooling) and does not modify existing manifest sources or customization mechanisms. Re-check after Phase 1 design to ensure contracts and quickstart remain compliant.

## Project Structure

### Documentation (this feature)

```
specs/002-build-an-olmv0/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── Containerfile.bundle      # Bundle image build definition
│   ├── bundle-labels.yaml        # OLM label specifications
│   └── bundle-validation.yaml    # Expected operator-sdk validation output
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
# Existing structure (preserved, not modified)
bundle/
├── manifests/
│   ├── toolhive-operator.clusterserviceversion.yaml  # Existing CSV
│   ├── mcpregistries.crd.yaml                        # Existing CRD
│   └── mcpservers.crd.yaml                           # Existing CRD
└── metadata/
    └── annotations.yaml                              # Existing OLM annotations

catalog/                                               # Existing OLMv1 FBC
└── toolhive-operator/
    └── catalog.yaml                                  # Existing FBC schema

# New additions for this feature
Containerfile.bundle      # NEW: Bundle image build definition (root level)
Makefile                  # MODIFIED: Add bundle-* targets (preserve existing targets)

# Testing artifacts (new)
tests/
└── bundle/
    ├── validate-bundle.sh          # Bundle validation test script
    └── test-bundle-build.sh        # Bundle build smoke test
```

**Structure Decision**:

This feature adds build tooling at the repository root level:
- **Containerfile.bundle** at root (parallel to existing Containerfile.catalog)
- **Makefile modifications** adding new `bundle-build`, `bundle-validate-sdk`, `bundle-push` targets under a new "##@ OLM Bundle Image Targets" section
- **Test scripts** in tests/bundle/ for CI/CD validation

The bundle/ directory remains unchanged (preserves existing OLMv0 metadata used by both catalog builds and new bundle builds). This maintains dual-build capability without conflicts.

## Complexity Tracking

*No constitutional violations requiring justification.*

This feature maintains project simplicity by:
- Reusing existing bundle/ directory structure (no new directories for manifests)
- Following established patterns from Containerfile.catalog
- Adding minimal Makefile targets that mirror catalog-* naming conventions
- Avoiding introduction of new dependencies beyond standard OLM tooling

---

## Post-Phase 1 Constitution Re-Check

*Verification after completing design artifacts (research.md, data-model.md, contracts/, quickstart.md)*

### I. Manifest Integrity (NON-NEGOTIABLE)

**Status**: ✅ COMPLIANT (CONFIRMED)

**Design Verification**:
- `contracts/Containerfile.bundle` uses `ADD bundle/manifests` and `ADD bundle/metadata` (read-only operations)
- No modifications to config/base or config/default directories
- Quickstart.md explicitly instructs "DO NOT MODIFY" for bundle/ directory
- data-model.md classifies all manifests as "READ-ONLY (existing file)"

**Result**: No manifest integrity violations. Kustomize builds remain unaffected.

### II. Kustomize-Based Customization

**Status**: ✅ NOT APPLICABLE (CONFIRMED)

**Design Verification**:
- Containerfile copies files verbatim (no patching or transformation)
- Build process operates on final manifests, not kustomize sources
- No kustomization.yaml files created or modified

**Result**: Feature correctly bypasses kustomize (operates on post-kustomize outputs).

### III. CRD Immutability (NON-NEGOTIABLE)

**Status**: ✅ COMPLIANT (CONFIRMED)

**Design Verification**:
- data-model.md: "Bundle Manifest (CRD)" marked as "MUST NOT be modified from upstream"
- Containerfile uses ADD (copy), not COPY with transformations
- No CRD editing in any contract or quickstart step

**Result**: CRDs remain upstream-controlled, immutable.

### IV. OpenShift Compatibility

**Status**: ✅ COMPLIANT (CONFIRMED)

**Design Verification**:
- Containerfile includes `LABEL com.redhat.openshift.versions="v4.10-v4.19"`
- contracts/bundle-labels.yaml documents OpenShift version range
- Quickstart tests include deployment to OpenShift 4.10-4.12

**Result**: OpenShift compatibility preserved via bundle metadata.

### V. Namespace Awareness

**Status**: ✅ NOT APPLICABLE (CONFIRMED)

**Design Verification**:
- Bundle images are namespace-agnostic by design
- Quickstart deploys CatalogSource to `olm` namespace (standard OLM pattern)
- No namespace-scoped resources created in bundle/

**Result**: Namespace placement handled correctly by OLM at deployment time.

### Final Constitution Compliance

**Result**: ✅ ALL GATES PASSED POST-DESIGN

All design artifacts (Containerfile, Makefile targets, contracts, quickstart) comply with constitutional principles. No violations introduced during planning phase. Ready to proceed to Phase 2 (task generation).