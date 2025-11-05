# Data Model: Operator Registry Index Images

**Feature**: Registry Database Container Image (Index Image)
**Date**: 2025-10-10
**Status**: Design Complete

## Overview

This document defines the data structures, metadata schemas, and relationships for operator registry index/catalog images. Based on research findings, we distinguish between OLMv1 File-Based Catalog images and OLMv0 SQLite-based index images.

## Entity Definitions

### 1. OLMv1 Catalog Image (File-Based Catalog)

**Description**: A container image containing File-Based Catalog (FBC) metadata in YAML/JSON format, served via gRPC API when referenced by a CatalogSource.

**Image Structure**:
```
Container Image: ghcr.io/stacklok/toolhive/catalog:v0.2.17
│
├── FROM scratch                                    # Base layer (immutable, data-only)
├── ADD catalog /configs                            # FBC metadata directory
│   └── toolhive-operator/
│       └── catalog.yaml                            # FBC schema file
│
└── LABEL operators.operatorframework.io.index.configs.v1=/configs
```

**Key Attributes**:
- **Image Name**: `ghcr.io/stacklok/toolhive/catalog`
- **Tag**: `v{operator-version}` (e.g., `v0.2.17`)
- **Base Image**: `scratch` (data-only, no runtime)
- **Content**: FBC YAML/JSON files in `/configs` directory
- **Discovery Label**: `operators.operatorframework.io.index.configs.v1=/configs`
- **Format**: File-Based Catalog (OLMv1)
- **OpenShift Versions**: 4.19+ (modern OLM)
- **CatalogSource Type**: `grpc` with `image:` reference

**Metadata Schema** (catalog.yaml):
```yaml
---
schema: olm.package
name: toolhive-operator
defaultChannel: fast
description: |
  ToolHive Operator manages MCP (Model Context Protocol) servers
  and registries in Kubernetes/OpenShift environments.

---
schema: olm.channel
package: toolhive-operator
name: fast
entries:
  - name: toolhive-operator.v0.2.17

---
schema: olm.bundle
name: toolhive-operator.v0.2.17
package: toolhive-operator
image: ghcr.io/stacklok/toolhive/operator:v0.2.17
properties:
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
  - type: olm.package
    value:
      packageName: toolhive-operator
      version: 0.2.17
  - type: olm.csv.metadata
    value:
      displayName: ToolHive Operator
      description: Manages MCP servers and registries
      minKubeVersion: 1.21.0
```

**Relationships**:
- **References**: Operator container image (`ghcr.io/stacklok/toolhive/operator:v0.2.17`)
- **Referenced By**: CatalogSource custom resource
- **Contains**: Package, Channel, and Bundle metadata schemas
- **Served By**: N/A (FBC is data-only, served by CatalogSource pod)

**Validation Rules**:
- Must contain at least one `olm.package` schema
- Each package must have at least one `olm.channel`
- Each channel must reference at least one `olm.bundle`
- Bundle names in channel entries must match bundle schema names
- Label `operators.operatorframework.io.index.configs.v1` must point to valid directory

**State Transitions**: N/A (immutable image)

---

### 2. OLMv0 Index Image (SQLite-Based)

**Description**: A container image containing a SQLite database index that references OLMv0 bundle images. Built using deprecated `opm index add` command for legacy OpenShift compatibility.

**Image Structure**:
```
Container Image: ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
│
├── FROM quay.io/operator-framework/opm:latest      # Base with opm binary
├── SQLite Database: /database/index.db             # Operator metadata database
│   ├── Table: package
│   ├── Table: channel
│   ├── Table: bundle
│   ├── Table: operatorbundle
│   └── Table: related_image
│
├── Bundle References:
│   └── ghcr.io/stacklok/toolhive/bundle:v0.2.17   # External bundle image
│
└── LABEL operators.operatorframework.io.index.database.v1=/database/index.db
```

**Key Attributes**:
- **Image Name**: `ghcr.io/stacklok/toolhive/index-olmv0`
- **Tag**: `v{operator-version}` (e.g., `v0.2.17`)
- **Base Image**: `quay.io/operator-framework/opm:latest` (includes gRPC server)
- **Content**: SQLite database at `/database/index.db`
- **Discovery Label**: `operators.operatorframework.io.index.database.v1=/database/index.db`
- **Format**: SQLite-based index (OLMv0, deprecated)
- **OpenShift Versions**: 4.15-4.18 (legacy OLM)
- **CatalogSource Type**: `grpc` with `image:` reference

**Database Schema** (conceptual, managed by opm):
```
Table: package
├── name: "toolhive-operator"
├── default_channel: "fast"
└── description: "ToolHive Operator manages MCP servers and registries"

Table: channel
├── package_name: "toolhive-operator"
├── name: "fast"
└── head_operatorbundle_name: "toolhive-operator.v0.2.17"

Table: bundle (operatorbundle)
├── name: "toolhive-operator.v0.2.17"
├── package: "toolhive-operator"
├── channel: "fast"
├── bundlepath: "ghcr.io/stacklok/toolhive/bundle:v0.2.17"
├── csv_name: "toolhive-operator.v0.2.17"
└── version: "0.2.17"

Table: related_image
├── operatorbundle_name: "toolhive-operator.v0.2.17"
├── image: "ghcr.io/stacklok/toolhive/operator:v0.2.17"
└── image: "ghcr.io/stacklok/toolhive/proxyrunner:v0.2.17"
```

**Relationships**:
- **References**: OLMv0 bundle image (`ghcr.io/stacklok/toolhive/bundle:v0.2.17`)
- **Bundle Contains**: CSV, CRDs, metadata for single operator version
- **Referenced By**: CatalogSource custom resource
- **Served By**: `opm` gRPC server (runs as CatalogSource pod)

**Validation Rules**:
- SQLite database must be queryable via `opm index export`
- Database must contain valid package, channel, and bundle entries
- Bundle image references must be valid and pullable
- Label `operators.operatorframework.io.index.database.v1` must point to valid database file

**State Transitions**: N/A (immutable image, deprecated format)

**Deprecation Notice**:
```
⚠️ SQLite-based index images are DEPRECATED by operator-framework.
Use only for legacy OpenShift 4.15-4.18 compatibility.
Migrate to File-Based Catalogs for modern deployments.
```

---

### 3. OLMv0 Bundle Image (Reference)

**Description**: A data-only container image containing operator manifests (CSV, CRDs) and metadata for a single operator version. Must be wrapped in an index image before use.

**Image Structure** (from spec 002):
```
Container Image: ghcr.io/stacklok/toolhive/bundle:v0.2.17
│
├── FROM scratch                                    # Base layer (data-only)
├── ADD bundle/manifests /manifests/                # CSV and CRDs
│   ├── toolhive-operator.clusterserviceversion.yaml
│   ├── mcpregistries.toolhive.stacklok.dev.crd.yaml
│   └── mcpservers.toolhive.stacklok.dev.crd.yaml
│
├── ADD bundle/metadata /metadata/                  # OLM metadata
│   └── annotations.yaml
│
└── LABELS:
    ├── operators.operatorframework.io.bundle.mediatype.v1=registry+v1
    ├── operators.operatorframework.io.bundle.manifests.v1=manifests/
    ├── operators.operatorframework.io.bundle.metadata.v1=metadata/
    ├── operators.operatorframework.io.bundle.package.v1=toolhive-operator
    ├── operators.operatorframework.io.bundle.channels.v1=fast
    └── operators.operatorframework.io.bundle.channel.default.v1=fast
```

**Key Attributes**:
- **Image Name**: `ghcr.io/stacklok/toolhive/bundle`
- **Tag**: `v{operator-version}` (e.g., `v0.2.17`)
- **Base Image**: `scratch` (data-only)
- **Content**: Manifests (`/manifests/`) and metadata (`/metadata/`)
- **Discovery Labels**: Multiple `operators.operatorframework.io.bundle.*` labels
- **Format**: OLMv0 Bundle
- **Usage**: Must be referenced by OLMv0 index image, **not used directly** in CatalogSource

**Relationships**:
- **Referenced By**: OLMv0 index image (via `opm index add --bundles`)
- **Contains**: CSV, CRDs, annotations for single operator version
- **Cannot Be Used**: Directly in CatalogSource (must be wrapped in index)

---

### 4. CatalogSource Custom Resource

**Description**: Kubernetes custom resource that references a catalog/index image and makes operators available in OperatorHub.

**Schema**:
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: string                      # Catalog name (e.g., "toolhive-catalog")
  namespace: string                 # Typically "olm" or "openshift-marketplace"
spec:
  sourceType: grpc                  # Always "grpc" for image-based catalogs
  image: string                     # Catalog or index image reference
  displayName: string               # Human-readable name for OperatorHub
  publisher: string                 # Organization name
  updateStrategy:
    registryPoll:
      interval: duration            # Update check interval (e.g., "15m", "30m")
  priority: int                     # Optional: catalog priority for conflict resolution
```

**Variations by Format**:

**OLMv1 (FBC Catalog)**:
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-catalog-olmv1
  namespace: olm
spec:
  sourceType: grpc
  image: ghcr.io/stacklok/toolhive/catalog:v0.2.17          # FBC catalog image
  displayName: ToolHive Operator Catalog (OLMv1)
  publisher: Stacklok
  updateStrategy:
    registryPoll:
      interval: 15m
```

**OLMv0 (SQLite Index)**:
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-catalog-olmv0
  namespace: olm
spec:
  sourceType: grpc
  image: ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17      # SQLite index image
  displayName: ToolHive Operator Catalog (OLMv0)
  publisher: Stacklok
  updateStrategy:
    registryPoll:
      interval: 30m
```

**Key Differences**:
- **Image reference**: FBC catalog vs SQLite index
- **Naming convention**: Distinct names to avoid conflicts
- **Display name**: Clearly indicates format for administrators

**Validation Rules**:
- `sourceType` must be `grpc` for image-based catalogs
- `image` must reference a valid catalog or index image
- `namespace` must exist and have appropriate permissions
- Image must be pullable by cluster (credentials if private registry)

**State Transitions**:
```
Created → Pending (pulling image) → Ready (serving catalog) → Failed (if image pull fails)
         ↓
         ↑ (polling for updates if updateStrategy.registryPoll configured)
```

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          OLMv1 (Modern) Path                            │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│ OLMv1 Catalog Image  │  ghcr.io/stacklok/toolhive/catalog:v0.2.17
│ (File-Based Catalog) │
│                      │  Contains:
│ /configs/            │  - olm.package schemas
│   toolhive-operator/ │  - olm.channel schemas
│     catalog.yaml     │  - olm.bundle schemas
└──────────┬───────────┘
           │ Referenced by
           ▼
┌──────────────────────┐
│   CatalogSource      │  toolhive-catalog-olmv1
│   (olmv1)            │
│                      │  spec:
│ sourceType: grpc     │    image: ghcr.io/stacklok/toolhive/catalog:v0.2.17
│ namespace: olm       │
└──────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                        OLMv0 (Legacy) Path                              │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│ OLMv0 Bundle Image   │  ghcr.io/stacklok/toolhive/bundle:v0.2.17
│                      │
│ /manifests/          │  Contains:
│   - CSV              │  - ClusterServiceVersion
│   - CRDs             │  - CustomResourceDefinitions
│ /metadata/           │  - annotations.yaml
└──────────┬───────────┘
           │ Referenced by (opm index add)
           ▼
┌──────────────────────┐
│ OLMv0 Index Image    │  ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
│ (SQLite-based)       │
│                      │  Contains:
│ /database/index.db   │  - SQLite database
│                      │  - Package/Channel/Bundle tables
└──────────┬───────────┘
           │ Referenced by
           ▼
┌──────────────────────┐
│   CatalogSource      │  toolhive-catalog-olmv0
│   (olmv0)            │
│                      │  spec:
│ sourceType: grpc     │    image: ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
│ namespace: olm       │
└──────────────────────┘
```

---

## Data Constraints

### Version Constraints

| Entity | Version Format | Example | Constraint |
|--------|---------------|---------|------------|
| OLMv1 Catalog Image | `v{semver}` | `v0.2.17` | Must match operator version |
| OLMv0 Index Image | `v{semver}` | `v0.2.17` | Must match bundle version |
| OLMv0 Bundle Image | `v{semver}` | `v0.2.17` | Must match CSV version |
| Operator Image | `v{semver}` | `v0.2.17` | Referenced by catalog/bundle |

**Rule**: All images for a given release share the same version tag to maintain consistency.

### Naming Constraints

| Entity | Pattern | Example | Notes |
|--------|---------|---------|-------|
| OLMv1 Catalog | `{registry}/{org}/{project}/catalog` | `ghcr.io/stacklok/toolhive/catalog` | No format suffix |
| OLMv0 Index | `{registry}/{org}/{project}/index-olmv0` | `ghcr.io/stacklok/toolhive/index-olmv0` | Explicit format suffix |
| OLMv0 Bundle | `{registry}/{org}/{project}/bundle` | `ghcr.io/stacklok/toolhive/bundle` | No format suffix |

**Rule**: Format suffix `-olmv0` explicitly marks deprecated SQLite-based images.

### OpenShift Version Constraints

| Image Type | OpenShift Versions | OLM Version | Status |
|------------|-------------------|-------------|--------|
| OLMv1 Catalog (FBC) | 4.19+ | OLMv1 | ✅ Active, recommended |
| OLMv0 Index (SQLite) | 4.15-4.18 | OLMv0 | ⚠️ Deprecated, temporary support |

**Rule**: Use OLMv1 for all modern deployments; use OLMv0 only for legacy compatibility.

### Format Exclusivity Constraint

**Critical Rule**: An operator version **MUST NOT** be distributed in both OLMv0 index and OLMv1 catalog formats **if they reference the same cluster**.

**Rationale**: OLM may behave unpredictably if it discovers the same operator version via multiple catalog formats.

**Enforcement**:
- Separate CatalogSource names (`toolhive-catalog-olmv1` vs `toolhive-catalog-olmv0`)
- Clear documentation on which format to use for each OpenShift version
- Separate Makefile targets prevent accidental dual builds

---

## Metadata Schemas

### OLMv1 FBC Package Schema

```yaml
schema: olm.package
name: string                        # Package name (e.g., "toolhive-operator")
defaultChannel: string              # Default channel (e.g., "fast", "stable")
description: string                 # Package description (optional)
icon:                               # Package icon (optional)
  base64data: string
  mediatype: string
```

### OLMv1 FBC Channel Schema

```yaml
schema: olm.channel
package: string                     # Must match olm.package name
name: string                        # Channel name (e.g., "fast", "stable")
entries:                            # Ordered list of bundle versions
  - name: string                    # Bundle name (e.g., "my-operator.v1.0.0")
    replaces: string                # Previous bundle (optional, for upgrades)
    skips: []string                 # Skippable versions (optional)
    skipRange: string               # Version range to skip (optional)
```

### OLMv1 FBC Bundle Schema

```yaml
schema: olm.bundle
name: string                        # Bundle name (must match channel entry)
package: string                     # Must match olm.package name
image: string                       # Operator image reference
properties:                         # List of bundle properties
  - type: olm.gvk                   # Provided CRD
    value:
      group: string
      kind: string
      version: string
  - type: olm.package               # Package metadata
    value:
      packageName: string
      version: string
  - type: olm.csv.metadata          # CSV metadata
    value:
      displayName: string
      description: string
      minKubeVersion: string
```

### OLMv0 Bundle Annotations (metadata/annotations.yaml)

```yaml
annotations:
  operators.operatorframework.io.bundle.mediatype.v1: registry+v1
  operators.operatorframework.io.bundle.manifests.v1: manifests/
  operators.operatorframework.io.bundle.metadata.v1: metadata/
  operators.operatorframework.io.bundle.package.v1: string       # Package name
  operators.operatorframework.io.bundle.channels.v1: string      # Comma-separated channels
  operators.operatorframework.io.bundle.channel.default.v1: string
  operators.operatorframework.io.metrics.builder: operator-sdk-v1.x.x
  operators.operatorframework.io.metrics.mediatype.v1: metrics+v1
  operators.operatorframework.io.metrics.project_layout: go.kubebuilder.io/v4
```

---

## Summary

This data model defines three distinct container image types used in operator distribution:

1. **OLMv1 Catalog Image**: Modern, file-based, recommended for OpenShift 4.19+
2. **OLMv0 Index Image**: Legacy, SQLite-based, deprecated, used only for OpenShift 4.15-4.18 compatibility
3. **OLMv0 Bundle Image**: Reference-only, wrapped by index image, not used directly

Each image type has specific structure, metadata schemas, validation rules, and CatalogSource integration patterns. The key insight from research is that **OLMv1 catalog images do not need an additional index wrapper** - they are already complete catalog/index images ready for CatalogSource consumption.
