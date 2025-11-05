# ToolHive Operator Metadata

Kubernetes/OpenShift manifest metadata and OLM bundle for the [ToolHive Operator](https://github.com/stacklok/toolhive), which manages MCP (Model Context Protocol) servers and registries.

## Overview

This repository contains:
- **Kustomize manifests** for deploying the ToolHive Operator
- **OLMv1 File-Based Catalog (FBC)** for operator distribution via Operator Lifecycle Manager
- **Bundle metadata** following Operator Framework standards

## Quick Start

### Prerequisites

- `kustomize` (v5.0.0+)
- `podman` or `docker`
- `opm` (Operator Package Manager) - for catalog operations
- `yq` (v4+) - for YAML processing
- `imagemagick` - for icon validation (optional, for custom icons)
- Kubernetes 1.24+ or OpenShift 4.12+

**OpenShift Compatibility**: The operator is fully compatible with OpenShift's `restricted-v2` Security Context Constraint (SCC). The manifests in `config/base/` are specifically configured to run under OpenShift's restrictive security policies without requiring custom SCCs or elevated privileges.

### Building Manifests

Build kustomize manifests:

```shell
# Standard Kubernetes deployment
kustomize build config/default

# OpenShift-specific deployment (includes security context patches)
kustomize build config/base
```

**Security Context Configuration**: The OpenShift deployment (`config/base`) applies JSON patches to ensure compliance with the `restricted-v2` SCC:
- Removes hardcoded `runAsUser` to allow dynamic UID assignment
- Adds `seccompProfile: RuntimeDefault` for container sandboxing
- Maintains `runAsNonRoot`, `allowPrivilegeEscalation: false`, and `readOnlyRootFilesystem: true`

See `config/base/openshift_sec_patches.yaml` for details.

### Building OLM Catalog

Build the File-Based Catalog container image:

```shell
# Using Makefile (recommended)
make olm-all

# Or manually
opm validate catalog/
podman build -f Containerfile.catalog -t ghcr.io/stacklok/toolhive/operator-catalog:v0.4.2 .
```

#### Custom Operator Icons

Customize the operator icon displayed in OperatorHub:

```shell
# Use custom icon for both bundle and catalog
make bundle BUNDLE_ICON=/path/to/your-icon.png
make catalog  # Inherits icon from bundle

# Use different icons for bundle and catalog (advanced)
make bundle BUNDLE_ICON=/path/to/bundle-icon.png
make catalog CATALOG_ICON=/path/to/catalog-icon.gif

# Validate icon before building
make validate-icon ICON_FILE=/path/to/your-icon.png
```

**Icon requirements**:
- Maximum dimensions: 80px × 40px
- Aspect ratio: 1:2 (±5%)
- Supported formats: PNG, JPEG, GIF, SVG

See [icons/README.md](icons/README.md) for detailed documentation.

### Installing via OLM

#### Modern OpenShift (4.19+) - Recommended

1. Deploy the CatalogSource:
   ```shell
   kubectl apply -f examples/catalogsource-olmv1.yaml
   ```

2. Install the operator:
   ```shell
   kubectl create namespace toolhive-system
   kubectl apply -f examples/subscription.yaml
   ```

3. Verify installation:
   ```shell
   kubectl get csv -n toolhive-system
   kubectl get pods -n toolhive-system
   ```

#### Legacy OpenShift (4.15-4.18)

For older OpenShift versions, use the OLMv0 index image:

1. Build the OLMv0 index image:
   ```shell
   make index-olmv0-build
   ```

2. Deploy the CatalogSource:
   ```shell
   kubectl apply -f examples/catalogsource-olmv0.yaml
   ```

3. Install the operator (same as modern OpenShift)

**Note**: OLMv0 support is temporary for legacy versions and will be sunset when OpenShift 4.18 reaches end-of-life.

## Repository Structure

```
.
├── bundle/                 # OLM bundle (CSV, CRDs, metadata)
├── catalog/                # OLMv1 File-Based Catalog metadata
├── config/                 # Kustomize manifests
│   ├── base/              # OpenShift overlay
│   ├── default/           # Standard Kubernetes config
│   ├── crd/               # Custom Resource Definitions
│   ├── manager/           # Operator deployment
│   └── rbac/              # RBAC manifests
├── icons/                  # Operator icon assets
│   ├── default-icon.svg   # Default OLM-compliant icon (80×40)
│   └── README.md          # Icon documentation
├── scripts/                # Build and validation scripts
│   ├── encode-icon.sh     # Base64 encoding for icons
│   └── validate-icon.sh   # Icon validation (format, size, ratio)
├── examples/              # Example deployment manifests
├── Containerfile.catalog  # Catalog image build file
├── Makefile              # Build and validation targets
└── VALIDATION.md         # Validation status and compliance report
```

## Makefile Targets

```shell
make help                   # Show all available targets
make kustomize-validate     # Validate kustomize builds
make bundle-validate        # Validate OLM bundle
make catalog-validate       # Validate FBC catalog
make catalog-build          # Build catalog container image
make catalog-push           # Push catalog image to registry
make validate-icon          # Validate custom icon file
make check-icon-deps        # Check icon processing dependencies
make olm-all               # Complete OLM workflow
make constitution-check     # Verify constitution compliance
make validate-all          # Run all validations
```

## Development

### Constitution Compliance

This repository follows strict constitutional principles (Constitution v1.2.0):

1. **Manifest Integrity**: All kustomize builds must pass
2. **Kustomize-Based Customization**: Use overlays, not direct modifications
3. **CRD Immutability**: CRDs are never modified here (upstream only)
4. **OpenShift Compatibility**: Maintained via config/base overlay
5. **Namespace Awareness**: Explicit namespace handling
6. **OLM Catalog Multi-Bundle Support**: Supports multiple bundle versions
7. **Scorecard Quality Assurance**: All operator-sdk scorecard tests must pass

Verify compliance:
```shell
make constitution-check      # Verify kustomize builds
make scorecard-test         # Run scorecard validation
```

### Adding New Operator Versions

1. Update bundle CSV version in `bundle/manifests/toolhive-operator.clusterserviceversion.yaml`
2. Update catalog metadata in `catalog/toolhive-operator/catalog.yaml`
3. Add new bundle entry to the channel
4. Validate and build:
   ```shell
   make olm-all
   ```

## Validation

All validation results are documented in [VALIDATION.md](VALIDATION.md).

**Current status**: ✅ All validations passing (v0.4.2)

- FBC Schema: ✅ opm validate passed
- Bundle Structure: ✅ Complete and correct (1 CSV + 6 CRDs)
- Scorecard Tests: ✅ All 6 tests passing
- Constitution Compliance: ✅ All 7 principles satisfied
- Catalog Image: ✅ Built successfully

## Custom Resources

The operator manages six custom resource types:

- **MCPRegistry** (`mcpregistries.toolhive.stacklok.dev`) - Manages registries of MCP server definitions
- **MCPServer** (`mcpservers.toolhive.stacklok.dev`) - Manages individual MCP server instances
- **MCPGroup** (`mcpgroups.toolhive.stacklok.dev`) - Organizes and manages groups of MCP servers
- **MCPRemoteProxy** (`mcpremoteproxies.toolhive.stacklok.dev`) - Configures remote proxy connections
- **MCPExternalAuthConfig** (`mcpexternalauthconfigs.toolhive.stacklok.dev`) - Configures external authentication
- **MCPToolConfig** (`mcptoolconfigs.toolhive.stacklok.dev`) - Configures individual tools within MCP servers

## License

TBD
