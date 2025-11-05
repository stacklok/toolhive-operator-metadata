# Feature Specification: Fix OperatorHub Availability

**Feature Branch**: `007-fix-operatorhub-availability`
**Created**: 2025-10-15
**Status**: Draft
**Input**: User description: "Fix OperatorHub availability. While all the created tests pass there remains a problem. The updated File Based Catalog now starts successfully and correctly makes available the data as defined within this project. However in the OpenShift OperatorHub web user interface under the 'Source' section where the 'Community' catalog is listed with its correct number of provided operators in parenthesis the entry from this project is listed without a name and the number of operators that the unnamed entry provides, as listed in parentheses, is 0. Thus we see that adding the toolhive file based catalog to openshift using the catalogsource from the examples directory results in a successful deployment of the file based catalog via that catalogsource instance, but the data contained therein is insufficient to populate the OpenShift OperatorHub web user interface. As well the examples in this project utilize the ghcr.io/stacklok/toolhive/* default container image names and locations. As this project is still undergoing development and not yet in production we should change the defaults in the examplees to use the correct quay.io/roddiekieley equivalent locations for the built container images. For the catalog image referenced in the catalogsource example: quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17 As well the default sourceNamespace for the subscrption should not be olm but rather openshift-marketplace."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - OperatorHub Displays Catalog with Operator Count (Priority: P1)

As a cluster administrator deploying the ToolHive catalog to OpenShift, I need the catalog to appear properly in the OperatorHub web UI with a name and correct operator count, so that I can verify the catalog is working and discover available operators.

**Why this priority**: This is the core issue - the catalog is deployed but invisible/unusable in the OperatorHub UI. Without proper display, users cannot discover or install the operator through the standard OpenShift interface.

**Independent Test**: Deploy the CatalogSource to an OpenShift cluster and verify the OperatorHub UI shows "ToolHive Operator Catalog" with "1 operator" in the Sources section. Can be tested by accessing OperatorHub → Sources and confirming the catalog entry displays correctly.

**Acceptance Scenarios**:

1. **Given** an OpenShift cluster with OperatorHub enabled, **When** administrator deploys the CatalogSource from examples directory, **Then** the OperatorHub web UI Sources section displays the catalog with name "ToolHive Operator Catalog"
2. **Given** the CatalogSource is deployed and running, **When** administrator views the Sources section in OperatorHub UI, **Then** the catalog entry shows "(1)" to indicate one operator is available
3. **Given** the catalog appears in OperatorHub, **When** administrator clicks on the catalog entry, **Then** the ToolHive Operator is listed and can be selected for installation
4. **Given** the catalog metadata is served correctly, **When** OpenShift queries the catalog via gRPC, **Then** the package information including name, description, and icon is returned successfully

---

### User Story 2 - Examples Use Development Registry Locations (Priority: P2)

As a developer working on the ToolHive operator, I need the example files to reference the development container registry (quay.io/roddiekieley) instead of production registry (ghcr.io/stacklok), so that I can test changes using images built from this repository without manually editing configuration files.

**Why this priority**: Supporting development workflow by ensuring examples match actual build artifacts. This is lower priority than fixing the OperatorHub display, but important for maintainability and preventing confusion.

**Independent Test**: Review all example files and verify they reference quay.io/roddiekieley registry. Build and deploy using examples without modifications to confirm they work with development images.

**Acceptance Scenarios**:

1. **Given** the CatalogSource example file, **When** developer reviews the image field, **Then** it specifies `quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17`
2. **Given** the catalog.yaml bundle reference, **When** developer reviews the bundle image field, **Then** it specifies `quay.io/roddiekieley/toolhive-operator-bundle:v0.2.17`
3. **Given** developer builds catalog and bundle images using Makefile, **When** images are pushed to registry, **Then** they are pushed to quay.io/roddiekieley registry matching example file references
4. **Given** all example files are updated, **When** developer deploys using unmodified examples, **Then** deployment succeeds using development registry images

---

### User Story 3 - Subscription Uses Correct Source Namespace (Priority: P2)

As a cluster administrator installing the ToolHive operator via Subscription, I need the sourceNamespace to point to "openshift-marketplace" (where the CatalogSource is deployed) instead of "olm", so that the subscription can find and install the operator successfully.

**Why this priority**: Incorrect sourceNamespace causes installation failures. This is a critical configuration error but lower priority than the OperatorHub display issue since it only affects installations via Subscription (not manual CSV installation).

**Independent Test**: Deploy CatalogSource to openshift-marketplace namespace, then apply Subscription with sourceNamespace set to "openshift-marketplace". Verify the operator installs successfully.

**Acceptance Scenarios**:

1. **Given** the Subscription example file, **When** developer reviews the sourceNamespace field, **Then** it specifies "openshift-marketplace" matching the CatalogSource deployment namespace
2. **Given** CatalogSource is deployed in openshift-marketplace, **When** administrator applies the Subscription, **Then** OLM successfully locates the catalog and installs the operator
3. **Given** a fresh OpenShift cluster, **When** administrator follows the deployment examples in order, **Then** installation completes without namespace-related errors

---

### Edge Cases

- What happens when the catalog is deployed to a namespace other than openshift-marketplace? (Subscription must specify matching sourceNamespace)
- How does the system handle catalog image pull failures from quay.io? (Pod status shows ImagePullBackOff, CatalogSource reports error condition)
- What happens if the bundle image reference in catalog.yaml is incorrect or unavailable? (Operator installation fails, but catalog still appears in OperatorHub)
- How does OpenShift handle a catalog with zero packages? (Catalog appears with "(0)" operator count, no operators shown when browsing)
- What happens when catalog metadata is malformed or missing required fields? (CatalogSource pod may start but catalog doesn't appear in OperatorHub, or appears with missing information)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Catalog metadata MUST include all required fields for OpenShift OperatorHub display (package name, displayName, description, icon)
- **FR-002**: Catalog deployment MUST result in OperatorHub UI showing the catalog name "ToolHive Operator Catalog"
- **FR-003**: Catalog deployment MUST result in OperatorHub UI showing operator count as "(1)" for the one available operator
- **FR-004**: CatalogSource example MUST reference catalog image at `quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17`
- **FR-005**: Bundle image reference in catalog.yaml MUST use `quay.io/roddiekieley/toolhive-operator-bundle:v0.2.17`
- **FR-006**: Subscription example MUST specify sourceNamespace as "openshift-marketplace"
- **FR-007**: All example files MUST be consistent with development registry locations (quay.io/roddiekieley)
- **FR-008**: CatalogSource displayName field MUST match the package description displayName for consistency
- **FR-009**: Catalog MUST serve package manifest data successfully via gRPC when queried by OpenShift
- **FR-010**: Example deployment workflow MUST succeed without requiring manual file edits
- **FR-011**: Catalog pod logs MUST show successful serving of catalog data without errors
- **FR-012**: PackageManifest resource MUST be created in openshift-marketplace namespace after CatalogSource deployment

### Key Entities

- **CatalogSource**: Kubernetes custom resource defining the catalog location, display information, and registry server configuration
- **Package Manifest**: OLM-created resource representing available operators from a catalog, includes name, channels, and operator versions
- **Subscription**: Kubernetes custom resource that references a catalog and installs an operator from it
- **FBC Schema Files**: YAML files (catalog.yaml) defining packages, channels, and bundles using OLM v1 schemas

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: OperatorHub web UI displays catalog with name "ToolHive Operator Catalog" within 30 seconds of CatalogSource deployment
- **SC-002**: OperatorHub web UI shows operator count "(1)" for the catalog in the Sources section
- **SC-003**: ToolHive Operator appears in OperatorHub search results when catalog is deployed
- **SC-004**: Catalog deployment succeeds using unmodified example files from the repository
- **SC-005**: Subscription-based installation completes successfully without namespace errors
- **SC-006**: 100% of example files reference quay.io/roddiekieley registry (0 references to ghcr.io/stacklok in examples)
- **SC-007**: PackageManifest for toolhive-operator is created and shows READY status within 1 minute of catalog deployment

## Constraints *(optional)*

### Technical Constraints

- Catalog image must be built using the existing Containerfile.catalog multi-stage build
- Catalog metadata schema must conform to OLM v1 File-Based Catalog format
- Changes must not break compatibility with Kubernetes (only OpenShift-specific features should be OpenShift-only)
- Registry-server must continue to serve catalog data via gRPC protocol on port 50051

### Operational Constraints

- Development images must be pushable to quay.io/roddiekieley registry
- OpenShift marketplace namespace is the standard location for community catalogs
- Catalog pod must run with restricted security context (OpenShift default)

## Assumptions *(optional)*

### Technical Assumptions

- The catalog image builds successfully and contains all required catalog metadata files
- The catalog.yaml file structure is correct and validated by opm validate
- OpenShift OperatorHub is enabled and functioning in the target cluster
- The quay.io/roddiekieley registry is accessible and images can be pulled from it
- The existing catalog metadata (package name, description, icon) is correct and should be preserved

### User Assumptions

- Users deploying the catalog have cluster-admin or equivalent privileges
- Users are familiar with basic OpenShift OperatorHub navigation
- Users are deploying to OpenShift 4.x with OLM v1 support

## Dependencies *(optional)*

### Internal Dependencies

- Spec 006 (Executable Catalog Image) must be complete - the multi-stage Containerfile with registry-server
- Catalog metadata files (catalog.yaml) must exist and be valid
- Makefile targets for building and pushing catalog images must be functional

### External Dependencies

- OpenShift cluster with OperatorHub enabled
- Access to quay.io/roddiekieley registry for pushing/pulling images
- OLM v1 support in target OpenShift version
- operator-framework opm tooling for catalog validation

## Related Specifications

- **Spec 006 - Executable Catalog Image**: Provides the foundation (Containerfile.catalog with registry-server)
- **Spec 001 - Build OLMv1 File-Based Catalog**: Original catalog.yaml creation
- **Spec 005 - Custom Container Image Naming**: Established pattern for image customization via Makefile variables
