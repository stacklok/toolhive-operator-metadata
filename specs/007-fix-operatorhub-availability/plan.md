# Implementation Plan: Fix OperatorHub Availability

**Branch**: `007-fix-operatorhub-availability` | **Date**: 2025-10-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/007-fix-operatorhub-availability/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

The ToolHive operator File-Based Catalog deploys successfully but does not appear correctly in the OpenShift OperatorHub UI - it shows with no name and zero operators. Additionally, example files reference production registry (ghcr.io/stacklok) instead of development registry (quay.io/roddiekieley), and the Subscription example has an incorrect sourceNamespace.

**Primary Requirements**:
1. Fix catalog metadata to appear in OperatorHub UI with name and operator count
2. Update example files to use development registry (quay.io/roddiekieley)
3. Correct Subscription sourceNamespace from "olm" to "openshift-marketplace"

**Technical Approach**: Investigate catalog.yaml metadata completeness, analyze OLM package manifest creation, update bundle image references in catalog.yaml, and correct example file configurations.

## Technical Context

**Language/Version**: YAML manifests, Shell (Makefile), Container images
**Primary Dependencies**:
- Kustomize (v3+) for manifest customization
- OPM (Operator Package Manager) for catalog validation
- Podman/Docker for container operations
- OpenShift 4.19+ / Kubernetes 1.24+ with OLM
**Storage**: File-based catalog YAML (catalog.yaml), example YAML manifests
**Testing**:
- Kustomize build validation (`kustomize build config/base`, `kustomize build config/default`)
- OPM catalog validation (`opm validate`)
- Manual OpenShift OperatorHub UI verification
**Target Platform**: OpenShift 4.19+ (primary), Kubernetes with OLM (secondary)
**Project Type**: Infrastructure/Kubernetes operator metadata repository
**Performance Goals**: Catalog pod startup <10s, PackageManifest creation <1 minute
**Constraints**:
- Must maintain constitution compliance (kustomize builds must pass)
- CRDs immutable (no modifications allowed)
- OpenShift restricted SCC compatibility
- Catalog served via gRPC on port 50051
**Scale/Scope**: Single operator package, 2 CRDs (MCPRegistry, MCPServer), 1 catalog channel

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Constitutional Principles Applicable to This Feature

✅ **I. Manifest Integrity (NON-NEGOTIABLE)** - COMPLIANT
- Changes involve YAML file edits (catalog.yaml, examples/*.yaml)
- Will verify `kustomize build config/base` and `kustomize build config/default` pass after changes
- No kustomize manifest modifications planned

✅ **II. Kustomize-Based Customization** - NOT APPLICABLE
- Feature does not modify kustomize overlays or patches
- Changes are to catalog metadata and example files only

✅ **III. CRD Immutability (NON-NEGOTIABLE)** - COMPLIANT
- No CRD modifications planned or needed
- CRDs remain untouched in config/crd/

✅ **IV. OpenShift Compatibility** - COMPLIANT
- Changes improve OpenShift OperatorHub integration
- Example files already target openshift-marketplace namespace
- No config/base or config/default modifications needed

✅ **V. Namespace Awareness** - COMPLIANT
- Subscription example will be corrected to use proper sourceNamespace
- CatalogSource already correctly deployed to openshift-marketplace
- No changes to manifest namespaces needed

### Gate Status: **PASS** ✅

All constitutional principles are satisfied. This feature involves:
1. Catalog metadata updates (catalog.yaml) - metadata-only, no manifest structure changes
2. Example file corrections - documentation/usage examples, not deployed manifests
3. No kustomize, CRD, or security context modifications

Proceeding to Phase 0 research.

### Post-Design Re-evaluation

**Status**: ✅ **PASS** (No changes from initial evaluation)

After completing Phases 0 and 1 (research, data modeling, contracts, quickstart), the implementation approach remains fully constitutional:

**Changes Confirmed**:
1. **catalog/toolhive-operator/catalog.yaml** - Regenerate using `opm render bundle/`
   - Metadata update only, no manifest structure changes
   - Constitution compliance: Manifest Integrity maintained (kustomize builds still pass)

2. **examples/catalogsource-olmv1.yaml** - Update image reference
   - Example file only, not a deployed kustomize manifest
   - Constitution compliance: Not applicable (documentation)

3. **examples/subscription.yaml** - Fix sourceNamespace
   - Example file only, not a deployed kustomize manifest
   - Constitution compliance: Not applicable (documentation)

**No kustomize manifests, CRDs, or security contexts modified.**

Gate Status: **PASS** ✅ - Proceed to implementation (tasks.md generation)

## Project Structure

### Documentation (this feature)

```
specs/007-fix-operatorhub-availability/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
# Repository structure for metadata/configuration project
catalog/
└── toolhive-operator/
    └── catalog.yaml          # OLM v1 File-Based Catalog metadata (EDIT)

examples/
├── catalogsource-olmv1.yaml  # CatalogSource deployment example (EDIT)
└── subscription.yaml          # Subscription installation example (EDIT)

bundle/
├── manifests/                 # OLM bundle CSVs and CRDs (READ-ONLY)
└── metadata/                  # Bundle annotations (READ-ONLY)

config/
├── base/                      # OpenShift kustomize overlay (NO CHANGES)
├── default/                   # Base kustomize config (NO CHANGES)
├── crd/                       # Custom Resource Definitions (IMMUTABLE)
├── manager/                   # Operator deployment (NO CHANGES)
└── rbac/                      # Service accounts, roles (NO CHANGES)

Makefile                       # Build and validation targets (NO CHANGES)
Containerfile.catalog          # Catalog image build (NO CHANGES - uses catalog.yaml)
```

**Structure Decision**: This is a Kubernetes operator metadata repository. Changes are confined to:
1. **catalog/toolhive-operator/catalog.yaml** - OLM catalog metadata defining package, channels, and bundle references
2. **examples/*.yaml** - Example deployment manifests for end users

No source code, kustomize manifests, or CRDs will be modified. The feature corrects metadata and example configurations.

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

No constitutional violations. This section is not applicable.
