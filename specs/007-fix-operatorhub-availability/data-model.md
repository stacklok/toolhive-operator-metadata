# Data Model: Fix OperatorHub Availability

**Feature**: 007-fix-operatorhub-availability
**Date**: 2025-10-15

## Overview

This feature works with OLM v1 File-Based Catalog YAML structures and Kubernetes custom resources. The "entities" in this context are YAML manifest objects that define operator catalog metadata and deployment configuration.

---

## Entity: OLM Package (olm.package)

**File**: `catalog/toolhive-operator/catalog.yaml`
**Purpose**: Defines the top-level operator package in the File-Based Catalog

### Fields

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| schema | string | ✅ | Must be "olm.package" | Schema identifier |
| name | string | ✅ | Must match bundle package name | Package name (e.g., "toolhive-operator") |
| defaultChannel | string | ✅ | Must reference existing channel | Default channel for package |
| description | string | ⚠️ Optional | Multi-line YAML string | Package description (not shown in OperatorHub UI) |
| icon.base64data | string | ⚠️ Optional | Valid base64 | Base64-encoded icon image |
| icon.mediatype | string | ⚠️ Optional | MIME type | Icon media type (e.g., "image/svg+xml") |

### Relationships

- **References**: olm.channel via `defaultChannel` field
- **Referenced by**: olm.channel (package field), olm.bundle (package field)

### State Transitions

N/A (static configuration)

### Validation Rules

- `name` must be a valid Kubernetes label value (lowercase, alphanumeric, hyphens, max 63 chars)
- `defaultChannel` must match an existing olm.channel `name` in the same catalog
- If `icon` is provided, both `base64data` and `mediatype` are required

---

## Entity: OLM Channel (olm.channel)

**File**: `catalog/toolhive-operator/catalog.yaml`
**Purpose**: Defines an update channel for the operator package

### Fields

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| schema | string | ✅ | Must be "olm.channel" | Schema identifier |
| name | string | ✅ | Unique within package | Channel name (e.g., "fast", "stable") |
| package | string | ✅ | Must match olm.package name | Package this channel belongs to |
| entries | array | ✅ | Non-empty array of objects | Bundle entries in this channel |
| entries[].name | string | ✅ | Must match olm.bundle name | Bundle name reference |
| entries[].replaces | string | ❌ Optional | Must match another bundle name | Bundle this one replaces |
| entries[].skips | array | ❌ Optional | Array of bundle names | Bundles this one skips |
| entries[].skipRange | string | ❌ Optional | Semver range | Version range this bundle skips |

### Relationships

- **Belongs to**: olm.package (via package field)
- **References**: olm.bundle entries (via entries[].name)

### State Transitions

N/A (static configuration)

### Validation Rules

- `name` must be unique across all channels in the same package
- `package` must match an existing olm.package `name`
- Each `entries[].name` must reference a valid olm.bundle
- For initial releases, `replaces` and `skips` should be omitted

---

## Entity: OLM Bundle (olm.bundle)

**File**: `catalog/toolhive-operator/catalog.yaml`
**Purpose**: Defines a specific operator bundle version with metadata and bundle image reference

### Fields

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| schema | string | ✅ | Must be "olm.bundle" | Schema identifier |
| name | string | ✅ | Unique bundle name | Bundle identifier (e.g., "toolhive-operator.v0.2.17") |
| package | string | ✅ | Must match olm.package name | Package this bundle belongs to |
| image | string | ✅ | Valid container image reference | Bundle image location |
| properties | array | ✅ | Array of property objects | Bundle metadata properties |

### Properties Array

The `properties` array contains typed metadata objects:

#### Property: olm.package (Version)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| type | string | ✅ | Must be "olm.package" |
| value.packageName | string | ✅ | Package name (should match bundle.package) |
| value.version | string | ✅ | Semver version without 'v' prefix (e.g., "0.2.17") |

#### Property: olm.gvk (CRD Reference)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| type | string | ✅ | Must be "olm.gvk" |
| value.group | string | ✅ | API group (e.g., "toolhive.stacklok.dev") |
| value.kind | string | ✅ | Resource kind (e.g., "MCPRegistry") |
| value.version | string | ✅ | API version (e.g., "v1alpha1") |

**Note**: Multiple olm.gvk properties can exist (one per CRD)

#### Property: olm.bundle.object (CSV and CRDs) **[CRITICAL - CURRENTLY MISSING]**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| type | string | ✅ | Must be "olm.bundle.object" |
| value.data | string | ✅ | Base64-encoded YAML of CSV or CRD |

**Purpose**: Contains the actual ClusterServiceVersion (CSV) and CRD manifests embedded in the catalog. This is what OperatorHub reads to display operator name, description, icon, and capabilities.

**Current Issue**: The catalog.yaml is missing olm.bundle.object properties containing the CSV. This causes:
- OperatorHub shows no operator name (uses empty/undefined)
- Operator count shows as 0
- No operator description or capabilities shown
- PackageManifest is incomplete

**Solution**: Use `opm render bundle/` to auto-generate catalog.yaml with embedded CSV

### Relationships

- **Belongs to**: olm.package (via package field)
- **Referenced by**: olm.channel entries (via name)
- **Contains**: ClusterServiceVersion via olm.bundle.object property
- **References**: Bundle image (container registry)

### State Transitions

N/A (static configuration)

### Validation Rules

- `name` should follow convention: `{package-name}.v{version}` (e.g., "toolhive-operator.v0.2.17")
- `package` must match an existing olm.package `name`
- `image` must be a valid container image reference with tag or digest
- `properties` array must contain:
  - Exactly one `olm.package` property with version info
  - At least one `olm.gvk` property (one per CRD provided)
  - At least one `olm.bundle.object` property containing the CSV (currently missing!)
- `value.version` in olm.package property must be valid semver without 'v' prefix

---

## Entity: CatalogSource

**File**: `examples/catalogsource-olmv1.yaml`
**Purpose**: Kubernetes custom resource that deploys the catalog to a cluster

### Fields

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| apiVersion | string | ✅ | "operators.coreos.com/v1alpha1" | API version |
| kind | string | ✅ | "CatalogSource" | Resource kind |
| metadata.name | string | ✅ | Valid k8s name | CatalogSource name |
| metadata.namespace | string | ✅ | Existing namespace | Deployment namespace (typically "openshift-marketplace") |
| spec.sourceType | string | ✅ | "grpc" for FBC | Catalog source type |
| spec.image | string | ✅ | Valid image reference | Catalog image location |
| spec.displayName | string | ✅ | Non-empty string | Display name in OperatorHub Sources section |
| spec.publisher | string | ⚠️ Optional | Non-empty string | Publisher name shown in OperatorHub |
| spec.updateStrategy | object | ⚠️ Optional | Valid update config | How to check for updates |
| spec.priority | integer | ❌ Optional | -100 to 100 | Catalog priority (default: 0) |

### Relationships

- **References**: Catalog container image
- **Creates**: PackageManifest resources (created by OLM based on catalog content)
- **Deployed to**: Namespace (typically openshift-marketplace)

### State Transitions

```
CREATED → PENDING → READY
                  ↓
                ERROR (if image pull fails or catalog invalid)
```

**States**:
- **CREATED**: Resource applied to cluster
- **PENDING**: OLM pulling catalog image and starting pod
- **READY**: Catalog pod running, serving gRPC, PackageManifests created
- **ERROR**: Image pull failure, invalid catalog, or gRPC service unavailable

### Validation Rules

- `metadata.namespace` should be "openshift-marketplace" for OpenShift community catalogs
- `spec.sourceType` must be "grpc" for File-Based Catalogs with registry-server
- `spec.image` must reference a catalog image containing /configs directory and opm serve
- `spec.displayName` is what appears in OperatorHub UI Sources section (separate from package description)

**Current State**: CatalogSource is correctly configured. The issue is in the catalog content (missing CSV), not the CatalogSource resource.

---

## Entity: Subscription

**File**: `examples/subscription.yaml`
**Purpose**: Kubernetes custom resource that installs an operator from a catalog

### Fields

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| apiVersion | string | ✅ | "operators.coreos.com/v1alpha1" | API version |
| kind | string | ✅ | "Subscription" | Resource kind |
| metadata.name | string | ✅ | Valid k8s name | Subscription name |
| metadata.namespace | string | ✅ | Existing namespace | Target namespace for operator |
| spec.channel | string | ✅ | Must match catalog channel | Update channel name |
| spec.name | string | ✅ | Must match package name | Package name to install |
| spec.source | string | ✅ | Must match CatalogSource name | CatalogSource name |
| spec.sourceNamespace | string | ✅ | Must match CatalogSource namespace | CatalogSource namespace |
| spec.installPlanApproval | string | ⚠️ Optional | "Automatic" or "Manual" | Install plan approval mode |

### Relationships

- **References**: CatalogSource (via source and sourceNamespace)
- **References**: Package from catalog (via name)
- **References**: Channel (via channel)
- **Creates**: InstallPlan, ClusterServiceVersion, operator Deployment

### State Transitions

```
CREATED → INSTALLING → UP_TO_DATE
                     ↓
                   FAILED (if source not found or package invalid)
```

### Validation Rules

- `spec.source` must match an existing CatalogSource `metadata.name`
- `spec.sourceNamespace` must match the CatalogSource's `metadata.namespace`
- `spec.name` must match a package name available in the referenced catalog
- `spec.channel` must match a channel defined in that package

**Current Issue**: The example has `sourceNamespace: olm` but CatalogSource is in `openshift-marketplace`

**Fix Required**: Change to `sourceNamespace: openshift-marketplace`

---

## Key Entity Relationships

```
CatalogSource (examples/catalogsource-olmv1.yaml)
    ├─ References: Catalog Image (quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17)
    └─ Creates: PackageManifest resources based on catalog content

Catalog Image
    └─ Contains: catalog.yaml

catalog.yaml
    ├─ olm.package (toolhive-operator)
    │   └─ defaultChannel: "fast"
    ├─ olm.channel (fast)
    │   └─ entries[]
    │       └─ name: "toolhive-operator.v0.2.17"
    └─ olm.bundle (toolhive-operator.v0.2.17)
        ├─ image: quay.io/roddiekieley/toolhive-operator-bundle:v0.2.17
        └─ properties[]
            ├─ olm.package (version: 0.2.17)
            ├─ olm.gvk (MCPRegistry)
            ├─ olm.gvk (MCPServer)
            └─ olm.bundle.object [MISSING - CAUSES OPERATORHUB ISSUE]
                └─ CSV (ClusterServiceVersion with displayName, description, icon)

Subscription (examples/subscription.yaml)
    ├─ References: CatalogSource (toolhive-catalog)
    ├─ References: sourceNamespace [WRONG VALUE - NEEDS FIX]
    └─ References: Package (toolhive-operator) from catalog
```

---

## Changes Required

### 1. catalog.yaml - Regenerate with CSV Embedded

**Current State**: Manually created, missing olm.bundle.object properties
**Target State**: Generated via `opm render bundle/` with full CSV embedded
**Change**: Replace entire catalog.yaml with output from `opm render bundle/ > catalog/toolhive-operator/catalog.yaml`
**Impact**: Adds ~100-200 lines of base64-encoded CSV data to olm.bundle properties

### 2. catalog.yaml - Update Bundle Image Reference

**Field**: `olm.bundle[].image`
**Current**: `ghcr.io/stacklok/toolhive/bundle:v0.2.17`
**Target**: `quay.io/roddiekieley/toolhive-operator-bundle:v0.2.17`
**Change**: Update image reference to development registry
**Note**: If using `opm render`, this is handled via Makefile BUNDLE_IMG variable

### 3. examples/catalogsource-olmv1.yaml - Update Catalog Image

**Field**: `spec.image`
**Current**: `ghcr.io/stacklok/toolhive/catalog:v0.2.17`
**Target**: `quay.io/roddiekieley/toolhive-operator-catalog:v0.2.17`
**Change**: Point to development registry catalog image

### 4. examples/subscription.yaml - Fix Source Namespace

**Field**: `spec.sourceNamespace`
**Current**: `olm`
**Target**: `openshift-marketplace`
**Change**: Correct namespace to match where CatalogSource is deployed
**Impact**: Subscription will successfully find the catalog

---

## Validation Strategy

### OLM Catalog Validation
```bash
# Validate catalog structure
opm validate catalog/toolhive-operator

# Expected output: no errors, confirmation of valid FBC
```

### CatalogSource Deployment Validation
```bash
# Check CatalogSource status
kubectl get catalogsource -n openshift-marketplace toolhive-catalog -o yaml

# Expected: status.connectionState.lastObservedState = "READY"
```

### PackageManifest Validation
```bash
# Verify PackageManifest creation
kubectl get packagemanifest -n openshift-marketplace toolhive-operator

# Expected: NAME = toolhive-operator, CATALOG = ToolHive Operator Catalog, AGE = <time>
```

### OperatorHub UI Validation
- Navigate to OperatorHub → Sources
- Verify "ToolHive Operator Catalog" appears with "(1)" operator count
- Click catalog entry
- Verify "ToolHive Operator" appears with description and icon

---

## Migration Path

This is not a data migration - it's a metadata correction:

1. Update catalog.yaml using `opm render`
2. Update example files with corrected values
3. Rebuild catalog container image
4. Deploy updated CatalogSource
5. Verify PackageManifest creation
6. Confirm OperatorHub UI display

No existing deployments are affected - only new catalog deployments will see the fixes.
