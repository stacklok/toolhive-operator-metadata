# Contract: catalog.yaml Structure

**Feature**: 007-fix-operatorhub-availability
**Purpose**: Define the expected structure of the regenerated catalog.yaml file

## Overview

The catalog.yaml file must be generated using `opm render bundle/` to include all required metadata for OperatorHub display. This contract defines the expected structure.

## File Location

`catalog/toolhive-operator/catalog.yaml`

## Generation Command

```bash
# Generate complete catalog with embedded CSV
opm render bundle/ > catalog/toolhive-operator/catalog.yaml

# Post-process to update bundle image reference
sed -i 's|ghcr.io/stacklok/toolhive/bundle:v0.2.17|quay.io/roddiekieley/toolhive-operator-bundle:v0.2.17|g' catalog/toolhive-operator/catalog.yaml
```

Or via Makefile:

```bash
# Set registry variables
make catalog-generate \
  BUNDLE_REGISTRY=quay.io \
  BUNDLE_ORG=roddiekieley \
  BUNDLE_NAME=toolhive-operator-bundle \
  BUNDLE_TAG=v0.2.17
```

## Required Structure

The generated catalog.yaml MUST contain three schema types in this order:

### 1. Package Schema (olm.package)

```yaml
---
schema: olm.package
name: toolhive-operator
defaultChannel: fast
description: |
  ToolHive Operator manages Model Context Protocol (MCP) servers and registries.

  The operator provides custom resources for:
  - MCPRegistry: Manages registries of MCP server definitions
  - MCPServer: Manages individual MCP server instances

  MCP enables AI assistants to securely access external tools and data sources.
icon:
  base64data: PHN2ZyB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4...
  mediatype: image/svg+xml
```

**Validation**:
- ✅ Must include name, defaultChannel, description, icon
- ✅ Name must match package name in bundle CSV
- ✅ defaultChannel must reference an existing channel

### 2. Channel Schema (olm.channel)

```yaml
---
schema: olm.channel
name: fast
package: toolhive-operator
entries:
  - name: toolhive-operator.v0.2.17
    # Initial release - no replaces/skips
```

**Validation**:
- ✅ Must include name, package, entries array
- ✅ Package must match olm.package name
- ✅ Entries must reference olm.bundle names

### 3. Bundle Schema (olm.bundle) - COMPLETE VERSION

```yaml
---
schema: olm.bundle
name: toolhive-operator.v0.2.17
package: toolhive-operator
image: quay.io/roddiekieley/toolhive-operator-bundle:v0.2.17
properties:
  # Package version property
  - type: olm.package
    value:
      packageName: toolhive-operator
      version: 0.2.17

  # CRD properties (one per CRD)
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

  # *** CRITICAL: CSV as bundle object (this is what was missing!) ***
  - type: olm.bundle.object
    value:
      data: >-
        YXBpVmVyc2lvbjogb3BlcmF0b3JzLmNvcmVvcy5jb20vdjFhbHBoYTEKa2luZDogQ2x1c3Rlcl...
        [Base64-encoded ClusterServiceVersion YAML - typically 5000+ characters]

  # CRDs as bundle objects (one per CRD)
  - type: olm.bundle.object
    value:
      data: >-
        YXBpVmVyc2lvbjogYXBpZXh0ZW5zaW9ucy5rOHMuaW8vdjEKa2luZDogQ3VzdG9tUmVzb3VyY2...
        [Base64-encoded MCPRegistry CRD YAML]

  - type: olm.bundle.object
    value:
      data: >-
        YXBpVmVyc2lvbjogYXBpZXh0ZW5zaW9ucy5rOHMuaW8vdjEKa2luZDogQ3VzdG9tUmVzb3VyY2...
        [Base64-encoded MCPServer CRD YAML]
```

**Validation**:
- ✅ Must include name, package, image, properties array
- ✅ Image must reference quay.io/roddiekieley registry (NOT ghcr.io/stacklok)
- ✅ Properties must include:
  - Exactly one olm.package property with version
  - At least one olm.gvk property per CRD
  - **At least one olm.bundle.object containing the CSV** (critical!)
  - At least one olm.bundle.object per CRD
- ✅ CSV bundle object must contain base64-encoded ClusterServiceVersion manifest
- ✅ CSV must include displayName, description, icon, version, replaces (if applicable)

## Size Expectations

The complete catalog.yaml with embedded CSV and CRDs will be significantly larger than the current version:

- **Current size** (without CSV): ~1.5 KB (53 lines)
- **Expected size** (with CSV): ~15-25 KB (500-800 lines)
- The olm.bundle.object values contain base64-encoded YAML, making them very long

## Validation Commands

```bash
# Validate FBC structure
opm validate catalog/toolhive-operator

# Check bundle image reference
grep "image:" catalog/toolhive-operator/catalog.yaml | grep bundle

# Verify CSV is embedded
grep "olm.bundle.object" catalog/toolhive-operator/catalog.yaml

# Count bundle objects (should be 3: 1 CSV + 2 CRDs)
grep -c "type: olm.bundle.object" catalog/toolhive-operator/catalog.yaml
```

**Expected validation output**:
```
✅ opm validate: no errors
✅ Bundle image: quay.io/roddiekieley/toolhive-operator-bundle:v0.2.17
✅ CSV embedded: olm.bundle.object found
✅ Bundle object count: 3
```

## Contract Guarantees

After regeneration, this catalog.yaml MUST:

1. **Pass OLM validation**: `opm validate catalog/toolhive-operator` succeeds with no errors
2. **Include CSV data**: At least one olm.bundle.object property with base64-encoded CSV
3. **Reference dev registry**: Bundle image uses quay.io/roddiekieley, NOT ghcr.io/stacklok
4. **Maintain package metadata**: Package name, description, icon remain unchanged
5. **Support OperatorHub**: When built into catalog image and deployed, OperatorHub shows operator name and count

## Breaking Changes from Current Version

- **File size increase**: ~1.5 KB → ~15-25 KB (10-15x larger)
- **Structure change**: Adds 3+ olm.bundle.object properties (currently missing)
- **Image reference change**: ghcr.io → quay.io
- **Generation method**: Manual → automated via `opm render`

## Backward Compatibility

- ✅ **OLM compatibility**: Both versions use olm.bundle schema - no breaking API changes
- ✅ **Catalog pod**: Same Containerfile.catalog, just different catalog.yaml content
- ✅ **Deployment**: Same CatalogSource manifest, just different image content
- ⚠️ **Display**: New version shows correctly in OperatorHub, old version doesn't

## Success Criteria

The regenerated catalog.yaml is considered valid when:

1. `opm validate` passes with no errors
2. File contains at least one olm.bundle.object with CSV data
3. Bundle image references quay.io/roddiekieley registry
4. File size is >10 KB (indicating CSV is embedded)
5. Deployed catalog creates PackageManifest with operator name
6. OperatorHub UI shows "ToolHive Operator Catalog" with "(1)" operator count
