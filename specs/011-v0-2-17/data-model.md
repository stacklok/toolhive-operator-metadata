# Data Model: Upgrade ToolHive Operator to v0.3.11

**Feature**: 011-v0-2-17
**Date**: 2025-10-21
**Purpose**: Define entities and their relationships for version upgrade

## Overview

This feature involves updating version references across configuration files, manifests, and documentation. The data model describes the entities being modified and their relationships.

---

## Core Entities

### 1. Version Reference

**Description**: A reference to a specific toolhive operator version in a configuration file

**Attributes**:
- `file_path` (string): Absolute path to file containing reference
- `line_number` (integer): Line number where reference occurs
- `old_version` (string): Current version (v0.2.17)
- `new_version` (string): Target version (v0.3.11)
- `reference_type` (enum): Type of reference (image_url, tag_variable, documentation_example)
- `image_component` (enum): Which image is referenced (operator, proxyrunner, catalog, bundle, index)

**Validation Rules**:
- `old_version` MUST match `v0.2.17` pattern
- `new_version` MUST match `v0.3.11` pattern
- `file_path` MUST exist and be readable
- `reference_type` MUST be one of: `image_url`, `tag_variable`, `doc_example`, `makefile_var`

**Example**:
```yaml
file_path: /wip/.../config/base/params.env
line_number: 1
old_version: v0.2.17
new_version: v0.3.11
reference_type: image_url
image_component: operator
```

---

### 2. Configuration File

**Description**: A file containing version-specific configuration that must be updated

**Attributes**:
- `path` (string): Absolute file path
- `type` (enum): File type (kustomize_params, deployment_manifest, makefile, documentation)
- `update_method` (enum): How to update (direct_replace, variable_substitution, manual_review)
- `references` (array): List of Version Reference entities in this file
- `validation_command` (string): Command to validate file after update

**File Types**:

1. **kustomize_params** (config/base/params.env):
   - Contains image URL variables used by kustomize replacements
   - Update method: direct_replace
   - Validation: `kustomize build config/base`

2. **deployment_manifest** (config/manager/manager.yaml):
   - Contains image references in container specs
   - Update method: direct_replace
   - Validation: `kustomize build config/default`

3. **makefile** (Makefile):
   - Contains tag variables for image builds
   - Update method: variable_substitution
   - Validation: `make bundle && make catalog-build`

4. **documentation** (README.md, CLAUDE.md, VALIDATION.md):
   - Contains version examples and references
   - Update method: direct_replace
   - Validation: manual_review

**Relationships**:
- Has many `Version Reference` entities
- Referenced by `Update Task` entities

---

### 3. Container Image

**Description**: A container image with version-specific tag

**Attributes**:
- `registry` (string): Container registry (ghcr.io, quay.io)
- `organization` (string): Organization/namespace (stacklok/toolhive, roddiekieley)
- `repository` (string): Repository name (operator, proxyrunner, catalog, bundle, index-olmv0)
- `old_tag` (string): Current tag (v0.2.17)
- `new_tag` (string): Target tag (v0.3.11)
- `availability_verified` (boolean): Whether new_tag exists in registry

**Full Image URL Pattern**: `{registry}/{organization}/{repository}:{tag}`

**Image Types**:

1. **Operator Image**:
   ```
   ghcr.io/stacklok/toolhive/operator:v0.3.11
   ```
   - Used in: config/base/params.env (toolhive-operator-image2)
   - Used in: config/manager/manager.yaml (spec.template.spec.containers[0].image)

2. **Proxy Runner Image**:
   ```
   ghcr.io/stacklok/toolhive/proxyrunner:v0.3.11
   ```
   - Used in: config/base/params.env (toolhive-proxy-image)
   - Used in: config/manager/manager.yaml (env.TOOLHIVE_RUNNER_IMAGE)

3. **Catalog Image**:
   ```
   ghcr.io/stacklok/toolhive/catalog:v0.3.11
   ```
   - Built by: Makefile (catalog-build target)
   - Tag defined by: CATALOG_TAG variable

4. **Bundle Image**:
   ```
   quay.io/roddiekieley/toolhive-operator-catalog:v0.3.11
   ```
   - Built by: Makefile (bundle-build target)
   - Tag defined by: BUNDLE_TAG variable

5. **Index Image** (OLMv0):
   ```
   ghcr.io/stacklok/toolhive/index-olmv0:v0.3.11
   ```
   - Built by: Makefile (index-olmv0-build target)
   - Tag defined by: INDEX_TAG variable

**Validation**:
- Verify image exists: `podman manifest inspect {full_url}`
- Verify pullable: `podman pull {full_url}`

---

### 4. Downloaded Manifest

**Description**: Upstream operator manifests downloaded from GitHub releases

**Attributes**:
- `version` (string): Operator version (v0.2.17, v0.3.11)
- `directory_path` (string): Local storage path (downloaded/toolhive-operator/{version}/)
- `source_url` (string): GitHub release URL
- `manifests` (array): List of manifest files (CSV, CRDs)
- `download_timestamp` (datetime): When manifests were downloaded

**Manifest Files**:
1. `toolhive-operator.clusterserviceversion.yaml` - ClusterServiceVersion defining operator
2. `mcpregistries.crd.yaml` - MCPRegistry CustomResourceDefinition
3. `mcpservers.crd.yaml` - MCPServer CustomResourceDefinition

**Directory Structure**:
```
downloaded/
└── toolhive-operator/
    ├── 0.2.17/                          # Old version (preserved)
    │   ├── toolhive-operator.clusterserviceversion.yaml
    │   ├── mcpregistries.crd.yaml
    │   └── mcpservers.crd.yaml
    ├── 0.3.11/                          # New version
    │   ├── toolhive-operator.clusterserviceversion.yaml
    │   ├── mcpregistries.crd.yaml
    │   └── mcpservers.crd.yaml
    └── package.yaml                     # Package metadata
```

**Operations**:
- Create new version directory: `mkdir -p downloaded/toolhive-operator/0.3.11`
- Download manifests from GitHub release
- Validate manifests: Check YAML syntax, verify API versions
- Update Makefile to reference new version directory

---

### 5. Validation Result

**Description**: Result of running a validation command after version update

**Attributes**:
- `validation_type` (enum): Type of validation (kustomize_build, bundle_validate, scorecard_test, catalog_validate, constitution_check)
- `command` (string): Validation command executed
- `exit_code` (integer): Command exit code (0 = success)
- `output` (string): Command output
- `timestamp` (datetime): When validation ran
- `passed` (boolean): Whether validation passed

**Validation Types**:

1. **kustomize_build**:
   - Command: `kustomize build config/base && kustomize build config/default`
   - Success criteria: Exit code 0, no errors in output
   - Maps to: SC-001

2. **bundle_validate**:
   - Command: `operator-sdk bundle validate bundle/`
   - Success criteria: "All validation tests have completed successfully"
   - Maps to: SC-002, FR-012

3. **scorecard_test**:
   - Command: `make scorecard-test`
   - Success criteria: All 6 tests pass (basic + OLM suite)
   - Maps to: SC-004, FR-014

4. **catalog_validate**:
   - Command: `opm validate catalog/`
   - Success criteria: Exit code 0
   - Maps to: SC-003, FR-013

5. **constitution_check**:
   - Command: `make constitution-check`
   - Success criteria: Kustomize builds succeed, CRDs unchanged
   - Maps to: SC-005, NFR-001, NFR-002, NFR-003

**State Transition**:
```
Not Run → Running → Completed (Passed | Failed)
```

---

### 6. Update Task

**Description**: A discrete update operation for a specific file or component

**Attributes**:
- `task_id` (string): Unique identifier (e.g., "T001", "T002")
- `description` (string): What the task updates
- `target_file` (string): File being modified
- `update_type` (enum): Type of update (version_reference, manifest_download, documentation, validation)
- `status` (enum): Task status (pending, in_progress, completed, failed)
- `dependencies` (array): List of task_ids that must complete first
- `validation` (Validation Result): Post-update validation result

**Update Types**:

1. **version_reference**: Update version string in configuration file
2. **manifest_download**: Download and install new version manifests
3. **documentation**: Update version references in documentation
4. **validation**: Run validation command to verify update

**Dependencies**:
- Manifest download tasks must complete before bundle generation
- Configuration updates must complete before kustomize builds
- All updates must complete before validation tasks

---

## Entity Relationships

```
Configuration File (1) ─┬─> (many) Version Reference
                        └─> (1) Validation Result

Container Image (1) ──> (many) Version Reference

Downloaded Manifest (1) ──> (many) Manifest Files
                       └──> (1) Update Task

Update Task (1) ──> (1) Configuration File
           (1) ──> (1) Validation Result
           (many) ──> (many) Update Task (dependencies)

Validation Result (1) ──> (1) Update Task
```

---

## State Machines

### Version Update Workflow

```
Initial State: v0.2.17 Configuration
    ↓
State: Configuration Files Updated
    ↓ (trigger: update params.env, manager.yaml, Makefile)
State: Manifests Downloaded
    ↓ (trigger: download v0.3.11 from GitHub)
State: Kustomize Builds Validated
    ↓ (trigger: kustomize build config/base && config/default)
State: Bundle Generated
    ↓ (trigger: make bundle)
State: Bundle Validated
    ↓ (trigger: operator-sdk bundle validate)
State: Scorecard Tests Run
    ↓ (trigger: make scorecard-test)
State: Catalog Generated
    ↓ (trigger: make catalog-build)
State: Catalog Validated
    ↓ (trigger: opm validate)
State: Documentation Updated
    ↓ (trigger: update README.md, CLAUDE.md, VALIDATION.md)
Final State: v0.3.11 Configuration Validated
```

### Rollback Workflow

```
Current State: v0.3.11 Configuration (Failed Validation)
    ↓
State: Git Revert Executed
    ↓ (trigger: git revert <commit-hash>)
State: v0.2.17 Configuration Restored
    ↓ (trigger: automatic from revert)
State: Bundle Regenerated
    ↓ (trigger: make bundle)
State: Validation Run
    ↓ (trigger: make validate-all)
Final State: v0.2.17 Configuration Validated
```

---

## Validation Rules

### Cross-Entity Validation

1. **Version Consistency**:
   - All Version Reference entities with `image_component=operator` MUST have same `new_version`
   - All Version Reference entities with `image_component=proxyrunner` MUST have same `new_version`

2. **File Integrity**:
   - Configuration File MUST exist before Update Task executes
   - Configuration File MUST pass validation after Update Task completes

3. **Image Availability**:
   - Container Image with `new_tag` MUST be verified available before updates
   - `podman manifest inspect` MUST succeed for all Container Image entities

4. **Manifest Completeness**:
   - Downloaded Manifest for v0.3.11 MUST contain all 3 manifest files
   - CSV file MUST reference v0.3.11 in spec.version
   - CRD files MUST NOT change schema (constitution principle III)

5. **Task Dependencies**:
   - Update Task MUST NOT start if dependencies have `status != completed`
   - Validation tasks MUST run after all configuration update tasks

---

## Data Invariants

1. **Version Uniqueness**: Only one "current" version exists across all files after update completes
2. **Constitution Compliance**: CRD files remain unchanged (byte-for-byte identical)
3. **Kustomize Validity**: Both config/base and config/default build successfully
4. **Rollback Capability**: v0.2.17 manifests preserved in downloaded/toolhive-operator/0.2.17/
5. **Validation Coverage**: Every Configuration File has associated Validation Result

---

## Example Data Flow

### Scenario: Update params.env

```yaml
# Input: Version Reference
file_path: /wip/.../config/base/params.env
line_number: 1
old_version: v0.2.17
new_version: v0.3.11
reference_type: image_url
image_component: operator

# Entity: Configuration File
path: /wip/.../config/base/params.env
type: kustomize_params
update_method: direct_replace
validation_command: kustomize build config/base

# Process: Update Task
task_id: T001
description: Update operator image in params.env
target_file: config/base/params.env
update_type: version_reference
status: completed

# Output: Validation Result
validation_type: kustomize_build
command: kustomize build config/base
exit_code: 0
passed: true
```

---

## Summary

The data model defines 6 core entities:
1. **Version Reference** - Individual version strings to update
2. **Configuration File** - Files containing references
3. **Container Image** - Image URLs with version tags
4. **Downloaded Manifest** - Upstream operator manifests
5. **Validation Result** - Validation command outcomes
6. **Update Task** - Discrete update operations

Entities are related through update workflows and validation dependencies. State machines govern version update and rollback procedures. Validation rules ensure consistency, constitution compliance, and rollback capability.
