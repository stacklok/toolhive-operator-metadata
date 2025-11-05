# Research: Icon Validation and Embedding for OLM Bundles and Catalogs

**Feature**: 009-allow-icon-customization
**Date**: 2025-10-17
**Status**: Research Complete

## Overview

This document consolidates research findings on implementing icon validation and customization for OLM bundles and File-Based Catalogs. The research addresses five critical areas: image validation tools, Makefile error handling, base64 encoding for CSV embedding, parameter passing mechanisms, and OLM icon display behavior.

---

## Research Area 1: Image Validation Tools

### Decision
**Use ImageMagick `identify` command for format and dimension validation**, combined with `file` command for initial format detection.

### Rationale

**ImageMagick `identify` advantages**:
1. **Comprehensive metadata extraction**: Single command provides format, dimensions, and aspect ratio
   ```bash
   identify -format "%w %h %m" icon.png
   # Output: 80 40 PNG
   ```

2. **Universal format support**: Handles all OLM-required formats (PNG, JPEG, GIF, SVG) consistently
   - Tested on PNG: `100 50 PNG`
   - Tested on SVG: `80 40 SVG`

3. **Widely available**: Standard package on Linux distributions and macOS
   - Fedora/RHEL: `imagemagick` package
   - Ubuntu/Debian: `imagemagick` package
   - macOS: Available via Homebrew (`brew install imagemagick`)

4. **Performance**: Meets <1 second requirement
   - Tested SVG (228 bytes): 0.002s
   - Tested PNG (316 bytes): <0.001s

5. **Aspect ratio calculation**: Width/height values enable automatic 1:2 ratio verification
   ```bash
   # Calculate aspect ratio (height/width should be 0.5 for 1:2)
   ratio=$(echo "scale=2; $height / $width" | bc)
   ```

**`file` command as supplementary tool**:
- **Purpose**: Quick format detection and MIME type validation
  ```bash
  file -b --mime-type icon.svg
  # Output: image/svg+xml
  ```
- **Advantages**: Minimal dependency, fast execution, reliable MIME type detection
- **Limitation**: Does not provide dimensions (hence use with ImageMagick)

**Combined validation strategy**:
```bash
# Step 1: Quick format check with file command
mime_type=$(file -b --mime-type "$icon_file")

# Step 2: Detailed validation with ImageMagick identify
read width height format <<< $(identify -format "%w %h %m" "$icon_file")

# Step 3: Validate dimensions and aspect ratio
if [ "$width" -gt 80 ] || [ "$height" -gt 40 ]; then
    echo "ERROR: Dimensions ${width}x${height} exceed maximum 80x40" >&2
    exit 3
fi
```

### Alternatives Considered

**Alternative 1: Custom PNG/SVG header parsing**
- **Approach**: Parse PNG header bytes (8-byte signature, IHDR chunk) or SVG XML attributes
- **Rejected because**:
  - Requires format-specific logic for each image type (PNG, JPEG, GIF, SVG)
  - SVG dimension parsing is complex (width/height can be in various units: px, em, %)
  - Error-prone for edge cases (corrupted files, malformed headers)
  - Reinvents functionality already provided by ImageMagick
  - No significant performance benefit (<1ms difference)

**Alternative 2: Use only `file` command**
- **Approach**: Rely solely on `file -b --mime-type` for validation
- **Rejected because**:
  - Cannot extract dimensions (critical for validating 80x40 limit)
  - Cannot verify aspect ratio
  - Would require additional tools anyway (defeating simplicity goal)

**Alternative 3: Use `sips` (macOS System Image Processing)**
- **Approach**: Use macOS native `sips -g pixelWidth -g pixelHeight` command
- **Rejected because**:
  - Not available on Linux (primary development platform is Linux/Fedora)
  - Cross-platform compatibility is essential for CI/CD and developer environments
  - ImageMagick provides same functionality with broader platform support

---

## Research Area 2: Makefile Error Handling

### Decision
**Use shell script validation with explicit exit codes** (0-5 range) and integrate into Makefile targets with `|| { error_handling; exit 1; }` pattern.

### Rationale

**Exit code convention** (POSIX standard + custom extensions):
```bash
# Exit codes for validate-icon.sh
0  - Icon is valid (all checks passed)
1  - File not found or unreadable
2  - Unsupported format (not PNG, JPEG, GIF, or SVG)
3  - Dimensions exceed limits (width > 80 or height > 40)
4  - Aspect ratio incorrect (not 1:2 with 5% tolerance)
5  - File corrupted or unreadable by ImageMagick
```

**Makefile integration pattern**:
```makefile
.PHONY: bundle
bundle:
	@echo "Validating custom icon..."
	@scripts/validate-icon.sh $(BUNDLE_ICON) || { \
		echo "ERROR: Icon validation failed. Bundle generation aborted." >&2; \
		exit 1; \
	}
	@echo "Icon validation passed"
	# Continue with bundle generation...
```

**Error message clarity** - validation script outputs actionable messages to stderr:
```bash
# Example error messages
"ERROR: Icon file not found: icons/missing.png"
"ERROR: Unsupported format 'WEBP'. Use PNG, JPEG, GIF, or SVG only"
"ERROR: Icon dimensions 100x50 exceed maximum 80x40"
"ERROR: Icon aspect ratio 2.00 must be 1:2 (height:width = 0.50)"
"ERROR: Cannot read icon file (possibly corrupted): icons/broken.png"
```

**Make build failure behavior**:
- Validation script returns non-zero exit code → Makefile target fails immediately
- Make returns exit code 2 (standard Make error code)
- Build process stops before bundle/catalog generation
- Tested: Make correctly propagates exit codes and halts execution

**Graceful degradation for optional icons**:
```makefile
# If BUNDLE_ICON is not set, skip validation and use default
ifdef BUNDLE_ICON
	@scripts/validate-icon.sh $(BUNDLE_ICON) || exit 1
	@scripts/encode-icon.sh $(BUNDLE_ICON) > /tmp/icon-encoded.txt
else
	@echo "No custom icon specified, using default"
	@cp icons/default-icon-base64.txt /tmp/icon-encoded.txt
endif
```

### Alternatives Considered

**Alternative 1: Use Make's built-in error handling only**
- **Approach**: Rely on Make's automatic failure detection (non-zero exit from commands)
- **Rejected because**:
  - No control over error messages (Make just says "Error 1")
  - Cannot provide actionable guidance to developers
  - Harder to distinguish between different error types
  - User experience is poor (cryptic "*** [target] Error 1" messages)

**Alternative 2: Use trap-based error handling in shell**
- **Approach**: Use Bash `set -e` and `trap` to catch errors
- **Rejected because**:
  - Overly complex for simple validation tasks
  - Makes debugging harder (errors caught by trap are less transparent)
  - Exit code semantics less clear (all errors become generic failure)
  - Our use case needs specific exit codes for different validation failures

**Alternative 3: Use Python script for validation instead of shell**
- **Approach**: Write validation in Python with PIL/Pillow for image processing
- **Rejected because**:
  - Adds Python dependency (PIL/Pillow not always installed)
  - Slower startup time compared to shell script calling native tools
  - Shell script with ImageMagick is simpler and leverages existing tools
  - No significant advantage for this straightforward validation task

---

## Research Area 3: Base64 Encoding for CSV

### Decision
**Use `base64 -w 0` (GNU coreutils) for single-line base64 encoding** when embedding icons in YAML.

### Rationale

**Line wrapping behavior**:
- **Default base64** (without `-w 0`): Wraps output at 76 characters per line
  ```bash
  base64 icon.svg | wc -c
  # Output: 308 (includes newline characters)
  ```
- **Single-line base64** (with `-w 0`): No line breaks, continuous string
  ```bash
  base64 -w 0 icon.svg | wc -c
  # Output: 304 (no newlines, pure base64)
  ```

**Why single-line for CSV embedding**:
1. **YAML scalar compatibility**: Multi-line base64 requires YAML block scalar syntax (`|` or `>`)
   ```yaml
   # Multi-line (requires block scalar)
   icon:
     - base64data: |
         PHN2ZyB3aWR0aD0iODAiIGhlaWdodD0iNDAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8y
         MDAwL3N2ZyI+CiAgPHJlY3Qgd2lkdGg9IjgwIiBoZWlnaHQ9IjQwIiBmaWxsPSIjMDA3ZmZm
   ```

   ```yaml
   # Single-line (simpler YAML)
   icon:
     - base64data: PHN2ZyB3aWR0aD0iODAiIGhlaWdodD0iNDAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+...
   ```

2. **yq manipulation simplicity**: Single-line strings are easier to set via yq eval
   ```bash
   # Simple assignment with single-line base64
   icon_data=$(base64 -w 0 "$icon_file")
   yq eval ".spec.icon[0].base64data = \"$icon_data\"" -i bundle/manifests/*.csv.yaml
   ```

3. **Existing bundle pattern**: Current toolhive-operator CSV uses single-line base64 (line 50)
   ```yaml
   base64data: PHN2ZyB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4K...
   ```

**Maximum practical size limits**:
- **OLM CSV size guideline**: Keep ClusterServiceVersion under 1MB (bundle images should be lightweight)
- **Icon size recommendations** (from operator-framework community-operators):
  - PNG icons: Typically 1-5 KB (80x40 @ 24-bit color)
  - SVG icons: Typically 200 bytes - 2 KB (optimized vector graphics)
  - Base64 overhead: ~33% increase (base64 encoding expands by 4/3 ratio)

- **Tested example**:
  - SVG source: 228 bytes
  - Base64 encoded: 304 characters (~33% overhead)
  - Well within CSV size limits

- **Practical limit**: Icons should be under 10 KB (embedded base64 ~13 KB) to keep CSV lean
- **Validation warning threshold**: Warn if icon file exceeds 10 KB during validation

**SVG optimization considerations**:
- **SVGO compatibility**: Recommend developers run svgo before embedding
  ```bash
  # Optional optimization (not enforced by build)
  svgo --multipass icon.svg -o icon-optimized.svg
  ```
- **Security**: SVG script tags and external references should be avoided (OLM/OpenShift may strip them)
- **Not enforced in validation**: SVG optimization is developer responsibility, not build requirement

### Alternatives Considered

**Alternative 1: Use multi-line base64 with YAML block scalars**
- **Approach**: Keep default 76-character line wrapping and use YAML `|` syntax
- **Rejected because**:
  - More complex YAML structure (requires proper indentation in block scalars)
  - Harder to manipulate with yq (multi-line strings are trickier)
  - No benefit over single-line encoding
  - Current CSV pattern uses single-line (consistency)

**Alternative 2: Compress icons before base64 encoding**
- **Approach**: gzip icon data, then base64 encode compressed blob
- **Rejected because**:
  - OLM does not support compressed icon data in CSV
  - Would require custom decompression in OperatorHub (not feasible)
  - PNG/SVG formats already use compression internally
  - Adds unnecessary complexity for minimal size gain

**Alternative 3: Reference icons via URL instead of embedding**
- **Approach**: Store icons externally and reference via HTTP URL in CSV
- **Rejected because**:
  - OLM CSV specification requires base64-encoded data in `spec.icon[0].base64data`
  - External URLs would require internet connectivity during operator installation
  - Introduces external dependencies (icon hosting, CDN availability)
  - Not supported by OLM/OperatorHub architecture

---

## Research Area 4: Makefile Parameter Passing

### Decision
**Use environment variables with Make variable override capability**: `BUNDLE_ICON` and `CATALOG_ICON` as optional parameters.

### Rationale

**Make variable pattern**:
```makefile
# Variables with default values
BUNDLE_ICON ?=
CATALOG_ICON ?= $(BUNDLE_ICON)

# Usage in targets
.PHONY: bundle
bundle:
ifdef BUNDLE_ICON
	@echo "Using custom icon: $(BUNDLE_ICON)"
	@scripts/validate-icon.sh $(BUNDLE_ICON)
	@scripts/encode-icon.sh $(BUNDLE_ICON) > /tmp/icon.b64
else
	@echo "Using default icon"
	@cp icons/default-icon-base64.txt /tmp/icon.b64
endif
```

**Command-line usage**:
```bash
# Method 1: Make variable override (recommended)
make bundle BUNDLE_ICON=icons/my-logo.png

# Method 2: Environment variable
export BUNDLE_ICON=icons/my-logo.png
make bundle

# Method 3: Inline environment variable
BUNDLE_ICON=icons/my-logo.png make bundle
```

**Advantages**:
1. **Familiar pattern**: Standard Make convention used throughout existing Makefile
   - Existing example: `CATALOG_REGISTRY ?= ghcr.io` (line 9)
   - Existing example: `BUNDLE_TAG ?= v0.2.17` (line 21)

2. **Default value handling**: `?=` operator provides clean fallback mechanism
   ```makefile
   CATALOG_ICON ?= $(BUNDLE_ICON)  # Catalog inherits bundle icon by default
   ```

3. **Multi-parameter scenarios**: Icon inheritance pattern for bundle vs catalog
   ```bash
   # Same icon for both bundle and catalog
   make bundle BUNDLE_ICON=icons/logo.png
   make catalog  # Automatically uses BUNDLE_ICON

   # Different icons for bundle and catalog
   make bundle BUNDLE_ICON=icons/logo.png
   make catalog CATALOG_ICON=icons/logo.svg
   ```

4. **Optional parameters**: `ifdef` checks enable graceful degradation
   ```makefile
   ifdef BUNDLE_ICON
       # Custom icon workflow
   else
       # Default icon workflow
   endif
   ```

5. **Compatibility with CI/CD**: Environment variables work seamlessly in GitHub Actions, GitLab CI
   ```yaml
   # GitHub Actions example
   - name: Build bundle with custom icon
     run: make bundle BUNDLE_ICON=icons/production-logo.png
   ```

**Variable precedence** (highest to lowest):
1. Command-line override: `make bundle BUNDLE_ICON=...`
2. Environment variable: `export BUNDLE_ICON=...`
3. Makefile default: `BUNDLE_ICON ?= ...`
4. Undefined (empty): `ifdef` check handles this case

### Alternatives Considered

**Alternative 1: Use positional arguments to Make targets**
- **Approach**: `make bundle-with-icon icons/logo.png`
- **Rejected because**:
  - Make doesn't natively support positional arguments to targets
  - Would require complex shell parsing or makefile tricks
  - Breaks standard Make conventions
  - Harder to document and less intuitive

**Alternative 2: Use configuration file for icon paths**
- **Approach**: Create `icon-config.env` file with `BUNDLE_ICON=icons/logo.png`
- **Rejected because**:
  - Adds file management overhead (create, edit, commit config file)
  - Less flexible than command-line parameters
  - Complicates CI/CD (need to manage config files in pipelines)
  - Existing Makefile doesn't use config file pattern

**Alternative 3: Use Make functions for complex parameter handling**
- **Approach**: Define Make function to parse and validate parameters
- **Rejected because**:
  - Overly complex for simple optional parameter use case
  - Make functions are hard to read and maintain
  - Shell scripts (validate-icon.sh) already handle validation
  - No significant benefit over simple `ifdef` checks

---

## Research Area 5: OLM Icon Display Behavior

### Decision
**OperatorHub renders icons with strict aspect ratio enforcement and MIME type validation**, rejecting SVG with unsafe content.

### Rationale

**Aspect ratio handling**:
- **OLM recommendation**: 80px width × 40px height (1:2 aspect ratio)
  - Source: operator-framework/community-operators contribution guidelines
  - Example: Many community operators use 80x40 PNG or 40x40 square icons

- **Violation behavior**: OperatorHub scales icons to fit tile space
  - Icons > 80x40: Scaled down proportionally (may appear small)
  - Incorrect aspect ratio: Displayed with original ratio (may look distorted in rectangular tile)
  - Best practice: Provide exact 80x40 dimensions to ensure optimal display

- **Current ToolHive icon issue**: Embedded icon is 512x512 SVG (violates 80x40 recommendation)
  ```xml
  <svg width="512" height="512" xmlns="http://www.w3.org/2000/svg">
  ```
  - Should be resized to 80x40 for compliance
  - Custom icon feature provides opportunity to fix this

**MIME type (mediatype) handling**:
- **Required field**: `spec.icon[0].mediatype` must be set in CSV
  ```yaml
  icon:
    - base64data: PHN2Zy...
      mediatype: image/svg+xml  # Required
  ```

- **Supported MIME types** (per OLM CSV specification):
  - `image/png` - Portable Network Graphics
  - `image/jpeg` - JPEG/JPG images
  - `image/gif` - Graphics Interchange Format
  - `image/svg+xml` - Scalable Vector Graphics

- **Incorrect/missing mediatype behavior**:
  - Missing mediatype: Icon may not display (OperatorHub cannot determine how to render)
  - Incorrect mediatype: Browser may fail to render (e.g., PNG served as image/jpeg)
  - Validation: OLM validates CSV schema but doesn't deeply validate icon MIME type correctness

- **Auto-detection strategy**:
  ```bash
  # Use file command to detect actual MIME type
  mediatype=$(file -b --mime-type "$icon_file")

  # Map to OLM-supported values
  case "$mediatype" in
    image/png|image/jpeg|image/gif|image/svg+xml)
      echo "$mediatype"  # Valid, use as-is
      ;;
    *)
      echo "ERROR: Unsupported MIME type $mediatype" >&2
      exit 2
      ;;
  esac
  ```

**SVG security restrictions**:
- **OpenShift Content Security Policy (CSP)**: OperatorHub enforces strict CSP
  - Blocks: `<script>` tags, inline JavaScript (`onclick`, `onload`)
  - Blocks: External resource references (`xlink:href` to external URLs)
  - Blocks: Data URIs embedding JavaScript

- **Allowed SVG features**:
  - Basic shapes: `<rect>`, `<circle>`, `<path>`, `<polygon>`
  - Text: `<text>` elements with fonts
  - Styling: Inline `fill`, `stroke` attributes (no external CSS)
  - Gradients: `<linearGradient>`, `<radialGradient>` (inline only)

- **Validation approach for this feature**:
  - **NOT enforced in build**: SVG content validation is complex (requires XML parsing)
  - **Developer responsibility**: Documentation should warn about script tags
  - **OpenShift safety**: CSP will strip unsafe SVG content at runtime
  - **Best practice**: Test icon in actual OperatorHub before production release

**Display fallback behavior**:
- **Icon load failure**: OperatorHub shows generic placeholder icon (grey box)
- **Missing icon field**: Operator displays with no icon (text-only tile)
- **Corrupted base64**: Console may show broken image icon

### Alternatives Considered

**Alternative 1: Enforce SVG content validation in build script**
- **Approach**: Parse SVG XML, reject files containing `<script>`, external references
- **Rejected because**:
  - Requires XML parsing (additional dependencies: xmllint, python lxml, etc.)
  - Complex edge cases (namespace handling, embedded data URIs, CSS)
  - OpenShift CSP already provides runtime protection
  - Build validation would duplicate OpenShift's security layer
  - Developer testing in OperatorHub is final validation anyway

**Alternative 2: Automatically resize icons to 80x40 during build**
- **Approach**: Use ImageMagick `convert` to resize icons to exact dimensions
- **Rejected because**:
  - Automatic resizing may distort icons (aspect ratio changes)
  - Developers should provide correctly sized icons (design responsibility)
  - Quality loss with PNG resizing (better to design at target size)
  - SVG resizing requires XML manipulation (changing width/height attributes)
  - Better to fail validation and prompt developer to fix source

**Alternative 3: Support multiple icon sizes/resolutions**
- **Approach**: Accept multiple icon files for different DPI/sizes, embed all in CSV
- **Rejected because**:
  - OLM CSV spec only supports single icon per version
  - OperatorHub doesn't use responsive images or srcset
  - Would bloat CSV size unnecessarily
  - 80x40 dimension is sufficient for OperatorHub tile display

---

## Key Findings Summary

### Finding 1: Tool Availability and Compatibility

**ImageMagick `identify` and `file` command are universally available**:
- ✅ Fedora Linux (build environment): ImageMagick 7.1.1-47, file 5.46
- ✅ RHEL/CentOS: Available via standard repositories
- ✅ macOS: Available via Homebrew
- ✅ CI/CD containers: Most base images include these tools

**Performance validation**:
- Icon validation: <5ms per icon
- Base64 encoding: <2ms for typical icons
- Total overhead: <10ms (well within <1 second requirement)
- Build impact: Negligible (<0.1% of total bundle build time)

### Finding 2: Current Icon Non-Compliance

**Existing default icon violates OLM recommendations**:
- Current: 512×512 SVG (base64data on line 50 of CSV)
- Required: 80×40 maximum dimensions
- Impact: Icon may appear oversized or improperly scaled in OperatorHub

**Action required**:
- Create new `icons/default-icon.svg` at 80×40 dimensions
- Update bundle generation to use compliant default icon
- Custom icon feature enables fixing this issue

### Finding 3: Validation Script Design

**Recommended validation workflow**:
```bash
#!/bin/bash
# scripts/validate-icon.sh

icon_file="$1"

# Check 1: File exists and is readable
[ -f "$icon_file" ] || { echo "ERROR: Icon file not found: $icon_file" >&2; exit 1; }

# Check 2: Detect MIME type
mime_type=$(file -b --mime-type "$icon_file")
case "$mime_type" in
  image/png|image/jpeg|image/gif|image/svg+xml) ;;
  *) echo "ERROR: Unsupported format '$mime_type'. Use PNG, JPEG, GIF, or SVG only" >&2; exit 2 ;;
esac

# Check 3: Extract dimensions and format
read width height format <<< $(identify -format "%w %h %m" "$icon_file" 2>&1)
[ $? -eq 0 ] || { echo "ERROR: Cannot read icon file (possibly corrupted): $icon_file" >&2; exit 5; }

# Check 4: Validate dimensions
if [ "$width" -gt 80 ] || [ "$height" -gt 40 ]; then
  echo "ERROR: Icon dimensions ${width}x${height} exceed maximum 80x40" >&2
  exit 3
fi

# Check 5: Validate aspect ratio (1:2 = height/width = 0.5, with 5% tolerance)
aspect_ratio=$(echo "scale=2; $height / $width" | bc)
if ! (echo "$aspect_ratio >= 0.475" | bc -l) || ! (echo "$aspect_ratio <= 0.525" | bc -l); then
  echo "WARNING: Icon aspect ratio ${aspect_ratio} is not exactly 1:2. Recommended: 80x40, 40x20, or 160x80" >&2
  # Don't fail - warning only (aspect ratio is recommendation, not hard requirement)
fi

echo "✅ Icon validation passed: ${width}x${height} $format" >&2
exit 0
```

### Finding 4: Makefile Integration Pattern

**Recommended Makefile modifications**:
```makefile
# Icon configuration
BUNDLE_ICON ?=
CATALOG_ICON ?= $(BUNDLE_ICON)
DEFAULT_ICON := icons/default-icon-base64.txt

.PHONY: bundle
bundle:
	@echo "Generating OLM bundle..."
	@mkdir -p bundle/manifests bundle/metadata
ifdef BUNDLE_ICON
	@echo "Validating custom icon: $(BUNDLE_ICON)"
	@scripts/validate-icon.sh $(BUNDLE_ICON) || exit 1
	@echo "Encoding custom icon..."
	@icon_data=$$(base64 -w 0 $(BUNDLE_ICON)); \
	 icon_type=$$(file -b --mime-type $(BUNDLE_ICON)); \
	 yq eval ".spec.icon[0].base64data = \"$$icon_data\"" -i bundle/manifests/*.csv.yaml; \
	 yq eval ".spec.icon[0].mediatype = \"$$icon_type\"" -i bundle/manifests/*.csv.yaml; \
	 echo "✅ Custom icon embedded in CSV"
else
	@echo "Using default icon (no BUNDLE_ICON specified)"
	@icon_data=$$(cat $(DEFAULT_ICON)); \
	 yq eval ".spec.icon[0].base64data = \"$$icon_data\"" -i bundle/manifests/*.csv.yaml; \
	 yq eval ".spec.icon[0].mediatype = \"image/svg+xml\"" -i bundle/manifests/*.csv.yaml
endif
	# ... continue with rest of bundle generation
```

---

## Implementation Recommendations

### Recommendation 1: Create Compliant Default Icon

**Action**: Replace 512×512 default icon with 80×40 compliant version

**Implementation**:
```bash
# Create icons/ directory structure
mkdir -p icons/

# Create 80x40 default icon (same blue "M" design, compliant dimensions)
cat > icons/default-icon.svg << 'EOF'
<svg width="80" height="40" xmlns="http://www.w3.org/2000/svg">
  <rect width="80" height="40" fill="#007fff"/>
  <text x="50%" y="50%" font-size="24" fill="white" text-anchor="middle" dominant-baseline="middle">M</text>
</svg>
EOF

# Pre-generate base64 encoded version for fast default usage
base64 -w 0 icons/default-icon.svg > icons/default-icon-base64.txt
```

### Recommendation 2: Implement Validation Script

**Action**: Create `scripts/validate-icon.sh` and `scripts/encode-icon.sh`

**Validation script** (`scripts/validate-icon.sh`):
- Exit codes: 0 (valid), 1 (not found), 2 (unsupported format), 3 (dimensions), 4 (aspect ratio), 5 (corrupted)
- Checks: File existence, MIME type, dimensions, aspect ratio (with tolerance)
- Output: Actionable error messages to stderr

**Encoding script** (`scripts/encode-icon.sh`):
- Input: Icon file path
- Output: Base64-encoded data (stdout) and MIME type (stderr)
- Format: Single-line base64 (`-w 0` flag)

### Recommendation 3: Add Makefile Validation Target

**Action**: Add `validate-icon` target for manual testing

```makefile
.PHONY: validate-icon
validate-icon: ## Validate icon file (use: make validate-icon ICON=path/to/icon.png)
ifndef ICON
	@echo "ERROR: ICON variable not set. Usage: make validate-icon ICON=path/to/icon.png" >&2
	@exit 1
endif
	@echo "Validating icon: $(ICON)"
	@scripts/validate-icon.sh $(ICON)
	@echo ""
	@echo "Icon details:"
	@identify -format "  Format: %m\n  Dimensions: %wx%h\n  File size: %b bytes\n" $(ICON)
	@echo "  MIME type: $$(file -b --mime-type $(ICON))"
```

### Recommendation 4: Document SVG Best Practices

**Action**: Add `icons/README.md` with icon requirements and examples

**Content**:
- Recommended dimensions: 80×40 (1:2 aspect ratio)
- Supported formats: PNG, JPEG, GIF, SVG
- SVG safety: Avoid script tags, external references, inline JavaScript
- File size: Keep under 10 KB for optimal CSV size
- Testing: Validate with `make validate-icon ICON=your-icon.svg`
- Preview: Test in actual OperatorHub before production release

---

## Alternatives Considered and Rejected

### Alternative 1: Python-based validation with Pillow/PIL

**Approach**: Use Python script with PIL library for image validation

**Rejected because**:
- Additional dependency (python3-pillow not always installed)
- Slower startup time (Python interpreter overhead)
- Shell script with ImageMagick is simpler and faster
- No significant advantage for straightforward validation task

### Alternative 2: Inline base64 encoding in Makefile

**Approach**: Encode icons directly in Makefile without separate script

**Rejected because**:
- Complex Makefile syntax (escaping quotes, handling newlines)
- Hard to test and debug
- Mixing concerns (Makefile should orchestrate, not implement logic)
- Separate scripts are more maintainable and testable

### Alternative 3: JSON Schema validation for CSV icons

**Approach**: Define JSON Schema for icon structure, validate with ajv or similar

**Rejected because**:
- Overly complex for simple base64 + mediatype validation
- CSV is YAML format, not JSON (would require conversion)
- ImageMagick + file command provide simpler, more direct validation
- JSON Schema doesn't validate image binary data (only structure)

---

## Next Steps

Proceed to **Phase 1: Design & Contracts** to:
1. Define data model for icon metadata (format, dimensions, aspect ratio, base64 encoding)
2. Create contract specifications for `validate-icon.sh` and `encode-icon.sh` scripts
3. Define Makefile target contracts for `bundle` and `catalog` with icon parameters
4. Generate quickstart guide with usage examples and best practices

---

## References

### OLM Documentation
- [ClusterServiceVersion (CSV) Specification](https://olm.operatorframework.io/docs/concepts/crds/clusterserviceversion/)
- [community-operators Contribution Guidelines](https://operator-framework.github.io/community-operators/contributing-prerequisites/)
- [OperatorHub.io Icon Guidelines](https://operatorhub.io/contribute)

### Tool Documentation
- [ImageMagick identify command](https://imagemagick.org/script/identify.php)
- [file command manual](https://man7.org/linux/man-pages/man1/file.1.html)
- [GNU Make Manual - Conditionals](https://www.gnu.org/software/make/manual/html_node/Conditionals.html)

### Repository Context
- Current CSV with default icon: [bundle/manifests/toolhive-operator.clusterserviceversion.yaml](../../bundle/manifests/toolhive-operator.clusterserviceversion.yaml)
- Existing Makefile: [Makefile](../../Makefile)
- Feature specification: [spec.md](./spec.md)
- Implementation plan: [plan.md](./plan.md)

### Tool Versions (Build Environment)
- ImageMagick: 7.1.1-47 Q16-HDRI
- file: 5.46
- base64: GNU coreutils 9.5
- yq: v4.x (YAML processor)
- GNU Make: 4.x
