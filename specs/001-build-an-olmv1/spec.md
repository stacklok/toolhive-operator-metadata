# Feature Specification: OLMv1 File-Based Catalog Bundle

**Feature Branch**: `001-build-an-olmv1`
**Created**: 2025-10-07
**Status**: Draft
**Input**: User description: "Build an OLMv1 bundle for the toolhive-operator. The OLMv1 in this case refers to the Operator Lifecycle Manager v1. Add the required data and files for manifests to add the ability to build a File Based Catalog (FBC) bundle for the Operator Lifecycle Manager v1 as per the documentation at https://olm.operatorframework.io/docs/reference/file-based-catalogs. The bundle metadata should be buildable into a container image using the opm tool. This bundle MUST validate successfully using the operator-sdk tool as per https://olm.operatorframework.io/docs/best-practices/common."

## Glossary

**Key Terms**:

- **FBC (File-Based Catalog)**: OLMv1's declarative catalog format using YAML/JSON schemas to define operator packages, channels, and bundles
- **Bundle**: A collection of Kubernetes manifests (CSV, CRDs, RBAC) representing a specific operator version
- **Bundle Image**: Container image containing operator manifests (CSV, CRDs, RBAC) for a specific version - referenced by `olm.bundle` schemas
- **Catalog Image**: Container image containing FBC metadata schemas (olm.package, olm.channel, olm.bundle) - built from the `catalog/` directory
- **CSV (ClusterServiceVersion)**: Kubernetes manifest describing operator metadata, capabilities, RBAC, and deployment specifications
- **Channel**: Release track (e.g., stable, candidate) defining available operator versions and upgrade paths
- **OLM (Operator Lifecycle Manager)**: Kubernetes extension for managing operator installation, updates, and lifecycle
- **opm**: Operator Package Manager - CLI tool for building and validating FBC catalogs
- **operator-sdk**: CLI tool for validating operator bundles and running quality tests

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Bundle Metadata Creation (Priority: P1)

Platform engineers need to create OLMv1 catalog metadata for the ToolHive Operator so it can be discovered and installed through Operator Lifecycle Manager v1 in Kubernetes/OpenShift clusters.

**Why this priority**: Without the basic catalog metadata files, the operator cannot be registered or discovered in OLMv1 systems. This is the foundation for all other functionality.

**Independent Test**: Can be fully tested by creating the catalog metadata files, validating them with `opm validate`, and verifying they contain all required schemas (olm.package, olm.channel, olm.bundle) and delivers a valid FBC structure.

**Acceptance Scenarios**:

1. **Given** the repository contains existing Kustomize manifests in config/, **When** a platform engineer adds FBC metadata files, **Then** the catalog directory structure includes separate subdirectories for package metadata with valid olm.package, olm.channel, and olm.bundle schemas
2. **Given** FBC metadata files exist, **When** running `opm validate` on the catalog directory, **Then** validation passes without errors
3. **Given** the catalog metadata is complete, **When** inspecting the olm.bundle schema, **Then** it references the correct container image location and includes all required properties (packageName, version)

---

### User Story 2 - Container Image Build (Priority: P2)

Platform engineers need to build the FBC metadata into a container image using the opm tool so it can be deployed to container registries and consumed by OLMv1 clusters.

**Why this priority**: After creating metadata files (P1), the next essential step is packaging them into a distributable container image format required by OLMv1.

**Independent Test**: Can be fully tested by running `opm` build commands on the catalog metadata, producing a container image, and verifying the image contains the expected catalog layers and can be pushed to a registry.

**Acceptance Scenarios**:

1. **Given** valid FBC metadata files exist, **When** a platform engineer runs the opm build command, **Then** a container image is created containing the catalog metadata
2. **Given** a built catalog container image, **When** the image is inspected, **Then** it contains the catalog directory structure with all metadata files intact
3. **Given** a built catalog image, **When** pushing to a container registry, **Then** the push succeeds and the image is accessible for OLMv1 consumption

---

### User Story 3 - Operator SDK Validation (Priority: P3)

Platform engineers need to validate the bundle using operator-sdk to ensure it meets Operator Framework best practices and quality standards before publishing.

**Why this priority**: While validation is critical for production readiness, it's performed after the bundle is created and built. It ensures quality but doesn't block initial creation.

**Independent Test**: Can be fully tested by running `operator-sdk bundle validate` on the bundle directory and verifying all validators pass, including the operatorframework suite.

**Acceptance Scenarios**:

1. **Given** a complete FBC bundle with metadata and manifests, **When** running `operator-sdk bundle validate`, **Then** all required validators pass without errors
2. **Given** the bundle specifies a minimum Kubernetes version, **When** validating with specific k8s-version parameters, **Then** compatibility checks pass for supported versions
3. **Given** validation passes, **When** running operator-sdk scorecard tests, **Then** the bundle meets Operator Framework quality standards

---

### User Story 4 - Multi-Channel Support (Priority: P4)

Platform engineers need to define multiple release channels (e.g., stable, candidate, fast) in the catalog metadata so users can choose their desired update cadence and stability level.

**Why this priority**: Multi-channel support is an advanced feature that enhances flexibility but is not required for initial OLMv1 adoption. A single default channel suffices for MVP.

**Independent Test**: Can be fully tested by adding multiple olm.channel schemas to the catalog metadata, validating the structure, and verifying each channel defines appropriate upgrade edges.

**Acceptance Scenarios**:

1. **Given** the catalog metadata exists with one channel, **When** a platform engineer adds additional channel definitions, **Then** each channel has unique entries and upgrade paths
2. **Given** multiple channels are defined, **When** validating with opm, **Then** all channels pass validation and define valid version sequences
3. **Given** channels with different stability levels exist, **When** the catalog is deployed, **Then** users can subscribe to their preferred channel

---

### User Story 5 - Registry-Server Compatibility (Priority: P3)

Platform engineers need to ensure the catalog container image is properly consumable by OpenShift's registry-server to host the catalog content and make it available to cluster users for operator installation.

**Why this priority**: While the catalog image builds successfully, it must be verified to work with OpenShift's internal registry infrastructure. This is critical for production deployment but can be validated after initial catalog creation.

**Independent Test**: Can be fully tested by deploying the catalog image to an OpenShift cluster with registry-server, creating a CatalogSource pointing to the image, and verifying the operator package is discoverable and installable.

**Acceptance Scenarios**:

1. **Given** a built catalog container image, **When** pushed to an OpenShift-accessible registry, **Then** the registry-server can pull and serve the catalog metadata
2. **Given** the catalog image is served by registry-server, **When** a CatalogSource resource references the image, **Then** OLM discovers the toolhive-operator package
3. **Given** the package is discoverable, **When** a platform engineer creates a Subscription, **Then** the operator installs successfully from the catalog
4. **Given** the catalog is hosted by registry-server, **When** querying available operators, **Then** the toolhive-operator appears with correct version and channel information

---

### Edge Cases

- What happens when the bundle image reference is invalid or inaccessible?
- How does the system handle missing required schemas (olm.package, olm.channel, olm.bundle)?
- What happens when semantic versions are malformed or conflict between channels?
- How does validation behave when minimum Kubernetes version is not specified?
- What happens when building the catalog image without required CRD manifests?
- How does the system handle incompatible Kubernetes versions during validation?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repository MUST include a catalog directory structure containing FBC metadata files organized by package
- **FR-002**: The catalog metadata MUST include exactly one olm.package schema per package defining package name, description, default channel, and icon
- **FR-003**: The catalog metadata MUST include at least one olm.channel schema defining channel entries and upgrade edges
- **FR-004**: The catalog metadata MUST include one or more olm.bundle schemas specifying bundle image location and required properties (packageName, version)
- **FR-005**: Bundle versions MUST follow semantic versioning format (major.minor.patch)
- **FR-006**: The bundle MUST specify a minimum Kubernetes version in the ClusterServiceVersion manifest
- **FR-007**: The catalog metadata MUST be buildable into a container image using the opm tool
- **FR-008**: The bundle MUST pass validation when running `operator-sdk bundle validate` with the operatorframework suite
- **FR-009**: The catalog structure MUST support both JSON and YAML file formats for metadata
- **FR-010**: Bundle images referenced in olm.bundle schemas MUST point to valid, accessible container image locations
- **FR-011**: The catalog MUST define unique combinations of schema, package, and name for each entry
- **FR-012**: The package metadata MUST reference the existing CRDs (MCPRegistry, MCPServer) defined in config/crd/
- **FR-013**: The catalog container image MUST be compatible with OpenShift registry-server for hosting and serving catalog content to cluster users

### Key Entities

- **Catalog Package**: Represents the ToolHive Operator as a distributable package containing metadata about available versions, channels, and upgrade paths
- **Channel**: Represents a release track (e.g., stable, candidate) defining which operator versions are available and how upgrades flow between versions
- **Bundle**: Represents a specific installable version of the ToolHive Operator including manifests (CRDs, RBAC, deployment) and metadata
- **Catalog Image**: Container image containing the FBC metadata files, buildable via opm and consumable by OLMv1 clusters

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The catalog metadata validates successfully with zero errors when running `opm validate`
- **SC-002**: The bundle validates successfully with zero errors when running `operator-sdk bundle validate --select-optional suite=operatorframework`
- **SC-003**: Platform engineers can build a catalog container image from the metadata files in under 120 seconds using standard opm commands (measured from `podman build` command start to successful completion)
- **SC-004**: The built catalog image contains all required schemas (olm.package, olm.channel, olm.bundle) and can be deployed to OLMv1 clusters
- **SC-005**: The bundle passes operator-sdk scorecard tests with a passing score
- **SC-006**: The catalog metadata includes version information for at least the current operator version (v0.2.17)
- **SC-007**: The catalog image successfully deploys to OpenShift registry-server and makes the operator package discoverable via CatalogSource

## Assumptions

- The repository already contains valid Kubernetes manifests in config/ directories that can be referenced by the bundle
- Platform engineers have opm and operator-sdk tools installed and available
- The catalog will initially support a single default channel (additional channels are P4)
- Bundle images will be hosted in the existing ghcr.io/stacklok/toolhive registry following current image naming conventions
- The catalog follows OLMv1 FBC format as documented at https://olm.operatorframework.io/docs/reference/file-based-catalogs
- Validation is performed before pushing catalog images to production registries

## Dependencies

- Existing CRD manifests in config/crd/ (MCPRegistry, MCPServer)
- Existing RBAC manifests in config/rbac/
- Existing manager deployment manifests in config/manager/
- ClusterServiceVersion (CSV) manifest defining operator metadata and capabilities
- opm tool (Operator Package Manager) for building catalog images
- operator-sdk tool for bundle validation and scorecard testing

## Constraints

- Must comply with OLMv1 File-Based Catalog specification
- Must pass all operator-sdk validation checks
- Catalog metadata must be version-controlled alongside existing manifests
- Bundle images must be immutable (no updates to existing version tags)
- Must support minimum Kubernetes version specified in operator requirements
- Must maintain compatibility with OpenShift OLM systems
