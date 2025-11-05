# Quickstart Guide: Custom Container Image Naming

**Feature**: Custom Container Image Naming
**Target Audience**: Developers, Testers, CI/CD Engineers
**Last Updated**: 2025-10-10

## Overview

This feature enables you to customize container image naming for the ToolHive Operator's three container images (OLMv1 catalog, OLMv0 bundle, OLMv0 index) without modifying the Makefile source code. Each image's registry, organization, name, and tag can be independently overridden using environment variables or command-line arguments.

**What This Enables**:
- Build images to your personal container registry (Quay.io, Docker Hub, etc.)
- Use custom organization/namespace paths matching your registry access
- Apply descriptive image names for different test scenarios
- Tag images with feature branch identifiers or custom version strings
- Mix custom and default values (override only what you need)

**Default Behavior** (unchanged when no overrides specified):
- Catalog: `ghcr.io/stacklok/toolhive/catalog:v0.2.17`
- Bundle: `ghcr.io/stacklok/toolhive/bundle:v0.2.17`
- Index: `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17`

## Prerequisites

Before using custom image naming, ensure you have:

- **GNU Make** (version 3.81 or later)
  ```bash
  make --version
  ```

- **Container Build Tool** (podman or docker)
  ```bash
  podman --version  # or docker --version
  ```

- **Registry Access** (for pushing custom images)
  - Authentication configured for your target registry
  - Write permissions to your target organization/namespace
  ```bash
  # Example: Login to Quay.io
  podman login quay.io

  # Example: Login to Docker Hub
  podman login docker.io
  ```

- **OPM Tool** (for index builds, if using OLMv0)
  ```bash
  opm version
  ```

## Quick Start Scenarios

### Scenario 1: Build to Personal Quay.io Registry

**Use Case**: You want to build the catalog image to your personal Quay.io account.

```bash
# Override only the registry and organization
make catalog-build \
  CATALOG_REGISTRY=quay.io \
  CATALOG_ORG=johndoe

# This produces: quay.io/johndoe/catalog:v0.2.17
# (name and tag remain default)
```

**Verify the image**:
```bash
podman images | grep catalog
# Expected output:
# quay.io/johndoe/catalog    v0.2.17    <image-id>    <timestamp>
```

**Push to your registry**:
```bash
make catalog-push \
  CATALOG_REGISTRY=quay.io \
  CATALOG_ORG=johndoe

# This pushes:
#   quay.io/johndoe/catalog:v0.2.17
#   quay.io/johndoe/catalog:latest
```

---

### Scenario 2: Build with Custom Organization

**Use Case**: Your team uses a shared registry with a specific organization/namespace.

```bash
# Build bundle image to team namespace
make bundle-build \
  BUNDLE_ORG=myteam/toolhive

# This produces: ghcr.io/myteam/toolhive/bundle:v0.2.17
# (registry, name, and tag remain default)
```

**Multiple levels of organization** (nested paths):
```bash
# Build to nested organization path
make bundle-build \
  BUNDLE_ORG=mycompany/engineering/operators

# This produces: ghcr.io/mycompany/engineering/operators/bundle:v0.2.17
```

---

### Scenario 3: Build with Custom Tag for Feature Branch

**Use Case**: You're developing a new feature and want to tag images with the branch name.

```bash
# Build catalog with feature branch tag
make catalog-build \
  CATALOG_TAG=feature-auth-v2

# This produces: ghcr.io/stacklok/toolhive/catalog:feature-auth-v2
# (registry, org, and name remain default)
```

**Testing multiple iterations**:
```bash
# Build iteration 1
make bundle-build BUNDLE_TAG=feature-xyz-iter1

# Build iteration 2
make bundle-build BUNDLE_TAG=feature-xyz-iter2

# Build release candidate
make bundle-build BUNDLE_TAG=v1.0.0-rc1
```

---

### Scenario 4: Build All Three Images with Custom Registry

**Use Case**: You want to build all operator images to your personal Docker Hub account.

```bash
# Set common environment variables
export CATALOG_REGISTRY=docker.io
export CATALOG_ORG=johndoe
export BUNDLE_REGISTRY=docker.io
export BUNDLE_ORG=johndoe
export INDEX_REGISTRY=docker.io
export INDEX_ORG=johndoe

# Build all three images
make catalog-build
# Produces: docker.io/johndoe/catalog:v0.2.17

make bundle-build
# Produces: docker.io/johndoe/bundle:v0.2.17

make index-olmv0-build
# Produces: docker.io/johndoe/index-olmv0:v0.2.17

# Clean up environment
unset CATALOG_REGISTRY CATALOG_ORG
unset BUNDLE_REGISTRY BUNDLE_ORG
unset INDEX_REGISTRY INDEX_ORG
```

**Alternative: Override all at once via CLI**:
```bash
# Build catalog
make catalog-build \
  CATALOG_REGISTRY=docker.io \
  CATALOG_ORG=johndoe

# Build bundle
make bundle-build \
  BUNDLE_REGISTRY=docker.io \
  BUNDLE_ORG=johndoe

# Build index
make index-olmv0-build \
  INDEX_REGISTRY=docker.io \
  INDEX_ORG=johndoe
```

---

## Common Patterns

### Development Workflow (Personal Registry + Custom Tags)

**Pattern**: Build to personal registry with descriptive tags for iterative development.

```bash
# Day 1: Initial feature development
make catalog-build \
  CATALOG_REGISTRY=quay.io \
  CATALOG_ORG=developer \
  CATALOG_TAG=wip-feature-api

# Day 2: Testing update
make catalog-build \
  CATALOG_REGISTRY=quay.io \
  CATALOG_ORG=developer \
  CATALOG_TAG=wip-feature-api-test2

# Day 3: Ready for review
make catalog-build \
  CATALOG_REGISTRY=quay.io \
  CATALOG_ORG=developer \
  CATALOG_TAG=feature-api-review

# Push for testing
make catalog-push \
  CATALOG_REGISTRY=quay.io \
  CATALOG_ORG=developer \
  CATALOG_TAG=feature-api-review
```

**Environment Variable Alternative** (reduces typing):
```bash
# Set once
export CATALOG_REGISTRY=quay.io
export CATALOG_ORG=developer

# Build with different tags
make catalog-build CATALOG_TAG=dev
make catalog-build CATALOG_TAG=test
make catalog-build CATALOG_TAG=staging
```

---

### Testing Workflow (Staging Registry)

**Pattern**: Use a staging registry for pre-production validation.

```bash
# Configure staging environment
export BUNDLE_REGISTRY=quay.io
export BUNDLE_ORG=mycompany/staging
export BUNDLE_TAG=v0.2.17-staging

# Build all images for staging
make bundle-build
# Produces: quay.io/mycompany/staging/bundle:v0.2.17-staging

# Validate before pushing
make bundle-validate

# Push to staging
make bundle-push

# After testing passes, rebuild for production
unset BUNDLE_REGISTRY BUNDLE_ORG BUNDLE_TAG
make bundle-build
# Produces: ghcr.io/stacklok/toolhive/bundle:v0.2.17 (production default)
```

---

### CI/CD Integration (Environment Variables)

**Pattern**: Configure image naming via environment variables in CI/CD pipelines.

**GitHub Actions Example**:
```yaml
# .github/workflows/build.yml
jobs:
  build-dev:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build catalog to dev registry
        env:
          CATALOG_REGISTRY: quay.io
          CATALOG_ORG: ${{ github.repository_owner }}
          CATALOG_TAG: ${{ github.sha }}
        run: |
          make catalog-build
          # Produces: quay.io/<owner>/catalog:<commit-sha>
```

**GitLab CI Example**:
```yaml
# .gitlab-ci.yml
build:catalog:
  variables:
    CATALOG_REGISTRY: registry.gitlab.com
    CATALOG_ORG: ${CI_PROJECT_PATH}
    CATALOG_TAG: ${CI_COMMIT_REF_SLUG}
  script:
    - make catalog-build
    # Produces: registry.gitlab.com/<project-path>/catalog:<branch-slug>
```

**Jenkins Pipeline Example**:
```groovy
// Jenkinsfile
stage('Build Operator Images') {
    environment {
        BUNDLE_REGISTRY = 'docker.io'
        BUNDLE_ORG = 'mycompany/builds'
        BUNDLE_TAG = "${env.BUILD_NUMBER}"
    }
    steps {
        sh 'make bundle-build'
        // Produces: docker.io/mycompany/builds/bundle:<build-number>
    }
}
```

---

## Troubleshooting

### Verify Override Applied (Check Make Output)

**Problem**: Unsure if your override was applied correctly.

**Solution**: Use `make -n` (dry-run) to see expanded commands without executing.

```bash
# Dry-run to see expanded podman command
make -n catalog-build CATALOG_REGISTRY=quay.io

# Expected output includes:
# podman build ... -t quay.io/stacklok/toolhive/catalog:v0.2.17
```

**Check specific target without building**:
```bash
# See full bundle build command
make -n bundle-build \
  BUNDLE_REGISTRY=quay.io \
  BUNDLE_ORG=myteam \
  BUNDLE_TAG=dev | grep "podman build"
```

---

### Debug Variable Values (show-image-vars)

**Problem**: Need to see effective values of all image variables.

**Solution**: Use the `show-image-vars` target (if available in Makefile).

```bash
# Display all effective image variable values
make show-image-vars

# Expected output:
# Catalog Image Variables:
#   CATALOG_REGISTRY = ghcr.io
#   CATALOG_ORG      = stacklok/toolhive
#   CATALOG_NAME     = catalog
#   CATALOG_TAG      = v0.2.17
#   CATALOG_IMG      = ghcr.io/stacklok/toolhive/catalog:v0.2.17
#
# Bundle Image Variables:
#   BUNDLE_REGISTRY  = ghcr.io
#   ...
```

**With overrides**:
```bash
# See effective values after overrides
make show-image-vars \
  CATALOG_REGISTRY=quay.io \
  BUNDLE_ORG=myteam

# Shows overridden values for verification
```

**Alternative: Manual variable inspection**:
```bash
# Print specific variable value
make -p | grep CATALOG_IMG

# Print all image-related variables
make -p | grep -E "(CATALOG|BUNDLE|INDEX)_"
```

---

### Reset to Defaults

**Problem**: Environment variables are interfering with builds.

**Solution**: Clear environment variables or start fresh shell.

```bash
# Method 1: Unset individual variables
unset CATALOG_REGISTRY CATALOG_ORG CATALOG_NAME CATALOG_TAG
unset BUNDLE_REGISTRY BUNDLE_ORG BUNDLE_NAME BUNDLE_TAG
unset INDEX_REGISTRY INDEX_ORG INDEX_NAME INDEX_TAG

# Method 2: Start new shell (environment variables don't persist)
exit
# Open new terminal

# Method 3: Verify defaults are in effect
make -n catalog-build | grep "ghcr.io/stacklok/toolhive/catalog:v0.2.17"
# Should show production default image
```

---

### Common Errors and Solutions

#### Error: "Permission denied" when pushing

**Symptom**:
```
Error: failed to push quay.io/johndoe/catalog:v0.2.17: authentication required
```

**Solution**: Login to your container registry.
```bash
# Login to Quay.io
podman login quay.io
# Enter username and password when prompted

# Verify login
podman login quay.io --get-login
# Should show your username
```

---

#### Error: Image reference contains spaces

**Symptom**:
```
invalid reference format: repository name must be lowercase
```

**Cause**: Accidentally included spaces in variable value.

**Solution**: Quote variables with spaces or remove spaces.
```bash
# WRONG (space in org name)
make catalog-build CATALOG_ORG="my org"

# CORRECT (no spaces)
make catalog-build CATALOG_ORG=myorg

# CORRECT (use hyphen instead)
make catalog-build CATALOG_ORG=my-org
```

---

#### Error: Tag not found after build

**Symptom**: Built image with custom tag but it doesn't appear in `podman images`.

**Cause**: Command-line override not applied (environment variable took precedence).

**Solution**: Command-line arguments override environment variables. Use CLI for explicit control.
```bash
# Environment variable set
export CATALOG_TAG=envtag

# This uses envtag (environment wins if no CLI arg)
make catalog-build

# This uses clitag (CLI overrides environment)
make catalog-build CATALOG_TAG=clitag

# Verify which tag was used
podman images | grep catalog
```

---

#### Error: Build succeeds but wrong image name used

**Symptom**: Build completes but image has unexpected name.

**Debug Steps**:
1. Check effective variable values:
   ```bash
   make show-image-vars CATALOG_REGISTRY=quay.io
   ```

2. Verify dry-run output:
   ```bash
   make -n catalog-build CATALOG_REGISTRY=quay.io | grep "podman build"
   ```

3. Check for typos in variable names:
   ```bash
   # WRONG (typo: REGSITRY instead of REGISTRY)
   make catalog-build CATALOG_REGSITRY=quay.io

   # CORRECT
   make catalog-build CATALOG_REGISTRY=quay.io
   ```

---

## Reference

### All Available Override Variables

**Catalog Image Variables** (OLMv1):
- `CATALOG_REGISTRY` - Registry hostname (default: `ghcr.io`)
- `CATALOG_ORG` - Organization/namespace path (default: `stacklok/toolhive`)
- `CATALOG_NAME` - Image name (default: `catalog`)
- `CATALOG_TAG` - Image tag (default: `v0.2.17`)
- `CATALOG_IMG` - Full image reference (composite, DO NOT override directly)

**Bundle Image Variables** (OLMv0):
- `BUNDLE_REGISTRY` - Registry hostname (default: `ghcr.io`)
- `BUNDLE_ORG` - Organization/namespace path (default: `stacklok/toolhive`)
- `BUNDLE_NAME` - Image name (default: `bundle`)
- `BUNDLE_TAG` - Image tag (default: `v0.2.17`)
- `BUNDLE_IMG` - Full image reference (composite, DO NOT override directly)

**Index Image Variables** (OLMv0):
- `INDEX_REGISTRY` - Registry hostname (default: `ghcr.io`)
- `INDEX_ORG` - Organization/namespace path (default: `stacklok/toolhive`)
- `INDEX_NAME` - Image name (default: `index-olmv0`)
- `INDEX_TAG` - Image tag (default: `v0.2.17`)
- `INDEX_OLMV0_IMG` - Full image reference (composite, DO NOT override directly)

**Important**: Only override component variables (`*_REGISTRY`, `*_ORG`, `*_NAME`, `*_TAG`). The composite variables (`*_IMG`) are automatically constructed from components.

---

### Default Values

```makefile
# Catalog Image (OLMv1)
CATALOG_REGISTRY = ghcr.io
CATALOG_ORG = stacklok/toolhive
CATALOG_NAME = catalog
CATALOG_TAG = v0.2.17
# Composite: ghcr.io/stacklok/toolhive/catalog:v0.2.17

# Bundle Image (OLMv0)
BUNDLE_REGISTRY = ghcr.io
BUNDLE_ORG = stacklok/toolhive
BUNDLE_NAME = bundle
BUNDLE_TAG = v0.2.17
# Composite: ghcr.io/stacklok/toolhive/bundle:v0.2.17

# Index Image (OLMv0)
INDEX_REGISTRY = ghcr.io
INDEX_ORG = stacklok/toolhive
INDEX_NAME = index-olmv0
INDEX_TAG = v0.2.17
# Composite: ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
```

---

### Make Targets That Support Overrides

**Build Targets**:
- `catalog-build` - Build OLMv1 catalog image
- `bundle-build` - Build OLMv0 bundle image
- `index-olmv0-build` - Build OLMv0 index image

**Push Targets**:
- `catalog-push` - Push catalog image (both versioned and `:latest` tag)
- `bundle-push` - Push bundle image (both versioned and `:latest` tag)
- `index-olmv0-push` - Push index image (both versioned and `:latest` tag)

**Validate Targets**:
- `catalog-validate` - Validate OLMv1 catalog structure
- `bundle-validate` - Validate OLMv0 bundle format
- `index-olmv0-validate` - Validate OLMv0 index content

**Clean Targets**:
- `clean-images` - Remove all operator container images
- `index-clean` - Remove index images specifically

**Debug Targets**:
- `show-image-vars` - Display effective variable values (if implemented)

**Note**: All targets that reference image variables (`*_IMG`) will automatically use your overridden component values.

---

### Override Precedence Order

Variables are resolved in the following precedence (highest to lowest):

1. **Command-line arguments** (highest precedence)
   ```bash
   make catalog-build CATALOG_TAG=cli-value
   ```

2. **Environment variables**
   ```bash
   export CATALOG_TAG=env-value
   make catalog-build
   ```

3. **Makefile defaults** (lowest precedence, used when no override)
   ```makefile
   CATALOG_TAG ?= v0.2.17
   ```

**Example**: CLI overrides environment:
```bash
export CATALOG_TAG=from-env
make catalog-build CATALOG_TAG=from-cli
# Result: Uses "from-cli" (CLI wins)
```

---

## Advanced Usage

### Building with Semantic Version Metadata

```bash
# Build with semantic version including build metadata
make bundle-build BUNDLE_TAG=v1.0.0-rc1+build.123

# Build with pre-release identifier
make catalog-build CATALOG_TAG=v2.0.0-beta.2
```

---

### Multi-Architecture Image References

```bash
# Build for specific architecture (if build supports it)
make catalog-build \
  CATALOG_TAG=v0.2.17-arm64

# Build for multiple architectures with different tags
make catalog-build CATALOG_TAG=v0.2.17-amd64
make catalog-build CATALOG_TAG=v0.2.17-arm64
```

---

### Using Custom Image Names

```bash
# Build with descriptive custom name
make catalog-build \
  CATALOG_NAME=toolhive-operator-catalog-experimental

# This produces:
# ghcr.io/stacklok/toolhive/toolhive-operator-catalog-experimental:v0.2.17
```

---

### Combining All Overrides

```bash
# Full custom configuration
make index-olmv0-build \
  INDEX_REGISTRY=quay.io \
  INDEX_ORG=mycompany/operators \
  INDEX_NAME=toolhive-index-custom \
  INDEX_TAG=feature-xyz-v1

# This produces:
# quay.io/mycompany/operators/toolhive-index-custom:feature-xyz-v1
```

---

## Related Documentation

- **Contracts**: See [contracts/makefile-variables.md](contracts/makefile-variables.md) for variable naming conventions
- **Override Precedence**: See [contracts/override-precedence.md](contracts/override-precedence.md) for detailed precedence rules
- **Data Model**: See [data-model.md](data-model.md) for container image reference structure
- **Implementation Plan**: See [plan.md](plan.md) for technical architecture
- **Feature Specification**: See [spec.md](spec.md) for complete requirements

---

## Feedback and Issues

If you encounter issues not covered in this guide:

1. **Verify your Makefile version**: Ensure you're using the version that includes custom image naming support
2. **Check variable syntax**: Review the reference section for correct variable names
3. **Test with dry-run**: Use `make -n <target>` to see expanded commands
4. **Review research findings**: See [research.md](research.md) for implementation details

---

**Last Updated**: 2025-10-10
**Feature Version**: 005-custom-container-image
**Makefile Compatibility**: Requires Makefile with hierarchical variable composition (spec 005+)
