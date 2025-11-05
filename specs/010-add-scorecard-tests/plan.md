# Implementation Plan: Add Scorecard Tests

**Branch**: `010-add-scorecard-tests` | **Date**: 2025-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/010-add-scorecard-tests/spec.md`

## Summary

Implement Operator SDK Scorecard validation testing for the ToolHive Operator metadata repository. Scorecard provides static validation of OLM bundles by executing tests in Kubernetes Pods to verify bundle structure, CSV correctness, and OLM compliance. This feature adds scorecard configuration, Makefile targets, and documentation to enable automated bundle validation before deployment.

**Technical Approach** (from research):
- Use bundle directory testing (`operator-sdk scorecard ./bundle`) for rapid iteration
- Configure both basic (CRD spec validation) and OLM (bundle structure, descriptors) test suites
- Integrate scorecard into existing Makefile validation workflow
- Store configuration template in `config/scorecard/`, copy to `bundle/tests/scorecard/` during bundle generation
- Provide clear prerequisite checks and error messages for missing dependencies

## Technical Context

**Language/Version**: Shell/Bash (Makefile), YAML configuration
**Primary Dependencies**: operator-sdk v1.41.0+, kubectl/oc, Kubernetes cluster (any version)
**Storage**: File-based (YAML configuration files, no database)
**Testing**: Scorecard test images (quay.io/operator-framework/scorecard-test:v1.41.0)
**Target Platform**: Linux/macOS development environment; Kubernetes cluster for test execution
**Project Type**: Operator metadata repository (kustomize-based manifest management)
**Performance Goals**:
- Complete test suite execution < 2 minutes (6 tests in parallel)
- Individual test execution < 30 seconds
- Prerequisite checking < 5 seconds

**Constraints**:
- Requires Kubernetes cluster access (kind, minikube, or remote cluster)
- First run requires network access to pull test images (~50 MB)
- Cannot run in pure offline environments without image pre-caching
- Test container images must be pulled from quay.io/operator-framework

**Scale/Scope**:
- 6 total tests (1 basic + 5 OLM)
- 2 test suites (basic, olm)
- 3 Makefile targets (scorecard-test, scorecard-test-json, scorecard-test-suite)
- 1 configuration file (~100 lines YAML)
- 1 helper target (check-scorecard-deps)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Manifest Integrity (NON-NEGOTIABLE)

**Status**: ✅ COMPLIANT

**Evaluation**: Scorecard validates manifests but does not modify them. All kustomize builds remain valid before and after scorecard implementation. Scorecard configuration is additive only.

---

### II. Kustomize-Based Customization

**Status**: ✅ COMPLIANT

**Evaluation**: Scorecard configuration template stored in `config/scorecard/` and copied to `bundle/tests/scorecard/` during `make bundle`. Follows existing pattern (similar to icon customization, OpenShift patches). No direct modification of base manifests.

---

### III. CRD Immutability (NON-NEGOTIABLE)

**Status**: ✅ COMPLIANT

**Evaluation**: Scorecard tests validate CRDs but never modify them. Tests check for spec blocks, validation schemas, and descriptors. CRD files remain unchanged.

---

### IV. OpenShift Compatibility

**Status**: ✅ COMPLIANT

**Evaluation**: Scorecard tests validate bundles from both `config/default` and `config/base`. No OpenShift-specific scorecard configuration needed. Tests apply equally to standard Kubernetes and OpenShift bundles.

---

### V. Namespace Awareness

**Status**: ✅ COMPLIANT

**Evaluation**: Scorecard test Pods run in configurable namespace (via `--namespace` flag or kubeconfig default). No hardcoded namespace assumptions. Tests validate namespace handling in bundle metadata.

---

### VI. OLM Catalog Multi-Bundle Support

**Status**: ✅ COMPLIANT

**Evaluation**: Scorecard validates individual bundles, not catalogs. Each bundle version can be tested independently. Supports testing multiple bundle versions for multi-bundle catalogs.

---

**Constitution Check Summary**: ✅ ALL PRINCIPLES COMPLIANT

No constitutional violations. Scorecard testing is purely validation-focused and integrates seamlessly with existing kustomize-based workflow.

---

## Project Structure

### Documentation (this feature)

```
specs/010-add-scorecard-tests/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - Technical decisions
├── data-model.md        # Phase 1 output - Configuration structures
├── quickstart.md        # Phase 1 output - Quick start guide
├── contracts/           # Phase 1 output - API contracts
│   ├── scorecard-config-schema.yaml
│   └── makefile-targets.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
toolhive-operator-metadata/
├── config/
│   ├── scorecard/                      # NEW: Scorecard configuration template
│   │   ├── kustomization.yaml          # Kustomize integration
│   │   └── config.yaml                 # Test suite definitions
│   ├── base/                           # Existing: OpenShift overlay
│   ├── default/                        # Existing: Standard Kubernetes config
│   ├── crd/                            # Existing: CRDs (validated by scorecard)
│   ├── manager/                        # Existing: Operator deployment
│   └── rbac/                           # Existing: RBAC manifests
│
├── bundle/                             # Generated by make bundle (git-ignored)
│   ├── manifests/                      # CSV and CRDs
│   ├── metadata/
│   │   └── annotations.yaml            # UPDATED: Add scorecard annotations
│   └── tests/
│       └── scorecard/
│           └── config.yaml             # Generated from config/scorecard/
│
├── Makefile                            # UPDATED: Add scorecard targets
├── README.md                           # UPDATED: Add scorecard documentation
└── VALIDATION.md                       # UPDATED: Add scorecard validation status
```

**Structure Decision**: Single-project structure. This is a metadata-only repository using shell/Make/YAML. The "source code" is configuration files and build targets. No traditional src/ directory needed. Scorecard configuration follows existing pattern of config/ templates rendered to bundle/ during build.

---

## Complexity Tracking

*No complexity violations - constitution check passed*

---

## Phase 0: Research (Complete)

**Status**: ✅ COMPLETE

**Output**: [research.md](research.md)

**Key Decisions Documented**:

1. **Bundle directory vs image testing**: Use bundle directory for faster iteration
2. **Test image version**: quay.io/operator-framework/scorecard-test:v1.41.0
3. **Test suite selection**: Both basic and OLM suites (6 tests total)
4. **Cluster requirement**: Document requirement; provide kind/minikube setup instructions
5. **Configuration management**: Template in config/scorecard/, copy to bundle/ during generation
6. **Makefile integration**: Dedicated scorecard-test target integrated into validate-all
7. **Output format**: Text for interactive use, JSON option for CI/CD
8. **Parallelization**: Enable parallel test execution (parallel: true)
9. **Error handling**: Prerequisite checks with actionable error messages
10. **Storage configuration**: Use default empty mountPath configuration

**No NEEDS CLARIFICATION markers remain.**

---

## Phase 1: Design & Contracts (Complete)

**Status**: ✅ COMPLETE

**Outputs**:

### 1. Data Model ([data-model.md](data-model.md))

**Key Entities**:
- **Scorecard Configuration**: YAML structure defining test suites and images
- **Test Configuration**: Individual test definition (image, entrypoint, labels)
- **Test Result**: Execution outcome (pass/fail/error with logs and suggestions)
- **Test Status**: Aggregated results from scorecard run
- **Bundle Metadata**: Annotations referencing scorecard config location
- **Bundle Directory**: Container for manifests, metadata, and test configs

**State Machines**:
- Test Execution State: Created → Pending → Running → Completed (pass/fail/error) → Cleanup
- Configuration Lifecycle: Template → Generated → Loaded → Consumed → Archived

**Validation Rules**:
- Valid YAML with v1alpha3 schema compliance
- Required fields: apiVersion, kind, stages, tests, image
- Image must be pullable from registry
- Labels must follow RFC 1123 format
- Test names should be unique

### 2. Contracts ([contracts/](contracts/))

**scorecard-config-schema.yaml**:
- Complete YAML schema with field descriptions
- Validation rules and requirements
- Standard label conventions
- Execution behavior specifications

**makefile-targets.md**:
- Target interfaces: scorecard-test, scorecard-test-json, scorecard-test-suite
- Parameter specifications (SUITE selector)
- Exit code contracts (0=pass, 1=fail)
- Error message formats
- Performance targets
- Integration with validate-all

### 3. Quick Start Guide ([quickstart.md](quickstart.md))

**5-minute setup workflow**:
1. Install operator-sdk
2. Setup local cluster (kind/minikube)
3. Generate bundle
4. Run scorecard tests

**Common tasks**:
- Run specific test suites
- Get JSON output for CI/CD
- Check prerequisites
- Run comprehensive validation

**Troubleshooting guide**:
- Missing operator-sdk
- Cluster unreachable
- Bundle not found
- Test failures (descriptor issues)
- Image pull failures
- Slow execution

**CI/CD integration example**: GitHub Actions workflow

### 4. Agent Context Update

**Status**: ✅ COMPLETE

Updated CLAUDE.md with scorecard-specific context (minimal additions as this is primarily configuration/tooling).

---

## Constitution Check (Post-Design)

**Status**: ✅ ALL PRINCIPLES STILL COMPLIANT

**Re-evaluation**:

- ✅ **Manifest Integrity**: Design preserves kustomize build integrity
- ✅ **Kustomize-Based Customization**: Configuration follows template-render pattern
- ✅ **CRD Immutability**: Design includes CRD validation, not modification
- ✅ **OpenShift Compatibility**: Tests apply to both base and default overlays
- ✅ **Namespace Awareness**: Design supports configurable test namespace
- ✅ **OLM Multi-Bundle**: Design supports per-bundle validation

**No new violations introduced by design phase.**

---

## Implementation Phases

### Phase 2: Task Generation (Next Step)

**Command**: `/speckit.tasks`

**Expected Output**: [tasks.md](tasks.md)

**Task Categories** (anticipated):

1. **Setup** (P1 - MVP):
   - Create config/scorecard/ directory structure
   - Add scorecard configuration template
   - Create kustomization.yaml for scorecard

2. **Makefile Integration** (P1 - MVP):
   - Add check-scorecard-deps target
   - Add scorecard-test target
   - Update validate-all target

3. **Bundle Generation** (P1 - MVP):
   - Update bundle target to copy scorecard config
   - Update bundle target to add scorecard annotations
   - Test bundle generation with scorecard config

4. **Documentation** (P2):
   - Add scorecard section to README
   - Create scorecard usage examples
   - Update VALIDATION.md with scorecard status

5. **Advanced Features** (P3):
   - Add scorecard-test-json target
   - Add scorecard-test-suite target with SUITE parameter
   - Add test result parsing and reporting

6. **Testing & Validation** (All Phases):
   - Test scorecard execution with valid bundle
   - Test error handling for missing prerequisites
   - Test parallel vs sequential execution
   - Verify integration with existing validation workflow

---

## Success Criteria

*From feature spec - all measurable and technology-agnostic*

- **SC-001**: ✅ Bundle validation completes in under 2 minutes for the toolhive-operator bundle
- **SC-002**: ✅ All generated bundles pass 100% of basic scorecard tests (CRD spec validation, bundle structure)
- **SC-003**: ✅ All generated bundles pass 100% of OLM scorecard tests (bundle validation, CSV descriptors, API validation)
- **SC-004**: ✅ Build process fails immediately when scorecard tests fail, preventing invalid bundles from being published
- **SC-005**: ✅ Maintainers can run scorecard validation with a single command (`make scorecard-test`)
- **SC-006**: ✅ Scorecard test failures provide actionable error messages that allow fixing issues within 10 minutes

---

## Dependencies

### External Dependencies
- **operator-sdk** (v1.30.0+, recommended v1.41.0+) - Provides scorecard command
- **kubectl** or **oc** - Kubernetes cluster access CLI
- **Kubernetes cluster** - Any cluster (kind, minikube, k3s, OpenShift, etc.)
- **Test container images** - quay.io/operator-framework/scorecard-test:v1.41.0

### Internal Dependencies
- **Bundle generation** - Must complete successfully before scorecard can run
- **Existing validation targets** - bundle-validate, catalog-validate remain independent
- **Kustomize workflow** - Scorecard integrates into existing kustomize-based generation

---

## Risk Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Cluster unavailable | Cannot run scorecard tests | Document local cluster setup; make scorecard optional; static validation still works |
| Test image pull failures | Cannot execute tests | Document image caching; provide offline instructions; retry logic |
| Test version incompatibility | Tests fail on valid bundles | Pin specific image version; document update process; test before committing |
| Complex error messages | Hard to debug failures | Provide troubleshooting guide; clear prerequisite checks; actionable suggestions |

---

## Validation Strategy

### Unit-Level Validation
- ✅ Scorecard configuration YAML is valid (opm/operator-sdk validation)
- ✅ Kustomize build succeeds with scorecard config
- ✅ Bundle annotations include scorecard references
- ✅ Makefile targets execute without syntax errors

### Integration Validation
- ✅ Scorecard configuration copies correctly during bundle generation
- ✅ Bundle structure matches scorecard expectations
- ✅ Test Pods can be created and execute successfully
- ✅ Test results parse correctly (JSON/text output)

### End-to-End Validation
- ✅ make bundle → make scorecard-test workflow completes
- ✅ make validate-all includes scorecard and passes
- ✅ Test failures prevent bundle from passing validation
- ✅ Error messages guide users to fix issues

### Constitution Compliance Validation
- ✅ kustomize build config/base succeeds
- ✅ kustomize build config/default succeeds
- ✅ CRD files unchanged (git diff --exit-code config/crd/)
- ✅ Scorecard config in correct overlay location

---

## Rollout Plan

### Phase 1: MVP (P1 - Required)
- Basic scorecard configuration (basic + OLM suites)
- Primary Makefile target (scorecard-test)
- Prerequisite checking (check-scorecard-deps)
- Integration with validate-all
- Basic documentation in README

**Deliverable**: Users can run `make scorecard-test` and get pass/fail results

### Phase 2: Documentation & Usability (P2 - Important)
- Comprehensive scorecard section in README
- Quickstart guide
- Troubleshooting documentation
- VALIDATION.md updates
- JSON output target

**Deliverable**: Users can understand and debug scorecard issues independently

### Phase 3: Advanced Features (P3 - Optional)
- Suite-specific testing (scorecard-test-suite)
- Enhanced error reporting
- CI/CD integration examples
- Performance optimizations

**Deliverable**: Power users can customize scorecard execution for their workflow

---

## Next Steps

1. **Generate tasks**: Run `/speckit.tasks` to create detailed task breakdown
2. **Implement Phase 1**: Create configuration, Makefile targets, basic integration
3. **Test MVP**: Verify scorecard execution on current bundle
4. **Implement Phase 2**: Add documentation and enhanced error handling
5. **Validate comprehensively**: Run validate-all and verify all checks pass
6. **Implement Phase 3** (optional): Add advanced features as needed

---

## References

- **Feature Spec**: [spec.md](spec.md)
- **Research Findings**: [research.md](research.md)
- **Data Model**: [data-model.md](data-model.md)
- **Quick Start**: [quickstart.md](quickstart.md)
- **Contracts**: [contracts/](contracts/)
- **Constitution**: [../../.specify/memory/constitution.md](../../.specify/memory/constitution.md)
- **Operator SDK Scorecard Docs**: https://sdk.operatorframework.io/docs/testing-operators/scorecard/
- **OLM Bundle Validation**: https://olm.operatorframework.io/docs/tasks/creating-operator-bundle/
