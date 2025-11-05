# Data Model: Scorecard Testing

**Feature**: Add Scorecard Tests (010-add-scorecard-tests)
**Date**: 2025-10-21

## Overview

This document defines the data structures and entities involved in scorecard testing for the ToolHive Operator metadata repository. Since scorecard is a validation tool rather than a data-processing application, the "data model" here refers to configuration structures and validation artifacts.

## Key Entities

### 1. Scorecard Configuration

**Purpose**: Defines the test suites, test images, and execution parameters for scorecard validation

**Location**: `config/scorecard/config.yaml` (template), `bundle/tests/scorecard/config.yaml` (generated)

**Structure**:
```yaml
apiVersion: scorecard.operatorframework.io/v1alpha3
kind: Configuration
metadata:
  name: config
stages:
  - parallel: boolean
    tests:
      - image: string
        entrypoint: []string
        labels: map[string]string
        storage:
          spec:
            mountPath: {}
storage:
  spec:
    mountPath: {}
```

**Fields**:

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| `apiVersion` | string | Yes | API version (scorecard.operatorframework.io/v1alpha3) | Must be v1alpha3 |
| `kind` | string | Yes | Resource type (Configuration) | Must be "Configuration" |
| `metadata.name` | string | Yes | Configuration name | Non-empty string |
| `stages` | []Stage | Yes | Test execution stages | At least one stage |
| `stages[].parallel` | boolean | No | Run tests in parallel | Default: false |
| `stages[].tests` | []Test | Yes | Tests to execute | At least one test |
| `storage` | Storage | No | Global storage config | Optional |

**Relationships**:
- Contains one or more Test entities
- Referenced by Bundle Metadata annotations
- Used by scorecard command at runtime

---

### 2. Test Configuration

**Purpose**: Defines an individual scorecard test including its container image, entrypoint, and labels

**Structure**:
```yaml
image: string
entrypoint: []string
labels: map[string]string
storage:
  spec:
    mountPath: {}
```

**Fields**:

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| `image` | string | Yes | Container image containing test | Valid image reference (registry/org/name:tag) |
| `entrypoint` | []string | No | Command and arguments | Must be executable in container |
| `labels` | map[string]string | No | Test metadata (suite, test name) | Standard label format |
| `storage` | Storage | No | Test-specific storage config | Optional |

**Standard Labels**:

| Label Key | Purpose | Example Values |
|-----------|---------|----------------|
| `suite` | Test suite grouping | `basic`, `olm`, `custom` |
| `test` | Unique test identifier | `basic-check-spec-test`, `olm-bundle-validation-test` |

**Relationships**:
- Contained within Stage entity
- References container image from quay.io/operator-framework
- Produces TestResult entities when executed

**Validation Rules**:
- Image must be pullable from registry
- Entrypoint command must exist in container image
- Labels must be valid Kubernetes label format (RFC 1123)
- Test name must be unique within configuration

---

### 3. Test Result

**Purpose**: Represents the outcome of a single scorecard test execution

**Structure** (from scorecard API):
```go
type TestResult struct {
    Name              string
    Log               string
    State             State  // "pass", "fail", or "error"
    Errors            []string
    Suggestions       []string
    CreationTimestamp metav1.Time
}
```

**Fields**:

| Field | Type | Description | Values |
|-------|------|-------------|--------|
| `name` | string | Test identifier | Matches test configuration name |
| `log` | string | Test execution log output | Arbitrary text |
| `state` | string | Test outcome | `pass`, `fail`, `error` |
| `errors` | []string | Error messages (if failed) | List of error descriptions |
| `suggestions` | []string | Remediation suggestions | List of actionable fixes |
| `creationTimestamp` | timestamp | Test execution time | ISO 8601 timestamp |

**State Values**:

| State | Meaning | Exit Code Impact |
|-------|---------|------------------|
| `pass` | Test succeeded | 0 (if all tests pass) |
| `fail` | Test failed validation | 1 |
| `error` | Fatal error during execution | 1 |

**Relationships**:
- Produced by Test execution
- Aggregated into TestStatus entity
- Consumed by validation workflow (Makefile)

**Validation Rules**:
- State must be one of: pass, fail, error
- Name must match a configured test
- Errors array only populated if state is fail or error

---

### 4. Test Status

**Purpose**: Aggregates all test results from a scorecard run

**Structure**:
```go
type TestStatus struct {
    Results []TestResult
}
```

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `results` | []TestResult | Array of individual test results |

**Relationships**:
- Contains multiple TestResult entities
- Serialized to JSON/text/XML for output
- Used to determine overall pass/fail status

**Validation Rules**:
- At least one result must be present
- Overall status is fail if any result is fail or error

---

### 5. Bundle Metadata

**Purpose**: Annotations in bundle metadata that reference scorecard configuration

**Location**: `bundle/metadata/annotations.yaml`

**Relevant Annotations**:
```yaml
annotations:
  # Scorecard configuration location
  operators.operatorframework.io.test.config.v1: tests/scorecard/

  # Scorecard media type
  operators.operatorframework.io.test.mediatype.v1: scorecard+v1
```

**Fields**:

| Annotation | Value | Description |
|------------|-------|-------------|
| `operators.operatorframework.io.test.config.v1` | `tests/scorecard/` | Path to scorecard config directory |
| `operators.operatorframework.io.test.mediatype.v1` | `scorecard+v1` | Scorecard configuration format version |

**Relationships**:
- References Scorecard Configuration location
- Part of Bundle structure
- Used by OLM and scorecard to locate test config

---

### 6. Bundle Directory

**Purpose**: Container for operator manifests, metadata, and test configurations

**Structure**:
```
bundle/
├── manifests/
│   ├── toolhive-operator.clusterserviceversion.yaml
│   ├── mcpregistries.crd.yaml
│   └── mcpservers.crd.yaml
├── metadata/
│   └── annotations.yaml
└── tests/
    └── scorecard/
        └── config.yaml
```

**Validation Rules**:
- Must contain manifests/ directory with CSV and CRDs
- Must contain metadata/annotations.yaml
- tests/scorecard/config.yaml must exist for scorecard to run
- All YAML files must be valid

**Relationships**:
- Contains Scorecard Configuration
- Referenced by scorecard command (`operator-sdk scorecard ./bundle`)
- Mounted at `/bundle` in test containers

---

## Data Flow

### 1. Configuration Generation Flow

```
config/scorecard/config.yaml (template)
    ↓ (make bundle - copy operation)
bundle/tests/scorecard/config.yaml (generated)
    ↓ (referenced by)
bundle/metadata/annotations.yaml (test.config.v1 annotation)
```

### 2. Test Execution Flow

```
User executes: make scorecard-test
    ↓
Makefile invokes: operator-sdk scorecard ./bundle
    ↓
Scorecard reads: bundle/tests/scorecard/config.yaml
    ↓
Scorecard creates: Kubernetes Pods (one per test or parallel group)
    ↓
Each Pod executes: Test container with bundle mounted at /bundle
    ↓
Test produces: TestResult (JSON output)
    ↓
Scorecard aggregates: TestStatus (all results)
    ↓
Scorecard outputs: Text/JSON/XML to stdout
    ↓
Makefile checks: Exit code (0 = pass, 1 = fail)
```

### 3. Validation Integration Flow

```
make bundle
    ↓
make bundle-validate (static validation - no cluster)
    ↓ (if pass)
make scorecard-test (dynamic validation - requires cluster)
    ↓ (if pass)
make catalog
    ↓ (if needed)
make validate-all (comprehensive validation)
```

---

## State Transitions

### Test Execution State Machine

```
[Created] → [Pending Pod Creation]
    ↓
[Pod Running] → [Test Executing]
    ↓
    ├─→ [Test Completed: Pass] → [State: pass]
    ├─→ [Test Completed: Fail] → [State: fail]
    └─→ [Test Error] → [State: error]
    ↓
[Pod Cleanup] → [Result Reported]
```

### Configuration Lifecycle

```
[Template Created] → config/scorecard/config.yaml
    ↓ (make bundle)
[Generated] → bundle/tests/scorecard/config.yaml
    ↓ (scorecard command)
[Loaded] → In-memory Configuration object
    ↓ (test execution)
[Consumed] → Test Pods created
    ↓ (after completion)
[Archived] → Results in logs/CI artifacts
```

---

## Validation Rules Summary

### Configuration File Validation

| Rule | Description | Enforcement |
|------|-------------|-------------|
| Valid YAML | Must parse as valid YAML | scorecard command |
| Schema compliance | Must match v1alpha3 schema | scorecard command |
| Required fields | apiVersion, kind, stages must exist | scorecard command |
| Image accessibility | Test images must be pullable | Kubernetes (at runtime) |
| Label format | Labels must follow RFC 1123 | scorecard command |
| Unique test names | No duplicate test identifiers | Best practice (not enforced) |

### Test Result Validation

| Rule | Description | Enforcement |
|------|-------------|-------------|
| State validity | Must be pass/fail/error | scorecard API |
| Name matching | Must match configured test | scorecard command |
| Error presence | Errors required if state is fail/error | Best practice |
| Timestamp validity | Must be valid ISO 8601 | scorecard API |

### Bundle Structure Validation

| Rule | Description | Enforcement |
|------|-------------|-------------|
| Config location | tests/scorecard/config.yaml must exist | scorecard command |
| Annotation presence | Metadata must include test annotations | OLM/scorecard |
| Manifest validity | CSV and CRDs must be valid | Test execution |
| Directory structure | Standard bundle layout | scorecard command |

---

## Example Instances

### Example: Basic Scorecard Configuration

```yaml
apiVersion: scorecard.operatorframework.io/v1alpha3
kind: Configuration
metadata:
  name: config
stages:
- parallel: true
  tests:
  - image: quay.io/operator-framework/scorecard-test:v1.41.0
    entrypoint:
    - scorecard-test
    - basic-check-spec
    labels:
      suite: basic
      test: basic-check-spec-test
    storage:
      spec:
        mountPath: {}
  - image: quay.io/operator-framework/scorecard-test:v1.41.0
    entrypoint:
    - scorecard-test
    - olm-bundle-validation
    labels:
      suite: olm
      test: olm-bundle-validation-test
    storage:
      spec:
        mountPath: {}
storage:
  spec:
    mountPath: {}
```

### Example: Test Result (Pass)

```json
{
  "name": "basic-check-spec-test",
  "state": "pass",
  "log": "time=\"2025-10-21T12:34:56Z\" level=info msg=\"All CRs have spec blocks\"",
  "creationTimestamp": "2025-10-21T12:34:56Z"
}
```

### Example: Test Result (Fail)

```json
{
  "name": "olm-spec-descriptors-test",
  "state": "fail",
  "log": "time=\"2025-10-21T12:35:02Z\" level=error msg=\"Missing spec descriptors\"",
  "errors": [
    "CRD mcpregistries.toolhive.stacklok.dev missing descriptor for spec.url",
    "CRD mcpservers.toolhive.stacklok.dev missing descriptor for spec.image"
  ],
  "suggestions": [
    "Add spec descriptors to CSV for all CRD spec fields",
    "See https://olm.operatorframework.io/docs/advanced-tasks/adding-descriptors/"
  ],
  "creationTimestamp": "2025-10-21T12:35:02Z"
}
```

---

## Notes

- **No persistent storage**: Test results are ephemeral (logged to stdout)
- **No database**: All configuration is file-based YAML
- **Stateless execution**: Each scorecard run is independent
- **Kubernetes dependency**: Test execution requires cluster state (Pods, namespaces)
- **Configuration versioning**: Config files are version-controlled; generated bundles are not

This data model focuses on configuration and validation artifacts rather than traditional application data, reflecting scorecard's nature as a testing tool rather than a data-processing application.
