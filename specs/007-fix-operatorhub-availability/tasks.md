---
description: "Implementation tasks for fixing OperatorHub availability"
---

# Tasks: Fix OperatorHub Availability

**Input**: Design documents from `/specs/007-fix-operatorhub-availability/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Not explicitly requested in feature specification. Focus is on metadata correction and validation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions
This is a Kubernetes operator metadata repository. File paths:
- `catalog/toolhive-operator/catalog.yaml` - OLM File-Based Catalog metadata
- `examples/catalogsource-olmv1.yaml` - CatalogSource deployment example
- `examples/subscription.yaml` - Subscription installation example
- `Makefile` - Build and validation targets (read-only for this feature)
- `Containerfile.catalog` - Catalog image build (read-only for this feature)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Validate prerequisites and prepare for catalog regeneration

- [x] T001 [P] Verify opm (Operator Package Manager) is installed and functional (run `opm version`)
- [x] T002 [P] Verify bundle directory exists and contains CSV at `bundle/manifests/toolhive-operator.clusterserviceversion.yaml`
- [x] T003 [P] Verify current catalog.yaml structure by reading `catalog/toolhive-operator/catalog.yaml`
- [x] T004 [P] Back up current catalog.yaml to `catalog/toolhive-operator/catalog.yaml.backup-pre-007`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core catalog regeneration that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 [US1] Regenerate catalog.yaml with embedded CSV using `opm render bundle/ > catalog/toolhive-operator/catalog.yaml`
- [x] T006 [US1] Verify catalog.yaml now contains olm.bundle.object properties (run `grep -c "olm.bundle.object" catalog/toolhive-operator/catalog.yaml` - expect 3)
- [x] T007 [US1] Verify catalog.yaml file size increased significantly (run `wc -l catalog/toolhive-operator/catalog.yaml` - expect 500-800 lines)
- [x] T008 [US1] Validate regenerated catalog using `opm validate catalog/toolhive-operator` (Note: validation may report schema warnings for FBC format; verify catalog contains 3 olm.bundle.object properties and correct bundle image reference as primary success criteria)
- [x] T008a [US1] Verify catalog.yaml contains required OperatorHub metadata fields (run `grep -E "(displayName|description|icon)" catalog/toolhive-operator/catalog.yaml` - should show matches for displayName, description, and icon within olm.bundle.object properties)

**Checkpoint**: Foundation ready - catalog.yaml regenerated with CSV embedded

---

## Phase 3: User Story 1 - OperatorHub Displays Catalog with Operator Count (Priority: P1) 🎯 MVP

**Goal**: Fix catalog metadata so OperatorHub shows "ToolHive Operator Catalog" with "(1)" operator count

**Independent Test**: Deploy the CatalogSource to an OpenShift cluster and verify the OperatorHub UI shows "ToolHive Operator Catalog" with "1 operator" in the Sources section.

### Implementation for User Story 1

- [x] T009 [US1] Update bundle image reference in `catalog/toolhive-operator/catalog.yaml` from `ghcr.io/stacklok/toolhive/bundle:v0.2.17` to `quay.io/roddiekieley/toolhive-operator-bundle:v0.2.17`
- [x] T010 [US1] Verify bundle image reference is correct (run `grep "image:" catalog/toolhive-operator/catalog.yaml | grep bundle`)
- [x] T011 [US1] Re-validate catalog after image update using `opm validate catalog/toolhive-operator`
- [x] T012 [US1] Verify kustomize builds still pass (constitutional compliance) - run `kustomize build config/default > /dev/null && kustomize build config/base > /dev/null`
- [x] T013 [US1] Build updated catalog container image using `podman build -f Containerfile.catalog -t quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17 .`
- [x] T014 [US1] Test catalog image locally by running `podman run --rm -p 50051:50051 quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17` and verify gRPC serves packages
- [ ] T015 [US1] Push catalog image to registry using `podman push quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17` (MANUAL: requires registry authentication)

**Checkpoint**: User Story 1 implementation complete - catalog.yaml has embedded CSV and references dev registry

---

## Phase 4: User Story 2 - Examples Use Development Registry Locations (Priority: P2)

**Goal**: Update example files to reference quay.io/roddiekieley registry instead of ghcr.io/stacklok

**Independent Test**: Review all example files and verify they reference quay.io/roddiekieley registry. Build and deploy using examples without modifications to confirm they work with development images.

### Implementation for User Story 2

- [x] T016 [P] [US2] Update catalog image reference in `examples/catalogsource-olmv1.yaml` - change `spec.image` from `ghcr.io/stacklok/toolhive/catalog:v0.2.17` to `quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17`
- [x] T017 [P] [US2] Verify catalogsource-olmv1.yaml references correct registry (run `grep "image:" examples/catalogsource-olmv1.yaml | grep catalog`)
- [x] T018 [P] [US2] Verify no ghcr.io references remain in catalogsource-olmv1.yaml (run `grep "ghcr.io" examples/catalogsource-olmv1.yaml` - should return no matches)

**Checkpoint**: User Story 2 complete - example files reference development registry

---

## Phase 5: User Story 3 - Subscription Uses Correct Source Namespace (Priority: P2)

**Goal**: Fix Subscription example to use correct sourceNamespace for CatalogSource location

**Independent Test**: Deploy CatalogSource to openshift-marketplace namespace, then apply Subscription with sourceNamespace set to "openshift-marketplace". Verify the operator installs successfully.

### Implementation for User Story 3

- [x] T019 [US3] Update sourceNamespace in `examples/subscription.yaml` - change `spec.sourceNamespace` from `olm` to `openshift-marketplace`
- [x] T020 [US3] Verify subscription.yaml has correct sourceNamespace (run `grep "sourceNamespace:" examples/subscription.yaml`)

**Checkpoint**: User Story 3 complete - subscription example uses correct namespace

---

## Phase 6: Validation & Verification

**Purpose**: Comprehensive validation of all changes before deployment

- [x] T021 [P] Run constitutional compliance validation - execute `make kustomize-validate` (both config/default and config/base must build successfully)
- [x] T022 [P] Verify CRDs unchanged (constitutional requirement) - run `git diff config/crd/` (should show no changes)
- [x] T023 [P] Validate catalog structure using `opm validate catalog/toolhive-operator` (final verification)
- [x] T024 Review quickstart.md verification checklist and confirm all items pass (including edge case scenarios from spec.md: malformed metadata detection, namespace mismatch handling, image pull failure behavior)

---

## Phase 7: Deployment Testing (OpenShift Cluster Required)

**Purpose**: End-to-end testing of fixes in actual OpenShift environment

**Note**: These tasks require access to an OpenShift cluster

### Deploy and Verify User Story 1 (OperatorHub Display)

- [ ] T025 [US1] Deploy CatalogSource using `kubectl apply -f examples/catalogsource-olmv1.yaml`
- [ ] T026 [US1] Wait for CatalogSource ready status - `kubectl wait --for=condition=Ready catalogsource/toolhive-catalog -n openshift-marketplace --timeout=60s`
- [ ] T027 [US1] Verify PackageManifest created - `kubectl get packagemanifest -n openshift-marketplace toolhive-operator` (should exist)
- [ ] T028 [US1] Inspect PackageManifest for correct metadata - `kubectl get packagemanifest toolhive-operator -n openshift-marketplace -o yaml | grep -A10 "channels:"`
- [ ] T029 [US1] Verify OperatorHub UI shows catalog name "ToolHive Operator Catalog" with "(1)" operator count in Sources section
- [ ] T030 [US1] Verify ToolHive Operator appears in OperatorHub search with description and icon

### Verify User Story 3 (Subscription Installation)

- [ ] T031 [US3] Create target namespace - `kubectl create namespace toolhive-system`
- [ ] T032 [US3] Deploy Subscription using `kubectl apply -f examples/subscription.yaml`
- [ ] T033 [US3] Wait for Subscription to reach AtLatestKnown state - `kubectl wait --for=jsonpath='{.status.state}'=AtLatestKnown subscription/toolhive-operator -n toolhive-system --timeout=300s`
- [ ] T034 [US3] Verify ClusterServiceVersion created - `kubectl get csv -n toolhive-system` (should show SUCCEEDED status)
- [ ] T035 [US3] Verify operator pod running - `kubectl get pods -n toolhive-system` (should show Running state)

**Checkpoint**: All user stories verified in OpenShift cluster - feature complete

---

## Phase 8: Polish & Documentation

**Purpose**: Final cleanup and documentation updates

- [ ] T036 [P] Review git diff for all changed files to ensure no unintended modifications
- [ ] T037 [P] Remove backup file `catalog/toolhive-operator/catalog.yaml.backup-pre-007` if all tests pass
- [ ] T038 Add commit message documenting changes (catalog regeneration, registry updates, namespace fix)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phases 3-5)**: All depend on Foundational phase completion
  - User Story 1 (P1): Can start after Foundational - No dependencies on other stories
  - User Story 2 (P2): Can start after Foundational - Independent of US1 (but benefits from US1's bundle image update in catalog.yaml)
  - User Story 3 (P2): Can start after Foundational - Independent of US1 and US2
- **Validation (Phase 6)**: Depends on all user stories being complete
- **Deployment Testing (Phase 7)**: Depends on Validation passing
- **Polish (Phase 8)**: Depends on successful deployment testing

### User Story Dependencies

- **User Story 1 (P1)**: Requires Foundational (T005-T008) - No dependencies on other stories
  - **Critical**: This is the core fix - catalog must have embedded CSV to appear in OperatorHub
- **User Story 2 (P2)**: Requires Foundational (T005-T008) - Independent but logically follows US1
  - Can be implemented in parallel with US3
  - Depends on US1's catalog.yaml bundle image update for consistency
- **User Story 3 (P2)**: Requires Foundational (T005-T008) - Completely independent
  - Can be implemented in parallel with US2
  - No interaction with catalog.yaml changes

### Within Each User Story

- **US1**: Sequential within story (catalog generation → image update → validation → build → test → push)
- **US2**: All tasks are parallelizable (marked [P]) - different example files
- **US3**: Sequential (only 2 tasks, same file)

### Parallel Opportunities

- **Phase 1 (Setup)**: All 4 tasks (T001-T004) can run in parallel [P]
- **Phase 2 (Foundational)**: Sequential - catalog regeneration must complete before validation
- **User Stories**: After Foundational complete, US2 and US3 can be implemented in parallel with each other
  - US1 must complete first to provide the bundle image reference that US2 validates
  - Or US2 can be done in parallel if the bundle image update in catalog.yaml (T009) is coordinated
- **Phase 6 (Validation)**: T021, T022, T023 can run in parallel [P]
- **Phase 8 (Polish)**: T036, T037 can run in parallel [P]

---

## Parallel Example: Setup Phase

```bash
# Launch all setup tasks together (Phase 1):
Task: "Verify opm installed"
Task: "Verify bundle directory exists"
Task: "Verify current catalog.yaml structure"
Task: "Back up current catalog.yaml"
```

## Parallel Example: User Story 2

```bash
# All US2 tasks can run together (different files):
Task: "Update catalog image in catalogsource-olmv1.yaml"
Task: "Verify catalogsource-olmv1.yaml references"
Task: "Verify no ghcr.io references"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T008) - CRITICAL
3. Complete Phase 3: User Story 1 (T009-T015)
4. **STOP and VALIDATE**:
   - Run Phase 6 validation tasks (T021-T024)
   - Deploy to test cluster (T025-T030)
   - Verify OperatorHub shows catalog correctly
5. Deploy/demo if ready

**MVP Deliverable**: Catalog appears in OperatorHub with name and operator count

### Incremental Delivery

1. **Setup + Foundational** → Foundation ready (catalog regenerated)
2. **Add User Story 1** → Test independently → OperatorHub displays correctly (MVP! 🎯)
3. **Add User Story 2** → Test independently → Examples reference dev registry
4. **Add User Story 3** → Test independently → Subscription installs successfully
5. **Polish** → Complete feature

Each story adds value without breaking previous stories.

### Parallel Team Strategy

With multiple developers:

1. **Team completes Setup + Foundational together** (T001-T008)
2. Once Foundational is done:
   - **Developer A**: User Story 1 (T009-T015) - Priority 1, sequential
   - **Developer B**: User Story 2 (T016-T018) - Can start after T009, all parallel
   - **Developer C**: User Story 3 (T019-T020) - Independent, can start immediately
3. Converge for validation (Phase 6) and deployment testing (Phase 7)

**Note**: US1 should complete first since it's the critical fix. US2 and US3 are lower priority enhancements.

---

## Task Summary

- **Total Tasks**: 38
- **User Story 1 (P1)**: 11 tasks (T005-T015) - Critical catalog fix
- **User Story 2 (P2)**: 3 tasks (T016-T018) - Example registry updates
- **User Story 3 (P2)**: 2 tasks (T019-T020) - Subscription namespace fix
- **Setup**: 4 tasks (T001-T004)
- **Validation**: 4 tasks (T021-T024)
- **Deployment Testing**: 11 tasks (T025-T035)
- **Polish**: 3 tasks (T036-T038)

### Parallel Opportunities Identified

- 4 tasks in Setup (all marked [P])
- 3 tasks in Validation (all marked [P])
- 3 tasks in User Story 2 (all marked [P])
- 2 tasks in Polish (marked [P])

**Total parallelizable tasks**: 12 out of 38 (32%)

### Independent Test Criteria

**User Story 1**: Deploy CatalogSource and verify OperatorHub UI shows "ToolHive Operator Catalog" with "(1)" operator count (T025-T030)

**User Story 2**: Review example files and verify they reference quay.io/roddiekieley registry; deploy using unmodified examples (T017-T018, implicit in T025-T035)

**User Story 3**: Deploy CatalogSource to openshift-marketplace, apply Subscription, verify operator installs (T031-T035)

### Suggested MVP Scope

**Minimum Viable Product**: User Story 1 only (T001-T015 + T021-T030)
- Fixes the core issue: catalog appears in OperatorHub with correct name and operator count
- Requires catalog regeneration with embedded CSV
- Validates catalog structure and deploys to test cluster
- Delivers immediate value to cluster administrators

**Enhanced MVP**: User Stories 1 + 2 + 3 (all P1 and P2 stories)
- Adds example file corrections for complete developer experience
- Minimal additional effort (5 tasks beyond US1)
- Provides comprehensive fix for all reported issues

---

## Notes

- [P] tasks = different files or independent operations, no dependencies
- [Story] label maps task to specific user story (US1, US2, US3) for traceability
- Each user story should be independently completable and testable
- Commit after each user story phase (checkpoints)
- Stop at any checkpoint to validate story independently
- Constitutional compliance is verified in Phase 6 (T021-T022)
- Deployment testing (Phase 7) requires OpenShift cluster access - optional but highly recommended
- The foundational phase (catalog regeneration) is CRITICAL and blocks all user stories
