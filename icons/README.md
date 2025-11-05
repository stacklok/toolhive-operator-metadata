# Operator Icons

This directory contains icon assets for the ToolHive Operator's OLM bundle and catalog.

## Default Icon

**File**: `default-icon.svg`

- **Dimensions**: 80px × 40px
- **Format**: SVG (image/svg+xml)
- **Design**: Blue background (#007fff) with white "M" text
- **Compliance**: Meets OLM recommended size (80×40) and aspect ratio (1:2)

This icon is automatically used when building the bundle and catalog if no custom icon is specified.

## Custom Icons

### OLM Requirements

Custom icons must meet the following requirements:

- **Maximum dimensions**: 80px width × 40px height
- **Aspect ratio**: 1:2 (±5% tolerance: 0.475 to 0.525)
- **Supported formats**:
  - PNG (image/png)
  - JPEG (image/jpeg)
  - GIF (image/gif)
  - SVG (image/svg+xml)

### Usage

#### Using the Same Icon for Both Bundle and Catalog

Specify a custom icon when building the bundle:

```bash
make bundle BUNDLE_ICON=/path/to/your-icon.png
```

The catalog automatically inherits the icon from the bundle via `opm render`:

```bash
make catalog  # Uses icon from bundle
```

#### Using Different Icons for Bundle and Catalog

For advanced use cases, you can specify separate icons:

```bash
# Use PNG for bundle (embedded in CSV)
make bundle BUNDLE_ICON=/path/to/bundle-icon.png

# Use GIF for catalog package schema (overrides bundle inheritance)
make catalog CATALOG_ICON=/path/to/catalog-icon.gif
```

**When to use separate icons**:
- Bundle icon appears in CSV manifests and OperatorHub operator detail pages
- Catalog icon appears in package listings and search results
- Use different icons if you want distinct branding for package-level vs operator-level contexts

### Validation

Validate your icon before building:

```bash
make validate-icon ICON_FILE=/path/to/your-icon.png
```

The validation checks:
- ✅ Supported format (PNG, JPEG, GIF, SVG)
- ✅ Dimensions within 80×40 limit
- ✅ Aspect ratio is 1:2 (±5%)

## Technical Details

### Encoding

Icons are base64-encoded for embedding in the ClusterServiceVersion YAML manifest.

**Script**: `../scripts/encode-icon.sh`

```bash
# Usage
scripts/encode-icon.sh icons/default-icon.svg
```

**Output**: Base64-encoded string (stdout) + mediatype metadata (stderr)

### Validation Script

**Script**: `../scripts/validate-icon.sh`

```bash
# Usage
scripts/validate-icon.sh icons/default-icon.svg

# Exit codes:
# 0 - Valid icon
# 1 - File not found/unreadable
# 2 - Unsupported format
# 3 - Dimensions exceed 80×40
# 4 - Aspect ratio incorrect (not 1:2)
# 5 - File corrupted
```

**Requirements**: ImageMagick (`identify`), `file`, `bc` commands

## Examples

### Creating a Custom SVG Icon (80×40)

```xml
<svg width="80" height="40" xmlns="http://www.w3.org/2000/svg">
  <rect width="80" height="40" fill="#007fff"/>
  <text x="50%" y="50%" font-size="24" fill="white"
        text-anchor="middle" dominant-baseline="middle">M</text>
</svg>
```

### Creating a PNG Icon with ImageMagick

```bash
# Create 80×40 PNG from larger image
convert large-icon.png -resize 80x40! custom-icon.png

# Validate
scripts/validate-icon.sh custom-icon.png

# Build bundle with custom icon
make bundle BUNDLE_ICON=custom-icon.png
```

## Icon Propagation

1. **Bundle build** (`make bundle`):
   - Encodes icon (custom or default)
   - Injects into `bundle/manifests/toolhive-operator.clusterserviceversion.yaml`
   - Sets `.spec.icon[0].base64data` and `.spec.icon[0].mediatype`

2. **Catalog build** (`make catalog`):
   - Runs `opm render bundle/` to embed CSV (with icon) into catalog
   - Icon appears in `olm.bundle.object` within catalog YAML
   - No separate icon parameter needed for catalog target

3. **OLM deployment**:
   - OperatorHub UI displays icon from CSV in catalog
   - Rendered in OpenShift Console and Kubernetes Operator Hub

## References

- [OLM Icon Guidelines](https://github.com/operator-framework/community-operators/blob/master/docs/packaging-required-fields.md#icon)
- [ClusterServiceVersion Spec](https://github.com/operator-framework/api/blob/master/crds/operators.coreos.com_clusterserviceversions.yaml)
- Feature specification: `../specs/009-allow-icon-customization/spec.md`
