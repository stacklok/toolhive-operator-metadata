# Feature Specification: Custom Icon Support for OLM Bundle and Catalog

**Feature Branch**: `009-allow-icon-customization`
**Created**: 2025-10-17
**Status**: Draft
**Input**: User description: "Allow icon customization. When building the bundle and the file based catalog there is a default icon configured to be used when the bundle or catalog's data is utilized in OpenShift via the Operator Lifecycle Manager's built in OperatorHub web interface. In this interface we see that default icon displayed next to the name of the ToolHive Operator and the details about it. This icon should be able to be customized and provided during bundle and file based catalog creation rather than simply being the default. There are specifications for the maximum width and height and allowable formats for this icon to be provided in available in the operator lifecycle manager operator framework documentation. When the user does provide a custom icon we should check to be sure that it meets the requirements of the operator lifecycle manager with respect to it's file format and sizing."

## User Scenarios & Testing

### User Story 1 - Replace Default Icon with Custom Branding (Priority: P1)

A developer building the ToolHive operator bundle wants to replace the default blue "M" placeholder icon with their organization's branded logo so that when operators browse OperatorHub, they see proper branding that matches their organization's identity.

**Why this priority**: Core functionality - the primary value of this feature. Without this, users cannot customize their operator's visual identity in OperatorHub, which is the main business requirement.

**Independent Test**: Can be fully tested by providing a valid PNG icon file, running the bundle build, and verifying the icon appears correctly in OperatorHub catalog interface. Delivers immediate branding value.

**Acceptance Scenarios**:

1. **Given** a valid PNG icon file at 80x40 pixels (1:2 aspect ratio), **When** developer provides icon path during bundle build, **Then** the bundle CSV contains the base64-encoded icon and displays correctly in OperatorHub
2. **Given** a valid SVG icon file at 80x40 dimensions, **When** developer provides icon path during bundle build, **Then** the bundle CSV contains the base64-encoded SVG and renders properly in OperatorHub
3. **Given** no custom icon is provided, **When** developer builds the bundle, **Then** the default blue "M" icon is used as fallback

---

### User Story 2 - Prevent Invalid Icons (Priority: P2)

A developer accidentally provides an oversized or incorrect format icon file and receives clear validation errors during the build process, preventing deployment of a non-compliant bundle.

**Why this priority**: Important for quality and user experience, but not blocking core functionality. Users can still use custom icons without validation, but validation prevents common mistakes.

**Independent Test**: Can be tested by providing various invalid icon files (wrong format, oversized, corrupted) and verifying appropriate error messages are displayed. Delivers improved developer experience and prevents deployment issues.

**Acceptance Scenarios**:

1. **Given** an icon file in WebP format (unsupported), **When** developer provides it for bundle build, **Then** build fails with error message "Unsupported icon format. Use PNG, JPEG, GIF, or SVG only"
2. **Given** a PNG icon larger than maximum allowed dimensions, **When** developer provides it for bundle build, **Then** build fails with error message specifying the size limit and actual dimensions
3. **Given** a valid icon that exceeds file size limits, **When** developer provides it for bundle build, **Then** build warns about large file size and suggests optimization
4. **Given** an invalid or corrupted image file, **When** developer provides it for bundle build, **Then** build fails with error message "Cannot read icon file"

---

### User Story 3 - Use Different Icons for Bundle and Catalog (Priority: P3)

A developer wants to use different icon variants for bundle development (high-resolution PNG) versus catalog distribution (optimized SVG) to balance quality and file size.

**Why this priority**: Nice-to-have optimization. Most users will use the same icon for both bundle and catalog. This provides flexibility for advanced use cases.

**Independent Test**: Can be tested by providing different icon files for bundle and catalog builds, verifying each uses the correct icon independently. Delivers optimization flexibility for advanced users.

**Acceptance Scenarios**:

1. **Given** separate icon paths for bundle and catalog, **When** developer builds both artifacts, **Then** bundle uses the PNG icon and catalog uses the SVG icon
2. **Given** only a bundle icon is specified, **When** developer builds the catalog, **Then** catalog reuses the bundle icon by default

---

### Edge Cases

- What happens when icon file path is specified but file doesn't exist?
- How does the system handle icon files with incorrect file extensions (e.g., .png file that's actually SVG)?
- What happens when base64 encoding fails?
- How does the system handle very large icon files that create oversized CSV files?
- What happens when icon validation fails during catalog generation but bundle was already built?
- How should the system handle icons with transparency or complex alpha channels?

## Requirements

### Functional Requirements

- **FR-001**: System MUST support PNG image format for operator icons
- **FR-002**: System MUST support SVG+XML image format for operator icons
- **FR-003**: System MUST support JPEG image format for operator icons
- **FR-004**: System MUST support GIF image format for operator icons
- **FR-005**: System MUST validate icon format before encoding (PNG, JPEG, GIF, or SVG+XML only)
- **FR-006**: System MUST validate icon dimensions do not exceed OLM maximum of 80px width x 40px height
- **FR-007**: System MUST validate icon aspect ratio is 1:2 (height:width) as required by OLM
- **FR-008**: System MUST base64-encode icon files for inclusion in CSV
- **FR-009**: System MUST allow developers to specify custom icon file path via command-line parameter or configuration file
- **FR-010**: System MUST use default icon when no custom icon is provided
- **FR-011**: System MUST display clear error messages when icon validation fails, including what was wrong and how to fix it
- **FR-012**: System MUST apply the same custom icon to both bundle and catalog by default
- **FR-013**: System MUST allow specifying different icons for bundle vs catalog (optional advanced feature)
- **FR-014**: System MUST verify icon file exists before attempting to process it
- **FR-015**: System MUST preserve existing bundle/catalog build process when custom icon is not specified

### Non-Functional Requirements

- **NFR-001**: Icon validation MUST complete in under 1 second for typical icon files
- **NFR-002**: Error messages MUST clearly explain what validation failed and provide actionable guidance
- **NFR-003**: Icon processing MUST not significantly increase bundle build time (less than 5% overhead)
- **NFR-004**: Documentation MUST include examples of valid icon files and common formats

### Key Entities

- **Custom Icon**: Image file provided by developer, must be PNG or SVG format, subject to size and dimension validation
- **Default Icon**: Fallback placeholder icon (current blue "M" SVG) used when no custom icon is specified
- **Icon Specification**: Metadata including base64-encoded data and mediatype, embedded in CSV

## Success Criteria

### Measurable Outcomes

- **SC-001**: Developers can successfully build bundles with custom PNG or SVG icons without manual CSV editing
- **SC-002**: Invalid icon formats are rejected during build with clear error messages within 1 second
- **SC-003**: Custom icons display correctly in OpenShift OperatorHub interface
- **SC-004**: Default icon behavior is preserved when no custom icon is specified
- **SC-005**: Build process remains backward compatible with existing workflows
- **SC-006**: Icon validation catches 100% of unsupported formats (non-PNG, non-JPEG, non-GIF, non-SVG) before bundle creation

## Assumptions

- OLM supports PNG, JPEG, GIF, and SVG+XML formats per official community-operators documentation
- Maximum icon dimensions are 80px width x 40px height with 1:2 aspect ratio per OLM requirements
- Developers have icon files available locally during build process
- Icon files are reasonably sized (base64-encoded data should fit comfortably in CSV)
- Base64 encoding is standard requirement for OLM icons per CSV specification
- Build process uses Makefile targets that can accept parameters or read configuration files
- Current default icon is a 512x512 SVG that will need to be resized/replaced to meet OLM 80x40 requirements

## Dependencies

- Makefile bundle and catalog build targets
- Access to icon file on filesystem during build
- Image validation tooling (e.g., file, imagemagick, or similar for format detection)
- Base64 encoding utility (standard on Unix systems)

## Out of Scope

- Automatic icon generation or conversion from other formats
- Icon editing or optimization tools
- Hosting or serving icon files
- Dynamic icon switching after deployment
- Multi-resolution icon variants
- Animated icons or icon themes
