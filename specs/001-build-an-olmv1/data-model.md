# Data Model: OLMv1 File-Based Catalog Bundle

**Feature**: 001-build-an-olmv1
**Date**: 2025-10-07
**Purpose**: Define the structure and relationships of FBC schemas and bundle metadata

## Overview

The OLMv1 File-Based Catalog uses three primary schema types defined by the olm.operatorframework.io specification. This document describes each schema's structure, required fields, relationships, and validation rules.

---

## Schema Hierarchy

```
catalog/
└── toolhive-operator/
    └── catalog.yaml                    # Combined FBC schemas

Schema relationships:
olm.package (1)
    ├─→ defaultChannel: references olm.channel.name
    └─→ packageName: used by olm.bundle.properties

olm.channel (1+)
    ├─→ name: referenced by olm.package.defaultChannel
    ├─→ package: references olm.package.name
    └─→ entries: list of bundle references
        └─→ name: references olm.bundle.name

olm.bundle (1+)
    ├─→ name: unique identifier (format: packageName.vVersion)
    ├─→ package: references olm.package.name
    ├─→ image: container image containing bundle manifests
    └─→ properties: metadata including version, packageName, CRDs
```

---

## Entity: olm.package

**Purpose**: Defines package-level metadata for the operator

**Cardinality**: Exactly one per package

**Required Fields**:
- `schema`: Must be "olm.package"
- `name`: Package identifier (e.g., "toolhive-operator")
- `defaultChannel`: Default update channel (references an olm.channel.name)

**Optional Fields**:
- `description`: Human-readable package description
- `icon`: Package icon metadata
  - `base64data`: Base64-encoded image data
  - `mediatype`: Image MIME type (e.g., "image/png")

**Validation Rules**:
- `name` must be unique across all packages in a catalog
- `defaultChannel` must reference an existing olm.channel.name
- `icon.base64data` must be valid base64 if provided
- `icon.mediatype` must be a valid image MIME type if icon is provided

**Relationships**:
- REFERENCES: olm.channel (via defaultChannel)
- REFERENCED BY: olm.bundle (via bundle.package)

**Example**:
```yaml
schema: olm.package
name: toolhive-operator
defaultChannel: stable
description: ToolHive Operator manages MCP servers and registries
icon:
  base64data: iVBORw0KGgoAAAANS... (base64-encoded image)
  mediatype: image/png
```

---

## Entity: olm.channel

**Purpose**: Defines a release channel with upgrade paths

**Cardinality**: At least one per package

**Required Fields**:
- `schema`: Must be "olm.channel"
- `name`: Channel identifier (e.g., "stable", "candidate")
- `package`: Package name (references olm.package.name)
- `entries`: List of bundle entries in the channel

**Entry Structure** (within entries array):
- `name`: Bundle identifier (references olm.bundle.name)
- `skipRange`: (Optional) Version range to skip during upgrades
- `replaces`: (Optional) Bundle version this entry replaces (for upgrade graph)
- `skips`: (Optional) List of bundle versions to skip over

**Validation Rules**:
- `name` must be unique within a package
- `package` must reference an existing olm.package.name
- `entries` must contain at least one entry
- Each entry.name must reference an existing olm.bundle.name
- Upgrade graph (replaces/skips) must not create cycles
- Version ordering must be consistent with semantic versioning

**Relationships**:
- REFERENCES: olm.package (via package)
- REFERENCES: olm.bundle (via entries[].name)
- REFERENCED BY: olm.package (via defaultChannel)

**Example**:
```yaml
schema: olm.channel
name: stable
package: toolhive-operator
entries:
  - name: toolhive-operator.v0.2.17
    # First version has no replaces/skips
  - name: toolhive-operator.v0.3.0
    replaces: toolhive-operator.v0.2.17
    skipRange: ">=0.2.0 <0.2.17"
```

---

## Entity: olm.bundle

**Purpose**: Defines a specific installable operator version

**Cardinality**: One or more per package

**Required Fields**:
- `schema`: Must be "olm.bundle"
- `name`: Bundle identifier (format: packageName.vVersion)
- `package`: Package name (references olm.package.name)
- `image`: Container image reference containing bundle manifests
- `properties`: Array of property objects

**Required Properties** (within properties array):
1. **Package property**:
   - `type`: "olm.package"
   - `value.packageName`: Package name
   - `value.version`: Semantic version string

2. **GVK property** (one per owned CRD):
   - `type`: "olm.gvk"
   - `value.group`: API group
   - `value.kind`: Resource kind
   - `value.version`: API version

**Optional Properties**:
- **olm.package.required**: External package dependencies
- **olm.gvk.required**: Required CRDs from other operators
- **olm.bundle.object**: Additional bundle objects

**Validation Rules**:
- `name` must follow format: `<packageName>.v<version>`
- `name` must be unique across all bundles
- `package` must reference an existing olm.package.name
- `image` must be a valid container image reference
- `properties` must include at least one olm.package property
- `properties` must include one olm.gvk property per owned CRD
- Version in name must match version in olm.package property
- Image must exist and be accessible at build/deploy time

**Relationships**:
- REFERENCES: olm.package (via package)
- REFERENCED BY: olm.channel (via entries[].name)

**Example**:
```yaml
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

---

## Entity: Bundle (Traditional OLM Format)

**Purpose**: Intermediate format containing operator manifests and metadata

**Location**: `bundle/` directory

**Structure**:
```
bundle/
├── manifests/
│   ├── <operator-name>.clusterserviceversion.yaml
│   ├── <crd-1>.yaml
│   └── <crd-2>.yaml
└── metadata/
    └── annotations.yaml
```

**Key Components**:

### ClusterServiceVersion (CSV)

**Required Fields**:
- `metadata.name`: Format `<operator>.v<version>`
- `spec.displayName`: Human-readable name
- `spec.description`: Operator description
- `spec.version`: Semantic version (must match metadata.name)
- `spec.minKubeVersion`: Minimum Kubernetes version
- `spec.install.spec.deployments`: Deployment specifications
- `spec.install.spec.permissions`: RBAC rules
- `spec.customresourcedefinitions.owned`: Owned CRD definitions

**Recommended Fields**:
- `spec.icon`: Operator icon for UI
- `spec.keywords`: Search keywords
- `spec.maintainers`: Maintainer contacts
- `spec.provider`: Provider organization
- `spec.links`: Documentation/source links
- `spec.maturity`: Release maturity level

**Validation Rules**:
- Version in metadata.name must match spec.version
- All CRDs in customresourcedefinitions.owned must exist in manifests/
- All RBAC permissions must align with operator requirements
- Deployment spec must reference valid container images

### Bundle Annotations

**Required Annotations** (`metadata/annotations.yaml`):
- `operators.operatorframework.io.bundle.mediatype.v1`: "registry+v1"
- `operators.operatorframework.io.bundle.manifests.v1`: "manifests/"
- `operators.operatorframework.io.bundle.metadata.v1`: "metadata/"
- `operators.operatorframework.io.bundle.package.v1`: Package name
- `operators.operatorframework.io.bundle.channels.v1`: Comma-separated channels
- `operators.operatorframework.io.bundle.channel.default.v1`: Default channel

**Validation Rules**:
- Package name must match olm.package.name
- Channels must match olm.channel names
- Default channel must match olm.package.defaultChannel

---

## State Transitions

### Bundle Lifecycle

```
1. [CREATED] Bundle directory generated via operator-sdk
           ↓
2. [RENDERED] FBC schemas generated via opm render
           ↓
3. [VALIDATED] Passes operator-sdk bundle validate
           ↓
4. [CATALOGED] Added to catalog/ directory
           ↓
5. [BUILT] Catalog container image built
           ↓
6. [PUBLISHED] Image pushed to container registry
           ↓
7. [DEPLOYED] OLMv1 cluster installs from catalog
```

### Version Progression in Channel

```
[v0.2.17] → Initial release in stable channel
    ↓
[v0.3.0] → Replaces v0.2.17, skips v0.2.x range
    ↓
[v0.4.0] → Replaces v0.3.0
```

Channels allow multiple progression paths:
- **stable**: Only thoroughly tested versions
- **candidate**: Release candidates (future)
- **fast**: Cutting edge releases (future)

---

## Validation Summary

| Schema/Entity | Primary Validator | Validation Command |
|---------------|-------------------|-------------------|
| bundle/ | operator-sdk | `operator-sdk bundle validate ./bundle --select-optional suite=operatorframework` |
| catalog/ | opm | `opm validate catalog/` |
| FBC schemas | opm | Built-in during `opm render` |
| Catalog image | opm | `opm serve` (starts local registry to test) |
| Overall quality | operator-sdk | `operator-sdk scorecard ./bundle` |

---

## Data Integrity Constraints

1. **Uniqueness**:
   - olm.package.name must be unique in catalog
   - olm.channel.name must be unique within package
   - olm.bundle.name must be unique in catalog

2. **Referential Integrity**:
   - olm.package.defaultChannel → olm.channel.name
   - olm.channel.package → olm.package.name
   - olm.channel.entries[].name → olm.bundle.name
   - olm.bundle.package → olm.package.name

3. **Version Consistency**:
   - Bundle name version matches property version
   - CSV version matches bundle version
   - Upgrade graph follows semantic versioning

4. **Image Accessibility**:
   - All olm.bundle.image references must resolve
   - Bundle images must contain valid manifests
   - Catalog image must be pullable by OLM

---

## Functional Requirements Mapping

| Requirement | Data Model Entity | Validation |
|-------------|------------------|------------|
| FR-001 | catalog/ directory structure | Directory exists, contains package subdirectory |
| FR-002 | olm.package schema | Exactly one per package, all required fields present |
| FR-003 | olm.channel schema | At least one, references valid package |
| FR-004 | olm.bundle schema | One or more, references valid package and image |
| FR-005 | olm.bundle.properties[olm.package].version | Matches semver regex pattern |
| FR-006 | CSV spec.minKubeVersion | Field present in CSV manifest |
| FR-007 | Containerfile.catalog | Image builds with opm |
| FR-008 | All schemas + bundle | operator-sdk validation passes |
| FR-009 | Schema format | .yaml extension, valid YAML syntax |
| FR-010 | olm.bundle.image | Image exists in registry |
| FR-011 | Schema primary keys | Unique (schema, package, name) tuples |
| FR-012 | Bundle manifests + olm.gvk properties | CRDs in bundle match config/crd/ |

---

## Notes

- All FBC schemas can be combined in a single `catalog.yaml` file or split across multiple files
- The opm tool automatically handles schema validation during rendering
- Bundle metadata is ephemeral - only FBC schemas are deployed to clusters
- CRD files in bundle/manifests/ are copies from config/crd/, maintaining constitution III (immutability)
