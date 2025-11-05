# Contract: Containerfile Multi-stage Build Structure

**Feature**: 006-executable-catalog-image
**Date**: 2025-10-15
**Purpose**: Define the contract for the multi-stage Containerfile.catalog build pattern

---

## Contract Overview

This contract specifies the structure, behavior, and requirements for the multi-stage Containerfile that builds an executable OLMv1 File-Based Catalog image with integrated registry-server.

---

## Builder Stage Contract

### Stage Declaration

```dockerfile
FROM quay.io/operator-framework/opm:latest AS builder
```

**Requirements**:
- **Base Image**: MUST use `quay.io/operator-framework/opm:latest` or pinned digest
- **Stage Name**: MUST be named `builder` (referenced in COPY commands)
- **Purpose**: Pre-populate catalog cache for runtime optimization

### Source Addition

```dockerfile
ADD catalog /configs
```

**Requirements**:
- **Source Path**: MUST be `catalog` (relative to build context root)
- **Destination Path**: MUST be `/configs` (OLM standard convention)
- **Preserved Structure**: MUST preserve subdirectory structure (e.g., `catalog/toolhive-operator/` → `/configs/toolhive-operator/`)
- **File Permissions**: Files copied with default permissions (0644 for files, 0755 for directories)

**Postcondition**: `/configs/toolhive-operator/catalog.yaml` exists in builder stage

### Cache Generation

```dockerfile
RUN ["/bin/opm", "serve", "/configs", "--cache-dir=/tmp/cache", "--cache-only"]
```

**Requirements**:
- **Executable**: MUST use `/bin/opm` (provided by base image)
- **Subcommand**: MUST be `serve`
- **Source Path**: MUST be `/configs` (matching ADD destination)
- **Cache Directory**: MUST be `/tmp/cache`
- **Cache-Only Flag**: MUST include `--cache-only` to exit after cache generation
- **Exec Form**: MUST use exec form (JSON array) to avoid shell processing

**Behavior**:
- Parse FBC schemas from `/configs`
- Generate cache files in `/tmp/cache`
- Validate catalog structure
- Exit with code 0 on success, non-zero on validation errors

**Postcondition**: `/tmp/cache/` contains pre-built cache files

**Error Handling**:
- If catalog YAML is invalid: Build MUST fail with validation error
- If `/configs` is empty: Build MUST fail
- If opm binary is missing: Build MUST fail

### Builder Stage Outputs

The builder stage MUST produce:
1. `/configs/` directory with complete catalog metadata
2. `/tmp/cache/` directory with pre-generated cache files

These outputs MUST be available for COPY in the runtime stage.

---

## Runtime Stage Contract

### Stage Declaration

```dockerfile
FROM quay.io/operator-framework/opm:latest
```

**Requirements**:
- **Base Image**: MUST use same base image as builder stage
- **Purpose**: Provide runtime environment for registry-server

### Artifact Copying

```dockerfile
COPY --from=builder /configs /configs
COPY --from=builder /tmp/cache /tmp/cache
```

**Requirements**:
- **Source Stage**: MUST reference `builder` stage by name
- **Configs Copy**: MUST copy `/configs` to `/configs` (preserving path)
- **Cache Copy**: MUST copy `/tmp/cache` to `/tmp/cache` (preserving path)
- **Order**: MUST copy /configs before /tmp/cache (logical ordering)

**Postcondition**: Runtime stage contains both /configs and /tmp/cache with identical contents from builder

### Entrypoint Configuration

```dockerfile
ENTRYPOINT ["/bin/opm"]
```

**Requirements**:
- **Executable**: MUST be `/bin/opm`
- **Form**: MUST use exec form (JSON array)
- **Overridable**: Can be overridden at runtime if needed (standard Docker behavior)

### Command Configuration

```dockerfile
CMD ["serve", "/configs", "--cache-dir=/tmp/cache"]
```

**Requirements**:
- **Subcommand**: MUST be `serve`
- **Source Path**: MUST be `/configs`
- **Cache Flag**: MUST include `--cache-dir=/tmp/cache`
- **Form**: MUST use exec form (JSON array)
- **Overridable**: Can be overridden at runtime (standard Docker behavior)

**Effective Command** (ENTRYPOINT + CMD):
```bash
/bin/opm serve /configs --cache-dir=/tmp/cache
```

### Label Requirements

#### Required OLM Label

```dockerfile
LABEL operators.operatorframework.io.index.configs.v1=/configs
```

**Requirements**:
- **Key**: MUST be exact string `operators.operatorframework.io.index.configs.v1`
- **Value**: MUST be `/configs` (matching ADD destination and CMD argument)
- **Purpose**: OLM uses this label to discover FBC metadata location

#### OCI Metadata Labels (Recommended)

```dockerfile
LABEL org.opencontainers.image.title="ToolHive Operator Catalog"
LABEL org.opencontainers.image.description="File-Based Catalog for ToolHive Operator (OLMv1)"
LABEL org.opencontainers.image.vendor="Stacklok"
LABEL org.opencontainers.image.source="https://github.com/RHEcosystemAppEng/toolhive-operator-metadata"
LABEL org.opencontainers.image.version="v0.2.17"
LABEL org.opencontainers.image.licenses="Apache-2.0"
```

**Requirements**:
- **Preservation**: MUST preserve all existing labels from current Containerfile.catalog
- **Format**: Follow OCI image-spec annotation conventions
- **Version**: Update `org.opencontainers.image.version` to match operator release

---

## Build Contract

### Build Command

```bash
podman build -f Containerfile.catalog -t <image-name>:<tag> .
```

**Requirements**:
- **Build Context**: Current directory (`.`) containing `catalog/` subdirectory
- **Containerfile**: MUST use `-f Containerfile.catalog` to specify file
- **Tag**: MUST include registry, organization, name, and tag (e.g., `ghcr.io/stacklok/toolhive/catalog:v0.2.17`)

### Build Stages Execution

1. **Builder Stage**:
   - Pull opm base image
   - ADD catalog to /configs
   - RUN opm serve with --cache-only
   - Verify cache generation (exit code 0)

2. **Runtime Stage**:
   - Pull opm base image (may use cache from builder)
   - COPY /configs from builder
   - COPY /tmp/cache from builder
   - Apply labels
   - Set entrypoint and command

### Build Success Criteria

Build MUST succeed if:
- ✅ Both stages complete without errors
- ✅ Builder stage generates cache in `/tmp/cache`
- ✅ Runtime stage contains both `/configs` and `/tmp/cache`
- ✅ Final image has all required labels
- ✅ ENTRYPOINT and CMD are correctly configured

Build MUST fail if:
- ❌ Catalog validation fails in builder stage
- ❌ `/configs` directory is missing or empty
- ❌ Cache generation fails (opm serve --cache-only exits with error)
- ❌ Required labels are missing

---

## Runtime Contract

### Container Startup

**Command Executed**:
```bash
/bin/opm serve /configs --cache-dir=/tmp/cache
```

**Startup Sequence**:
1. Load cache from `/tmp/cache/`
2. Validate cache integrity (fail-fast if corrupted)
3. Start gRPC server on port 50051 (default)
4. Register health check endpoint
5. Log "serving registry" or equivalent ready message
6. Accept gRPC API requests

**Startup Time**:
- **With Valid Cache**: 1-3 seconds
- **Cache Missing/Invalid**: Container MUST exit with error (fail-fast with --cache-enforce-integrity=true)

### Network Behavior

**Port**: 50051 (gRPC default)
**Protocol**: gRPC over HTTP/2
**Exposed Services**:
- OLM Registry API (ListPackages, GetPackage, GetBundle, etc.)
- gRPC Health Check Protocol

### Health Check Support

**Binary**: `/bin/grpc_health_probe` (provided by base image)
**Usage**:
```bash
/bin/grpc_health_probe -addr=:50051
```

**Expected Response**: `status: SERVING` when registry-server is healthy

### Resource Requirements

**Minimum**:
- CPU: 10m (millicore)
- Memory: 50Mi (MiB)

**Recommended**:
- CPU Request: 10m, Limit: 100m
- Memory Request: 50Mi, Limit: 100Mi

### File System Access

**Read-Only Paths**:
- `/configs/` - Catalog metadata (no writes required)
- `/tmp/cache/` - Pre-built cache (no writes required)

**Writable Paths**:
- None required for normal operation

**Security Context Compatibility**:
- Compatible with OpenShift restricted SCC
- No root privileges required
- No host path mounts needed

---

## Validation Contract

### Pre-build Validation

```bash
opm validate catalog/
```

**Requirements**:
- MUST pass before building image
- Validates FBC schema correctness
- Verifies all required fields present

### Post-build Validation

```bash
opm validate <image-reference>
```

**Requirements**:
- MUST pass after image build
- Validates catalog within container image
- Confirms /configs structure is correct

### Runtime Validation

```bash
podman run -d -p 50051:50051 --name test <image-reference>
grpc_health_probe -addr localhost:50051
```

**Requirements**:
- Container MUST start successfully
- Health probe MUST return `status: SERVING`
- Registry-server MUST respond to gRPC queries

---

## Compatibility Contract

### Backward Compatibility

**Preserved Elements**:
- ✅ All 7 existing labels (no removals, only additions allowed)
- ✅ Catalog metadata structure in `/configs/toolhive-operator/catalog.yaml`
- ✅ FBC schema format (olm.package, olm.channel, olm.bundle)
- ✅ Bundle image reference (`ghcr.io/stacklok/toolhive/bundle:v0.2.17`)

**Breaking Changes** (Intentional):
- Base image changes from `scratch` to `opm:latest` (required for executable functionality)
- Image size increases from ~1MB to ~60-100MB (trade-off for executable capability)

### Forward Compatibility

**Support for Future Enhancements**:
- Nested `/configs/` structure supports multi-package catalogs
- Label structure allows additional OCI labels
- Base image can be pinned to specific digest for version stability

---

## Error Handling Contract

### Build-time Errors

| Error Condition | Expected Behavior |
|-----------------|-------------------|
| Invalid YAML syntax | Build fails with parse error from opm |
| Missing required schema fields | Build fails with validation error |
| Empty catalog directory | Build fails (no content to serve) |
| opm binary missing in base image | Build fails (command not found) |
| Cache generation failure | Build fails with non-zero exit code |

### Runtime Errors

| Error Condition | Expected Behavior |
|-----------------|-------------------|
| Cache corrupted/missing | Container exits with error (fail-fast) |
| Port 50051 already in use | Container fails to start with bind error |
| Invalid /configs structure | Container exits with error during startup |
| Out of memory | Container OOMKilled, Kubernetes restarts pod |

---

## Testing Contract

### Required Tests

**1. Build Test**:
```bash
podman build -f Containerfile.catalog -t test:latest .
# Expected: Exit code 0, image created
```

**2. Structure Test**:
```bash
podman run --rm test:latest ls -R /configs
podman run --rm test:latest ls -la /tmp/cache
# Expected: Files present in both directories
```

**3. Label Test**:
```bash
podman inspect test:latest | jq -r '.[0].Config.Labels."operators.operatorframework.io.index.configs.v1"'
# Expected: /configs
```

**4. Runtime Test**:
```bash
podman run -d -p 50051:50051 --name test test:latest
sleep 3
grpc_health_probe -addr localhost:50051
# Expected: status: SERVING
```

**5. API Test**:
```bash
grpcurl -plaintext localhost:50051 api.Registry/ListPackages
# Expected: JSON response with toolhive-operator package
```

### Success Criteria

All 5 tests MUST pass before considering the implementation complete.

---

## Version Tracking

**Containerfile Version**: Aligned with operator version (v0.2.17)
**Base Image**: quay.io/operator-framework/opm:latest (or pinned digest for production)
**Contract Version**: 1.0.0 (initial executable catalog)

**Change Management**:
- Minor catalog updates (new bundles, channels): Update catalog.yaml, rebuild image
- OPM version updates: Test compatibility, rebuild image, verify cache integrity
- Major structural changes: Update this contract document, increment version

---

## Summary

This contract ensures that the multi-stage Containerfile:

1. ✅ Uses proven two-stage build pattern (builder + runtime)
2. ✅ Pre-populates cache for optimal startup performance
3. ✅ Preserves all existing labels and metadata
4. ✅ Maintains backward compatibility with catalog structure
5. ✅ Provides executable registry-server for Kubernetes/OpenShift deployment
6. ✅ Includes comprehensive validation and testing requirements
7. ✅ Defines clear error handling and success criteria

Adherence to this contract guarantees a functional executable catalog image compatible with OLM v1 File-Based Catalog requirements.
