# Data Model: Executable Catalog Image Structure

**Feature**: 006-executable-catalog-image
**Date**: 2025-10-15
**Purpose**: Define the container image layer structure, file paths, and runtime components

---

## Container Image Architecture

### Multi-stage Build Stages

#### Stage 1: Builder (Cache Generation)

**Base Image**: `quay.io/operator-framework/opm:latest`
**Purpose**: Pre-populate catalog cache for optimized runtime performance

**Layer Structure**:
```
FROM quay.io/operator-framework/opm:latest as builder

Layer 1: Base image layers
  ├── /bin/opm (binary ~50-80MB)
  ├── /bin/grpc_health_probe (binary ~10-20MB)
  └── [minimal OS dependencies]

Layer 2: ADD catalog /configs
  └── /configs/
      └── toolhive-operator/
          └── catalog.yaml (1.6KB)

Layer 3: RUN opm serve --cache-only
  └── /tmp/cache/
      ├── [internal cache files - structure varies by opm version]
      └── [estimated 5-10MB for single-package catalog]
```

**Outputs from Builder**:
- `/configs/toolhive-operator/catalog.yaml` - Original FBC metadata
- `/tmp/cache/*` - Pre-generated cache files

#### Stage 2: Runtime (Executable Server)

**Base Image**: `quay.io/operator-framework/opm:latest`
**Purpose**: Serve catalog metadata via gRPC registry-server

**Layer Structure**:
```
FROM quay.io/operator-framework/opm:latest

Layer 1: Base image layers
  ├── /bin/opm (binary)
  ├── /bin/grpc_health_probe (binary)
  └── [minimal OS dependencies]

Layer 2: COPY --from=builder /configs /configs
  └── /configs/
      └── toolhive-operator/
          └── catalog.yaml (1.6KB)

Layer 3: COPY --from=builder /tmp/cache /tmp/cache
  └── /tmp/cache/
      └── [pre-built cache files]

Layer 4: Metadata (LABEL, ENTRYPOINT, CMD)
  ├── ENTRYPOINT ["/bin/opm"]
  ├── CMD ["serve", "/configs", "--cache-dir=/tmp/cache"]
  └── LABEL operators.operatorframework.io.index.configs.v1=/configs
      LABEL org.opencontainers.image.title="ToolHive Operator Catalog"
      LABEL org.opencontainers.image.description="File-Based Catalog for ToolHive Operator (OLMv1)"
      LABEL org.opencontainers.image.vendor="Stacklok"
      LABEL org.opencontainers.image.source="https://github.com/RHEcosystemAppEng/toolhive-operator-metadata"
      LABEL org.opencontainers.image.version="v0.2.17"
      LABEL org.opencontainers.image.licenses="Apache-2.0"
```

**Final Image Size**: Estimated 60-100MB (base image + catalog + cache)

---

## File System Layout

### Critical Paths

| Path | Type | Size | Purpose | Permissions |
|------|------|------|---------|-------------|
| `/bin/opm` | Binary | ~50-80MB | Registry-server executable | `0755` (executable) |
| `/bin/grpc_health_probe` | Binary | ~10-20MB | Health check probe | `0755` (executable) |
| `/configs/` | Directory | - | FBC root directory | `0755` (read/execute) |
| `/configs/toolhive-operator/` | Directory | - | Package directory | `0755` (read/execute) |
| `/configs/toolhive-operator/catalog.yaml` | File | 1.6KB | FBC schemas | `0644` (read-only) |
| `/tmp/cache/` | Directory | ~5-10MB | Pre-built cache | `0755` (read/execute) |
| `/tmp/cache/*` | Files | Varies | Cache data files | `0644` (read-only) |

### Directory Ownership

**User/Group**: Inherited from opm base image (typically `root:root` or non-root user)
**Security Context**: Compatible with OpenShift restricted SCC (no special privileges required)

---

## Catalog Metadata Structure

### FBC Schema Organization

**File**: `/configs/toolhive-operator/catalog.yaml`

**Schema Definitions** (YAML multi-document format):

```yaml
# Document 1: Package Schema
---
schema: olm.package
name: toolhive-operator
defaultChannel: fast
description: |
  ToolHive Operator manages Model Context Protocol (MCP) servers and registries.
icon:
  base64data: [base64-encoded SVG]
  mediatype: image/svg+xml

# Document 2: Channel Schema
---
schema: olm.channel
name: fast
package: toolhive-operator
entries:
  - name: toolhive-operator.v0.2.17

# Document 3: Bundle Schema
---
schema: olm.bundle
name: toolhive-operator.v0.2.17
package: toolhive-operator
image: ghcr.io/stacklok/toolhive/bundle:v0.2.17
properties:
  - type: olm.package
    value:
      packageName: toolhive-operator
      version: 0.2.17
  - type: olm.gvk
    value:
      group: toolhive.stacklok.dev
      kind: MCPRegistry
      version: v1alpha1
  - type: olm.gvk
    value:
      group: toolhive.stacklok.dev
      kind: MCPServer
      version: v1alpha1
```

**Key Entities**:

- **Package**: `toolhive-operator` - Top-level operator package
- **Channel**: `fast` - Release channel for updates
- **Bundle**: `toolhive-operator.v0.2.17` - Specific operator version
- **CRDs**: MCPRegistry, MCPServer - Custom resources managed by operator

### Relationships

```
Package (toolhive-operator)
  └── Channel (fast)
       └── Entry (toolhive-operator.v0.2.17)
            └── Bundle Image (ghcr.io/stacklok/toolhive/bundle:v0.2.17)
                 └── CRDs (MCPRegistry, MCPServer)
```

---

## Cache Structure

### Purpose

The `/tmp/cache/` directory contains optimized representations of the catalog metadata for fast serving by the registry-server.

### Contents (OPM Internal Format)

**Note**: Cache file format is internal to opm and may vary between versions. The following is a logical model based on registry-server behavior:

**Logical Components**:
1. **Package Index** - Fast lookup table for package names
2. **Channel Graph** - Upgrade path computation structures
3. **Bundle Metadata** - Denormalized bundle properties
4. **Schema Validators** - Pre-compiled validation rules

**Physical Files** (examples, actual names may differ):
- `/tmp/cache/packages.db` (hypothetical)
- `/tmp/cache/channels.db` (hypothetical)
- `/tmp/cache/bundles.db` (hypothetical)

### Cache Generation Process

**During Builder Stage**:
```bash
/bin/opm serve /configs --cache-dir=/tmp/cache --cache-only
```

**Steps**:
1. Parse `/configs/toolhive-operator/catalog.yaml`
2. Validate FBC schemas (olm.package, olm.channel, olm.bundle)
3. Build internal indexes and graphs
4. Write optimized data structures to `/tmp/cache/`
5. Exit without starting server (`--cache-only`)

### Cache Integrity

**Validation**: Registry-server validates cache at startup
**Behavior**: With `--cache-enforce-integrity=true` (default when cache-dir set):
- **Valid cache**: Immediate serving (1-3s startup)
- **Invalid/missing cache**: Exit with error (fail-fast)

**Cache Invalidation Scenarios**:
- OPM version mismatch (cache built with different opm version)
- Corrupted cache files (disk errors, incomplete COPY)
- Schema changes (catalog.yaml updated but cache not regenerated)

---

## Runtime Configuration

### Entrypoint and Command

**ENTRYPOINT**: `["/bin/opm"]`
**CMD**: `["serve", "/configs", "--cache-dir=/tmp/cache"]`

**Effective Command at Container Start**:
```bash
/bin/opm serve /configs --cache-dir=/tmp/cache
```

**Arguments Breakdown**:
- `serve` - Start registry-server subcommand
- `/configs` - FBC root directory (scanned recursively)
- `--cache-dir=/tmp/cache` - Use pre-built cache from builder stage

### Default Runtime Behavior

**Port**: 50051 (gRPC default)
**Protocol**: gRPC over HTTP/2
**Startup Sequence**:
1. Load cache from `/tmp/cache/`
2. Verify cache integrity
3. Start gRPC server on port 50051
4. Register health check endpoint
5. Log "serving registry" message
6. Accept gRPC API requests

**Resource Usage** (estimated):
- CPU: Minimal (~10-50m during startup, <10m at idle)
- Memory: 50-100MB (depends on catalog size)
- Network: Port 50051 (ingress only)

### Environment Variables

**Standard Variables** (inherited from base image):
- None required for basic operation

**Optional Variables** (not currently used but supported by opm):
- `OPM_SERVE_PORT` - Override default port
- `OPM_DEBUG` - Enable debug logging

---

## Labels and Metadata

### Required OLM Label

```dockerfile
LABEL operators.operatorframework.io.index.configs.v1=/configs
```

**Purpose**: Tells OLM where to find FBC metadata within the image
**Value**: `/configs` (absolute path to FBC root directory)
**Status**: Non-negotiable for OLM discovery

### OCI Image Metadata Labels

```dockerfile
LABEL org.opencontainers.image.title="ToolHive Operator Catalog"
LABEL org.opencontainers.image.description="File-Based Catalog for ToolHive Operator (OLMv1)"
LABEL org.opencontainers.image.vendor="Stacklok"
LABEL org.opencontainers.image.source="https://github.com/RHEcosystemAppEng/toolhive-operator-metadata"
LABEL org.opencontainers.image.version="v0.2.17"
LABEL org.opencontainers.image.licenses="Apache-2.0"
```

**Purpose**: Standard OCI metadata for image registries, security scanning, and documentation
**Status**: Recommended for production images

---

## Deployment Model

### Kubernetes/OpenShift Integration

**Resource**: CatalogSource (operators.coreos.com/v1alpha1)

**Example CatalogSource**:
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: ghcr.io/stacklok/toolhive/catalog:v0.2.17
  displayName: ToolHive Operator Catalog
  publisher: Stacklok
  updateStrategy:
    registryPoll:
      interval: 10m
```

**Generated Resources**:
- **Pod**: Runs catalog container image with registry-server
- **Service**: ClusterIP service on port 50051 for gRPC access
- **ConfigMap**: (Optional) Additional catalog configuration

### Pod Specification (Generated by OLM)

**Container**:
```yaml
containers:
- name: registry-server
  image: ghcr.io/stacklok/toolhive/catalog:v0.2.17
  ports:
  - containerPort: 50051
    protocol: TCP
  livenessProbe:
    exec:
      command: ["/bin/grpc_health_probe", "-addr=:50051"]
    initialDelaySeconds: 5
    periodSeconds: 10
  readinessProbe:
    exec:
      command: ["/bin/grpc_health_probe", "-addr=:50051"]
    initialDelaySeconds: 1
    periodSeconds: 5
  resources:
    requests:
      cpu: 10m
      memory: 50Mi
    limits:
      cpu: 100m
      memory: 100Mi
```

**Startup Flow**:
1. Image pull from registry
2. Container start (runs `/bin/opm serve /configs --cache-dir=/tmp/cache`)
3. Registry-server loads cache (1-3s)
4. Health probes pass (readiness probe succeeds)
5. Service routes traffic to pod
6. OLM queries catalog for packages

---

## Validation and Testing

### Image Inspection Commands

```bash
# Verify /configs structure
podman run --rm catalog:test find /configs -type f
# Expected: /configs/toolhive-operator/catalog.yaml

# Verify /tmp/cache exists
podman run --rm catalog:test ls -la /tmp/cache
# Expected: Cache files from builder stage

# Verify labels
podman inspect catalog:test | jq -r '.[0].Config.Labels'
# Expected: All 7 labels present

# Verify entrypoint/cmd
podman inspect catalog:test | jq -r '.[0].Config.Entrypoint, .[0].Config.Cmd'
# Expected: ["/bin/opm"], ["serve", "/configs", "--cache-dir=/tmp/cache"]
```

### Runtime Validation

```bash
# Start server locally
podman run -d -p 50051:50051 --name test catalog:test

# Check logs for startup message
podman logs test
# Expected: "serving registry" or similar

# Test gRPC health check
grpc_health_probe -addr localhost:50051
# Expected: status: SERVING

# Query packages
grpcurl -plaintext localhost:50051 api.Registry/ListPackages
# Expected: toolhive-operator package in response
```

---

## Summary

The executable catalog image uses a multi-stage build pattern to create a container image that:

1. **Contains** the registry-server binary (`/bin/opm`)
2. **Serves** catalog metadata from `/configs/toolhive-operator/catalog.yaml`
3. **Uses** pre-built cache from `/tmp/cache/` for fast startup
4. **Exposes** gRPC API on port 50051
5. **Supports** health checks via `/bin/grpc_health_probe`
6. **Maintains** full compatibility with existing catalog metadata and labels

The data model ensures backward compatibility while adding executable functionality for deployment in Kubernetes/OpenShift clusters.
