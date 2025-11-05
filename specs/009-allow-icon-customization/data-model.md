# Data Model: Custom Icon Support

**Feature**: 009-allow-icon-customization
**Created**: 2025-10-17
**Status**: Design Phase

## Overview

This document defines the data entities, validation rules, and state transitions for custom icon support in OLM bundle and catalog builds.

## Entities

### Icon Metadata

Represents a validated and encoded operator icon ready for embedding in CSV.

**Fields**:

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| file_path | string | Must exist, readable | Absolute or relative path to icon file |
| format | enum | {PNG, JPEG, GIF, SVG} | Detected image format |
| width | integer | 1-80 pixels | Image width in pixels |
| height | integer | 1-40 pixels | Image height in pixels |
| aspect_ratio | float | 0.475-0.525 (1:2 ±5%) | height/width ratio |
| file_size_bytes | integer | >0 | Raw file size before encoding |
| base64_data | string | Valid base64 | Encoded icon data |
| mediatype | string | See format mapping | MIME type for CSV embedding |

**Format-to-MediaType Mapping**:

| Format | MediaType | File Extensions |
|--------|-----------|-----------------|
| PNG | image/png | .png |
| JPEG | image/jpeg | .jpg, .jpeg |
| GIF | image/gif | .gif |
| SVG | image/svg+xml | .svg |

### CSV Icon Specification

Represents the icon field structure in ClusterServiceVersion YAML.

**Structure** (as embedded in CSV):

```yaml
spec:
  icon:
    - base64data: "<base64-encoded-image>"
      mediatype: "<image/format>"
```

**Fields**:

| Field | Type | Source | Description |
|-------|------|--------|-------------|
| base64data | string (base64) | Icon Metadata.base64_data | Single-line base64 without wrapping |
| mediatype | string | Icon Metadata.mediatype | MIME type identifier |

Note: CSV icon is an array with single element per OLM spec.

## Validation Rules

### Format Validation

- **Rule FR-005**: Icon format MUST be one of {PNG, JPEG, GIF, SVG+XML}
- **Detection method**: Use `file` command for MIME type detection
- **Validation tool**: ImageMagick `identify` for format confirmation
- **Error**: Exit code 2, message "Unsupported format 'X'. Use PNG, JPEG, GIF, or SVG only"

### Dimension Validation

- **Rule FR-006**: Width MUST be ≤ 80 pixels
- **Rule FR-006**: Height MUST be ≤ 40 pixels
- **Validation tool**: ImageMagick `identify -format "%w %h"`
- **Error**: Exit code 3, message "Icon dimensions WxH exceed maximum 80x40"

### Aspect Ratio Validation

- **Rule FR-007**: Aspect ratio (height/width) MUST be 1:2 (0.5)
- **Tolerance**: ±5% to accommodate rounding (0.475 - 0.525)
- **Calculation**: aspect_ratio = height / width
- **Examples**:
  - 80x40 → 40/80 = 0.5 ✅ VALID
  - 79x40 → 40/79 = 0.506 ✅ VALID (within tolerance)
  - 60x40 → 40/60 = 0.667 ❌ INVALID (exceeds tolerance)
- **Error**: Exit code 4, message "Icon aspect ratio X must be 1:2 (height:width)"

### File Existence Validation

- **Rule FR-014**: File path MUST exist and be readable
- **Validation**: Shell test `[ -f "$file" ] && [ -r "$file" ]`
- **Error cases**:
  - File not found: Exit code 1, message "Icon file not found: <path>"
  - File unreadable: Exit code 5, message "Cannot read icon file: <path>"

### Encoding Validation

- **Rule FR-008**: Base64 encoding MUST succeed without errors
- **Encoding command**: `base64 -w 0 <file>`
- **Validation**: Check exit code of base64 command
- **Error**: Exit code 5, message "Cannot encode icon file: <path>"

### Size Recommendations

While OLM has no hard file size limit, practical constraints apply:

- **Recommended maximum**: 10 KB raw file size (13.3 KB base64-encoded)
- **Warning threshold**: 50 KB raw file size
- **Rationale**: CSV files become unwieldy with very large embedded data
- **Action**: If >50 KB, emit warning suggesting SVG optimization or dimension reduction

## State Transitions

### Icon Validation State Machine

```
[File Path Provided]
        ↓
    [Validate Existence]
        ↓
    ┌───┴───┐
    NO      YES → [Detect Format]
    ↓                   ↓
[ERROR 1]          ┌────┴────┐
                   Supported  Unsupported
                   ↓              ↓
           [Check Dimensions]  [ERROR 2]
                   ↓
            ┌──────┴──────┐
            OK          Exceeded
            ↓              ↓
     [Check Aspect]    [ERROR 3]
            ↓
        ┌───┴───┐
        OK      BAD
        ↓        ↓
   [Encode]   [ERROR 4]
        ↓
    ┌───┴───┐
    OK      FAIL
    ↓        ↓
 [VALID]  [ERROR 5]
```

### Build Process Integration

```
[make bundle]
      ↓
  BUNDLE_ICON set?
      ↓
  ┌───┴───┐
  NO      YES
  ↓        ↓
[Use     [Validate Icon]
Default]      ↓
  ↓       ┌───┴───┐
  ↓       VALID   INVALID
  ↓       ↓        ↓
  ↓   [Encode]  [BUILD FAILS]
  ↓       ↓
  └───→ [Inject into CSV via yq]
            ↓
     [Continue bundle generation]
```

## Relationships

### Makefile → Icon Validation

- **Trigger**: `make bundle` or `make catalog`
- **Input**: `BUNDLE_ICON` or `CATALOG_ICON` environment variable
- **Process**: Call `scripts/validate-icon.sh <path>`
- **Output**: Exit code (0 = valid, 1-5 = specific errors)
- **Action on success**: Proceed to encoding
- **Action on failure**: Stop build, display error message

### Icon Validation → Icon Encoding

- **Prerequisite**: Validation MUST pass (exit code 0)
- **Input**: Validated icon file path
- **Process**: Call `scripts/encode-icon.sh <path>`
- **Output**: Base64-encoded string to stdout
- **Action**: Capture output for yq injection

### Icon Encoding → CSV Injection

- **Prerequisite**: Encoding MUST succeed
- **Input**: Base64 string + mediatype
- **Process**: yq command to update CSV
- **Target path**: `.spec.icon[0].base64data` and `.spec.icon[0].mediatype`
- **Pattern**:
  ```bash
  yq eval '.spec.icon = [{"base64data": "'$ENCODED'", "mediatype": "'$MEDIATYPE'"}]' -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml
  ```

### Bundle → Catalog Icon Inheritance

- **Default behavior**: Catalog uses same icon as bundle
- **Override**: `CATALOG_ICON` environment variable can specify different icon
- **Implementation**:
  - If `CATALOG_ICON` set: validate and encode catalog icon independently
  - If `CATALOG_ICON` not set and `BUNDLE_ICON` set: reuse bundle icon
  - If neither set: use default icon

## Default Icon Handling

### Current State

- **Location**: `downloaded/toolhive-operator/0.2.17/toolhive-operator.clusterserviceversion.yaml`
- **Embedded icon**: 512x512 SVG with blue background and white "M"
- **Compliance**: ❌ VIOLATES OLM 80x40 recommendation

### Required Action

Create compliant default icon:

- **New location**: `icons/default-icon.svg`
- **Dimensions**: 80x40 pixels
- **Aspect ratio**: 1:2 (exact)
- **Content**: Simplified version of current "M" logo or ToolHive branding
- **Encoding**: Pre-encoded base64 version stored for quick fallback

## Validation Error Messages

All validation errors include actionable guidance:

| Exit Code | Error Message Template | Example |
|-----------|------------------------|---------|
| 0 | (success - no message) | - |
| 1 | Icon file not found: \<path\> | Icon file not found: icons/logo.png |
| 2 | Unsupported format '\<format\>'. Use PNG, JPEG, GIF, or SVG only | Unsupported format 'WebP'. Use PNG, JPEG, GIF, or SVG only |
| 3 | Icon dimensions \<W\>x\<H\> exceed maximum 80x40 | Icon dimensions 100x50 exceed maximum 80x40 |
| 4 | Icon aspect ratio \<ratio\> must be 1:2 (height:width) | Icon aspect ratio 0.67 must be 1:2 (height:width) |
| 5 | Cannot read/encode icon file: \<path\> | Cannot read icon file: /protected/logo.png |

## Performance Constraints

Per NFR-001 and NFR-003:

- **Icon validation**: Must complete in <1 second
- **Build overhead**: Must be <5% of total bundle build time
- **Measurement**: Time from validation start to encoded output ready
- **Typical profile**:
  - File existence check: <1ms
  - Format detection (`file`): ~5ms
  - Dimension extraction (`identify`): ~10ms
  - Base64 encoding: ~5ms
  - Total: ~21ms for 80x40 PNG

**Optimization notes**:
- SVG dimension extraction is faster (text parsing)
- Large files (>100 KB) may exceed 1s budget - emit warning
- Parallel validation (bundle + catalog) not required - sequential OK

## Testing Data Fixtures

Required test icons for validation:

| Fixture | Purpose | Expected Result |
|---------|---------|-----------------|
| valid-png-80x40.png | Valid PNG | PASS (exit 0) |
| valid-svg-80x40.svg | Valid SVG | PASS (exit 0) |
| valid-jpeg-80x40.jpg | Valid JPEG | PASS (exit 0) |
| valid-gif-80x40.gif | Valid GIF | PASS (exit 0) |
| invalid-webp-80x40.webp | Unsupported format | FAIL (exit 2) |
| invalid-100x50.png | Oversized dimensions | FAIL (exit 3) |
| invalid-80x60.png | Wrong aspect ratio | FAIL (exit 4) |
| invalid-512x512.png | Oversized (legacy default) | FAIL (exit 3) |
| corrupted.png | Unreadable file | FAIL (exit 5) |

## References

- OLM Icon Specification: https://github.com/operator-framework/community-operators/blob/master/docs/packaging-required-fields.md
- ClusterServiceVersion Schema: https://github.com/operator-framework/operator-lifecycle-manager/blob/master/doc/design/building-your-csv.md
- Feature Spec: [spec.md](./spec.md)
- Research Decisions: [research.md](./research.md)
