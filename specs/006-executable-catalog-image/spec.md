# Feature Specification: Executable Catalog Image

**Feature Branch**: `006-executable-catalog-image`
**Created**: 2025-10-15
**Status**: Draft
**Input**: User description: "Executable catalog image. The File Based Catalog container image that is generated at the moment is metadata only. To make this execute successfully the Containerfile.catalog needs to be updated to make it properly executable once deployed into the kubernetes or OpenShift cluster. The labels used at the moment are OK and can continue to be used. Likewise the config metadata is also ok and should be used as is due to the fact that the OLMv0 bundle and index container images have been used in a live OpenShift cluster to deploy the ToolHive operator successfully. For this feature we need to make sure that the Containerfile.catalog file builds a container image that includes the required registry-server from the operator-framework opm tooling. A working example for a different operator can be found at https://github.com/arkmq-org/activemq-artemis-operator/blob/main/catalog.Dockerfile . Use the structure of the catalog.Dockerfile to update this projects Containerfile.catalog container image build file so that it builds an image that will successfully run the registry-server from within the catalog container image when deployed on kubernetes or OpenShift."

## User Scenarios & Testing

### User Story 1 - Deploy Catalog as Running Service (Priority: P1)

As a cluster operator, I want to deploy the ToolHive operator catalog image as a running pod in my Kubernetes/OpenShift cluster, so that OLM can dynamically discover and serve operator metadata through the catalog's registry server.

**Why this priority**: This is the core requirement that enables OLMv1 File-Based Catalogs to function as running services. Without an executable catalog image, the catalog cannot be deployed and OLM cannot access the operator metadata at runtime. This is the foundational capability that all other scenarios depend on.

**Independent Test**: Can be fully tested by deploying the catalog image to a Kubernetes/OpenShift cluster via a CatalogSource resource and verifying that the pod starts successfully, the registry-server process is running, and OLM can query the catalog for operator metadata.

**Acceptance Scenarios**:

1. **Given** a catalog image built with the updated Containerfile.catalog, **When** the image is deployed to a Kubernetes cluster via CatalogSource, **Then** the pod starts successfully and enters Running state
2. **Given** a running catalog pod, **When** OLM queries the catalog for package metadata, **Then** the registry-server responds with the correct operator metadata from the catalog files
3. **Given** a catalog pod deployed in OpenShift, **When** checking pod logs, **Then** the registry-server process logs indicate it is serving catalog content from /configs directory

---

### User Story 2 - Validate Catalog Image Before Deployment (Priority: P2)

As a developer building operator releases, I want to validate that the catalog image contains a functional registry-server before pushing to production registries, so that I can catch configuration issues early in the development workflow.

**Why this priority**: While not blocking basic functionality, pre-deployment validation prevents deployment failures and reduces troubleshooting time. This improves developer productivity and release confidence but can be worked around by testing in live clusters.

**Independent Test**: Can be fully tested by building the catalog image locally and running validation commands (e.g., container inspection, test runs) to verify the registry-server binary is present and the entrypoint is configured correctly, without requiring cluster deployment.

**Acceptance Scenarios**:

1. **Given** a freshly built catalog image, **When** inspecting the image metadata, **Then** the image shows the correct entrypoint configured to run the registry-server
2. **Given** a built catalog image, **When** running the container locally with port mapping, **Then** the registry-server starts and serves catalog content on the expected port
3. **Given** a catalog build process, **When** validation is run as part of the build workflow, **Then** any missing dependencies or configuration errors are detected before the image is tagged

---

### User Story 3 - Maintain Backward Compatibility with Existing Metadata (Priority: P1)

As an operator maintainer, I want the executable catalog image to preserve all existing labels and catalog metadata structure, so that the catalog continues to work with OLM tooling and doesn't break existing deployments.

**Why this priority**: Maintaining compatibility with proven catalog metadata is critical because the existing OLMv0 bundle and index have been successfully deployed in production OpenShift clusters. Breaking this compatibility could cause deployment failures for users upgrading to the new catalog format.

**Independent Test**: Can be fully tested by comparing the metadata labels and catalog.yaml structure in the new executable image against the existing metadata-only image, and verifying that all OLM-required labels remain unchanged.

**Acceptance Scenarios**:

1. **Given** an existing catalog with specific OLM labels, **When** the catalog is rebuilt with the executable Containerfile, **Then** all original labels (operators.operatorframework.io.index.configs.v1=/configs, etc.) remain present and unchanged
2. **Given** catalog metadata files (catalog.yaml with olm.package, olm.channel, olm.bundle schemas), **When** the catalog image is built, **Then** the metadata is copied to /configs directory in the same structure as before
3. **Given** a catalog image deployed in OpenShift, **When** OLM reads the catalog, **Then** the operator package, channels, and bundle references are discovered correctly as they were with the OLMv0 index

---

### User Story 4 - Use Pre-cached Catalog Data for Fast Startup (Priority: P3)

As a cluster operator, I want the catalog image to include pre-cached catalog data, so that the registry-server starts quickly without needing to rebuild the cache on every pod restart.

**Why this priority**: This is an optimization that improves startup time and reduces resource usage but is not essential for basic functionality. The registry-server can build the cache at runtime if needed, though with a performance penalty.

**Independent Test**: Can be fully tested by building the catalog image with cache pre-population enabled, then starting the container and measuring startup time compared to an image without pre-cached data.

**Acceptance Scenarios**:

1. **Given** a catalog build process that pre-populates the cache, **When** the catalog pod starts, **Then** the registry-server uses the pre-cached data and starts serving requests in under 5 seconds
2. **Given** a catalog image with pre-cached data, **When** inspecting the image layers, **Then** the /tmp/cache directory contains pre-generated cache files from the build process

---

### Edge Cases

- What happens when the registry-server binary is missing or corrupted in the base image?
- How does the catalog pod behave if the /configs directory is empty or contains invalid YAML?
- What happens if the entrypoint is misconfigured and the registry-server fails to start?
- How does OLM handle catalog pods that are in CrashLoopBackOff state?
- What happens if the cache directory permissions prevent the registry-server from reading pre-cached data?
- How does the system behave if the catalog image is deployed to a cluster without OLM installed?

## Requirements

### Functional Requirements

- **FR-001**: The catalog container image MUST include the registry-server binary from the operator-framework opm tooling
- **FR-002**: The catalog container image MUST be configured with an entrypoint that executes the registry-server with appropriate arguments
- **FR-003**: The catalog container image MUST serve catalog metadata from the /configs directory when the registry-server is running
- **FR-004**: The catalog build process MUST preserve all existing OLM metadata labels (specifically operators.operatorframework.io.index.configs.v1=/configs)
- **FR-005**: The catalog build process MUST maintain the existing catalog.yaml file structure and location in /configs directory
- **FR-006**: The catalog container image MUST use a base image that provides the registry-server binary (e.g., quay.io/operator-framework/opm:latest)
- **FR-007**: The catalog build process MUST copy catalog metadata files to /configs directory in the container image
- **FR-008**: The catalog container image MUST be deployable in both Kubernetes and OpenShift clusters
- **FR-009**: The registry-server MUST be configured to serve catalog content on a network port accessible to OLM components
- **FR-010**: The catalog build process MUST support pre-caching catalog data during image build to optimize startup performance
- **FR-011**: The catalog container image MUST include health probe endpoints compatible with Kubernetes liveness/readiness checks
- **FR-012**: The Containerfile.catalog build instructions MUST follow the multi-stage build pattern demonstrated in the reference implementation (https://github.com/arkmq-org/activemq-artemis-operator/blob/main/catalog.Dockerfile)

### Key Entities

- **Catalog Container Image**: An OCI container image that packages FBC metadata files, the registry-server binary, and runtime configuration needed to serve operator catalog content in Kubernetes/OpenShift clusters
- **Registry Server**: The executable component from opm tooling that serves catalog metadata via a network API that OLM queries to discover operators, channels, and bundles
- **Catalog Metadata**: YAML files following the FBC schema (olm.package, olm.channel, olm.bundle) that describe the operator's available versions and installation channels
- **CatalogSource**: A Kubernetes custom resource that references the catalog container image and instructs OLM where to find operator metadata
- **Catalog Cache**: Pre-generated index data stored in /tmp/cache that accelerates registry-server startup by avoiding runtime parsing of catalog YAML files

## Success Criteria

### Measurable Outcomes

- **SC-001**: Cluster operators can successfully deploy the catalog image to Kubernetes/OpenShift clusters and the pod enters Running state within 10 seconds of image pull completion
- **SC-002**: The registry-server in the catalog pod responds to OLM metadata queries within 500ms of receiving the request
- **SC-003**: The catalog image build process completes successfully without errors when running `make catalog-build` on systems with the container build tool installed
- **SC-004**: 100% of existing OLM metadata labels and catalog.yaml schemas remain unchanged when comparing the executable catalog image to the previous metadata-only image
- **SC-005**: Developers can validate catalog image functionality locally by running the container and accessing the registry-server on localhost before pushing to remote registries

## Constraints

- The solution must not modify the existing catalog.yaml metadata structure, as this metadata has been validated in production OpenShift deployments
- The solution must preserve all existing OLM labels that enable catalog discovery
- The solution must use the operator-framework opm tooling and registry-server implementation (no custom registry server implementations)
- The Containerfile.catalog must remain compatible with both podman and docker build tools
- The solution must not introduce dependencies that are unavailable in standard Kubernetes/OpenShift environments

## Assumptions

- The target Kubernetes/OpenShift clusters have OLM installed and configured to discover CatalogSource resources
- The operator-framework opm base image (quay.io/operator-framework/opm:latest) is accessible and provides a stable registry-server implementation
- The existing catalog metadata files in the catalog/toolhive-operator/ directory are valid and complete
- Container build tools (podman or docker) are available in the development environment
- The registry-server serves content via gRPC protocol on a standard port (as demonstrated in the reference implementation)
- The /configs directory path is the standard location expected by both OLM and the registry-server for catalog metadata

## Dependencies

- **External**: operator-framework opm base image (quay.io/operator-framework/opm:latest) must be available and contain the registry-server binary
- **Internal**: Existing catalog metadata files in catalog/toolhive-operator/catalog.yaml must be present and valid
- **Tooling**: Container build tool (podman or docker) must be available for building the catalog image
- **Validation**: opm CLI tool must be available for catalog validation (already required by existing Makefile targets)

## Out of Scope

- Creating or modifying catalog metadata content (catalog.yaml) - only the container image build process is being updated
- Implementing custom registry server logic - the existing opm registry-server implementation will be used as-is
- Modifying CatalogSource deployment manifests - this feature only updates the catalog image itself
- Supporting OLMv0 SQLite-based index images - this feature focuses solely on OLMv1 File-Based Catalogs
- Automated catalog updates or continuous delivery pipelines - this feature provides the executable image foundation only
- Custom caching strategies beyond the standard opm serve --cache-dir approach
