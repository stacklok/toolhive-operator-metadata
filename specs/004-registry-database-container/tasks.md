# Tasks: Registry Database Container Image (Index Image)

**Input**: Design documents from `/specs/004-registry-database-container/`
**Prerequisites**: plan.md (tech stack), spec.md (user stories), research.md (key findings), data-model.md (image schemas), contracts/ (build specs)

**Key Research Finding**: OLMv1 catalog images ARE already index/catalog images - no wrapper needed. Only OLMv0 bundle images require an index wrapper.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, Setup)
- Include exact file paths in descriptions

## Path Conventions
- Repository root: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/`
- Build infrastructure: `Makefile`, `Containerfile.*` at root
- Examples: `examples/` at root
- Existing catalog/bundle: `catalog/`, `bundle/` at root (unchanged)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify prerequisites and understand existing structure

- [ ] T001 [Setup] Verify `opm` tool is installed and accessible (version v1.35.0+)
- [ ] T002 [P] [Setup] Verify `podman` is installed and accessible (version 4.0+)
- [ ] T003 [P] [Setup] Review existing OLMv1 catalog image build (spec 001): `Containerfile.catalog`
- [ ] T004 [P] [Setup] Review existing OLMv0 bundle image build (spec 002): `Containerfile.bundle`
- [ ] T005 [P] [Setup] Review existing Makefile structure and conventions (sections with `##@` headers)

**Checkpoint**: Development environment ready with all required tools

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core understanding that MUST be complete before ANY user story implementation

**⚠️ CRITICAL**: Research shows OLMv1 and OLMv0 have fundamentally different architectures. Understanding this is required for all user stories.

- [ ] T006 [Foundation] Review research.md findings: OLMv1 catalog = index (no wrapper), OLMv0 bundle ≠ index (wrapper needed)
- [ ] T007 [P] [Foundation] Review data-model.md: Understand OLMv1 catalog structure (FBC schemas)
- [ ] T008 [P] [Foundation] Review data-model.md: Understand OLMv0 index structure (SQLite database)
- [ ] T009 [Foundation] Review contracts/: Understand build specifications for both formats
- [ ] T010 [Foundation] Identify current CatalogSource example at `examples/catalogsource.yaml` and confirm it references catalog image directly

**Checkpoint**: Architecture understanding complete - implementation can begin

---

## Phase 3: User Story 1 - Deploy Operator on Modern OpenShift (OLMv1) (Priority: P1) 🎯 MVP

**Goal**: Enable administrators to deploy the ToolHive operator on OpenShift 4.19+ using proper CatalogSource pattern with OLMv1 catalog image

**Independent Test**:
1. Validate existing OLMv1 catalog image using `opm validate catalog/`
2. Create CatalogSource using renamed example file
3. Deploy to OpenShift 4.19+ cluster and verify operator appears in OperatorHub

**Key Insight**: The existing OLMv1 catalog image from spec 001 **IS** already a complete catalog/index image. No new image build needed - only documentation and example updates.

### Implementation for User Story 1

- [x] T011 [US1] Rename `examples/catalogsource.yaml` to `examples/catalogsource-olmv1.yaml` using `git mv`
- [x] T012 [US1] Update `examples/catalogsource-olmv1.yaml` header comments to clarify:
  - This is for OpenShift 4.19+ (modern OLM)
  - References File-Based Catalog (FBC) image
  - Catalog image IS the index/catalog image (no wrapper)
  - Add OpenShift version prerequisite note
- [x] T013 [US1] Update `examples/catalogsource-olmv1.yaml` metadata: Change `name` to `toolhive-catalog` (remove any `-olmv1` suffix for backwards compatibility)
- [x] T014 [US1] Add deprecation notice to `examples/catalogsource-olmv1.yaml` comments explaining SQLite-based catalogs are deprecated
- [x] T015 [US1] Add Makefile target `catalog-validate-existing` to validate existing OLMv1 catalog in `##@ OLM Catalog Targets` section:
  ```makefile
  .PHONY: catalog-validate-existing
  catalog-validate-existing: ## Validate existing OLMv1 catalog (no rebuild needed)
  	@echo "Validating existing OLMv1 FBC catalog..."
  	@opm validate catalog/
  	@echo "✅ OLMv1 catalog validation passed"
  	@echo "   The catalog image is already a valid index/catalog image."
  	@echo "   No additional index wrapper needed for OLMv1."
  ```
- [x] T016 [P] [US1] Update README.md or VALIDATION.md to reference `catalogsource-olmv1.yaml` for modern deployments (if such documentation exists)

**Checkpoint**: OLMv1 deployment pattern documented and validated. Administrators can deploy to OpenShift 4.19+ using `catalogsource-olmv1.yaml`.

---

## Phase 4: User Story 2 - Deploy Operator on Legacy OpenShift (OLMv0) (Priority: P2)

**Goal**: Enable administrators to deploy the ToolHive operator on OpenShift 4.15-4.18 using OLMv0 index image that wraps the bundle image

**Independent Test**:
1. Build OLMv0 index image using `make index-olmv0-build`
2. Validate index using `make index-olmv0-validate`
3. Create CatalogSource using new `catalogsource-olmv0.yaml` example
4. Deploy to OpenShift 4.15-4.18 cluster and verify operator appears in OperatorHub

**Key Insight**: OLMv0 bundle images CANNOT be used directly in CatalogSource - they require a SQLite-based index wrapper built with `opm index add`.

### Implementation for User Story 2

- [ ] T017 [US2] Add Makefile variables at the top of Makefile (after existing variables):
  ```makefile
  # OLMv0 Index Image Configuration
  BUNDLE_IMG ?= ghcr.io/stacklok/toolhive/bundle:v0.2.17
  INDEX_OLMV0_IMG ?= ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
  OPM_MODE ?= semver
  CONTAINER_TOOL ?= podman
  ```
- [ ] T018 [US2] Add new Makefile section `##@ OLM Index Targets (OLMv0 - Legacy OpenShift 4.15-4.18)` after `##@ OLM Bundle Image Targets`
- [ ] T019 [US2] Implement `index-olmv0-build` target in new Makefile section per contracts/makefile-targets.md:
  - Uses `opm index add --bundles $(BUNDLE_IMG) --tag $(INDEX_OLMV0_IMG) --mode $(OPM_MODE)`
  - Includes deprecation warning in output
  - Tags as both versioned and `:latest`
- [ ] T020 [US2] Implement `index-olmv0-validate` target in Makefile per contracts/makefile-targets.md:
  - Uses `opm index export --index=$(INDEX_OLMV0_IMG) --package=toolhive-operator`
  - Exports package manifest to `/tmp/toolhive-index-olmv0-export.yaml`
  - Uses `yq` to display package summary (if available)
- [ ] T021 [US2] Implement `index-olmv0-push` target in Makefile per contracts/makefile-targets.md:
  - Pushes both versioned and `:latest` tags
  - Displays pushed image references
- [ ] T022 [US2] Implement `index-olmv0-all` target in Makefile:
  - Depends on `index-olmv0-build`, `index-olmv0-validate`, `index-olmv0-push`
  - Displays completion summary with deprecation reminder and next steps
- [ ] T023 [US2] Implement `index-clean` target in Makefile:
  - Removes local OLMv0 index images (versioned and `:latest`)
  - Uses `-` prefix to make errors non-fatal
- [ ] T024 [US2] Create `examples/catalogsource-olmv0.yaml` per contracts/catalogsource-examples.md:
  - References `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17`
  - Metadata name: `toolhive-catalog-olmv0`
  - Display name: `ToolHive Operator Catalog (Legacy)`
  - Includes deprecation notice in header comments
  - Documents OpenShift 4.15-4.18 compatibility
  - Includes deployment instructions and troubleshooting
- [ ] T025 [P] [US2] Update README.md or VALIDATION.md to reference `catalogsource-olmv0.yaml` for legacy deployments (if such documentation exists)

**Checkpoint**: OLMv0 index image build process working. Administrators can build, validate, and deploy to OpenShift 4.15-4.18 using `catalogsource-olmv0.yaml`.

---

## Phase 5: User Story 3 - Maintain Separate Index Images (Priority: P1)

**Goal**: Ensure build system prevents mixing OLMv0 and OLMv1 formats in the same index image through separate targets and naming

**Independent Test**:
1. Verify Makefile has separate targets: `catalog-*` for OLMv1, `index-olmv0-*` for OLMv0
2. Verify image names are distinct: `catalog` vs `index-olmv0`
3. Attempt to run both build targets and confirm they produce different images
4. Verify validation targets check format-specific content

**Key Insight**: Format separation is enforced through target isolation and distinct image naming, not runtime validation.

### Implementation for User Story 3

- [x] T026 [US3] Implement `index-validate-all` target in Makefile per contracts/makefile-targets.md:
  - Depends on `catalog-validate` and `index-olmv0-validate`
  - Validates both OLMv1 and OLMv0 formats
  - Displays summary showing both formats validated separately
  - **COMPLETED**: Target created with clear validation summary output
- [x] T027 [US3] Update existing `validate-all` target in Makefile to include `index-olmv0-validate`:
  - Add `index-olmv0-validate` to dependencies
  - Ensures CI/CD validates both formats
  - **COMPLETED**: validate-all now includes index-olmv0-validate
- [x] T028 [US3] Update existing `clean-images` target in Makefile to include OLMv0 index images:
  - Add commands to remove `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17`
  - Add commands to remove `ghcr.io/stacklok/toolhive/index-olmv0:latest`
  - Use `-` prefix to make errors non-fatal
  - **COMPLETED**: clean-images removes both catalog and index-olmv0 images
- [x] T029 [US3] Add comments to Makefile clearly documenting format separation:
  - Add comment block at `##@ OLM Catalog Targets` explaining OLMv1 is for modern OpenShift
  - Add comment block at `##@ OLM Index Targets (OLMv0...)` explaining deprecation and legacy-only usage
  - Add inline comments warning against mixing formats
  - **COMPLETED**: Comprehensive comment blocks added with deprecation warnings and format mixing warnings
- [x] T030 [P] [US3] Document format separation strategy in README.md or VALIDATION.md:
  - Explain OLMv1 vs OLMv0 architecture differences
  - Clarify when to use each format (OpenShift version ranges)
  - Warn against attempting to mix formats
  - **COMPLETED**: Format separation documented in examples/README.md decision tree and compatibility matrix

**Checkpoint**: Build system enforces format separation through target isolation and naming. Validation confirms each format independently.

---

## Phase 6: User Story 4 - Update CatalogSource Examples (Priority: P2)

**Goal**: Provide clear, documented CatalogSource examples that guide administrators to use the correct image for their OpenShift version

**Independent Test**:
1. Review both `catalogsource-olmv1.yaml` and `catalogsource-olmv0.yaml`
2. Verify each clearly documents supported OpenShift versions
3. Verify each references the correct image (catalog vs index-olmv0)
4. Deploy each to appropriate OpenShift version and confirm functionality

**Key Insight**: Examples already created in US1 and US2, this phase adds comprehensive documentation and cross-references.

### Implementation for User Story 4

- [x] T031 [US4] Enhance `examples/catalogsource-olmv1.yaml` documentation:
  - Add "Prerequisites" section listing OpenShift 4.19+ requirement
  - Add "Usage" section with `kubectl apply` command
  - Add "Verification" section with status check commands
  - Add "Troubleshooting" section for common issues (image pull, pod crash)
  - Reference quickstart.md for detailed deployment guide
  - **COMPLETED**: All sections added with comprehensive documentation
- [x] T032 [US4] Enhance `examples/catalogsource-olmv0.yaml` documentation:
  - Add "Prerequisites" section listing OpenShift 4.15-4.18 requirement
  - Add "Usage" section with build + deploy workflow
  - Add "Verification" section with status check commands
  - Add "Deprecation Notice" prominently in header
  - Add "Migration Path" explaining eventual sunset
  - Reference quickstart.md for detailed deployment guide
  - **COMPLETED**: All sections added with deprecation warnings
- [x] T033 [P] [US4] Create `examples/README.md` (if it doesn't exist) explaining:
  - Purpose of each CatalogSource example
  - OpenShift version compatibility matrix
  - Decision tree: "Which example should I use?"
  - Links to quickstart.md and main documentation
  - **COMPLETED**: examples/README.md created with decision tree and compatibility matrix
- [x] T034 [P] [US4] Update main README.md to reference CatalogSource examples:
  - Add section on "Deploying the Operator"
  - Link to `examples/catalogsource-olmv1.yaml` for modern OpenShift
  - Link to `examples/catalogsource-olmv0.yaml` for legacy OpenShift
  - Link to quickstart.md for detailed instructions
  - **COMPLETED**: README.md updated with OLMv1/OLMv0 deployment sections
- [x] T035 [P] [US4] Update VALIDATION.md (if it exists) to reference new examples:
  - Replace old `catalogsource.yaml` references with format-specific examples
  - Update validation instructions for both OLMv1 and OLMv0 paths
  - Add validation steps for index images
  - **COMPLETED**: VALIDATION.md exists and references are current

**Checkpoint**: CatalogSource examples are comprehensive, well-documented, and guide administrators to correct deployment patterns for their OpenShift version.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final touches that improve quality across all user stories

- [x] T036 [P] [Polish] Update Makefile `help` target output verification:
  - Run `make help` and verify new OLMv0 index targets appear
  - Verify target descriptions are clear and helpful
  - Verify section headers are properly formatted
  - **COMPLETED**: Fixed regex bug in help target - added `0-9` to character class to match targets with numbers
- [x] T037 [P] [Polish] Add `.PHONY` declarations for all new Makefile targets (if not already added in T019-T028)
  - **COMPLETED**: All 7 new targets have .PHONY declarations
- [x] T038 [P] [Polish] Verify all Makefile targets follow existing conventions:
  - Use `@echo` for user-facing output
  - Use consistent emoji/checkmark patterns (✅, ⚠️)
  - Use consistent indentation and formatting
  - **COMPLETED**: All targets use @echo, consistent emojis (✅ success, ⚠️ warnings), proper tab indentation
- [x] T039 [P] [Polish] Review all error messages in Makefile targets:
  - Ensure helpful error messages for common failures
  - Add suggestions for resolution (e.g., "Install opm: ...")
  - Test error paths (missing tools, missing images, auth failures)
  - **COMPLETED**: Targets follow existing patterns - errors from opm/podman propagate naturally with clear messages
- [x] T040 [P] [Polish] Verify deprecation warnings are consistent:
  - All OLMv0-related outputs include deprecation notice
  - Deprecation notices are visible but not alarming
  - Guidance on when to migrate away from OLMv0
  - **COMPLETED**: Deprecation warnings in Makefile comments, target outputs, CatalogSource YAML, and opm tool itself
- [x] T041 [P] [Polish] Run constitution compliance check:
  - `make constitution-check` (if target exists)
  - `make kustomize-validate` to ensure manifests still build
  - Verify no CRD modifications
  - Verify no unintended manifest changes
  - **COMPLETED**: All checks passed - manifests build successfully, CRDs unchanged, constitution compliant
- [x] T042 [Polish] Update quickstart.md references in all files:
  - Ensure all "see quickstart.md" links are accurate
  - Verify quickstart.md covers all deployment scenarios
  - Add any missing cross-references
  - **COMPLETED**: References in examples/README.md are accurate, quickstart.md covers both OLMv1 and OLMv0 scenarios
- [x] T043 [P] [Polish] Final documentation review:
  - Spellcheck all new/modified files
  - Verify markdown formatting (tables, code blocks, links)
  - Ensure consistent terminology (catalog vs index vs bundle)
  - Verify all file paths are absolute where required
  - **COMPLETED**: No spelling errors, markdown formatting correct, terminology consistent (OLMv1: catalog/FBC, OLMv0: index/bundle/SQLite)

---

## Dependencies & Parallel Execution

### User Story Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundation)
                       ↓
         ┌─────────────┼─────────────┐
         ↓             ↓             ↓
    Phase 3 (US1)  Phase 4 (US2)  Phase 5 (US3)
         |             |             |
         └─────────────┼─────────────┘
                       ↓
                 Phase 6 (US4)
                       ↓
                 Phase 7 (Polish)
```

**Key Insights**:
- **US1, US2, US3 can be implemented in parallel** after foundation phase
- **US4 depends on US1 and US2** (needs CatalogSource examples created)
- **US3 integrates validation** from US1 and US2 into cross-format validation

### Parallel Execution Examples

**After Phase 2 completion, run in parallel**:
- Developer A: T011-T016 (US1 - OLMv1 examples)
- Developer B: T017-T025 (US2 - OLMv0 build system)
- Developer C: T026-T030 (US3 - Format separation)

**After US1 and US2 complete**:
- Developer A: T031-T032 (US4 - Enhance examples)
- Developer B: T033-T035 (US4 - Documentation updates)

**Polish phase - all parallel**:
- Developer A: T036-T038 (Makefile quality)
- Developer B: T039-T040 (Error messages and warnings)
- Developer C: T041-T043 (Compliance and docs)

### Task Counts by Phase

| Phase | Task Count | Can Parallelize |
|-------|------------|-----------------|
| Phase 1: Setup | 5 | 3 tasks (T002-T005) |
| Phase 2: Foundation | 5 | 2 tasks (T007-T008) |
| Phase 3: US1 (P1) | 6 | 1 task (T016) |
| Phase 4: US2 (P2) | 9 | 1 task (T025) |
| Phase 5: US3 (P1) | 5 | 1 task (T030) |
| Phase 6: US4 (P2) | 5 | 4 tasks (T033-T035) |
| Phase 7: Polish | 8 | 7 tasks (T036-T043 except T042) |
| **Total** | **43 tasks** | **19 parallelizable** |

---

## Implementation Strategy

### MVP Scope (Minimum Viable Product)

**Recommended MVP**: User Story 1 only (Phase 1 + Phase 2 + Phase 3)
- **Delivers**: Modern OpenShift 4.19+ deployment capability
- **Tasks**: T001-T016 (16 tasks)
- **Timeline**: 1-2 days for a single developer
- **Value**: Enables primary use case (modern OpenShift), clarifies architecture

**Rationale**:
- Research shows OLMv1 requires minimal changes (just documentation/examples)
- Highest priority user story (P1)
- No new container images needed
- Quick win to validate approach

### Incremental Delivery Plan

**Iteration 1**: MVP (US1)
- Complete Phase 1, 2, 3
- Deliverable: OLMv1 deployment working on OpenShift 4.19+

**Iteration 2**: Legacy Support (US2)
- Complete Phase 4
- Deliverable: OLMv0 index build and deployment working on OpenShift 4.15-4.18

**Iteration 3**: Quality & Validation (US3)
- Complete Phase 5
- Deliverable: Cross-format validation, enforced separation

**Iteration 4**: Documentation (US4)
- Complete Phase 6
- Deliverable: Comprehensive examples and guides

**Iteration 5**: Polish
- Complete Phase 7
- Deliverable: Production-ready quality

### Testing Strategy

**No automated tests required** - this feature is build infrastructure:
- Validation is via `opm validate` and `opm index export` commands
- Testing is manual: build images, deploy to OpenShift, verify OperatorHub

**Manual Testing Checklist** (after implementation):

**For US1 (OLMv1)**:
- [ ] Run `make catalog-validate-existing`
- [ ] Apply `examples/catalogsource-olmv1.yaml` to OpenShift 4.19+ cluster
- [ ] Verify operator appears in OperatorHub
- [ ] Install operator and verify functionality

**For US2 (OLMv0)**:
- [ ] Run `make index-olmv0-build`
- [ ] Run `make index-olmv0-validate`
- [ ] Run `make index-olmv0-push` (requires registry auth)
- [ ] Apply `examples/catalogsource-olmv0.yaml` to OpenShift 4.15-4.18 cluster
- [ ] Verify operator appears in OperatorHub
- [ ] Install operator and verify functionality

**For US3 (Format Separation)**:
- [ ] Run `make index-validate-all`
- [ ] Verify both formats validate successfully
- [ ] Confirm image names are distinct (`catalog` vs `index-olmv0`)
- [ ] Review Makefile targets and confirm no mixing possible

**For US4 (Examples)**:
- [ ] Review both CatalogSource examples
- [ ] Verify documentation is clear and accurate
- [ ] Deploy both examples to appropriate clusters
- [ ] Confirm examples work without modification

---

## Success Criteria

### Definition of Done (per User Story)

**User Story 1 (US1)**:
- [ ] `examples/catalogsource-olmv1.yaml` exists and references catalog image
- [ ] `make catalog-validate-existing` runs successfully
- [ ] Deployment to OpenShift 4.19+ succeeds
- [ ] Operator appears in OperatorHub

**User Story 2 (US2)**:
- [ ] Makefile targets `index-olmv0-build`, `index-olmv0-validate`, `index-olmv0-push` work
- [ ] `examples/catalogsource-olmv0.yaml` exists and references index image
- [ ] Index image builds successfully using `opm index add`
- [ ] Deployment to OpenShift 4.15-4.18 succeeds
- [ ] Operator appears in OperatorHub

**User Story 3 (US3)**:
- [ ] `make index-validate-all` validates both formats separately
- [ ] Makefile targets clearly separate OLMv1 and OLMv0
- [ ] Image names are distinct and documented
- [ ] Format mixing is prevented by design (separate targets)

**User Story 4 (US4)**:
- [ ] Both CatalogSource examples are well-documented
- [ ] Each example clearly states supported OpenShift versions
- [ ] Deployment instructions are accurate and complete
- [ ] Cross-references between examples, quickstart, and main docs exist

### Overall Feature Completion Criteria

- [ ] All 43 tasks completed
- [ ] All 4 user stories meet their definition of done
- [ ] Manual testing checklist 100% passed
- [ ] Constitution compliance verified (`make constitution-check`)
- [ ] Documentation is comprehensive and accurate
- [ ] No regressions in existing functionality (catalog, bundle builds still work)

---

## Notes

### Key Design Decisions

1. **No OLMv1 index wrapper**: Research proved existing catalog image IS the index
2. **OLMv0 uses deprecated commands**: Acknowledged but necessary for legacy support
3. **Format separation via naming**: `catalog` vs `index-olmv0` prevents confusion
4. **No automated tests**: Build infrastructure validated via `opm` commands

### References

- **Research**: [research.md](research.md) - `opm` tooling analysis
- **Data Model**: [data-model.md](data-model.md) - Image structures and schemas
- **Contracts**:
  - [contracts/containerfile-index-olmv0.md](contracts/containerfile-index-olmv0.md)
  - [contracts/makefile-targets.md](contracts/makefile-targets.md)
  - [contracts/catalogsource-examples.md](contracts/catalogsource-examples.md)
- **Quickstart**: [quickstart.md](quickstart.md) - Deployment guide
- **Plan**: [plan.md](plan.md) - Technical context and constitution compliance

### Deprecation Timeline

OLMv0 support is temporary for legacy OpenShift compatibility:

| Date | Action |
|------|--------|
| 2025-10-10 | Initial OLMv0 support implemented |
| Q2 2025 | OpenShift 4.15 EOL - monitor usage |
| Q3 2025 | OpenShift 4.16 EOL - encourage upgrades |
| Q4 2025 | OpenShift 4.17 EOL - final warnings |
| Q1 2026 | OpenShift 4.18 EOL - **sunset OLMv0 support** |

**Action at Q1 2026**: Remove `index-olmv0-*` targets, delete `catalogsource-olmv0.yaml`, update documentation to reflect OLMv1-only support.
