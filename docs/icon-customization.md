# Icon Customization Guide

This guide covers the complete icon customization feature for OLM bundles and catalogs in the ToolHive Operator metadata repository.

## Overview

The icon customization feature allows you to specify custom operator icons for OLM bundles and File-Based Catalogs (FBC), with automatic validation against OLM requirements.

**Feature specification**: [specs/009-allow-icon-customization/spec.md](../specs/009-allow-icon-customization/spec.md)

## Quick Start

### Basic Usage (Single Icon)

```bash
# Validate your icon
make validate-icon ICON_FILE=/path/to/your-icon.png

# Build bundle with custom icon
make bundle BUNDLE_ICON=/path/to/your-icon.png

# Build catalog (inherits icon from bundle)
make catalog
```

### Advanced Usage (Separate Icons)

```bash
# Use different icons for bundle and catalog
make bundle BUNDLE_ICON=/path/to/bundle-icon.png
make catalog CATALOG_ICON=/path/to/catalog-icon.svg
```

### Example Workflow

Run the complete workflow with the example script:

```bash
# Using default icon
scripts/example-icon-workflow.sh

# Using custom icon
scripts/example-icon-workflow.sh /path/to/your-icon.png

# Using separate bundle and catalog icons
scripts/example-icon-workflow.sh /path/to/bundle.png /path/to/catalog.svg
```

## Icon Requirements

### OLM Specifications

Icons must meet the following requirements to be accepted by OLM:

- **Maximum dimensions**: 80px width × 40px height
- **Aspect ratio**: 1:2 (±5% tolerance)
- **Supported formats**:
  - PNG (image/png)
  - JPEG (image/jpeg)
  - GIF (image/gif)
  - SVG (image/svg+xml)

### Why These Limits?

- **80×40 size**: OLM recommendation for consistent UI rendering across OperatorHub
- **1:2 aspect ratio**: Standard for operator package logos in Kubernetes ecosystem
- **Format support**: All web-safe image formats are supported

## Validation

### Automatic Validation

When you build a bundle with `BUNDLE_ICON` or a catalog with `CATALOG_ICON`, validation runs automatically:

```bash
make bundle BUNDLE_ICON=/path/to/icon.png
# Automatically validates icon before encoding
```

### Manual Validation

Validate an icon before building:

```bash
make validate-icon ICON_FILE=/path/to/icon.png
```

**Exit codes**:
- `0` - Icon is valid
- `1` - File not found or unreadable
- `2` - Unsupported format
- `3` - Dimensions exceed 80×40
- `4` - Aspect ratio incorrect (not 1:2 ±5%)
- `5` - File corrupted

### Validation Details

The validation script checks:

1. **File existence and readability**
2. **Format** (via `file` command MIME type detection)
3. **Dimensions** (via ImageMagick `identify`)
4. **Aspect ratio** (calculated with `bc`)

**Example output**:

```
Validating icon: tests/icons/valid-png-80x40.png
✅ Icon validation passed
```

**Error example**:

```
Validating icon: tests/icons/invalid-100x50.png
ERROR: Icon dimensions 100x50 exceed maximum 80x40
```

## Icon Encoding

Icons are base64-encoded for embedding in YAML manifests.

### Manual Encoding

```bash
scripts/encode-icon.sh /path/to/icon.png
```

**Output**: Base64-encoded string (stdout)
**Metadata**: `MEDIATYPE:image/png` (stderr)

### Cross-Platform Compatibility

The encoding script handles platform differences:

- **Linux**: Uses `base64 -w 0` (no line wrapping)
- **macOS**: Uses `base64 -i` (default unwrapped output)

## Icon Propagation

### Bundle Icon Flow

1. **Makefile `bundle` target** receives `BUNDLE_ICON` parameter
2. **Validation** runs via `scripts/validate-icon.sh`
3. **Encoding** runs via `scripts/encode-icon.sh`
4. **Injection** into CSV via `yq` at `.spec.icon[0]`

**Result**: Icon embedded in `bundle/manifests/toolhive-operator.clusterserviceversion.yaml`

### Catalog Icon Flow

#### Default Behavior (Inheritance)

1. **Makefile `catalog` target** runs `opm render bundle/`
2. **opm** embeds entire CSV (including icon) into catalog's `olm.bundle.object`
3. **Catalog** inherits bundle icon automatically

**Result**: No CATALOG_ICON needed for most use cases

#### Advanced (Separate Icon)

1. **Makefile `catalog` target** receives `CATALOG_ICON` parameter
2. **Validation** runs via `scripts/validate-icon.sh`
3. **Encoding** runs via `scripts/encode-icon.sh`
4. **Injection** into catalog package schema at `.icon`

**Result**: Catalog package icon differs from bundle CSV icon

### Where Icons Appear

- **Bundle CSV icon** (`.spec.icon[0]`):
  - OperatorHub operator detail pages
  - Operator installation wizards
  - Installed operator listings

- **Catalog package icon** (olm.package schema `.icon`):
  - OperatorHub package search results
  - CatalogSource listings
  - Package-level branding

## Creating Custom Icons

### Using ImageMagick

Resize existing images:

```bash
# Resize to exactly 80×40 (forced aspect ratio)
convert large-logo.png -resize 80x40! icon-80x40.png

# Resize maintaining aspect ratio (may be smaller than 80×40)
convert large-logo.png -resize 80x40 icon-80x40.png

# Add padding to maintain ratio
convert large-logo.png -resize 80x40 -gravity center -extent 80x40 icon-80x40.png
```

### Creating SVG Icons

OLM-compliant SVG template:

```xml
<svg width="80" height="40" xmlns="http://www.w3.org/2000/svg">
  <rect width="80" height="40" fill="#007fff"/>
  <text x="50%" y="50%" font-size="24" fill="white"
        text-anchor="middle" dominant-baseline="middle">
    Your Text
  </text>
</svg>
```

Save as `custom-icon.svg` and validate:

```bash
make validate-icon ICON_FILE=custom-icon.svg
```

## Troubleshooting

### Icon Validation Fails

**Error**: `Icon dimensions 100x50 exceed maximum 80x40`

**Solution**: Resize image to 80×40 or smaller:

```bash
convert icon.png -resize 80x40! icon-80x40.png
make validate-icon ICON_FILE=icon-80x40.png
```

### Aspect Ratio Error

**Error**: `Icon aspect ratio 0.333 must be 1:2`

**Solution**: Crop or pad image to 1:2 ratio (height = width / 2):

```bash
# Crop to 80×40
convert icon.png -gravity center -crop 80x40+0+0 icon-80x40.png

# Or pad with white background
convert icon.png -gravity center -background white -extent 80x40 icon-80x40.png
```

### Unsupported Format

**Error**: `Unsupported format 'image/webp'`

**Solution**: Convert to PNG, JPEG, GIF, or SVG:

```bash
convert icon.webp icon.png
```

### Missing Dependencies

**Error**: `ImageMagick 'identify' command not found`

**Solution**: Install ImageMagick:

```bash
# Fedora/RHEL
sudo dnf install imagemagick

# Ubuntu/Debian
sudo apt install imagemagick

# macOS
brew install imagemagick
```

Check dependencies:

```bash
make check-icon-deps
```

## Best Practices

### Icon Design

1. **Simple designs**: Icons are small (80×40), avoid complex details
2. **High contrast**: Ensure visibility on light and dark backgrounds
3. **Text readability**: Use font size ≥24px for SVG text
4. **Brand colors**: Use your organization's brand palette

### File Selection

- **SVG preferred**: Scales well, small file size
- **PNG for photos**: Use for photographic content
- **GIF for animations**: Supported but animations may not display in all contexts
- **JPEG for gradients**: Better compression for gradient backgrounds

### Workflow Tips

1. **Validate early**: Check icon before building bundle
2. **Use defaults**: Let catalog inherit from bundle unless branding requires separation
3. **Version control**: Store source icons (pre-resized) in version control
4. **Test locally**: Use `make catalog-test-local` to verify icon rendering

## Advanced Topics

### Multiple Bundle Versions

When maintaining multiple operator versions in the catalog:

```bash
# Build v0.2.17 bundle
make bundle BUNDLE_ICON=icons/v0.2.17-icon.svg

# Update catalog with new bundle
make catalog

# Catalog now contains multiple bundles, each with its own icon
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
- name: Validate and build bundle with custom icon
  run: |
    make check-icon-deps
    make validate-icon ICON_FILE=icons/prod-icon.png
    make bundle BUNDLE_ICON=icons/prod-icon.png
    make catalog
    make catalog-build
```

### Icon Inheritance Override

To override inherited icon in catalog package schema:

```bash
# Bundle uses PNG
make bundle BUNDLE_ICON=icons/bundle.png

# Catalog uses different SVG (overrides inheritance in package schema)
make catalog CATALOG_ICON=icons/catalog.svg
```

**Note**: The catalog will still contain the bundle's embedded PNG icon in `olm.bundle.object`, but the package-level listing will show the SVG.

## Technical Reference

### Files and Scripts

- **[icons/README.md](../icons/README.md)** - Icon asset documentation
- **[scripts/validate-icon.sh](../scripts/validate-icon.sh)** - Validation script
- **[scripts/encode-icon.sh](../scripts/encode-icon.sh)** - Encoding script
- **[scripts/example-icon-workflow.sh](../scripts/example-icon-workflow.sh)** - Example workflow
- **[Makefile](../Makefile)** - Bundle and catalog targets (lines 79-97, 156-172)

### Makefile Parameters

| Parameter | Target | Description |
|-----------|--------|-------------|
| `BUNDLE_ICON` | `bundle` | Path to custom icon for CSV |
| `CATALOG_ICON` | `catalog` | Path to custom icon for package schema |
| `ICON_FILE` | `validate-icon` | Path to icon for validation |

### Dependencies

| Tool | Purpose | Installation |
|------|---------|--------------|
| `yq` (v4+) | YAML processing | `brew install yq` / `dnf install yq` |
| `imagemagick` | Image validation | `brew install imagemagick` / `dnf install imagemagick` |
| `file` | MIME type detection | Usually pre-installed |
| `bc` | Aspect ratio calculation | Usually pre-installed |

## Related Documentation

- **Feature Specification**: [specs/009-allow-icon-customization/spec.md](../specs/009-allow-icon-customization/spec.md)
- **Implementation Plan**: [specs/009-allow-icon-customization/plan.md](../specs/009-allow-icon-customization/plan.md)
- **Task Breakdown**: [specs/009-allow-icon-customization/tasks.md](../specs/009-allow-icon-customization/tasks.md)
- **Icon Assets**: [icons/README.md](../icons/README.md)
- **Main README**: [README.md](../README.md)

## Support

For issues or questions about icon customization:

1. Check [Troubleshooting](#troubleshooting) section above
2. Review [OLM Icon Guidelines](https://github.com/operator-framework/community-operators/blob/master/docs/packaging-required-fields.md#icon)
3. Open an issue in the repository
