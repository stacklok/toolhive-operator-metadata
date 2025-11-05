# Quickstart: Building OLMv1 File-Based Catalog

**Feature**: 001-build-an-olmv1
**Date**: 2025-10-07
**Audience**: Platform engineers, operator maintainers

## Overview

This guide walks through building an OLMv1 File-Based Catalog (FBC) for the ToolHive Operator. The process involves three main steps:

1. **Generate Bundle** - Create traditional OLM bundle from kustomize manifests
2. **Render FBC** - Convert bundle to FBC format using opm
3. **Build Catalog Image** - Package FBC metadata into container image

**Time estimate**: 15-20 minutes for initial setup

---

## Prerequisites

### Required Tools

Install the following tools before proceeding:

```bash
# operator-sdk (bundle generation and validation)
# Install from: https://sdk.operatorframework.io/docs/installation/
operator-sdk version  # Verify: v1.30.0 or later

# opm (Operator Package Manager - FBC rendering and catalog building)
# Install from: https://github.com/operator-framework/operator-registry/releases
opm version  # Verify: v1.30.0 or later

# kustomize (manifest building - likely already installed)
kustomize version  # Verify: v5.0.0 or later

# Container runtime (podman recommended, docker also works)
podman version  # or: docker version
```

### Repository Setup

```bash
# Clone the repository
git clone https://github.com/RHEcosystemAppEng/toolhive-operator-metadata.git
cd toolhive-operator-metadata

# Verify existing kustomize builds work (constitution check)
kustomize build config/default  # Should succeed
kustomize build config/base     # Should succeed
```

---

## Step 1: Generate Bundle

The bundle generation process creates a traditional OLM bundle containing ClusterServiceVersion (CSV), CRDs, and metadata.

### 1.1 Create Bundle Directory Structure

```bash
# Create bundle directory
mkdir -p bundle/manifests
mkdir -p bundle/metadata
```

### 1.2 Copy CRDs to Bundle

```bash
# Copy CRDs from config/crd/ (maintaining immutability - constitution III)
cp config/crd/bases/toolhive.stacklok.dev_mcpregistries.yaml \
   bundle/manifests/mcpregistries.crd.yaml

cp config/crd/bases/toolhive.stacklok.dev_mcpservers.yaml \
   bundle/manifests/mcpservers.crd.yaml
```

### 1.3 Generate ClusterServiceVersion

The CSV is the core bundle manifest describing the operator's capabilities.

**Option A: Use operator-sdk generate (recommended if kubebuilder project)**

```bash
# If the upstream operator repository has operator-sdk scaffolding
cd <upstream-operator-repo>
make bundle  # Generates bundle/ directory

# Copy generated CSV to this repository
cp bundle/manifests/toolhive-operator.clusterserviceversion.yaml \
   <this-repo>/bundle/manifests/
```

**Option B: Create CSV manually**

If operator-sdk generate isn't available, create the CSV using the template below.

See: [CSV Template Example](#csv-template-example) at the end of this guide.

### 1.4 Create Bundle Metadata

```bash
# Create bundle/metadata/annotations.yaml
cat > bundle/metadata/annotations.yaml <<EOF
annotations:
  operators.operatorframework.io.bundle.mediatype.v1: registry+v1
  operators.operatorframework.io.bundle.manifests.v1: manifests/
  operators.operatorframework.io.bundle.metadata.v1: metadata/
  operators.operatorframework.io.bundle.package.v1: toolhive-operator
  operators.operatorframework.io.bundle.channels.v1: stable
  operators.operatorframework.io.bundle.channel.default.v1: stable
EOF
```

### 1.5 Validate Bundle

```bash
# Basic validation
operator-sdk bundle validate ./bundle

# Full Operator Framework validation
operator-sdk bundle validate ./bundle --select-optional suite=operatorframework

# Expected output: "All validation tests have completed successfully"
```

**Common validation errors and fixes**:

| Error | Fix |
|-------|-----|
| "missing required field: spec.version" | Add spec.version to CSV |
| "CRD not found in bundle" | Ensure CRDs are in bundle/manifests/ |
| "invalid semantic version" | Use format: 0.2.17 (not v0.2.17) |
| "minKubeVersion not specified" | Add spec.minKubeVersion to CSV |

---

## Step 2: Render FBC Metadata

Convert the traditional bundle to FBC format using opm.

### 2.1 Create Catalog Directory

```bash
mkdir -p catalog/toolhive-operator
```

### 2.2 Render Bundle to FBC

```bash
# Render the bundle to FBC format
opm render bundle/ \
    --output yaml \
    > catalog/toolhive-operator/catalog-bundle.yaml

# This creates olm.bundle schema with properties extracted from the CSV
```

### 2.3 Add Package and Channel Schemas

The rendered output contains only the olm.bundle schema. Add the package and channel schemas manually:

```bash
# Create catalog.yaml with all three schemas
cat > catalog/toolhive-operator/catalog.yaml <<EOF
---
schema: olm.package
name: toolhive-operator
defaultChannel: stable
description: |
  ToolHive Operator manages Model Context Protocol (MCP) servers and registries.

---
schema: olm.channel
name: stable
package: toolhive-operator
entries:
  - name: toolhive-operator.v0.2.17

---
EOF

# Append the rendered bundle schema
cat catalog/toolhive-operator/catalog-bundle.yaml >> catalog/toolhive-operator/catalog.yaml

# Remove the temporary file
rm catalog/toolhive-operator/catalog-bundle.yaml
```

**Alternative**: Use the example from [contracts/catalog.yaml](contracts/catalog.yaml) as a template.

### 2.4 Validate FBC Metadata

```bash
# Validate the catalog structure
opm validate catalog/

# Expected output: No errors (silent success)
```

---

## Step 3: Build Catalog Image

Package the FBC metadata into a container image for distribution.

### 3.1 Create Containerfile

```bash
# Create Containerfile.catalog at repository root
cat > Containerfile.catalog <<EOF
FROM scratch
ADD catalog /configs
LABEL operators.operatorframework.io.index.configs.v1=/configs
EOF
```

**Note**: See [contracts/Containerfile.catalog](contracts/Containerfile.catalog) for a more comprehensive example with metadata labels.

### 3.2 Build Catalog Image

```bash
# Build the catalog image
podman build -f Containerfile.catalog \
    -t ghcr.io/stacklok/toolhive/catalog:v0.2.17 .

# Verify the build succeeded
podman images | grep catalog
```

### 3.3 Validate Catalog Image

```bash
# Validate the catalog image can be parsed by OLM
opm validate ghcr.io/stacklok/toolhive/catalog:v0.2.17

# Alternative: Serve the catalog locally to test
opm serve ghcr.io/stacklok/toolhive/catalog:v0.2.17 -p 50051

# In another terminal, test catalog serving
grpcurl -plaintext localhost:50051 api.Registry/ListPackages
# Expected: JSON response with "toolhive-operator" package
```

### 3.4 Push Catalog Image (Optional)

```bash
# Login to container registry
podman login ghcr.io

# Push the catalog image
podman push ghcr.io/stacklok/toolhive/catalog:v0.2.17

# Tag as latest (if this is the current stable version)
podman tag ghcr.io/stacklok/toolhive/catalog:v0.2.17 \
           ghcr.io/stacklok/toolhive/catalog:latest
podman push ghcr.io/stacklok/toolhive/catalog:latest
```

---

## Step 4: Quality Assurance (Optional but Recommended)

### 4.1 Run Scorecard Tests

```bash
# Run scorecard tests for quality validation
operator-sdk scorecard ./bundle

# This tests:
# - Basic operator functionality
# - OLM integration
# - Best practices compliance
```

### 4.2 Constitution Compliance Check

```bash
# Verify kustomize builds still pass (constitution I)
kustomize build config/default > /dev/null && echo "✅ default build passed"
kustomize build config/base > /dev/null && echo "✅ base build passed"

# Verify CRDs unchanged (constitution III)
git diff --exit-code config/crd/ && echo "✅ CRDs unchanged"
```

---

## Makefile Integration (Recommended)

Add these targets to your Makefile for easier workflow:

```makefile
# OLM Bundle and Catalog targets

.PHONY: bundle
bundle: ## Generate bundle manifests
	mkdir -p bundle/manifests bundle/metadata
	cp config/crd/bases/*.yaml bundle/manifests/
	# TODO: Generate or copy CSV
	# TODO: Create metadata/annotations.yaml

.PHONY: bundle-validate
bundle-validate: ## Validate bundle
	operator-sdk bundle validate ./bundle --select-optional suite=operatorframework

.PHONY: catalog
catalog: ## Generate FBC catalog from bundle
	mkdir -p catalog/toolhive-operator
	opm render bundle/ --output yaml > catalog/toolhive-operator/catalog.yaml
	# TODO: Add package and channel schemas

.PHONY: catalog-validate
catalog-validate: ## Validate FBC catalog
	opm validate catalog/

.PHONY: catalog-build
catalog-build: ## Build catalog container image
	podman build -f Containerfile.catalog -t ghcr.io/stacklok/toolhive/catalog:v0.2.17 .

.PHONY: catalog-push
catalog-push: ## Push catalog image to registry
	podman push ghcr.io/stacklok/toolhive/catalog:v0.2.17

.PHONY: olm-all
olm-all: bundle bundle-validate catalog catalog-validate catalog-build ## Run full OLM workflow
```

Usage:
```bash
make olm-all  # Runs entire bundle → catalog → image workflow
```

---

## Deployment to Kubernetes/OpenShift

Once the catalog image is built and pushed, deploy it to a cluster:

### Using OLMv1 (Operator Lifecycle Manager v1)

```bash
# Create CatalogSource in the cluster
kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-catalog
  namespace: olm
spec:
  sourceType: grpc
  image: ghcr.io/stacklok/toolhive/catalog:v0.2.17
  displayName: ToolHive Operator Catalog
  publisher: Stacklok
  updateStrategy:
    registryPoll:
      interval: 15m
EOF

# Verify catalog is loaded
kubectl get catalogsource -n olm
kubectl get packagemanifest | grep toolhive

# Install the operator
kubectl create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: toolhive-operator
  namespace: operators
spec:
  channel: stable
  name: toolhive-operator
  source: toolhive-catalog
  sourceNamespace: olm
EOF
```

---

## Troubleshooting

### Bundle Validation Failures

**Problem**: `operator-sdk bundle validate` fails

**Solutions**:
1. Check CSV has all required fields (displayName, description, version, minKubeVersion)
2. Ensure CRDs in manifests/ match customresourcedefinitions.owned in CSV
3. Verify semantic versioning format (0.2.17, not v0.2.17)
4. Check metadata/annotations.yaml has all required annotations

### FBC Validation Failures

**Problem**: `opm validate catalog/` fails

**Solutions**:
1. Verify all three schemas present (olm.package, olm.channel, olm.bundle)
2. Check referential integrity (channel.package → package.name, etc.)
3. Ensure bundle name format: `<packageName>.v<version>`
4. Validate YAML syntax (use `yamllint` or similar)

### Catalog Image Build Failures

**Problem**: `podman build` fails or image doesn't validate

**Solutions**:
1. Ensure Containerfile.catalog is at repository root
2. Verify catalog/ directory exists and contains metadata
3. Check the label syntax in Containerfile
4. Validate with `opm validate <image>` after build

### Catalog Not Loading in Cluster

**Problem**: CatalogSource shows errors or packagemanifest doesn't appear

**Solutions**:
1. Check image is accessible from cluster (pull secrets may be needed)
2. Verify CatalogSource points to correct image and namespace
3. Check catalog-operator logs: `kubectl logs -n olm -l app=catalog-operator`
4. Test catalog locally first: `opm serve <image>`

---

## CSV Template Example

If creating the CSV manually, use this template:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: ClusterServiceVersion
metadata:
  name: toolhive-operator.v0.2.17
  namespace: placeholder
  annotations:
    capabilities: Basic Install
    categories: AI/ML, Developer Tools
    description: Manages MCP (Model Context Protocol) servers and registries
spec:
  displayName: ToolHive Operator
  description: |
    The ToolHive Operator manages Model Context Protocol (MCP) servers and registries
    in Kubernetes and OpenShift clusters.

    MCP enables AI assistants to securely access external tools and data sources through
    a standardized protocol. This operator provides:

    - **MCPRegistry**: Manage registries of MCP server definitions
    - **MCPServer**: Deploy and manage individual MCP server instances

  version: 0.2.17
  minKubeVersion: 1.16.0

  keywords:
    - mcp
    - model-context-protocol
    - ai
    - toolhive

  maintainers:
    - name: Stacklok
      email: support@stacklok.com

  provider:
    name: Stacklok

  links:
    - name: Documentation
      url: https://github.com/stacklok/toolhive
    - name: Source Code
      url: https://github.com/stacklok/toolhive

  icon:
    - base64data: PHN2ZyB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgZmlsbD0iIzAwN2ZmZiIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LXNpemU9IjI1NiIgZmlsbD0id2hpdGUiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGRvbWluYW50LWJhc2VsaW5lPSJtaWRkbGUiPk08L3RleHQ+PC9zdmc+
      mediatype: image/svg+xml

  maturity: alpha

  install:
    strategy: deployment
    spec:
      permissions:
        - serviceAccountName: toolhive-operator-controller-manager
          rules:
            # TODO: Copy from config/rbac/role.yaml
            - apiGroups: [""]
              resources: [configmaps, secrets, services, pods]
              verbs: [get, list, watch, create, update, patch, delete]
            - apiGroups: [apps]
              resources: [deployments]
              verbs: [get, list, watch, create, update, patch, delete]
            - apiGroups: [toolhive.stacklok.dev]
              resources: [mcpregistries, mcpservers]
              verbs: [get, list, watch, create, update, patch, delete]
            - apiGroups: [toolhive.stacklok.dev]
              resources: [mcpregistries/status, mcpservers/status]
              verbs: [get, update, patch]

      deployments:
        - name: toolhive-operator-controller-manager
          spec:
            replicas: 1
            selector:
              matchLabels:
                control-plane: controller-manager
            template:
              metadata:
                labels:
                  control-plane: controller-manager
              spec:
                serviceAccountName: toolhive-operator-controller-manager
                containers:
                  - name: manager
                    image: ghcr.io/stacklok/toolhive/operator:v0.2.17
                    command:
                      - /manager
                    args:
                      - --leader-elect
                    env:
                      - name: TOOLHIVE_RUNNER_IMAGE
                        value: ghcr.io/stacklok/toolhive/proxyrunner:v0.2.17
                    ports:
                      - containerPort: 8080
                        name: metrics
                        protocol: TCP
                      - containerPort: 8081
                        name: health
                        protocol: TCP
                    livenessProbe:
                      httpGet:
                        path: /healthz
                        port: 8081
                      initialDelaySeconds: 15
                      periodSeconds: 20
                    readinessProbe:
                      httpGet:
                        path: /readyz
                        port: 8081
                      initialDelaySeconds: 5
                      periodSeconds: 10
                    resources:
                      limits:
                        cpu: 500m
                        memory: 256Mi
                      requests:
                        cpu: 10m
                        memory: 64Mi

  customresourcedefinitions:
    owned:
      - name: mcpregistries.toolhive.stacklok.dev
        version: v1alpha1
        kind: MCPRegistry
        displayName: MCP Registry
        description: Represents a registry of MCP server definitions
      - name: mcpservers.toolhive.stacklok.dev
        version: v1alpha1
        kind: MCPServer
        displayName: MCP Server
        description: Represents an MCP server instance
```

**Note**: The CSV must be customized with actual RBAC rules from config/rbac/ and deployment specs from config/manager/.

---

## Next Steps

After completing this quickstart:

1. **Automate**: Add Makefile targets or CI/CD pipeline for bundle/catalog generation
2. **Version Management**: Create process for adding new operator versions to the catalog
3. **Multi-Channel**: Add additional channels (candidate, fast) as operator matures
4. **Testing**: Set up automated validation in CI (bundle validate, catalog validate, scorecard)
5. **Documentation**: Update main README with OLM installation instructions

---

## References

- [OLM File-Based Catalogs Documentation](https://olm.operatorframework.io/docs/reference/file-based-catalogs)
- [OLM Best Practices](https://olm.operatorframework.io/docs/best-practices/common)
- [operator-sdk Bundle Documentation](https://sdk.operatorframework.io/docs/olm-integration/tutorial-bundle/)
- [opm CLI Reference](https://github.com/operator-framework/operator-registry/blob/master/docs/design/opm-tooling.md)
