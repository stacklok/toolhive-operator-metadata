# Feature Specification: Upgrade ToolHive Operator to v0.3.11

**Feature Branch**: `011-v0-2-17`
**Created**: 2025-10-21
**Status**: Draft
**Input**: User description: "v0.2.17 to v0.3.11. This project has been building out its functionality utilizing the tagged toolhive-operator container image version v0.2.17. The v0.2.17 package release page is at https://github.com/stacklok/toolhive/pkgs/container/toolhive%2Foperator/510178764?tag=v0.2.17 which references the ghcr.io/stacklok/toolhive/operator:v0.2.17 container image url that this project references. This version, v0.2.17, was released about 1 month ago. Just recently a newer version has been released that this project requires an update to use, v0.3.11 at https://github.com/stacklok/toolhive/pkgs/container/toolhive%2Foperator/548053212?tag=v0.3.11. This version was released about 4 days ago. To be clear the project is now required to use version v0.3.11 instead of the existing version in use v0.2.17."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Update Configuration Files (Priority: P1)

As a maintainer, I need to update all configuration files and manifests to reference v0.3.11 so that the operator metadata repository uses the latest stable version of the toolhive-operator.

**Why this priority**: This is the core requirement - updating version references is mandatory and blocks all other work. Without this, the repository continues using outdated v0.2.17 images.

**Independent Test**: Can be fully tested by running `kustomize build config/base` and `kustomize build config/default` and verifying all image references show v0.3.11 instead of v0.2.17.

**Acceptance Scenarios**:

1. **Given** configuration files reference v0.2.17, **When** version update is applied, **Then** all operator image references change to v0.3.11
2. **Given** configuration files reference v0.2.17, **When** version update is applied, **Then** all proxyrunner image references change to v0.3.11
3. **Given** updated configuration files, **When** kustomize builds are executed, **Then** both config/base and config/default build successfully without errors

---

### User Story 2 - Validate Compatibility (Priority: P2)

As a maintainer, I need to validate that the v0.3.11 upgrade doesn't break existing functionality so that deployments continue working correctly.

**Why this priority**: After updating references, validation ensures the new version is compatible with existing manifests and doesn't introduce regressions.

**Independent Test**: Can be tested independently by running `make validate-all` and `make scorecard-test` after version updates are applied.

**Acceptance Scenarios**:

1. **Given** updated v0.3.11 configuration, **When** bundle is generated, **Then** bundle validation passes without errors
2. **Given** updated v0.3.11 configuration, **When** scorecard tests run, **Then** all 6 tests (1 basic + 5 OLM) pass successfully
3. **Given** updated v0.3.11 configuration, **When** catalog is built, **Then** OLM catalog validation passes

---

### User Story 3 - Update Documentation (Priority: P3)

As a developer or user, I need documentation to reflect v0.3.11 as the current version so that I understand which version to use and how to upgrade.

**Why this priority**: Documentation updates are important for clarity but don't block functionality. They can be completed after the core upgrade is validated.

**Independent Test**: Can be tested by reviewing all documentation files and verifying examples, quickstart guides, and references mention v0.3.11 instead of v0.2.17.

**Acceptance Scenarios**:

1. **Given** README and CLAUDE.md files, **When** version update is documented, **Then** all references to v0.2.17 are updated to v0.3.11
2. **Given** feature specification documents, **When** reviewed, **Then** version-specific examples reflect v0.3.11 where appropriate
3. **Given** validation documentation, **When** updated, **Then** image references in examples show v0.3.11

---

### Edge Cases

- **Cached downloads**: What happens when generated bundle references old v0.2.17 version due to cached downloads?
  - *Detection*: T009 (bundle generation) + T010 (validation) verify correct version
  - *Resolution*: `make clean-bundle` before regeneration; verify with `grep v0.3.11 bundle/manifests/*.yaml`

- **Image availability**: How does the system handle if v0.3.11 container images are not yet pulled locally?
  - *Prevention*: T003 verifies image availability before any configuration updates (blocking gate)
  - *Resolution*: `podman pull ghcr.io/stacklok/toolhive/operator:v0.3.11` manually if needed

- **Breaking changes**: What happens if v0.3.11 introduces breaking changes that cause validation failures?
  - *Detection*: T010 (bundle structure), T011 (scorecard API contract), T013 (CRD immutability check)
  - *Response*: See [contracts/rollback-procedure.md](contracts/rollback-procedure.md) for reversion to v0.2.17
  - *Indicators*: Scorecard test failures, CRD schema changes, bundle validation errors

- **Rollback**: How does the system handle rollback if v0.3.11 proves incompatible?
  - *Guarantee*: v0.2.17 manifests preserved in `downloaded/toolhive-operator/0.2.17/` (Principle VI)
  - *Procedure*: Revert version references in 3 files (params.env, manager.yaml, Makefile) + regenerate bundle
  - *Validation*: Re-run T008 (kustomize builds) to confirm v0.2.17 restoration

- **Cosign version compatibility**: What if the cosign installer downgrade (v4 → v3.10.1 in v0.3.11) causes runtime failures?
  - *Assumption*: Cosign v3.10.1 is compatible with existing signature verification workflows (spec.md:L122)
  - *Build-time detection*: T010 (bundle validation), T011 (scorecard tests) verify manifest correctness
  - *Runtime detection*: Requires cluster deployment; monitor operator logs for signature verification errors
  - *Symptoms*: Container image pull failures, "signature verification failed" errors in operator logs
  - *Mitigation*: If detected in production, rollback to v0.2.17 per rollback procedure
  - *Note*: Build/validation tests cannot detect cosign runtime issues; requires live cluster testing

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST update config/base/params.env to reference ghcr.io/stacklok/toolhive/operator:v0.3.11
- **FR-002**: System MUST update config/base/params.env to reference ghcr.io/stacklok/toolhive/proxyrunner:v0.3.11
- **FR-003**: System MUST update config/manager/manager.yaml operator image to v0.3.11
- **FR-004**: System MUST update config/manager/manager.yaml TOOLHIVE_RUNNER_IMAGE environment variable to v0.3.11
- **FR-005**: System MUST update Makefile CATALOG_TAG variable from v0.2.17 to v0.3.11
- **FR-006**: System MUST update Makefile BUNDLE_TAG variable from v0.2.17 to v0.3.11
- **FR-007**: System MUST update Makefile INDEX_TAG variable from v0.2.17 to v0.3.11
- **FR-008**: System MUST maintain compatibility with existing kustomize build process
- **FR-009**: System MUST maintain compatibility with existing bundle generation workflow
- **FR-010**: System MUST maintain compatibility with existing catalog build process
- **FR-011**: Documentation files (README.md, CLAUDE.md) MUST be updated to reference v0.3.11
- **FR-012**: Generated bundle MUST pass operator-sdk bundle validation after version update
- **FR-013**: Generated catalog MUST pass OLM validation after version update
- **FR-014**: Generated manifests MUST pass scorecard tests after version update
- **FR-015**: Downloaded operator manifests MUST be updated from v0.2.17 to v0.3.11

### Key Entities

- **Operator Image**: Container image for toolhive operator controller, version ghcr.io/stacklok/toolhive/operator:v0.3.11
- **Proxy Runner Image**: Container image for MCP proxy runner sidecar, version ghcr.io/stacklok/toolhive/proxyrunner:v0.3.11
- **Configuration Parameters**: Environment file (params.env) containing image references used by kustomize replacements
- **Manager Deployment**: Kubernetes deployment manifest defining operator pod template with image references
- **Makefile Variables**: Build configuration variables (CATALOG_TAG, BUNDLE_TAG, INDEX_TAG) controlling version tags
- **Downloaded Manifests**: Upstream operator manifests stored in downloaded/toolhive-operator/0.2.17/ directory
- **Bundle**: OLM bundle containing operator manifests, CRDs, and metadata
- **Catalog**: File-Based Catalog (FBC) containing olm.package, olm.channel, and olm.bundle declarations

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All kustomize builds (config/base and config/default) complete successfully in under 5 seconds without errors
- **SC-002**: Bundle generation completes with all v0.3.11 image references and passes validation on first attempt
- **SC-003**: Catalog generation completes with v0.3.11 bundle reference and passes OLM validation on first attempt
- **SC-004**: All scorecard tests (6 total) pass with 100% success rate after upgrade
- **SC-005**: Constitution compliance check passes - both kustomize builds succeed and CRDs remain unchanged
- **SC-006**: Version upgrade completes within 30 minutes from start to validated deployment
- **SC-007**: No manual intervention required during version update process beyond initial version number change
- **SC-008**: Generated manifests reference only v0.3.11 images with zero v0.2.17 references remaining

## Non-Functional Requirements

- **NFR-001**: Version upgrade MUST NOT modify CRD definitions (constitution principle III)
- **NFR-002**: Version upgrade MUST preserve kustomize-based customization pattern (constitution principle II)
- **NFR-003**: Version upgrade MUST maintain OpenShift compatibility for both config/base and config/default overlays
- **NFR-004**: Version upgrade MUST NOT require changes to existing deployment workflows or procedures
- **NFR-005**: Rollback to v0.2.17 MUST be possible by reverting version number changes only

## Assumptions

- v0.3.11 container images are publicly available at ghcr.io/stacklok/toolhive registry
- v0.3.11 maintains API compatibility with v0.2.17 (no breaking CRD changes)
- v0.3.11 release notes indicate compatibility with existing OpenShift versions (4.15+)
- Cosign installer revert in v0.3.11 (from v4 to v3.10.1) does not affect operator functionality
- Existing bundle and catalog generation processes remain compatible with v0.3.11
- No new CRDs or API versions are introduced in v0.3.11 that require manifest changes
- Downloaded operator manifests for v0.3.11 will be available from upstream release artifacts

## Out of Scope

- Upgrading to versions newer than v0.3.11
- Backporting v0.3.11 features to v0.2.17
- Modifying operator controller code or behavior
- Changing deployment topologies or architectures
- Adding new features beyond version update
- Performance tuning or optimization
- Updating dependencies beyond operator images
- Creating new OLM channels or update paths
