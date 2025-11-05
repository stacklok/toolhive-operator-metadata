# Implementation Plan: Upgrade ToolHive Operator to v0.3.11

**Branch**: `011-v0-2-17` | **Date**: 2025-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/011-v0-2-17/spec.md`

## Summary

Upgrade toolhive-operator container images from v0.2.17 to v0.3.11 across all configuration files, manifests, and documentation. The v0.3.11 release addresses a cosign installer compatibility issue (reverting from v4 to v3.10.1) and includes 295 commits with updates across 487 files since v0.2.17.

**Technical Approach** (from research):
- Update 7 primary files containing version references (params.env, manager.yaml, Makefile, documentation)
- Download v0.3.11 upstream manifests from GitHub release to downloaded/toolhive-operator/0.3.11/
- Validate using multi-layer approach: kustomize builds, bundle validation, scorecard tests, catalog validation, constitution compliance
- Preserve v0.2.17 manifests for rollback capability
- Assume API compatibility based on semantic versioning (minor version increment)

## Technical Context

**Language/Version**: Shell/Bash (Makefile), YAML configuration, Kustomize v5.0.0+  
**Primary Dependencies**: kustomize v5.0.0+, operator-sdk v1.30.0+, opm v1.26.0+, podman/docker  
**Storage**: File-based (configuration files, YAML manifests)  
**Testing**: operator-sdk bundle validate, scorecard tests, kustomize validation, opm validate  
**Target Platform**: Linux development environment, Kubernetes/OpenShift deployment  
**Project Type**: Metadata repository (kustomize-based manifest management)  
**Performance Goals**:
- Kustomize builds < 5 seconds (SC-001)
- Bundle generation < 30 seconds
- Scorecard tests < 2 minutes (SC-004)
- Total upgrade time < 30 minutes (SC-006)

**Constraints**:
- CRDs MUST NOT change (constitution principle III - non-negotiable)
- Both config/base and config/default overlays MUST build successfully
- Scorecard tests require Kubernetes cluster access
- v0.3.11 container images must be publicly available at ghcr.io/stacklok/toolhive

**Scale/Scope**:
- 7 primary files to update
- 3 upstream manifest files to download
- 6 scorecard tests to pass
- 2 kustomize overlays to validate
- 8 success criteria to meet

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Manifest Integrity (NON-NEGOTIABLE)

**Status**: ✅ COMPLIANT

**Evaluation**: Version upgrade modifies only version references in configuration files. Kustomize build process remains unchanged. Both config/base and config/default must build successfully after upgrade (SC-001, SC-005).

---

### II. Kustomize-Based Customization

**Status**: ✅ COMPLIANT

**Evaluation**: Version updates use kustomize variable replacement via params.env. No direct manifest edits. Manager.yaml updates are in base manifests before kustomize processing. Pattern preserved.

---

### III. CRD Immutability (NON-NEGOTIABLE)

**Status**: ✅ COMPLIANT

**Evaluation**: CRD files in config/crd/ must NOT change. Downloaded manifests may have updated CRDs, but if they differ from v0.2.17, this indicates a breaking change that violates the constitution.

**Critical Check**: `git diff config/crd/` MUST return no changes after upgrade  
**Failure condition**: If CRDs change, STOP - requires separate feature branch and team consultation

---

### IV. OpenShift Compatibility

**Status**: ✅ COMPLIANT

**Evaluation**: Version upgrade affects both config/base (OpenShift) and config/default (Kubernetes) equally. Security patches, resource limits, and environment variables remain unchanged. Only image references update.

---

### V. Namespace Awareness

**Status**: ✅ COMPLIANT

**Evaluation**: Version upgrade does not modify namespace configuration. config/base targets opendatahub, config/default targets toolhive-operator-system. Namespace placement unchanged.

---

### VI. OLM Catalog Multi-Bundle Support

**Status**: ✅ COMPLIANT

**Evaluation**: Version upgrade creates new v0.3.11 bundle while preserving v0.2.17 manifests in downloaded/ directory. Catalog structure supports multiple bundle versions. Future catalogs can reference both v0.2.17 and v0.3.11.

---

**Constitution Check Summary**: ✅ ALL PRINCIPLES COMPLIANT

No constitutional violations. Version upgrade is configuration-only and preserves all architectural patterns.

---

## Project Structure

### Documentation (this feature)

```
specs/011-v0-2-17/
├── plan.md                       # This file
├── research.md                   # Phase 0 - 10 technical decisions
├── data-model.md                 # Phase 1 - 6 entities and state machines
├── quickstart.md                 # Phase 1 - 30-minute upgrade guide
├── contracts/                    # Phase 1 - Contracts
│   ├── file-updates.yaml         # Exact update locations
│   └── rollback-procedure.md     # Rollback process
├── checklists/
│   └── requirements.md           # Spec quality checklist
└── tasks.md                      # Phase 2 (/speckit.tasks - NOT YET CREATED)
```

### Source Code (repository root)

```
toolhive-operator-metadata/
├── config/
│   ├── base/
│   │   └── params.env                           # UPDATED: v0.2.17 → v0.3.11
│   ├── manager/
│   │   └── manager.yaml                         # UPDATED: v0.2.17 → v0.3.11
│   ├── default/                                 # VALIDATED
│   └── crd/                                     # IMMUTABLE
│
├── downloaded/
│   └── toolhive-operator/
│       ├── 0.2.17/                              # PRESERVED
│       └── 0.3.11/                              # NEW
│
├── Makefile                                     # UPDATED
├── README.md                                    # UPDATED
├── CLAUDE.md                                    # UPDATED
└── VALIDATION.md                                # UPDATED
```

**Structure Decision**: Metadata-only repository using shell/Make/YAML configuration. Version updates target configuration templates (config/), build definitions (Makefile), and documentation.

---

## Phase 0: Research (✅ COMPLETE)

**Output**: [research.md](research.md)

**10 Technical Decisions**:
1. Files to update
2. Manifest download approach
3. Breaking change analysis
4. Validation strategy
5. Documentation update strategy
6. Rollback strategy
7. Downloaded manifest management
8. Constitution compliance verification
9. Container image availability
10. Testing scope

---

## Phase 1: Design & Contracts (✅ COMPLETE)

**Outputs**:
- [data-model.md](data-model.md) - 6 entities, state machines, validation rules
- [contracts/file-updates.yaml](contracts/file-updates.yaml) - Update specifications and validation
- [contracts/rollback-procedure.md](contracts/rollback-procedure.md) - Rollback guarantee
- [quickstart.md](quickstart.md) - 30-minute upgrade guide

---

## Next Steps

**Command**: `/speckit.tasks`

Generate detailed task breakdown for implementation.

---

## Success Criteria

- **SC-001**: Kustomize builds complete in <5 seconds
- **SC-002**: Bundle validation passes on first attempt
- **SC-003**: Catalog validation passes on first attempt
- **SC-004**: All scorecard tests pass (100%)
- **SC-005**: Constitution compliance verified
- **SC-006**: Upgrade completes within 30 minutes
- **SC-007**: No manual intervention required
- **SC-008**: Zero v0.2.17 references in generated manifests

---

## References

- [spec.md](spec.md) - Feature specification
- [research.md](research.md) - Technical decisions
- [data-model.md](data-model.md) - Entity definitions
- [quickstart.md](quickstart.md) - Upgrade guide
- [contracts/](contracts/) - Update and rollback contracts
- [../../.specify/memory/constitution.md](../../.specify/memory/constitution.md) - Project constitution
