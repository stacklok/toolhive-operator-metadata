# Feature Specification: Registry Database Container Image (Index Image)

**Feature Branch**: `004-registry-database-container`
**Created**: 2025-10-10
**Status**: Draft
**Input**: User description: "Registry database container image. Specification 001 resulted in an OLMv1 catalog container image for newer versions of OpenShift. Specification 002 resulted in an OLMv0 bundle container image for older versions of OpenShift. Either one or the other but not both at the same time for the same version can be referenced from within an operator registry database container image. This specifications purpose is to build a valid operator registry database container image, or index image. This index image will be served by the operator-registry registry-server container image which contains the registry-serve command that gets executed automatically when a CatalogSource is added to OpenShift. At the moment our CatalogSource example references either the OLMv1 catalog image or the OLMv0 bundle image directly which is incorrect. The CatalogSource example should reference the index image which internally references the OLMv1 catalog image or OLMv0 bundle image. The index image can contain references to multiple versions of a given catalog or bundle images but never the same version with information in the two different formats for OLMv0 and OLMv1. Use the documentation reference for the operator-registry at https://github.com/operator-framework/operator-registry/blob/master/docs/design/opm-tooling.md. Use the opm tool to create a valid index image that references either the OLMv1 catalog or the OLMv0 bundle container image that we already generate. Update the Makefile with targets that generate an index image containing either one or the other but not both the OLMv1 catalog image and OLMv0 bundle image. Also add targets to validate the newly created index image after its creation. Update the CatalogSource example to utilize the index image."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy Operator on Modern OpenShift via Index Image (Priority: P1)

Platform administrators deploying the ToolHive operator on newer OpenShift versions (4.19+) need to create a CatalogSource that references an index image containing the OLMv1 catalog image. The index image serves as the proper distribution mechanism for operator metadata, allowing OpenShift's registry-server to serve the catalog correctly.

**Why this priority**: This is the primary use case for modern OpenShift deployments and represents the correct architectural pattern for operator distribution. Without this, CatalogSources will incorrectly reference catalog images directly.

**Independent Test**: Can be fully tested by building an OLMv1-based index image, creating a CatalogSource pointing to it, and verifying that OpenShift successfully discovers and displays the operator in the OperatorHub.

**Acceptance Scenarios**:

1. **Given** an OLMv1 catalog image already exists from specification 001, **When** the administrator runs the build process for an OLMv1 index image, **Then** a valid index image container is created that internally references the OLMv1 catalog image
2. **Given** a valid OLMv1 index image exists, **When** the administrator creates a CatalogSource using the index image reference, **Then** the operator appears in the OperatorHub and can be installed successfully
3. **Given** an OLMv1 index image, **When** the administrator validates the index image, **Then** the validation confirms the index contains correct OLMv1 catalog references with no errors

---

### User Story 2 - Deploy Operator on Legacy OpenShift via Index Image (Priority: P2)

Platform administrators deploying the ToolHive operator on older OpenShift versions (4.15-4.18) need to create a CatalogSource that references an index image containing the OLMv0 bundle image. The index image provides backward compatibility for older OpenShift installations while maintaining the proper registry architecture.

**Why this priority**: This enables support for legacy OpenShift versions, expanding the operator's deployment reach. While important, it's secondary to modern deployments as the ecosystem moves toward newer versions.

**Independent Test**: Can be fully tested by building an OLMv0-based index image, creating a CatalogSource pointing to it on an OpenShift 4.15-4.18 cluster, and verifying successful operator installation.

**Acceptance Scenarios**:

1. **Given** an OLMv0 bundle image already exists from specification 002, **When** the administrator runs the build process for an OLMv0 index image, **Then** a valid index image container is created that internally references the OLMv0 bundle image
2. **Given** a valid OLMv0 index image exists, **When** the administrator creates a CatalogSource using the index image reference on OpenShift 4.15-4.18, **Then** the operator appears in the OperatorHub and can be installed successfully
3. **Given** an OLMv0 index image, **When** the administrator validates the index image, **Then** the validation confirms the index contains correct OLMv0 bundle references with no errors

---

### User Story 3 - Maintain Separate Index Images for Each Format (Priority: P1)

Build and release engineers need to ensure that index images never mix OLMv0 and OLMv1 formats for the same version, as this would create invalid operator registry databases. The build system must prevent accidental mixing while supporting both formats independently.

**Why this priority**: This is a critical constraint that prevents broken deployments. A mixed-format index image would fail at runtime or cause undefined behavior in OpenShift's operator lifecycle management.

**Independent Test**: Can be fully tested by attempting to build an index image with both OLMv0 and OLMv1 content for the same version and verifying the build system prevents this or produces validation errors.

**Acceptance Scenarios**:

1. **Given** both OLMv1 catalog and OLMv0 bundle images exist for the same operator version, **When** the build process runs, **Then** only one format is included in each index image and separate index images are created for OLMv0 and OLMv1
2. **Given** an index image building process, **When** validation runs on the completed index, **Then** the validation detects and reports any mixed-format content as an error
3. **Given** multiple versions of the operator exist, **When** building index images over time, **Then** each index image consistently uses one format and can reference multiple operator versions all in the same format

---

### User Story 4 - Update CatalogSource Examples for Correct Architecture (Priority: P2)

Documentation users and administrators referencing example CatalogSource manifests need to see the correct pattern of referencing index images instead of direct catalog or bundle image references. This guides proper deployment practices.

**Why this priority**: Essential for user guidance and preventing incorrect deployments, but dependent on P1 stories being completed first.

**Independent Test**: Can be fully tested by reviewing updated CatalogSource example files and verifying they reference index image paths instead of catalog/bundle image paths, then deploying them to confirm functionality.

**Acceptance Scenarios**:

1. **Given** CatalogSource example files exist in the repository, **When** they are updated, **Then** they reference index image container paths instead of direct catalog or bundle image paths
2. **Given** updated CatalogSource examples, **When** an administrator follows the examples, **Then** they successfully deploy the operator without needing to modify the image references
3. **Given** separate examples for OLMv0 and OLMv1 scenarios, **When** administrators choose the appropriate example for their OpenShift version, **Then** each example clearly indicates which OpenShift version range it supports

---

### Edge Cases

- What happens when an administrator tries to create an index image referencing both OLMv0 bundle and OLMv1 catalog images for the same version?
- How does the system handle building an index image when the referenced catalog or bundle image doesn't exist or is unreachable?
- What happens when validation runs on a corrupted or incomplete index image?
- How does the build process behave when multiple versions of operator metadata exist but only some versions have both OLMv0 and OLMv1 formats available?
- What happens when a CatalogSource references an index image that was built with the wrong format for the OpenShift version?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Build system MUST create index images that reference OLMv1 catalog images for modern OpenShift deployments (4.19+)
- **FR-002**: Build system MUST create index images that reference OLMv0 bundle images for legacy OpenShift deployments (4.15-4.18)
- **FR-003**: Build system MUST prevent inclusion of both OLMv0 and OLMv1 content for the same operator version within a single index image
- **FR-004**: Build system MUST provide separate targets for building OLMv1-based and OLMv0-based index images
- **FR-005**: Build system MUST provide validation targets that verify index image correctness after creation
- **FR-006**: Validation process MUST detect mixed-format content (OLMv0 and OLMv1) within an index image and report it as an error
- **FR-007**: Index images MUST be compatible with the operator-registry registry-server container, which serves the registry-serve command used by OpenShift CatalogSources
- **FR-008**: CatalogSource example manifests MUST reference index images instead of direct catalog or bundle images
- **FR-009**: Build system MUST support creating index images that contain multiple versions of operator metadata (all in the same format - either OLMv0 or OLMv1)
- **FR-010**: Index image build process MUST use the opm tool as specified in the operator-registry documentation
- **FR-011**: Each index image build target MUST clearly indicate whether it produces an OLMv0-based or OLMv1-based index
- **FR-012**: Validation targets MUST verify that index images contain valid references to existing catalog or bundle images
- **FR-013**: CatalogSource examples MUST clearly document which OpenShift version ranges they support (4.19+ for OLMv1, 4.15-4.18 for OLMv0)

### Key Entities

- **Index Image**: A container image containing an operator registry database and the opm binary. It references either OLMv1 catalog images or OLMv0 bundle images (but never both formats for the same version). Served by OpenShift's registry-server when referenced in a CatalogSource.

- **OLMv1 Catalog Image**: A container image containing operator metadata in the File-Based Catalog (FBC) format, created by specification 001, used for OpenShift 4.19+ deployments.

- **OLMv0 Bundle Image**: A container image containing operator metadata in the legacy bundle format, created by specification 002, used for OpenShift 4.15-4.18 deployments.

- **CatalogSource**: An OpenShift custom resource that references an index image and triggers the registry-server to serve operator metadata to the OperatorHub.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Administrators can successfully build an OLMv1-based index image and deploy it to OpenShift 4.19+ clusters, with the operator appearing in OperatorHub within 2 minutes of CatalogSource creation

- **SC-002**: Administrators can successfully build an OLMv0-based index image and deploy it to OpenShift 4.15-4.18 clusters, with the operator appearing in OperatorHub within 2 minutes of CatalogSource creation

- **SC-003**: Validation process detects 100% of invalid index images (including mixed-format content) before deployment

- **SC-004**: CatalogSource example files correctly reference index images in 100% of provided examples, eliminating direct catalog/bundle image references

- **SC-005**: Build process prevents or clearly warns against creating index images with mixed OLMv0/OLMv1 content for the same version, with zero mixed-format index images produced in normal usage

- **SC-006**: Index images built using the new process are compatible with OpenShift's operator-registry registry-server without requiring manual configuration or workarounds

## Assumptions

- The opm tool is available in the build environment or can be installed as part of the build process
- Existing OLMv1 catalog images (from spec 001) and OLMv0 bundle images (from spec 002) are accessible and properly tagged
- Container registry credentials are properly configured for pushing index images
- Build environment has network access to pull base images and push resulting index images
- OpenShift version ranges (4.19+ for OLMv1, 4.15-4.18 for OLMv0) are based on current OLM support matrices
- CatalogSource examples currently exist in the repository and need updating (not creating from scratch)
- The build system uses Make as indicated by the requirement to update the Makefile

## Dependencies

- Completion of specification 001 (OLMv1 catalog image generation)
- Completion of specification 002 (OLMv0 bundle image generation)
- Availability of opm tool from operator-framework/operator-registry project
- Access to container registry for storing index images
- Existing Makefile structure for adding new build targets
