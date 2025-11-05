<!--
  Sync Impact Report
  ==================
  Version Change: 1.1.2 → 1.2.0 (new quality assurance principle)

  Modified Principles: N/A

  Added Sections:
  - Principle VII: Scorecard Quality Assurance (NON-NEGOTIABLE)

  Removed Sections: N/A

  Templates Requiring Updates:
  ✅ plan-template.md - reviewed, Constitution Check section includes scorecard validation
  ✅ spec-template.md - reviewed, no changes required
  ✅ tasks-template.md - reviewed, includes optional test tasks compatible with scorecard principle
  ⚠ Makefile - already has scorecard-test target, constitution reference updated

  Follow-up TODOs:
  - Update CI/CD pipelines to include scorecard testing if automated testing is implemented
  - Consider adding scorecard results to VALIDATION.md documentation
-->

# ToolHive Operator Metadata Constitution

## Core Principles

### I. Manifest Integrity (NON-NEGOTIABLE)

All changes to Kubernetes/OpenShift manifests MUST preserve the ability to build valid manifests using kustomize. Before any modification is committed, `kustomize build config/base` and `kustomize build config/default` MUST execute successfully without errors.

**Rationale**: This repository serves as a metadata source for the OpenDataHub operator integration. Broken manifests prevent deployment and integration, breaking downstream consumers. The dual-build requirement ensures both the base OpenShift configuration and default Kubebuilder configuration remain valid.

### II. Kustomize-Based Customization

All manifest customization MUST be performed using kustomize overlays, patches, and replacements. Direct modification of base manifests from upstream sources is prohibited unless explicitly required for permanent divergence.

**Rationale**: Kustomize-based customization enables:
- Clear separation between upstream (Kubebuilder) and OpenShift-specific changes
- Maintainable upgrade paths when upstream releases new versions
- Transparent diff visibility showing what was changed and why
- Reusable patterns across similar deployments

### III. CRD Immutability (NON-NEGOTIABLE)

Custom Resource Definitions (CRDs) for MCPRegistry and MCPServer MUST NOT be modified in this repository. CRDs are defined and maintained in the upstream ToolHive operator source and must remain unchanged.

**Rationale**: CRDs define the API contract for the operator. Modifying them breaks compatibility with the upstream operator controller implementation and creates version skew that prevents successful operation. CRD changes must originate from the upstream ToolHive operator project.

### IV. OpenShift Compatibility

All OpenShift-specific customizations (security contexts, resource limits, environment variables) MUST be isolated in the `config/base` overlay and applied via patches. The `config/default` base MUST remain OpenShift-agnostic.

**Rationale**: This separation maintains compatibility with both standard Kubernetes deployments (via `config/default`) and OpenShift deployments (via `config/base`), enabling the operator to support multiple deployment targets without duplication.

### V. Namespace Awareness

Manifests MUST explicitly handle namespace placement. The `config/default` overlay uses the `toolhive-operator-system` namespace, while `config/base` targets `opendatahub` for OpenDataHub integration. Any new namespace-scoped resources MUST be consistent with their overlay's target namespace.

**Rationale**: Namespace mismatches cause deployment failures and access control issues. Explicit namespace handling ensures resources deploy to the correct namespaces for their intended integration contexts.

### VI. OLM Catalog Multi-Bundle Support

A file-based catalog for the Operator Lifecycle Manager (OLM) MUST support one or more `olm.bundle` sections for each Operator package. Each `olm.bundle` section represents a specific version of an Operator and its associated metadata. While a catalog requires exactly one `olm.package` blob and at least one `olm.channel` blob for each Operator, it MUST be able to contain multiple `olm.bundle` blobs to define different versions and update paths within a channel. A bundle MAY be included as an entry in multiple `olm.channel` blobs.

**Rationale**: Supporting multiple bundle versions within a single catalog enables:
- Gradual rollout and upgrade paths for operator versions
- Channel-based version management (stable, candidate, preview)
- Rollback capabilities by maintaining previous bundle versions
- Flexibility in update graph definitions for complex upgrade scenarios
- Single catalog serving multiple release channels without duplication

### VII. Scorecard Quality Assurance (NON-NEGOTIABLE)

All OLM bundles MUST pass operator-sdk scorecard validation tests before being considered production-ready. The scorecard test suite validates bundle structure, OLM metadata correctness, CRD validation schemas, and Operator Framework best practices. Failures in scorecard tests indicate bundle defects that could prevent successful deployment via OLM.

**Rationale**: The operator-sdk scorecard is the Operator Framework's official quality gate for operator bundles. Scorecard tests verify:
- Bundle structure integrity (manifests, metadata, annotations)
- OLM-specific requirements (install modes, CRD ownership, RBAC completeness)
- CRD schema validation and resource specifications
- Operator Framework best practices and compatibility

Passing scorecard tests ensures the operator bundle is compatible with OLM, reduces deployment failures, and maintains compliance with Operator Framework standards. Scorecard failures often indicate subtle configuration errors that would otherwise surface as runtime failures in production environments.

## Kustomize Build Standards

All kustomize manifests MUST:
- Use explicit file references (no wildcard includes that might capture unintended files)
- Document patches with comments explaining what is patched and why
- Use strategic merge patches for structured additions (environment variables, volumes)
- Use JSON patches for precise removals or replacements (security contexts, namespaces)
- Validate outputs using `kustomize build` before committing

ConfigMap-based variable substitution MUST:
- Centralize image references in `config/base/params.env`
- Use kustomize replacements to propagate values to both container images and environment variables
- Document variable purpose and expected format in comments

## OpenDataHub Integration Requirements

When adding manifests for OpenDataHub integration, developers MUST:
- Ensure all resources deploy to the `opendatahub` namespace
- Apply OpenShift security context constraints compatible with restricted SCC
- Remove or patch any hard-coded namespaces from upstream manifests
- Test with `kustomize build config/base` to verify OpenShift compatibility
- Document integration-specific patches in `config/base/kustomization.yaml`

## Governance

**Constitution Authority**: This constitution supersedes ad-hoc development practices. When conflicts arise between convenience and constitutional principles, principles take precedence unless explicitly amended.

**Amendment Process**: Amendments require:
1. Documented justification explaining why current principles are insufficient
2. Review confirming no alternative approach satisfies the requirement
3. Update to this constitution with version bump
4. Migration plan if existing manifests require changes

**Git Operations Policy**: Git operations that modify the repository state are PROHIBITED during automated processes, constitutional updates, and development workflows unless explicitly requested by a human operator. Read-only git operations (status, log, diff, show, branch listing) are permitted for informational purposes. Write operations (commit, push, merge, rebase, tag, config changes) MUST only be performed through explicit human-initiated actions.

**Operator SDK Plugin Policy**: When using operator-sdk for any operations (bundle generation, scorecard testing, or other SDK commands), the `go.kubebuilder.io/v4` plugin MUST be specified. Commands that do not explicitly specify this plugin will fail with plugin resolution errors. This requirement applies to all operator-sdk invocations in Makefiles, scripts, and documentation.

**Rationale**: The operator-sdk defaults have changed across versions, and this project's structure requires the v4 plugin for compatibility. Explicit plugin specification prevents failures and ensures consistent behavior across development environments.

**Compliance Verification**: All pull requests MUST verify:
1. Version consistency across all configuration files (`scripts/verify-version-consistency.sh`)
2. `kustomize build config/base` succeeds
3. `kustomize build config/default` succeeds
4. CRD files remain unchanged (hash/diff check)
5. New patches are documented
6. Namespace placement is correct for the overlay
7. OLM catalog contains valid `olm.package`, `olm.channel`, and `olm.bundle` blobs
8. operator-sdk commands specify `go.kubebuilder.io/v4` plugin where applicable
9. `operator-sdk scorecard bundle/` passes all required tests

**Version**: 1.2.1 | **Ratified**: 2025-10-07 | **Last Amended**: 2025-10-28
