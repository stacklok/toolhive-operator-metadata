# Implementation Plan: OLMv1 File-Based Catalog Bundle

**Branch**: `001-build-an-olmv1` | **Date**: 2025-10-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-build-an-olmv1/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Create OLMv1 File-Based Catalog (FBC) bundle metadata for the ToolHive Operator to enable distribution and installation through Operator Lifecycle Manager v1. The implementation adds catalog metadata files following the FBC schema specification (olm.package, olm.channel, olm.bundle), provides tooling to build catalog container images using opm, and ensures operator-sdk validation compliance for production readiness.

## Technical Context

**Language/Version**: YAML/JSON (FBC schema format), Container images (catalog packaging)
**Primary Dependencies**: opm (Operator Package Manager), operator-sdk (validation), kustomize (existing manifests)
**Storage**: Container registry (ghcr.io/stacklok/toolhive) for catalog images, Git repository for FBC metadata files
**Testing**: opm validate (schema validation), operator-sdk bundle validate (Operator Framework compliance), operator-sdk scorecard (quality testing)
**Target Platform**: Kubernetes 1.16+ / OpenShift 4.x with OLMv1 support
**Project Type**: Kubernetes operator metadata (manifest-based)
**Performance Goals**: Catalog image build time < 2 minutes, validation time < 1 minute
**Constraints**: Must comply with OLMv1 FBC specification, must pass operator-sdk validation suite, CRDs must remain unchanged (constitution III), kustomize builds must succeed (constitution I)
**Scale/Scope**: Single operator package (toolhive-operator), 1+ bundle versions (starting with v0.2.17), single "stable" channel initially (multi-channel support deferred to P4)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Manifest Integrity | ✅ PASS | FBC bundle adds new catalog/ directory with metadata files. Existing kustomize builds in config/base and config/default remain unchanged and must continue to pass. |
| II. Kustomize-Based Customization | ✅ PASS | FBC metadata is separate from kustomize manifests. No modification of existing kustomize overlays required. |
| III. CRD Immutability | ✅ PASS | FBC bundle references existing CRDs from config/crd/ without modification. CRDs remain unchanged. |
| IV. OpenShift Compatibility | ✅ PASS | FBC bundle metadata will support both Kubernetes and OpenShift deployments through OLMv1. No changes to existing OpenShift overlays. |
| V. Namespace Awareness | ✅ PASS | FBC bundle metadata is namespace-agnostic (OLMv1 handles namespace placement at install time). Existing namespace configuration in config/ unchanged. |

**Constitution Compliance**: ✅ ALL GATES PASSED

No complexity tracking required - no constitutional violations.

## Project Structure

### Documentation (this feature)

```
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
catalog/                          # NEW: FBC metadata directory
└── toolhive-operator/           # Package directory
    ├── catalog.yaml             # Combined FBC schemas (olm.package, olm.channel, olm.bundle)
    └── .indexignore             # Optional: exclude files from catalog build

bundle/                          # NEW: OLM bundle directory (traditional bundle format)
├── manifests/                   # Operator manifests for bundle
│   ├── toolhive-operator.clusterserviceversion.yaml  # CSV manifest
│   ├── mcpregistries.crd.yaml  # MCPRegistry CRD (copied from config/crd/)
│   └── mcpservers.crd.yaml     # MCPServer CRD (copied from config/crd/)
└── metadata/                    # Bundle metadata
    └── annotations.yaml         # Bundle annotations

config/                          # EXISTING: Unchanged kustomize structure
├── base/                        # OpenShift overlay
├── default/                     # Default Kubebuilder config
├── crd/                         # CRD sources (referenced by bundle)
├── manager/                     # Deployment manifests (referenced by bundle)
└── rbac/                        # RBAC manifests (referenced by bundle)

Containerfile.catalog            # NEW: Catalog image build file (for opm)
Makefile                         # UPDATED: Add targets for bundle/catalog build
```

**Structure Decision**: This is a manifest-based repository (not a traditional application). The structure adds two new top-level directories:

1. **catalog/**: Contains FBC metadata following the olm.operatorframework.io schema
2. **bundle/**: Contains traditional OLM bundle format (manifests + metadata) as an intermediate step for catalog generation

The existing config/ kustomize structure remains unchanged per constitution principles I and II.

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

No violations - complexity tracking not required.

---

## Phase 0: Research Summary

**Status**: ✅ Complete

**Artifacts**:
- [research.md](research.md) - Technology decisions and best practices

**Key Decisions**:
1. **Single "stable" channel** for initial release (multi-channel deferred to P4)
2. **YAML format** for FBC schemas (consistency with existing manifests)
3. **Bundle-first approach**: Generate traditional bundle → convert to FBC with opm
4. **Comprehensive CSV metadata** including required and recommended fields
5. **Full validation suite**: operator-sdk bundle validate + opm validate + scorecard

**Research Coverage**:
- OLM FBC specification and schema requirements
- Bundle generation workflow and tooling
- Validation requirements and best practices
- Container image build process for catalogs

---

## Phase 1: Design Summary

**Status**: ✅ Complete

**Artifacts**:
- [data-model.md](data-model.md) - FBC schema structure and relationships
- [contracts/catalog.yaml](contracts/catalog.yaml) - Example FBC metadata
- [contracts/bundle-annotations.yaml](contracts/bundle-annotations.yaml) - Bundle metadata template
- [contracts/Containerfile.catalog](contracts/Containerfile.catalog) - Catalog image build file
- [quickstart.md](quickstart.md) - Step-by-step build and validation guide

**Design Highlights**:
- Three FBC schemas: olm.package, olm.channel, olm.bundle
- Clear referential integrity between schemas
- Bundle directory structure with manifests/ and metadata/
- Catalog container image using scratch base for minimal size
- Comprehensive validation workflow

**Agent Context Updated**: ✅ CLAUDE.md updated with technology stack

---

## Constitution Re-Check (Post-Design)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Manifest Integrity | ✅ PASS | Design adds bundle/ and catalog/ directories. No changes to config/ structure. Kustomize builds remain intact. |
| II. Kustomize-Based Customization | ✅ PASS | FBC bundle is independent of kustomize. CRDs copied to bundle/ maintain source in config/crd/. |
| III. CRD Immutability | ✅ PASS | CRDs copied from config/crd/ to bundle/manifests/ without modification. Source CRDs remain unchanged. |
| IV. OpenShift Compatibility | ✅ PASS | CSV will reference both Kubernetes and OpenShift deployments. OLM handles platform detection. |
| V. Namespace Awareness | ✅ PASS | Bundle is namespace-agnostic. OLM deploys to namespace specified in Subscription resource. |

**Final Constitution Compliance**: ✅ ALL GATES PASSED

---

## Next Steps

Run `/speckit.tasks` to generate task breakdown from this implementation plan.
