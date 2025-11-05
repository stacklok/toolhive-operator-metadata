# Feature Specification: OLMv0 Bundle Container Image Build System

**Feature Branch**: `002-build-an-olmv0`
**Created**: 2025-10-09
**Status**: Draft
**Input**: User description: "Build an OLMv0 bundle container image for the toolhive-operator. The OLMv0 in this case refers to the Operator Lifecycle Manager v0. This project currently utilizes OLMv0 bundle data as a part of a system to build a File Based Catalog container image. For any missing required data and build files that don't already exists to build a OLMv0 bundle container image, add the required data and files as per the documentation at https://olm.operatorframework.io/docs. The bundle metadata should be buildable into a container image using the opm tool so that it can be deployed to an older kubernetes or OpenShift cluster that utilizes OLMv0. This bundle MUST validate successfully using the operator-sdk tool as per https://olm.operatorframework.io/docs/best-practices/common. NOTE: The project ALSO requires the ability to build the current OLMv1 File Based Catalog as it does now. DO NOT remove this functionality."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Bundle Container Image Build (Priority: P1)

Platform engineers need to build a container image containing the OLMv0 bundle metadata for the ToolHive Operator so they can deploy the operator to legacy Kubernetes or OpenShift clusters (v4.10-v4.12) that do not support OLMv1 File-Based Catalogs.

**Why this priority**: This is the core deliverable. Without a buildable bundle container image, operators cannot be distributed to OLMv0 clusters, blocking deployment to legacy infrastructure.

**Independent Test**: Can be fully tested by running a build command (e.g., `podman build` or `make bundle-build`) and validating the resulting container image contains the correct directory structure and annotations.

**Acceptance Scenarios**:

1. **Given** the bundle directory contains valid CSV, CRD manifests, and metadata files, **When** a build command is executed, **Then** a container image is created with bundle metadata at `/manifests/` and `/metadata/` paths
2. **Given** a built bundle container image, **When** inspected with `podman inspect`, **Then** the image contains required OLM labels including bundle channels, package name, and mediatype
3. **Given** a built bundle container image, **When** the operator-sdk bundle validation command runs against it, **Then** validation passes with no errors

---

### User Story 2 - Bundle Validation (Priority: P2)

Platform engineers need to validate their bundle metadata against OLM best practices before building and deploying, ensuring the bundle will be accepted by OLMv0 cluster catalogs.

**Why this priority**: Validation prevents deployment failures. It's essential but can be performed manually if automation isn't ready, making it slightly lower priority than the build capability itself.

**Independent Test**: Can be fully tested by running validation commands against the bundle directory and verifying all checks pass according to OLM specifications.

**Acceptance Scenarios**:

1. **Given** bundle manifests exist in the bundle directory, **When** operator-sdk bundle validate runs, **Then** the tool reports success with no warnings or errors
2. **Given** bundle metadata annotations.yaml exists, **When** checked against OLM requirements, **Then** all required annotations are present (mediatype, manifests path, metadata path, package name, channels)
3. **Given** the ClusterServiceVersion (CSV) manifest, **When** validated, **Then** it declares correct CRD ownership, RBAC permissions, and container images

---

### User Story 3 - Automated Build Integration (Priority: P3)

Developers and CI/CD systems need automated Make targets or scripts to build and validate the OLMv0 bundle container image as part of the release workflow, similar to the existing OLMv1 catalog build process.

**Why this priority**: Automation improves developer experience and reduces errors, but manual builds can serve as a fallback while automation is developed.

**Independent Test**: Can be fully tested by running `make bundle-build` (or similar target) and verifying the complete workflow from source to validated container image succeeds.

**Acceptance Scenarios**:

1. **Given** a Makefile with bundle build targets, **When** `make bundle-build` is executed, **Then** the bundle container image is built and tagged with the correct version
2. **Given** the bundle build succeeds, **When** validation targets run automatically, **Then** the build fails if validation does not pass
3. **Given** existing OLMv1 catalog build targets, **When** they are executed, **Then** they continue to function without interference from OLMv0 bundle build additions

---

### User Story 4 - Dual Build System Coexistence (Priority: P1)

The project must maintain both OLMv0 bundle builds and OLMv1 File-Based Catalog builds simultaneously, allowing operators to target both legacy (OLMv0) and modern (OLMv1) cluster versions from the same repository.

**Why this priority**: This is a critical constraint. Breaking the existing OLMv1 functionality would prevent upgrades and modern cluster deployments.

**Independent Test**: Can be fully tested by running both OLMv0 bundle builds and OLMv1 catalog builds in sequence, verifying both produce valid outputs without conflicts.

**Acceptance Scenarios**:

1. **Given** the repository contains both bundle and catalog directories, **When** OLMv1 catalog build runs, **Then** it produces a valid File-Based Catalog container image identical to previous builds
2. **Given** the repository contains both build systems, **When** OLMv0 bundle build runs, **Then** it produces a valid bundle container image without modifying catalog artifacts
3. **Given** both container images are built, **When** deployed to their respective cluster types, **Then** both successfully install the ToolHive Operator with identical functionality

---

### Edge Cases

- What happens when the CSV references container images that don't exist or aren't accessible?
- How does the system handle bundle builds when CRD manifests are missing or incomplete?
- What occurs if bundle metadata annotations are malformed or missing required fields?
- How does validation respond when the operator-sdk tool is not installed or is an incompatible version?
- What happens if both OLMv0 and OLMv1 builds are triggered simultaneously in CI/CD?
- How does the system handle version mismatches between bundle metadata annotations and CSV spec.version?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a Containerfile (or Dockerfile) to build an OLMv0 bundle container image from the bundle/ directory
- **FR-002**: System MUST include bundle manifests (CSV and CRDs) in the container image at the `/manifests/` path
- **FR-003**: System MUST include bundle metadata (annotations.yaml) in the container image at the `/metadata/` path
- **FR-004**: Bundle container image MUST include OLM labels for bundle mediatype, package name, channels, and default channel
- **FR-005**: System MUST provide validation capability using operator-sdk to verify bundle compliance with OLM best practices
- **FR-006**: Bundle metadata annotations.yaml MUST declare all required OLM annotations per the OLMv0 specification
- **FR-007**: CSV manifest MUST declare ownership of MCPRegistry and MCPServer CRDs
- **FR-008**: CSV manifest MUST specify all required RBAC permissions for the operator
- **FR-009**: CSV manifest MUST reference correct container images for the operator and proxy runner
- **FR-010**: System MUST maintain existing OLMv1 File-Based Catalog build functionality without modification
- **FR-011**: Build system MUST allow both OLMv0 bundle and OLMv1 catalog images to be built from the same repository
- **FR-012**: Makefile or build scripts MUST provide targets for building, validating, and tagging bundle container images
- **FR-013**: Bundle image build MUST be compatible with both podman and docker container build tools
- **FR-014**: System MUST support versioning of bundle images (e.g., v0.2.17 and latest tags)
- **FR-015**: Bundle validation MUST fail the build if operator-sdk detects errors or critical warnings

### Key Entities

- **OLMv0 Bundle Container Image**: A container image containing operator manifests (CSV, CRDs) and metadata (annotations.yaml) at standardized paths, compliant with OLM Bundle format specification
- **Bundle Manifests Directory**: Contains ClusterServiceVersion (CSV) YAML and CustomResourceDefinition (CRD) YAML files that define the operator's capabilities and API schemas
- **Bundle Metadata**: Contains annotations.yaml defining OLM-specific metadata (package name, channels, mediatype, supported platforms)
- **Containerfile/Dockerfile**: Build instructions defining how bundle directory contents are packaged into the container image with required labels
- **OLMv1 File-Based Catalog**: Existing catalog system using FBC schema (olm.package, olm.channel, olm.bundle) that must continue functioning alongside OLMv0 bundle builds

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Platform engineers can build a valid OLMv0 bundle container image using a single command (e.g., `make bundle-build` or `podman build`)
- **SC-002**: Bundle validation using operator-sdk completes with zero errors when run against the bundle directory or built image
- **SC-003**: Built bundle container image can be pushed to a container registry and successfully referenced in an OLMv0 CatalogSource on clusters running Kubernetes 1.20+ or OpenShift 4.10-4.12
- **SC-004**: OLMv1 File-Based Catalog builds continue to succeed and produce identical outputs to pre-implementation builds (verified by image layer comparison or file checksums)
- **SC-005**: CI/CD pipelines can build both OLMv0 bundle and OLMv1 catalog images in sequence without conflicts or errors
- **SC-006**: Documentation or Makefile help output clearly distinguishes between OLMv0 bundle build targets and OLMv1 catalog build targets
- **SC-007**: Built bundle image size remains under 50MB (typical for metadata-only images)
- **SC-008**: Bundle builds complete in under 2 minutes on standard CI/CD infrastructure

## Assumptions

- The existing bundle/ directory contains all necessary OLMv0 manifests (CSV, CRDs) and metadata (annotations.yaml)
- The operator-sdk tool is available in the development environment or CI/CD pipeline for validation
- Container build tools (podman or docker) are available in the build environment
- The bundle will be built from the existing bundle/ directory structure without requiring reorganization
- OLM bundle images follow the standard registry+v1 mediatype format
- Target clusters support standard OLMv0 bundle format (OpenShift 4.10-4.19, upstream Kubernetes with OLM installed)
- Version numbering will align with existing versioning scheme (currently v0.2.17)
- The bundle Containerfile will use a minimal base image (e.g., scratch or ubi8-minimal) for security and size optimization
- Bundle image will be published to the same registry as the catalog image (ghcr.io/stacklok/toolhive/)