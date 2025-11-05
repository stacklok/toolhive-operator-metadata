# Implementation Tasks: Upgrade ToolHive Operator to v0.3.11

**Feature**: Upgrade ToolHive Operator to v0.3.11 (011-v0-2-17)
**Branch**: `011-v0-2-17`
**Date**: 2025-10-21

## Overview

This document provides the detailed task breakdown for upgrading the toolhive-operator from v0.2.17 to v0.3.11. Tasks are organized by user story to enable independent implementation and testing of each increment.

**Total Tasks**: 18
**Parallel Opportunities**: 8 tasks can run in parallel
**MVP Scope**: Phase 3 (User Story 1) - Tasks T001-T008

## Task Organization

- **Phase 1**: Setup (pre-flight verification and baseline capture)
- **Phase 2**: Foundational (image availability verification - blocking prerequisite)
- **Phase 3**: User Story 1 - Update Configuration Files (P1 - MVP)
- **Phase 4**: User Story 2 - Validate Compatibility (P2)
- **Phase 5**: User Story 3 - Update Documentation (P3)
- **Phase 6**: Polish & Final Verification

---

## Phase 1: Setup

### T001 - Create baseline kustomize outputs

**Story**: Setup
**File**: Multiple (kustomize output capture)
**Parallel**: No
**Depends on**: None

Capture baseline kustomize build outputs from v0.2.17 configuration for comparison after upgrade.

**Implementation**:
```bash
# Capture baseline outputs
kustomize build config/base > /tmp/baseline-base.yaml
kustomize build config/default > /tmp/baseline-default.yaml

# Count v0.2.17 references
grep -c "v0.2.17" /tmp/baseline-base.yaml > /tmp/baseline-version-count.txt
```

**Verification**: Baseline files exist in /tmp/ with v0.2.17 references

---

### T002 - Document current state

**Story**: Setup
**File**: N/A (informational task)
**Parallel**: Yes (can run with T001)
**Depends on**: None

Document the current v0.2.17 configuration state for rollback reference.

**Implementation**:
```bash
# List files with v0.2.17 references
echo "=== Current v0.2.17 Configuration ===" > /tmp/pre-upgrade-state.txt
echo "Configuration files:" >> /tmp/pre-upgrade-state.txt
grep -l "v0.2.17" config/base/params.env config/manager/manager.yaml Makefile >> /tmp/pre-upgrade-state.txt

# Capture git commit
echo "Git commit:" >> /tmp/pre-upgrade-state.txt
git rev-parse HEAD >> /tmp/pre-upgrade-state.txt

# Capture CRD checksums
echo "CRD checksums:" >> /tmp/pre-upgrade-state.txt
sha256sum config/crd/*.yaml >> /tmp/pre-upgrade-state.txt
```

**Verification**: /tmp/pre-upgrade-state.txt contains v0.2.17 configuration details

---

## Phase 2: Foundational

### T003 - Verify v0.3.11 container images exist

**Story**: Foundation
**File**: N/A (external verification)
**Parallel**: No
**Depends on**: None

Verify that v0.3.11 operator and proxyrunner images are available in ghcr.io registry before proceeding with configuration updates.

**Implementation**:
```bash
# Check operator image
echo "Verifying operator image..."
podman manifest inspect ghcr.io/stacklok/toolhive/operator:v0.3.11 > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ Operator image v0.3.11 exists"
else
  echo "✗ Operator image v0.3.11 not found"
  exit 1
fi

# Check proxyrunner image
echo "Verifying proxyrunner image..."
podman manifest inspect ghcr.io/stacklok/toolhive/proxyrunner:v0.3.11 > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ Proxyrunner image v0.3.11 exists"
else
  echo "✗ Proxyrunner image v0.3.11 not found"
  exit 1
fi
```

**Verification**: Both images return valid manifest data; exit code 0

**Critical**: This task MUST complete successfully before any configuration updates (blocks T004-T007)

---

## Phase 3: User Story 1 - Update Configuration Files (P1 - MVP)

**Goal**: Update all configuration files to reference v0.3.11 so that the repository uses the latest operator version

**Independent Test**: Run `kustomize build config/base && kustomize build config/default` and verify all image references show v0.3.11

---

### T004 - [US1] Update config/base/params.env

**Story**: US1
**File**: `config/base/params.env`
**Parallel**: No
**Depends on**: T003

Update kustomize parameter file with v0.3.11 image references.

**Implementation**:
```bash
# Update operator image
sed -i 's|toolhive-operator-image2=ghcr.io/stacklok/toolhive/operator:v0.2.17|toolhive-operator-image2=ghcr.io/stacklok/toolhive/operator:v0.3.11|' config/base/params.env

# Update proxyrunner image
sed -i 's|toolhive-proxy-image=ghcr.io/stacklok/toolhive/proxyrunner:v0.2.17|toolhive-proxy-image=ghcr.io/stacklok/toolhive/proxyrunner:v0.3.11|' config/base/params.env

# Verify changes
grep "v0.3.11" config/base/params.env
```

**Verification**: Both lines in params.env reference v0.3.11; no v0.2.17 remains

---

### T005 - [US1] Update config/manager/manager.yaml

**Story**: US1
**File**: `config/manager/manager.yaml`
**Parallel**: Yes (can run with T004)
**Depends on**: T003

Update operator deployment manifest with v0.3.11 image references.

**Implementation**:
```bash
# Update container image (line 45)
sed -i 's|image: "ghcr.io/stacklok/toolhive/operator:v0.2.17"|image: "ghcr.io/stacklok/toolhive/operator:v0.3.11"|' config/manager/manager.yaml

# Update TOOLHIVE_RUNNER_IMAGE env var (line 67)
sed -i 's|value: "ghcr.io/stacklok/toolhive/proxyrunner:v0.2.17"|value: "ghcr.io/stacklok/toolhive/proxyrunner:v0.3.11"|' config/manager/manager.yaml

# Verify changes
grep "v0.3.11" config/manager/manager.yaml
```

**Verification**: Both image references show v0.3.11; no v0.2.17 remains

---

### T006 - [US1] Update Makefile version tags

**Story**: US1
**File**: `Makefile`
**Parallel**: Yes (can run with T004, T005)
**Depends on**: T003

Update Makefile version tag variables for catalog, bundle, and index images.

**Implementation**:
```bash
# Update CATALOG_TAG (line 12)
sed -i 's|CATALOG_TAG ?= v0.2.17|CATALOG_TAG ?= v0.3.11|' Makefile

# Update BUNDLE_TAG (line 21)
sed -i 's|BUNDLE_TAG ?= v0.2.17|BUNDLE_TAG ?= v0.3.11|' Makefile

# Update INDEX_TAG (line 30)
sed -i 's|INDEX_TAG ?= v0.2.17|INDEX_TAG ?= v0.3.11|' Makefile

# Verify changes
grep "TAG.*v0.3.11" Makefile
```

**Verification**: All three TAG variables show v0.3.11

---

### T007 - [US1] Download v0.3.11 upstream manifests

**Story**: US1
**File**: `downloaded/toolhive-operator/0.3.11/` (new directory)
**Parallel**: Yes (can run with T004, T005, T006)
**Depends on**: T003

Download v0.3.11 operator manifests from GitHub release.

**Implementation**:
```bash
# Create directory
mkdir -p downloaded/toolhive-operator/0.3.11

cd downloaded/toolhive-operator/0.3.11/

# Download ClusterServiceVersion
curl -L -o toolhive-operator.clusterserviceversion.yaml \
  https://raw.githubusercontent.com/stacklok/toolhive/v0.3.11/config/manifests/toolhive-operator.clusterserviceversion.yaml

# Download MCPRegistry CRD
curl -L -o mcpregistries.crd.yaml \
  https://raw.githubusercontent.com/stacklok/toolhive/v0.3.11/config/crd/bases/toolhive.stacklok.dev_mcpregistries.yaml

# Download MCPServer CRD
curl -L -o mcpservers.crd.yaml \
  https://raw.githubusercontent.com/stacklok/toolhive/v0.3.11/config/crd/bases/toolhive.stacklok.dev_mcpservers.yaml

cd ../../..

# Verify files
ls -la downloaded/toolhive-operator/0.3.11/
```

**Verification**: Directory contains 3 YAML files; CSV shows version: v0.3.11

**Note**: If URLs don't work, download manually from https://github.com/stacklok/toolhive/releases/tag/v0.3.11

---

### T008 - [US1] Validate kustomize builds with v0.3.11

**Story**: US1
**File**: Multiple (validation)
**Parallel**: No
**Depends on**: T004, T005, T006

Validate that both kustomize overlays build successfully with v0.3.11 references.

**Implementation**:
```bash
# Build config/base
echo "Building config/base..."
kustomize build config/base > /tmp/upgraded-base.yaml
if [ $? -eq 0 ]; then
  echo "✓ config/base builds successfully"
else
  echo "✗ config/base build failed"
  exit 1
fi

# Build config/default
echo "Building config/default..."
kustomize build config/default > /tmp/upgraded-default.yaml
if [ $? -eq 0 ]; then
  echo "✓ config/default builds successfully"
else
  echo "✗ config/default build failed"
  exit 1
fi

# Verify v0.3.11 in outputs
if grep -q "v0.3.11" /tmp/upgraded-base.yaml && grep -q "v0.3.11" /tmp/upgraded-default.yaml; then
  echo "✓ Both outputs contain v0.3.11 references"
else
  echo "✗ Missing v0.3.11 references in outputs"
  exit 1
fi

# Verify no v0.2.17 remains
if grep -q "v0.2.17" /tmp/upgraded-base.yaml || grep -q "v0.2.17" /tmp/upgraded-default.yaml; then
  echo "✗ Old v0.2.17 references still present"
  exit 1
else
  echo "✓ No v0.2.17 references remain"
fi
```

**Verification**: Both builds succeed; outputs contain only v0.3.11 (no v0.2.17)

**CHECKPOINT**: ✅ User Story 1 Complete - Configuration files updated to v0.3.11

---

## Phase 4: User Story 2 - Validate Compatibility (P2)

**Goal**: Validate that v0.3.11 upgrade doesn't break existing functionality

**Independent Test**: Run `make validate-all` and `make scorecard-test` and verify all tests pass

---

### T009 - [US2] Generate bundle with v0.3.11

**Story**: US2
**File**: `bundle/` (generated)
**Parallel**: No
**Depends on**: T007, T008

Generate OLM bundle using v0.3.11 manifests.

**Implementation**:
```bash
# Clean existing bundle
make clean-bundle

# Generate new bundle
make bundle

# Verify bundle generated
if [ -d "bundle/manifests" ]; then
  echo "✓ Bundle directory created"
else
  echo "✗ Bundle generation failed"
  exit 1
fi

# Check for v0.3.11 references
grep -r "v0.3.11" bundle/manifests/
```

**Verification**: bundle/manifests/ exists and contains v0.3.11 references

---

### T010 - [US2] Validate bundle structure

**Story**: US2
**File**: `bundle/` (validation)
**Parallel**: No
**Depends on**: T009

Validate bundle structure using operator-sdk.

**Implementation**:
```bash
# Run bundle validation
echo "Validating bundle structure..."
operator-sdk bundle validate bundle/

# Check exit code
if [ $? -eq 0 ]; then
  echo "✓ Bundle validation passed"
else
  echo "✗ Bundle validation failed"
  exit 1
fi
```

**Verification**: Validation outputs "All validation tests have completed successfully"

---

### T011 - [US2] Run scorecard tests

**Story**: US2
**File**: `bundle/tests/scorecard/` (uses existing config from feature 010)
**Parallel**: No
**Depends on**: T010

Run scorecard tests to validate OLM compliance.

**Implementation**:
```bash
# Check scorecard prerequisites
make check-scorecard-deps

# Run scorecard tests
echo "Running scorecard tests..."
make scorecard-test

# Verify results
if [ $? -eq 0 ]; then
  echo "✓ All scorecard tests passed"
else
  echo "✗ Scorecard tests failed"
  exit 1
fi
```

**Verification**: All 6 tests pass (1 basic + 5 OLM)

Expected tests:
- basic-check-spec: pass
- olm-bundle-validation: pass
- olm-crds-have-validation: pass
- olm-crds-have-resources: pass
- olm-spec-descriptors: pass
- olm-status-descriptors: pass

---

### T012 - [US2] Build and validate catalog

**Story**: US2
**File**: `catalog/` (generated)
**Parallel**: Yes (can run with T011 if cluster available)
**Depends on**: T009

Build OLM catalog with v0.3.11 bundle reference and validate.

**Implementation**:
```bash
# Build catalog
echo "Building catalog..."
make catalog-build

# Validate catalog
echo "Validating catalog..."
opm validate catalog/

if [ $? -eq 0 ]; then
  echo "✓ Catalog validation passed"
else
  echo "✗ Catalog validation failed"
  exit 1
fi
```

**Verification**: Catalog builds successfully and passes opm validation

---

### T013 - [US2] Verify constitution compliance

**Story**: US2
**File**: Multiple (compliance check)
**Parallel**: No
**Depends on**: T010, T011, T012

Verify all constitution principles maintained after upgrade.

**Implementation**:
```bash
# Constitution compliance check (manual verification - no make target)
echo "Verifying constitution compliance..."

# Principle III: Verify CRDs unchanged (CRITICAL - NON-NEGOTIABLE)
echo "Checking CRD immutability (Principle III)..."
git diff --exit-code config/crd/

if [ $? -eq 0 ]; then
  echo "✓ CRDs unchanged (constitution principle III)"
else
  echo "✗ CRDs have changed - CONSTITUTION VIOLATION"
  echo "STOP: This requires team consultation and separate feature branch"
  exit 1
fi

# Principle I: Verify both overlays build successfully
echo "Checking manifest integrity (Principle I)..."
kustomize build config/base > /dev/null && kustomize build config/default > /dev/null

if [ $? -eq 0 ]; then
  echo "✓ Both overlays build successfully (Principle I)"
else
  echo "✗ Kustomize build failures detected - CONSTITUTION VIOLATION"
  exit 1
fi

echo "✓ Constitution compliance verified (Principles I, III checked)"
```

**Verification**: Constitution check passes; CRDs unchanged; both overlays build

**CHECKPOINT**: ✅ User Story 2 Complete - Compatibility validated

---

## Phase 5: User Story 3 - Update Documentation (P3)

**Goal**: Update documentation to reflect v0.3.11 as current version

**Independent Test**: Review documentation files and verify all examples show v0.3.11

---

### T014 - [US3] Update README.md

**Story**: US3
**File**: `README.md`
**Parallel**: No
**Depends on**: T013

Update README version references to v0.3.11.

**Implementation**:
```bash
# Update version references
sed -i 's/v0\.2\.17/v0.3.11/g' README.md

# Verify changes
echo "Updated references:"
grep "v0.3.11" README.md

# Count changes
echo "Number of v0.3.11 references: $(grep -c 'v0.3.11' README.md)"
```

**Verification**: README.md contains v0.3.11 references; no v0.2.17 remains in user-facing examples

---

### T015 - [US3] Update CLAUDE.md

**Story**: US3
**File**: `CLAUDE.md`
**Parallel**: Yes (can run with T014)
**Depends on**: T013

Update agent context file with v0.3.11 references.

**Implementation**:
```bash
# Update version references
sed -i 's/v0\.2\.17/v0.3.11/g' CLAUDE.md

# Verify changes
echo "Updated default images reference:"
grep "Default images" CLAUDE.md
```

**Verification**: CLAUDE.md line 41 shows v0.3.11 default images

---

### T016 - [US3] Update VALIDATION.md

**Story**: US3
**File**: `VALIDATION.md`
**Parallel**: Yes (can run with T014, T015)
**Depends on**: T013

Update validation documentation with v0.3.11 examples.

**Implementation**:
```bash
# Update version references
sed -i 's/v0\.2\.17/v0.3.11/g' VALIDATION.md

# Verify changes
echo "Updated validation examples:"
grep "v0.3.11" VALIDATION.md | head -5

# Count changes
echo "Number of v0.3.11 references: $(grep -c 'v0.3.11' VALIDATION.md)"
```

**Verification**: VALIDATION.md contains v0.3.11 in catalog build examples and image references

---

### T017 - [US3] Verify documentation consistency

**Story**: US3
**File**: Multiple documentation files
**Parallel**: No
**Depends on**: T014, T015, T016

Verify all user-facing documentation consistently references v0.3.11.

**Implementation**:
```bash
# Check for remaining v0.2.17 in docs
echo "Checking for v0.2.17 in user-facing docs..."
grep -l "v0.2.17" README.md CLAUDE.md VALIDATION.md

if [ $? -eq 0 ]; then
  echo "⚠ Warning: Some v0.2.17 references remain in documentation"
  grep -n "v0.2.17" README.md CLAUDE.md VALIDATION.md
else
  echo "✓ No v0.2.17 references in user-facing documentation"
fi

# Verify v0.3.11 present in all files
for file in README.md CLAUDE.md VALIDATION.md; do
  if grep -q "v0.3.11" $file; then
    echo "✓ $file contains v0.3.11 references"
  else
    echo "✗ $file missing v0.3.11 references"
  fi
done
```

**Verification**: All three documentation files contain v0.3.11; no v0.2.17 in examples

**CHECKPOINT**: ✅ User Story 3 Complete - Documentation updated

---

## Phase 6: Polish & Final Verification

### T018 - Run complete validation checklist

**Story**: Polish
**File**: Multiple (end-to-end validation)
**Parallel**: No
**Depends on**: T017

Run comprehensive validation checklist to verify all success criteria met.

**Implementation**:
```bash
#!/bin/bash
echo "=== Version Upgrade Validation Checklist ==="

# SC-001: Kustomize builds under 5 seconds
echo -n "SC-001 Kustomize builds (<5s): "
time_start=$(date +%s)
kustomize build config/base > /dev/null 2>&1 && kustomize build config/default > /dev/null 2>&1
time_end=$(date +%s)
time_diff=$((time_end - time_start))
if [ $time_diff -lt 5 ]; then
  echo "PASS (${time_diff}s)"
else
  echo "FAIL (${time_diff}s > 5s)"
fi

# SC-002: Bundle validation passes first attempt
echo -n "SC-002 Bundle validation: "
operator-sdk bundle validate bundle/ 2>&1 | grep -q "completed successfully" && echo "PASS" || echo "FAIL"

# SC-003: Catalog validation passes
echo -n "SC-003 Catalog validation: "
opm validate catalog/ > /dev/null 2>&1 && echo "PASS" || echo "FAIL"

# SC-004: Scorecard tests pass (100%)
echo -n "SC-004 Scorecard tests (6/6): "
make scorecard-test > /dev/null 2>&1 && echo "PASS" || echo "FAIL"

# SC-005: Constitution check passes (Principle I: builds + Principle III: CRD immutability)
echo -n "SC-005 Constitution compliance: "
kustomize build config/base > /dev/null 2>&1 && kustomize build config/default > /dev/null 2>&1 && git diff --exit-code config/crd/ > /dev/null 2>&1 && echo "PASS" || echo "FAIL"

# SC-006: Upgrade completed in <30 minutes
echo "SC-006 Upgrade time: Manual tracking required (target <30 minutes)"

# SC-007: No manual intervention required
echo "SC-007 Automation: All tasks automated via sed/make commands"

# SC-008: No v0.2.17 in generated manifests
echo -n "SC-008 No v0.2.17 in bundle: "
! grep -q "v0.2.17" bundle/manifests/* 2>/dev/null && echo "PASS" || echo "FAIL"

# Version consistency check
echo -n "Version consistency: "
OPERATOR_VERSION=$(grep "toolhive-operator-image2" config/base/params.env | grep -o "v[0-9.]*")
PROXY_VERSION=$(grep "toolhive-proxy-image" config/base/params.env | grep -o "v[0-9.]*")
CATALOG_VERSION=$(grep "CATALOG_TAG" Makefile | head -1 | grep -o "v[0-9.]*")

if [ "$OPERATOR_VERSION" == "v0.3.11" ] && [ "$PROXY_VERSION" == "v0.3.11" ] && [ "$CATALOG_VERSION" == "v0.3.11" ]; then
  echo "PASS (all v0.3.11)"
else
  echo "FAIL (versions: op=$OPERATOR_VERSION, proxy=$PROXY_VERSION, cat=$CATALOG_VERSION)"
fi

echo "==========================================="
```

**Verification**: All checks pass; validation summary shows PASS for all criteria

---

## Dependency Graph

```
Phase 1: Setup
  T001 (baseline capture) [P]
  T002 (document state) [P]
    ↓
Phase 2: Foundation
  T003 (verify images) ← T001, T002
    ↓
Phase 3: User Story 1 (P1 - MVP)
  T004 (params.env) ← T003
  T005 (manager.yaml) ← T003 [P]
  T006 (Makefile) ← T003 [P]
  T007 (download manifests) ← T003 [P]
  T008 (validate kustomize) ← T004, T005, T006
    ↓
Phase 4: User Story 2 (P2 - Validation)
  T009 (generate bundle) ← T007, T008
  T010 (validate bundle) ← T009
  T011 (scorecard tests) ← T010
  T012 (build/validate catalog) ← T009 [P]
  T013 (constitution check) ← T010, T011, T012
    ↓
Phase 5: User Story 3 (P3 - Documentation)
  T014 (README.md) ← T013
  T015 (CLAUDE.md) ← T013 [P]
  T016 (VALIDATION.md) ← T013 [P]
  T017 (verify docs) ← T014, T015, T016
    ↓
Phase 6: Polish
  T018 (final validation) ← T017
```

## Parallel Execution Opportunities

### Within User Story 1 (MVP)
```bash
# After T003 completes, run in parallel:
- T004 (params.env update)
- T005 (manager.yaml update)
- T006 (Makefile update)
- T007 (manifest download)

# Then T008 (validation)
```

### Within User Story 2 (Validation)
```bash
# After T009 completes:
- T011 (scorecard) can run while T012 (catalog) builds
# Both complete before T013
```

### Within User Story 3 (Documentation)
```bash
# After T013 completes, run in parallel:
- T014 (README.md)
- T015 (CLAUDE.md)
- T016 (VALIDATION.md)

# Then T017 (verification)
```

**Total parallel opportunities**: 8 tasks (T002, T005, T006, T007, T012, T015, T016)

## Implementation Strategy

### MVP Delivery (User Story 1 Only)

**Tasks**: T001-T008 (8 tasks)
**Estimated effort**: 15-20 minutes
**Deliverable**: v0.3.11 configuration files with validated kustomize builds

**Critical path**:
```
T001 → T003 → T004 → T008
     → T002↗ → T005↗
            → T006↗
            → T007↗
```

**Value delivered**:
- All configuration files reference v0.3.11
- v0.3.11 manifests downloaded
- Both kustomize overlays build successfully
- Ready for validation phase

### Incremental Delivery (Add User Story 2)

**Tasks**: T009-T013 (5 additional tasks)
**Estimated effort**: 10-15 minutes
**Deliverable**: Validated v0.3.11 bundle, scorecard tests passed, catalog built

**Value delivered**:
- Bundle validates with operator-sdk
- All 6 scorecard tests pass
- Catalog validates with opm
- Constitution compliance verified

### Complete Feature (Add User Story 3)

**Tasks**: T014-T017 (4 additional tasks)
**Estimated effort**: 5 minutes
**Deliverable**: Complete documentation update

**Value delivered**:
- User-facing documentation reflects v0.3.11
- Agent context updated
- Validation examples current

### Polish

**Tasks**: T018 (1 task)
**Estimated effort**: 2 minutes
**Deliverable**: Comprehensive validation report

## Testing Strategy

### Unit Testing (Per Task)
Each task includes verification criteria that can be tested independently.

### Integration Testing (Per User Story)
- T008: MVP workflow test (kustomize builds)
- T013: Validation workflow test (bundle, scorecard, catalog, constitution)
- T017: Documentation consistency test

### End-to-End Testing
After T018, complete upgrade is verified:
```bash
# All success criteria met
# All configuration files updated
# All validation tests passed
# All documentation updated
```

## Success Criteria Mapping

| Success Criterion | Verified By | Phase |
|-------------------|-------------|-------|
| SC-001: Kustomize builds < 5s | T008, T018 (measure time) | Phase 3, 6 |
| SC-002: Bundle validation passes | T010, T018 | Phase 4, 6 |
| SC-003: Catalog validation passes | T012, T018 | Phase 4, 6 |
| SC-004: Scorecard tests pass (100%) | T011, T018 | Phase 4, 6 |
| SC-005: Constitution compliant | T013, T018 | Phase 4, 6 |
| SC-006: Upgrade < 30 minutes | T018 (manual tracking) | Phase 6 |
| SC-007: No manual intervention | T018 (verify automation) | Phase 6 |
| SC-008: No v0.2.17 in bundle | T008, T018 (grep check) | Phase 3, 6 |

## File Modifications Summary

| File | Tasks | Type |
|------|-------|------|
| `config/base/params.env` | T004 | Update |
| `config/manager/manager.yaml` | T005 | Update |
| `Makefile` | T006 | Update |
| `downloaded/toolhive-operator/0.3.11/` | T007 | Create |
| `bundle/` | T009 | Generate |
| `catalog/` | T012 | Generate |
| `README.md` | T014 | Update |
| `CLAUDE.md` | T015 | Update |
| `VALIDATION.md` | T016 | Update |

**Configuration files**: 3 updated
**Documentation files**: 3 updated
**Directories created**: 1
**Directories generated**: 2 (bundle, catalog)

## Notes

- **No custom code**: This is a configuration-only upgrade
- **Image dependency**: T003 is critical gate - upgrade cannot proceed without v0.3.11 images available
- **Constitution enforcement**: T013 includes CRD immutability check that will STOP upgrade if violated
- **Rollback capability**: See [contracts/rollback-procedure.md](contracts/rollback-procedure.md) for guaranteed rollback process
- **Historical documentation preserved**: Spec docs (001-010) intentionally not updated to preserve historical context
- **Incremental value**: Each user story delivers independent, testable functionality

## Next Steps After Task Completion

1. **Commit changes**: Create commit with version upgrade
2. **Create pull request**: Submit for review with validation evidence
3. **Test deployment** (optional): Deploy v0.3.11 to test cluster
4. **Build and push catalog** (if deploying): `make catalog-build && make catalog-push`
5. **Update deployment** (if using GitOps): Update image references in deployment manifests
