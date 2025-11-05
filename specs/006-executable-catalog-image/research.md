# Research: Executable Catalog Image

**Feature**: 006-executable-catalog-image
**Date**: 2025-10-15
**Status**: Complete

## Overview

This research document consolidates findings from investigating the multi-stage Containerfile pattern, opm base image capabilities, and catalog metadata structure validation to support the implementation of an executable OLMv1 File-Based Catalog image.

---

## Research Task 1: Multi-stage Containerfile Pattern Analysis

### Reference Implementation Pattern

The ActiveMQ Artemis operator catalog.Dockerfile demonstrates a proven two-stage build pattern:

**Builder Stage**:
```dockerfile
FROM quay.io/operator-framework/opm:latest as builder
ADD catalog /configs
RUN ["/bin/opm", "serve", "/configs", "--cache-dir=/tmp/cache", "--cache-only"]
```

**Runtime Stage**:
```dockerfile
FROM quay.io/operator-framework/opm:latest
ENTRYPOINT ["/bin/opm"]
CMD ["serve", "/configs", "--cache-dir=/tmp/cache"]
COPY --from=builder /configs /configs
COPY --from=builder /tmp/cache /tmp/cache
LABEL operators.operatorframework.io.index.configs.v1=/configs
```

### Key Differences from Current Implementation

| Aspect | Current (ToolHive) | Required Change |
|--------|-------------------|-----------------|
| Base image | `FROM scratch` | Change to `quay.io/operator-framework/opm:latest` |
| Build stages | Single stage | Add builder + runtime stages |
| Executable | None | Add ENTRYPOINT + CMD |
| Cache | Not generated | Add cache pre-population in builder |
| Size | ~1MB (metadata only) | ~50-80MB (with registry-server) |

### Decision: Source Directory Structure

**Decision**: Use `ADD catalog /configs` (preserve current approach)

**Rationale**:
- Current structure: `catalog/toolhive-operator/catalog.yaml`
- ADD command copies catalog/ directory contents to /configs
- Results in: `/configs/toolhive-operator/catalog.yaml` in image
- This nested structure is the **recommended FBC pattern** for package organization
- Supports future multi-package catalogs
- Matches reference implementation approach
- OPM registry-server recursively scans /configs for FBC files

**Alternatives Rejected**:
- `ADD catalog/toolhive-operator /configs` - Would flatten structure and lose package organization
- Renaming toolhive-operator directory - Would require schema updates and break conventions

### Decision: Label Preservation

**Decision**: Preserve all 7 existing labels without modification

**Current Labels**:
- `operators.operatorframework.io.index.configs.v1=/configs` (required by OLM)
- `org.opencontainers.image.title` (OCI metadata)
- `org.opencontainers.image.description` (OCI metadata)
- `org.opencontainers.image.vendor` (OCI metadata)
- `org.opencontainers.image.source` (OCI metadata)
- `org.opencontainers.image.version` (OCI metadata)
- `org.opencontainers.image.licenses` (OCI metadata)

**Rationale**:
- All labels are compatible with executable catalog pattern
- OCI labels provide valuable metadata for registries and security scanning
- Reference implementation uses minimal labels but doesn't prohibit additional metadata
- No conflicts exist between labels and registry-server functionality

---

## Research Task 2: OPM Base Image Investigation

### Base Image: quay.io/operator-framework/opm:latest

**Contents**:
- `/bin/opm` - Operator package manager CLI (version e42f5c260, built 2025-09-23)
- `/bin/grpc_health_probe` - gRPC health check utility for Kubernetes probes
- Minimal runtime dependencies for serving FBC content

**Image Characteristics**:
- Platform: linux/amd64
- Approximate size: 50-100MB (including binaries and dependencies)
- Supports both podman and docker build tools

### OPM Serve Command

**Syntax**:
```bash
opm serve <source_path> [flags]
```

**Key Flags**:
- `--port` / `-p` - gRPC server port (default: 50051)
- `--cache-dir` - Directory for caching parsed catalog data
- `--cache-only` - Generate cache and exit (no server startup)
- `--cache-enforce-integrity` - Exit with error if cache is invalid (default: true when cache-dir set)
- `--debug` - Enable debug logging

**Typical Usage in Production**:
```bash
/bin/opm serve /configs --cache-dir=/tmp/cache
```

### Cache Pre-population Benefits

**Without Cache** (runtime parsing):
- Startup time: 5-15 seconds for typical catalogs
- CPU intensive: YAML parsing on every pod restart
- Memory allocation overhead during startup

**With Pre-cached Data**:
- Startup time: 1-3 seconds (3-5x faster)
- Immediate availability: Cache loaded from /tmp/cache
- Lower resource usage: No parsing overhead

**Cache Contents**:
- Parsed FBC data in optimized internal format
- Package indexes for fast lookups
- Channel graphs for upgrade path computation
- Denormalized bundle metadata

**Trade-off**: Image size increases by 5-10MB per operator, but startup performance improves significantly.

### Health Probes

**Purpose**: `/bin/grpc_health_probe` implements gRPC Health Checking Protocol

**Kubernetes Integration**:
```yaml
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
```

**Status**: Strongly recommended for production deployments (automatic pod restart on failures, traffic routing to healthy pods only)

### Network Protocol

**Protocol**: gRPC over HTTP/2
**Default Port**: 50051
**API**: OLM Registry gRPC API (ListPackages, GetPackage, GetBundle, etc.)

**OLM Connection Flow**:
1. CatalogSource creates Pod running catalog image
2. OLM creates ClusterIP Service on port 50051
3. OLM components query registry-server via gRPC
4. Discovered operators populate OperatorHub UI

---

## Research Task 3: Catalog Metadata Structure Validation

### Current Directory Structure

```
catalog/
└── toolhive-operator/
    └── catalog.yaml (1,600 bytes)
```

**Total size**: ~12KB (including directory overhead)

**File location**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/catalog/toolhive-operator/catalog.yaml`

### FBC Schema Validation

The catalog.yaml contains all required schemas:

1. **olm.package**
   - Package name: `toolhive-operator`
   - Default channel: `fast`
   - Description: Multi-line operator description
   - Icon: Base64-encoded SVG

2. **olm.channel**
   - Channel name: `fast`
   - Package: `toolhive-operator`
   - Entry: `toolhive-operator.v0.2.17`

3. **olm.bundle**
   - Bundle name: `toolhive-operator.v0.2.17`
   - Package: `toolhive-operator`
   - Image: `ghcr.io/stacklok/toolhive/bundle:v0.2.17`
   - CRDs: MCPRegistry and MCPServer (toolhive.stacklok.dev/v1alpha1)

**Compatibility**: Fully compatible with opm serve command (standard FBC YAML format)

### Label Verification

**Current OLM Label** (Containerfile.catalog line 22):
```dockerfile
LABEL operators.operatorframework.io.index.configs.v1=/configs
```

**Status**: ✅ Correctly points to /configs (OLM standard convention)

**All Labels Compatible**: No modifications required for executable catalog pattern

### /configs Directory Structure in Image

**Source**: `ADD catalog /configs` copies directory contents
**Result**: `/configs/toolhive-operator/catalog.yaml` in container image

**Registry-server Behavior**:
- Recursively scans /configs for FBC YAML/JSON files
- Discovers toolhive-operator package automatically
- Supports nested subdirectories for multi-package organization

**Validation**: Structure matches OLM expectations for File-Based Catalogs

---

## Research Task 4: Build and Validation Workflow

### Current Makefile Catalog Targets

**Existing targets**:
- `catalog` - Display catalog metadata (already generated)
- `catalog-validate` - Run `opm validate catalog/`
- `catalog-build` - Build container image with validation
- `catalog-push` - Push image to registry

**Current catalog-build behavior**:
```makefile
catalog-build: catalog-validate
	@echo "Building catalog container image: $(CATALOG_IMG)"
	$(CONTAINER_TOOL) build -f Containerfile.catalog -t $(CATALOG_IMG) .
	$(CONTAINER_TOOL) tag $(CATALOG_IMG) $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest
	@echo "✅ Catalog image built: $(CATALOG_IMG)"
	@$(CONTAINER_TOOL) images $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME)
```

**Compatibility**: Existing workflow compatible with multi-stage Containerfile (no Makefile changes required)

### Validation Steps for Executable Catalog

**Pre-build Validation**:
```bash
# Validate catalog metadata structure
opm validate catalog/
```

**Build Validation**:
```bash
# Build with multi-stage Containerfile
podman build -f Containerfile.catalog -t catalog:test .

# Verify builder stage completed (check logs for cache generation)
# Expected: "cache only mode, exiting after cache generation"
```

**Post-build Validation**:
```bash
# Inspect image contents
podman run --rm catalog:test ls -R /configs
# Expected: /configs/toolhive-operator/catalog.yaml

podman run --rm catalog:test ls -R /tmp/cache
# Expected: cache files generated by builder stage

# Verify image metadata
podman inspect catalog:test | jq -r '.[0].Config.Labels'
# Expected: All 7 labels present

# Validate image with opm
opm validate catalog:test
```

### Local Testing Approach

**Test registry-server functionality**:
```bash
# Start catalog server locally
podman run -d -p 50051:50051 --name test-catalog catalog:test

# Wait for startup (check logs)
podman logs -f test-catalog
# Expected: "serving registry" or similar ready message

# Test gRPC health probe
grpc_health_probe -addr localhost:50051
# Expected: status: SERVING

# Query catalog content
grpcurl -plaintext localhost:50051 api.Registry/ListPackages
# Expected: JSON response with toolhive-operator package

# Verify bundle metadata
grpcurl -plaintext -d '{"name":"toolhive-operator"}' \
  localhost:50051 api.Registry/GetPackage
# Expected: Package details with fast channel

# Cleanup
podman stop test-catalog && podman rm test-catalog
```

### Kubernetes/OpenShift Deployment Validation

**Test in live cluster**:
```bash
# Push catalog image to registry
podman push catalog:test quay.io/user/toolhive-catalog:test

# Create CatalogSource
cat <<EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-catalog-test
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: quay.io/user/toolhive-catalog:test
  displayName: ToolHive Operator Test Catalog
  publisher: Stacklok
  updateStrategy:
    registryPoll:
      interval: 10m
EOF

# Verify catalog pod is running
kubectl get pods -n openshift-marketplace | grep toolhive-catalog
# Expected: Pod in Running state within 10 seconds

# Check catalog pod logs
kubectl logs -n openshift-marketplace catalogsource-toolhive-catalog-test-xyz
# Expected: "serving registry" message, no errors

# Verify PackageManifest creation
kubectl get packagemanifest toolhive-operator -o yaml
# Expected: Package with fast channel, v0.2.17 bundle reference

# Test operator installation flow
# (Install operator through OperatorHub UI or Subscription CR)
```

**Success Criteria**:
- Catalog pod enters Running state within 10 seconds
- Registry-server responds to gRPC queries within 500ms
- PackageManifest appears in cluster
- Operator visible in OperatorHub UI
- Subscription can install operator successfully

---

## Key Decisions Summary

### Decision 1: Multi-stage Build Pattern
**Chosen**: Two-stage build (builder + runtime) with cache pre-population
**Rationale**: 3-5x faster startup time, build-time validation, proven pattern from reference implementation

### Decision 2: Base Image
**Chosen**: `quay.io/operator-framework/opm:latest` for both stages
**Rationale**: Contains required binaries (/bin/opm, /bin/grpc_health_probe), official operator-framework image

### Decision 3: Directory Structure
**Chosen**: Preserve `ADD catalog /configs` resulting in `/configs/toolhive-operator/catalog.yaml`
**Rationale**: Matches FBC conventions, supports package organization, compatible with registry-server scanning

### Decision 4: Labels
**Chosen**: Preserve all 7 existing labels without modification
**Rationale**: All compatible with executable catalog, OCI labels provide valuable metadata

### Decision 5: Cache Strategy
**Chosen**: Pre-populate cache in builder stage using `--cache-only` flag
**Rationale**: Optimize startup performance, validate at build time, reduce runtime resource usage

### Decision 6: Health Probes
**Chosen**: Include grpc_health_probe configuration in documentation (provided by base image)
**Rationale**: Essential for production deployments, enables Kubernetes liveness/readiness checks

### Decision 7: Validation Workflow
**Chosen**: Multi-layer validation (pre-build, build-time, post-build, local testing, cluster testing)
**Rationale**: Comprehensive verification ensures executable catalog functions correctly before deployment

---

## Alternatives Considered

### Alternative 1: Single-stage Build (No Cache Pre-population)
**Rejected**: Slower startup (5-15s vs 1-3s), runtime overhead, no build-time validation benefits

### Alternative 2: Runtime Cache Generation
**Rejected**: Requires persistent volume for cache, complexity in CatalogSource configuration, slower first startup

### Alternative 3: Flatten Directory Structure
**Rejected**: Breaks FBC package organization conventions, limits future multi-package support

### Alternative 4: Custom Registry Server Implementation
**Rejected**: Violates constraints (must use opm tooling), increased maintenance, security concerns

### Alternative 5: Pinned OPM Version
**Deferred**: Use `:latest` for initial implementation, consider pinning to specific digest for production stability in future enhancement

---

## Risks and Mitigations

### Risk 1: Image Size Increase
**Impact**: Catalog image grows from ~1MB to ~50-80MB
**Mitigation**: Acceptable trade-off for executable functionality; size aligns with industry standard catalog images

### Risk 2: Cache Format Compatibility
**Impact**: OPM version upgrades may invalidate pre-built cache
**Mitigation**: Use `--cache-enforce-integrity=true` to fail fast on cache incompatibility; rebuild image on opm upgrades

### Risk 3: gRPC Client Compatibility
**Impact**: HTTP/1.1 clients cannot query registry-server directly
**Mitigation**: OLM already uses gRPC; no client-side changes needed; document grpcurl for manual testing

### Risk 4: Startup Time Regression
**Impact**: If cache is corrupted, fallback to runtime parsing (slower)
**Mitigation**: Build-time validation ensures cache integrity; Kubernetes health probes detect startup failures

### Risk 5: Multi-package Catalog Expansion
**Impact**: Future multi-package catalogs may require directory restructuring
**Mitigation**: Current nested structure (`/configs/toolhive-operator/`) already supports this pattern

---

## Next Steps

With research complete, proceed to Phase 1 design artifacts:

1. **data-model.md** - Document container image layer structure and file paths
2. **contracts/containerfile-structure.md** - Define multi-stage build contract
3. **quickstart.md** - Create developer usage guide for building and testing
4. **Update agent context** - Run `.specify/scripts/bash/update-agent-context.sh claude`

All decisions documented in this research provide the foundation for implementation in subsequent phases.
