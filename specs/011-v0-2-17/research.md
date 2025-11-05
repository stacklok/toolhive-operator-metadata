# Research: Upgrade ToolHive Operator to v0.3.11

**Feature**: 011-v0-2-17
**Date**: 2025-10-21
**Purpose**: Research technical decisions for version upgrade from v0.2.17 to v0.3.11

## Research Questions

1. What files contain v0.2.17 references that need updating?
2. What is the process for downloading v0.3.11 upstream manifests?
3. Are there breaking changes between v0.2.17 and v0.3.11?
4. What validation steps are needed after version update?
5. How should documentation be updated?

---

## Decision 1: Files to Update

**What was chosen**: Update 7 primary files containing version references

**Rationale**:
- `config/base/params.env` - Central configuration for kustomize replacements
- `config/manager/manager.yaml` - Base operator deployment manifest
- `Makefile` - Version tags for catalog, bundle, and index images
- `README.md` - User-facing documentation
- `CLAUDE.md` - Agent context file
- `VALIDATION.md` - Validation examples
- `downloaded/toolhive-operator/` - Directory structure for upstream manifests

**Alternatives considered**:
- **Update all 66 files with v0.2.17 references**: Rejected - most are historical spec docs that should remain unchanged
- **Update only params.env**: Rejected - insufficient, manager.yaml and Makefile have independent references
- **Automated search-replace**: Rejected - risk of updating historical documentation incorrectly

**Implementation approach**:
- Phase 1: Update configuration files (params.env, manager.yaml, Makefile)
- Phase 2: Download v0.3.11 manifests and replace downloaded/toolhive-operator/0.2.17/ with 0.3.11/
- Phase 3: Update documentation (README.md, CLAUDE.md, VALIDATION.md)

---

## Decision 2: Upstream Manifest Download

**What was chosen**: Download v0.3.11 manifests from GitHub release artifacts

**Rationale**:
- ToolHive operator releases include manifest artifacts in GitHub releases
- Existing pattern uses downloaded/ directory structure
- Version-specific directories allow rollback by switching directory references

**Alternatives considered**:
- **Pull from container image**: Rejected - images don't contain source manifests
- **Generate from upstream repo**: Rejected - requires cloning and building, adds complexity
- **Manually create manifests**: Rejected - error-prone and doesn't match upstream exactly

**Implementation approach**:
1. Download v0.3.11 release artifacts from https://github.com/stacklok/toolhive/releases/tag/v0.3.11
2. Extract operator manifests (CSV, CRDs)
3. Create downloaded/toolhive-operator/0.3.11/ directory
4. Copy manifests to new directory
5. Update Makefile references from 0.2.17 to 0.3.11

**Download URL pattern**: `https://github.com/stacklok/toolhive/releases/download/v0.3.11/[artifacts]`

---

## Decision 3: Breaking Change Analysis

**What was chosen**: Assume API compatibility based on minor version increment (0.2 → 0.3)

**Rationale**:
- Semantic versioning suggests 0.3.11 is a minor version with backward compatibility
- v0.3.11 release notes mention only cosign installer revert (v4 → v3.10.1)
- No CRD schema changes mentioned in release notes
- Constitution requires CRD immutability (principle III)

**Alternatives considered**:
- **Full regression testing**: Preferred but blocked on cluster availability
- **Wait for upstream upgrade guide**: Rejected - no specific guide available
- **Incremental rollout**: Considered but unnecessary for metadata-only repository

**Risk mitigation**:
- Validate bundle structure with operator-sdk after upgrade
- Run scorecard tests to verify OLM compliance
- Check kustomize builds succeed for both base and default overlays
- Test catalog generation and validation

**Breaking change indicators to watch**:
- CRD spec changes (MUST NOT occur per constitution)
- CSV spec.install.spec changes (deployment structure)
- Required annotation changes
- New RBAC permissions

---

## Decision 4: Validation Strategy

**What was chosen**: Multi-layer validation approach

**Rationale**:
- Existing validation workflow provides comprehensive checks
- Constitution compliance must be verified
- Scorecard tests validate OLM compliance
- Kustomize builds validate manifest correctness

**Validation layers**:

1. **Constitutional validation** (NFR-001, NFR-002):
   - `kustomize build config/base` succeeds
   - `kustomize build config/default` succeeds
   - CRDs unchanged: `git diff config/crd/` shows no changes

2. **Bundle validation** (FR-012):
   - `make bundle` completes successfully
   - `operator-sdk bundle validate bundle/` passes
   - Bundle annotations reference v0.3.11

3. **Scorecard validation** (FR-014):
   - `make scorecard-test` passes all 6 tests
   - Basic check spec passes
   - OLM bundle validation passes
   - CRD validation passes

4. **Catalog validation** (FR-013):
   - `make catalog-build` completes successfully
   - `opm validate` passes for catalog image
   - Catalog references v0.3.11 bundle correctly

**Success criteria mapping**:
- SC-001: Kustomize builds complete in <5 seconds
- SC-002: Bundle validation passes on first attempt
- SC-003: Catalog validation passes on first attempt
- SC-004: All scorecard tests pass (100% success rate)
- SC-005: Constitution check passes

---

## Decision 5: Documentation Update Strategy

**What was chosen**: Update version references in user-facing and context documentation only

**Rationale**:
- README.md contains primary user instructions
- CLAUDE.md provides agent context for future development
- VALIDATION.md contains validation examples users follow
- Historical spec docs should preserve version context from when written

**Files to update**:
1. **README.md**:
   - Line 54: Catalog build example
   - Default version references

2. **CLAUDE.md**:
   - Line 41: Default images in config/manager

3. **VALIDATION.md**:
   - Lines 100, 111-112: Catalog build examples
   - Lines 197-198, 210: Catalog image references

**Files NOT to update**:
- specs/001-build-an-olmv1/ through specs/010-add-scorecard-tests/ - Historical context
- Containerfile.bundle, Containerfile.catalog - Comments reference historical versions
- examples/*.yaml - May be updated if they serve as active templates

**Update approach**:
- Search for v0.2.17 in each target file
- Replace with v0.3.11 where appropriate
- Preserve historical context in example comments
- Update "last validated" dates where present

---

## Decision 6: Rollback Strategy

**What was chosen**: Git-based rollback with version tag references

**Rationale**:
- Version upgrade is purely configuration changes
- Git revert provides atomic rollback
- No data migration or state changes involved

**Rollback procedure** (NFR-005):
1. Revert version update commit: `git revert <commit-hash>`
2. Regenerate bundle: `make bundle`
3. Validate rollback: `make validate-all`
4. Optional: Rebuild catalog with v0.2.17 reference

**Rollback verification**:
- All image references show v0.2.17
- Kustomize builds succeed
- Bundle validates successfully
- Scorecard tests pass

---

## Decision 7: Downloaded Manifest Management

**What was chosen**: Create parallel v0.3.11 directory, then update Makefile reference

**Rationale**:
- Preserves v0.2.17 manifests for rollback
- Allows side-by-side comparison
- Matches existing directory structure pattern

**Directory structure**:
```
downloaded/
└── toolhive-operator/
    ├── 0.2.17/                           # Preserved for rollback
    │   ├── toolhive-operator.clusterserviceversion.yaml
    │   ├── mcpregistries.crd.yaml
    │   └── mcpservers.crd.yaml
    ├── 0.3.11/                           # New version
    │   ├── toolhive-operator.clusterserviceversion.yaml
    │   ├── mcpregistries.crd.yaml
    │   └── mcpservers.crd.yaml
    └── package.yaml                      # Updated to reference 0.3.11
```

**Makefile integration**:
- Update `OPERATOR_VERSION` variable from 0.2.17 to 0.3.11
- Bundle target copies from downloaded/toolhive-operator/$(OPERATOR_VERSION)/
- Allows quick version switching via variable change

---

## Decision 8: Constitution Compliance Verification

**What was chosen**: Automated pre-commit and post-update validation

**Rationale**:
- Constitution principles are non-negotiable
- Automated checks prevent violations
- Multiple validation points catch issues early

**Compliance checks**:

1. **Manifest Integrity** (Principle I):
   - Pre-update: Capture baseline kustomize outputs
   - Post-update: Verify builds still succeed
   - Test: `kustomize build config/base && kustomize build config/default`

2. **Kustomize-Based Customization** (Principle II):
   - Verify params.env still uses kustomize var replacement
   - Verify no direct manifest edits in config/base or config/default
   - Test: `grep -r "v0.3.11" config/manager/` shows only base references

3. **CRD Immutability** (Principle III):
   - Pre-update: Capture CRD checksums
   - Post-update: Verify CRDs unchanged
   - Test: `git diff config/crd/ | wc -l` returns 0

4. **OpenShift Compatibility** (Principle IV):
   - Verify security patches still apply
   - Verify OpenShift-specific env vars preserved
   - Test: Build succeeds for both overlays

5. **Namespace Awareness** (Principle V):
   - Verify base targets opendatahub namespace
   - Verify default targets toolhive-operator-system namespace
   - Test: Namespace labels unchanged in manifests

6. **OLM Multi-Bundle Support** (Principle VI):
   - Verify catalog structure supports multiple bundles
   - Verify v0.3.11 can coexist with future versions
   - Test: Catalog YAML maintains olm.package, olm.channel, olm.bundle structure

---

## Decision 9: Container Image Availability

**What was chosen**: Verify image existence before updating references

**Rationale**:
- Prevents broken configuration from unavailable images
- Edge case handling for image pull failures
- Pre-flight check reduces downstream errors

**Verification approach**:
```bash
# Check operator image
podman manifest inspect ghcr.io/stacklok/toolhive/operator:v0.3.11

# Check proxy runner image
podman manifest inspect ghcr.io/stacklok/toolhive/proxyrunner:v0.3.11
```

**Expected output**: JSON manifest showing image exists and is pullable

**Failure handling**:
- If images not found: Wait for upstream to publish images
- If images are architecture-specific: Verify linux/amd64 availability
- If images require authentication: Document registry login requirement

---

## Decision 10: Testing Without Cluster

**What was chosen**: Use bundle and catalog validation without deployment testing

**Rationale**:
- This is a metadata-only repository
- Deployment testing requires OpenShift cluster
- Static validation provides confidence without cluster
- Scorecard tests run in temporary cluster pods

**Validation without cluster**:
1. **Bundle validation**: `operator-sdk bundle validate bundle/` (no cluster needed)
2. **Catalog validation**: `opm validate catalog/` (no cluster needed)
3. **Manifest validation**: `kustomize build` (no cluster needed)
4. **Scorecard tests**: Require cluster but validate OLM compliance

**Testing with cluster** (optional):
1. Deploy v0.3.11 operator to test cluster
2. Create MCPRegistry and MCPServer CRs
3. Verify operator reconciliation
4. Test upgrade path from v0.2.17 to v0.3.11

---

## Summary of Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Files to update | 7 primary files (configs, Makefile, docs) | Balance completeness with avoiding historical doc changes |
| Manifest download | GitHub release artifacts to downloaded/0.3.11/ | Matches existing pattern, enables rollback |
| Breaking changes | Assume API compatibility (minor version) | Semantic versioning + release notes analysis |
| Validation | Multi-layer (constitution, bundle, scorecard, catalog) | Comprehensive coverage without cluster deployment |
| Documentation | Update user-facing and context files only | Preserve historical accuracy in specs |
| Rollback | Git revert + bundle regeneration | Simple, atomic, no state migration |
| Directory structure | Parallel 0.2.17 and 0.3.11 directories | Preserve rollback capability |
| Constitution | Automated pre/post validation checks | Enforce non-negotiable principles |
| Image availability | Pre-flight manifest inspection | Prevent configuration errors |
| Testing scope | Static validation + scorecard only | Metadata repo doesn't require deployment testing |

---

## Open Questions

None - all research questions resolved with documented decisions.

---

## Next Steps

1. Proceed to Phase 1: Design & Contracts
2. Create data-model.md defining version update entities
3. Create contracts/ with file update specifications
4. Create quickstart.md with upgrade procedure
5. Update agent context (CLAUDE.md)
