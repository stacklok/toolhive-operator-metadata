# Research: OpenShift OLM v1 File-Based Catalog Metadata Requirements for OperatorHub Display

**Feature**: 007-fix-operatorhub-availability
**Date**: 2025-10-15
**Status**: Complete

## Overview

This research investigates the required metadata fields for OpenShift OLM v1 File-Based Catalogs to appear correctly in the OperatorHub web UI. The current issue is that a successfully deployed File-Based Catalog (pod runs, serves gRPC) does not display properly in OperatorHub - it shows with no name and zero operators.

---

## Research Question 1: Required Fields in olm.package Schema for OperatorHub Display

### Decision: Current catalog.yaml has all structurally required olm.package fields

**Current olm.package fields** (from `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/catalog/toolhive-operator/catalog.yaml`):
- `schema: olm.package` ✅
- `name: toolhive-operator` ✅
- `defaultChannel: fast` ✅
- `description: |` (multi-line operator description) ✅
- `icon.base64data` ✅
- `icon.mediatype: image/svg+xml` ✅

### Rationale: OLM v1 Package Schema Requirements

According to the OLM v1 File-Based Catalog specification:

**Required fields for olm.package**:
1. **schema** (string) - Must be "olm.package"
2. **name** (string) - Package name, must match package field in olm.bundle and olm.channel
3. **defaultChannel** (string) - Name of the default channel for this package

**Optional but important for OperatorHub display**:
4. **description** (string) - Package description shown in OperatorHub UI
5. **icon** (object) - Package icon displayed in OperatorHub
   - `icon.base64data` (string) - Base64-encoded icon image
   - `icon.mediatype` (string) - MIME type (e.g., "image/svg+xml", "image/png")

**Analysis**: The current catalog.yaml contains all required fields plus the optional fields for OperatorHub display. The package schema itself is correctly structured.

### Alternatives Considered

**Alternative 1: Add displayName field to olm.package**
- **Status**: Not applicable to olm.package schema
- **Reason**: The olm.package schema does not have a displayName field. The displayName comes from the ClusterServiceVersion (CSV) in the bundle, not from the package metadata.

**Alternative 2: Add additional metadata fields (keywords, categories)**
- **Status**: Not applicable to olm.package schema
- **Reason**: These fields belong in the CSV, not the package metadata. The olm.package schema is minimal by design.

---

## Research Question 2: Required Fields in olm.bundle Schema for Package Manifest Creation

### Decision: Missing critical olm.bundle.object properties - ClusterServiceVersion is not referenced

**Current olm.bundle properties** (from `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/catalog/toolhive-operator/catalog.yaml`):
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

**CRITICAL FINDING**: The bundle is missing the **olm.bundle.object** property for the ClusterServiceVersion (CSV).

### Rationale: Why olm.bundle.object is Required for OperatorHub Display

When comparing with the output of `opm render bundle/` (which successfully generates FBC from the bundle directory), we can see that a properly rendered bundle includes:

```json
{
  "type": "olm.bundle.object",
  "value": {
    "data": "<base64-encoded-CSV>"
  }
}
```

**Why this matters**:

1. **PackageManifest Creation**: OLM creates PackageManifest resources by reading the catalog metadata. The PackageManifest includes:
   - Package name and description (from olm.package)
   - Channel information (from olm.channel)
   - **CSV metadata including displayName, description, icon** (from olm.bundle.object containing the CSV)

2. **OperatorHub Display**: The OperatorHub UI displays:
   - **Catalog name**: From CatalogSource.spec.displayName ✅ (already present)
   - **Operator count**: Number of packages that have valid CSV data ❌ (missing - no CSV in bundle)
   - **Operator name**: From CSV.spec.displayName ❌ (missing - no CSV in bundle)
   - **Operator description**: From CSV.spec.description ❌ (missing - no CSV in bundle)
   - **Operator icon**: From CSV.spec.icon ❌ (missing - no CSV in bundle)

3. **Current Symptom Explanation**: The catalog shows with:
   - No name → Because the operator displayName comes from CSV, not package description
   - Zero operators → Because OLM cannot create a valid PackageManifest without CSV metadata

### Required olm.bundle Properties for Full Functionality

**Minimum required properties**:
1. **type: olm.package** - Package version information ✅
2. **type: olm.gvk** - CRD information (one per CRD) ✅
3. **type: olm.bundle.object** - CSV data ❌ **MISSING**
4. **type: olm.bundle.object** - CRD objects (one per CRD) - Optional but recommended

**Additional useful properties**:
- **type: olm.csv.metadata** - CSV metadata extracted for quick access
- **type: olm.bundle.mediatype** - Bundle format version
- **type: olm.package.required** - Package dependencies

### Alternatives Considered

**Alternative 1: Manually add CSV as olm.bundle.object property**
- **Status**: Not recommended
- **Reason**: Base64 encoding large CSV YAML is error-prone and difficult to maintain

**Alternative 2: Use opm render to generate complete FBC**
- **Status**: **RECOMMENDED SOLUTION**
- **Reason**: `opm render bundle/` automatically extracts CSV and CRDs from the bundle directory and creates proper olm.bundle.object entries
- **Implementation**: Replace manually created catalog.yaml with opm-generated catalog

**Alternative 3: Use opm alpha render-template**
- **Status**: Considered but not preferred
- **Reason**: More complex, requires template syntax, harder to understand and maintain

---

## Research Question 3: Metadata Causing OperatorHub UI to Show Catalog Name and Operator Count

### Decision: Three-layer metadata structure determines OperatorHub display

**Layer 1: CatalogSource Metadata** (Kubernetes resource)
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-catalog
  namespace: openshift-marketplace
spec:
  displayName: ToolHive Operator Catalog  # Shows in Sources section
  publisher: Stacklok  # Shows in OperatorHub
```

**Layer 2: Package Metadata** (olm.package schema in catalog.yaml)
```yaml
schema: olm.package
name: toolhive-operator
description: |
  ToolHive Operator manages MCP servers...
icon:
  base64data: PHN2Zy...
  mediatype: image/svg+xml
```

**Layer 3: CSV Metadata** (embedded in olm.bundle.object)
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: ClusterServiceVersion
metadata:
  name: toolhive-operator.v0.2.17
spec:
  displayName: ToolHive Operator  # Primary display name in OperatorHub
  description: |
    The ToolHive Operator manages MCP servers...
  icon:
    - base64data: PHN2Zy...
      mediatype: image/svg+xml
```

### OperatorHub UI Display Mapping

| UI Element | Data Source | Current Status |
|------------|-------------|----------------|
| **Sources Section - Catalog Name** | CatalogSource.spec.displayName | ✅ Shows "ToolHive Operator Catalog" |
| **Sources Section - Operator Count** | Count of packages with valid CSV | ❌ Shows "(0)" - no CSV in bundle |
| **Operator Tile - Name** | CSV.spec.displayName | ❌ Not displayed - no CSV in bundle |
| **Operator Tile - Description** | CSV.spec.description (first line) | ❌ Not displayed - no CSV in bundle |
| **Operator Tile - Icon** | CSV.spec.icon | ❌ Not displayed - no CSV in bundle |
| **Operator Details - Full Description** | CSV.spec.description | ❌ Not available - no CSV in bundle |
| **Operator Details - Provider** | CSV.spec.provider.name | ❌ Not available - no CSV in bundle |
| **Operator Details - Categories** | CSV.metadata.annotations.categories | ❌ Not available - no CSV in bundle |

### Rationale: Why All Three Layers Matter

1. **CatalogSource.spec.displayName**: Identifies the catalog source in the UI but does NOT provide operator-level information
2. **olm.package.description**: Provides package-level description but is NOT used for operator display in OperatorHub
3. **CSV.spec.displayName**: This is the **primary source** for operator name in OperatorHub UI

**Root Cause**: The catalog.yaml contains package metadata but lacks the CSV data that OperatorHub requires to display operators.

---

## Research Question 4: CatalogSource Fields That Must Match Package Metadata

### Decision: No strict matching requirements, but consistency improves user experience

**CatalogSource fields** (from `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/examples/catalogsource-olmv1.yaml`):
```yaml
spec:
  displayName: ToolHive Operator Catalog
  publisher: Stacklok
  sourceType: grpc
  image: ghcr.io/stacklok/toolhive/catalog:v0.2.17
```

**Package metadata** (from catalog.yaml):
```yaml
schema: olm.package
name: toolhive-operator  # Must match bundle package field
defaultChannel: fast  # Must exist in olm.channel entries
```

### Required Matches

1. **CatalogSource.spec.sourceType = "grpc"** ✅
   - Matches: Executable catalog with registry-server
   - Required: Yes, for File-Based Catalog with opm serve

2. **olm.package.name = olm.bundle.package** ✅
   - Matches: Both are "toolhive-operator"
   - Required: Yes, OLM validates this consistency

3. **olm.package.defaultChannel exists in olm.channel** ✅
   - Matches: "fast" channel exists in catalog.yaml
   - Required: Yes, OLM will fail validation otherwise

### Optional Consistency (Best Practices)

4. **CatalogSource.spec.publisher ≈ CSV.spec.provider.name**
   - Current: "Stacklok" in both ✅
   - Recommended: Keep consistent for user clarity

5. **CatalogSource.spec.displayName contains package theme**
   - Current: "ToolHive Operator Catalog" (good naming)
   - Recommended: Include "Catalog" suffix to differentiate from operator name

### Alternatives Considered

**Alternative 1: Use package description as catalog displayName**
- **Status**: Not recommended
- **Reason**: CatalogSource displayName should identify the catalog source, not individual operators

**Alternative 2: Match all names exactly (catalog, package, CSV)**
- **Status**: Not recommended
- **Reason**: Each serves a different purpose and should have appropriate names

---

## Research Question 5: Relationship Between CatalogSource displayName and Package Metadata

### Decision: These are independent fields serving different purposes

**CatalogSource.spec.displayName** (Catalog-level):
- **Purpose**: Identifies the catalog source in OperatorHub Sources section
- **Scope**: Applies to the entire catalog (may contain multiple packages)
- **Display**: Shows in Sources list with operator count in parentheses
- **Example**: "ToolHive Operator Catalog (1)"

**olm.package.description** (Package-level):
- **Purpose**: Provides package-level description for documentation
- **Scope**: Describes a single package within the catalog
- **Display**: **NOT directly displayed in OperatorHub UI**
- **Usage**: May be used by CLI tools (kubectl/oc) or API consumers

**CSV.spec.displayName** (Operator-level):
- **Purpose**: Primary operator name shown in OperatorHub
- **Scope**: Describes a specific operator version
- **Display**: **Primary operator name in OperatorHub tiles and details**
- **Example**: "ToolHive Operator"

### Rationale: Three-Tier Hierarchy

```
CatalogSource (ToolHive Operator Catalog)
└── Package (toolhive-operator)
    ├── Channel (fast)
    │   └── Bundle (v0.2.17)
    │       └── CSV (ToolHive Operator)
    └── Channel (stable) [future]
        └── Bundle (v1.0.0) [future]
```

**Why displayName doesn't cascade**:
- A catalog may contain multiple packages (e.g., "Red Hat Operators" contains 100+ operators)
- Each operator needs its own displayName from its CSV
- Package description is metadata, not a display field

### Current vs. Expected Behavior

**Current** (catalog.yaml without CSV):
```
OperatorHub → Sources
  └── [unnamed catalog] (0)  ❌ No CSV = no operator count
```

**Expected** (catalog.yaml with CSV):
```
OperatorHub → Sources
  └── ToolHive Operator Catalog (1)  ✅

OperatorHub → All Items
  └── [ToolHive Operator]  ✅ CSV.spec.displayName
      Icon: [blue M icon]   ✅ CSV.spec.icon
      Description: "Manages MCP servers..."  ✅ CSV.spec.description
```

---

## Research Question 6: Debugging Steps to Verify Package Manifest Creation

### Decision: Multi-step verification process from catalog deployment to OperatorHub display

**Step 1: Verify CatalogSource Creation and Status**

```bash
# Check CatalogSource exists and is ready
oc get catalogsource -n openshift-marketplace toolhive-catalog

# Expected output:
# NAME               DISPLAY                       TYPE   PUBLISHER   AGE
# toolhive-catalog   ToolHive Operator Catalog     grpc   Stacklok    2m
```

**Check CatalogSource status conditions**:
```bash
oc get catalogsource -n openshift-marketplace toolhive-catalog -o yaml

# Look for status.connectionState.lastObservedState: READY
# Status should show:
#   status:
#     connectionState:
#       lastObservedState: READY
#       lastConnect: <timestamp>
```

**Step 2: Verify Catalog Pod Deployment and Logs**

```bash
# Find catalog pod
oc get pods -n openshift-marketplace | grep toolhive-catalog

# Expected output:
# toolhive-catalog-xyz   1/1     Running   0          2m

# Check pod logs for registry-server startup
oc logs -n openshift-marketplace <catalog-pod-name>

# Expected log output:
# time="..." level=info msg="serving registry" database=/tmp/cache port=50051
# OR (for uncached):
# time="..." level=info msg="serving FBC catalogs" port=50051
```

**Common Issues**:
- Pod in ImagePullBackOff → Image not accessible from registry
- Pod in CrashLoopBackOff → Catalog metadata validation failed
- Logs show "no such file or directory" → Missing /configs directory in image
- Logs show "invalid catalog" → Malformed YAML or schema errors

**Step 3: Verify gRPC Service Accessibility**

```bash
# Check if Service exists
oc get svc -n openshift-marketplace | grep toolhive-catalog

# Expected output:
# toolhive-catalog   ClusterIP   10.x.x.x   <none>   50051/TCP   2m

# Test gRPC health probe (from within cluster or port-forward)
oc port-forward -n openshift-marketplace svc/toolhive-catalog 50051:50051 &
grpc_health_probe -addr localhost:50051

# Expected output:
# status: SERVING
```

**Step 4: Verify PackageManifest Creation** (CRITICAL STEP)

```bash
# List all PackageManifests
oc get packagemanifests -A

# Check for toolhive-operator package
oc get packagemanifest toolhive-operator

# Expected output:
# NAME                CATALOG                       AGE
# toolhive-operator   ToolHive Operator Catalog     2m

# If missing, PackageManifest was not created → catalog metadata issue
```

**Inspect PackageManifest details**:
```bash
oc get packagemanifest toolhive-operator -o yaml

# Key fields to verify:
# status:
#   catalogSource: toolhive-catalog
#   catalogSourceNamespace: openshift-marketplace
#   catalogSourceDisplayName: ToolHive Operator Catalog
#   provider:
#     name: Stacklok
#   channels:
#     - name: fast
#       currentCSV: toolhive-operator.v0.2.17
#       currentCSVDesc:
#         displayName: ToolHive Operator  ← Should come from CSV
#         description: "..."               ← Should come from CSV
#         icon:
#           - base64data: "..."            ← Should come from CSV
#             mediatype: image/svg+xml
```

**If PackageManifest is missing or incomplete**:
- **Missing entirely** → Catalog has no valid packages (no CSV in bundle)
- **Present but no currentCSVDesc.displayName** → CSV not embedded in bundle
- **Present but empty channels** → Channel configuration issue

**Step 5: Verify Operator Visibility in OperatorHub UI**

**Via Web Console**:
1. Navigate to: Operators → OperatorHub
2. Check Sources section (left sidebar):
   - Should show "ToolHive Operator Catalog (1)"
   - Number in parentheses = operator count
3. Search for "toolhive" in search box
4. Operator tile should appear with:
   - Name: "ToolHive Operator"
   - Icon: Blue M icon
   - Description preview
   - Provider: "Stacklok"

**Via CLI**:
```bash
# Query OperatorHub for available operators from catalog
oc get packagemanifests -l catalog=toolhive-catalog

# Check operator appears in search
oc get packagemanifests -o json | jq '.items[] | select(.metadata.name == "toolhive-operator") | .status.catalogSourceDisplayName'

# Expected output:
# "ToolHive Operator Catalog"
```

**Step 6: Debug Catalog Metadata Structure**

```bash
# Extract catalog metadata from image
podman run --rm ghcr.io/stacklok/toolhive/catalog:v0.2.17 cat /configs/toolhive-operator/catalog.yaml

# Validate catalog with opm
opm validate catalog/

# Expected output:
# [no output = validation passed]

# If validation fails, check:
# - YAML syntax errors
# - Missing required fields (schema, name, package)
# - Mismatched package names across schemas
# - Invalid channel references
```

**Step 7: Test Catalog with opm serve Locally**

```bash
# Serve catalog locally for testing
opm serve catalog/ --cache-dir=/tmp/cache

# In another terminal, query with grpcurl
grpcurl -plaintext localhost:50051 api.Registry/ListPackages

# Expected output (JSON):
# {
#   "name": "toolhive-operator"
# }

# Get package details
grpcurl -plaintext -d '{"name":"toolhive-operator"}' localhost:50051 api.Registry/GetPackage

# Expected output should include:
# - Package name
# - Channels
# - Bundle metadata including CSV data
```

**Step 8: Compare with Working Catalog**

```bash
# Check a known-working catalog (e.g., community-operators)
oc get catalogsource -n openshift-marketplace
oc get packagemanifests | grep community-operators

# Compare structure and fields with toolhive-catalog
```

### Debugging Decision Tree

```
CatalogSource READY?
├─ NO → Check pod status, logs, image accessibility
└─ YES → PackageManifest exists?
    ├─ NO → Check catalog.yaml structure, missing CSV in bundle
    └─ YES → PackageManifest has displayName?
        ├─ NO → CSV not embedded in olm.bundle.object
        └─ YES → OperatorHub shows operator?
            ├─ NO → Browser cache issue, UI bug (rare)
            └─ YES → ✅ Working correctly
```

---

## Key Findings Summary

### Finding 1: Root Cause of OperatorHub Display Issue

**Problem**: Catalog shows with no name and zero operators.

**Root Cause**: The catalog.yaml is missing **olm.bundle.object** properties containing the ClusterServiceVersion (CSV) data.

**Evidence**:
- Current catalog.yaml only has olm.package, olm.gvk properties
- Missing olm.bundle.object with embedded CSV
- `opm render bundle/` output shows CSV should be included as base64-encoded bundle object

**Impact**: Without CSV data:
- PackageManifest is created but incomplete
- OperatorHub cannot extract displayName, description, icon
- Operator count shows as 0 because there's no valid CSV to count

### Finding 2: Correct Catalog Generation Method

**Decision**: Use `opm render bundle/` instead of manually writing catalog.yaml

**Rationale**:
1. **Automatic CSV Extraction**: opm render reads the CSV from bundle/manifests/ and embeds it correctly
2. **Complete Metadata**: Generates all required olm.bundle.object entries
3. **Validation**: opm validates bundle structure before rendering
4. **Maintenance**: Bundle changes automatically flow to catalog

**Current Process** (manual, incomplete):
```bash
# Manually write catalog.yaml with package, channel, bundle schemas
# Missing: CSV embedding
```

**Correct Process** (automated, complete):
```bash
# Generate catalog from bundle directory
opm render bundle/ > catalog/toolhive-operator/catalog.yaml

# Or for template-based approach:
opm alpha render-template basic catalog/toolhive-operator
```

### Finding 3: CatalogSource vs. Package vs. CSV Display Hierarchy

**Three-tier display structure**:

1. **CatalogSource Level** (Catalog identity)
   - Field: `spec.displayName`
   - Display: Sources section → "ToolHive Operator Catalog (N)"
   - Purpose: Identifies catalog source containing multiple operators

2. **Package Level** (Package metadata)
   - Field: `description` (in olm.package schema)
   - Display: **Not directly shown in OperatorHub UI**
   - Purpose: Package documentation, CLI usage

3. **CSV Level** (Operator identity)
   - Field: `spec.displayName`, `spec.description`, `spec.icon`
   - Display: **Primary operator display in OperatorHub**
   - Purpose: Operator name, description, icon in UI tiles

**Mistake to Avoid**: Assuming package description or CatalogSource displayName will show as operator name.

### Finding 4: PackageManifest as Validation Checkpoint

**PackageManifest Creation** = Success Indicator

When OLM successfully reads catalog metadata and creates a PackageManifest:
- ✅ Catalog connectivity is working
- ✅ Package structure is valid
- ✅ CSV data is accessible
- ✅ OperatorHub can display the operator

**Debugging Priority**:
1. First: Verify CatalogSource READY
2. Second: Verify PackageManifest created
3. Third: Inspect PackageManifest for CSV fields
4. Fourth: Check OperatorHub UI display

**Command**: `oc get packagemanifest <package-name> -o yaml`

This is the most reliable way to verify catalog metadata completeness before checking UI.

---

## Recommendations for Implementation

### Recommendation 1: Regenerate Catalog with opm render

**Action**: Replace manually created catalog.yaml with opm-rendered version

```bash
# Backup current catalog
cp catalog/toolhive-operator/catalog.yaml catalog/toolhive-operator/catalog.yaml.manual

# Generate complete catalog from bundle
opm render bundle/ > catalog/toolhive-operator/catalog.yaml

# Validate
opm validate catalog/
```

**Expected Changes**:
- Addition of olm.bundle.object entries with base64-encoded CSV and CRDs
- Addition of olm.csv.metadata property (optional but useful)
- Potential addition of other OLM properties

### Recommendation 2: Update Makefile Catalog Target

**Action**: Add `catalog-generate` target to automate catalog creation

```makefile
.PHONY: catalog-generate
catalog-generate: ## Generate FBC catalog from bundle directory
	@echo "Generating FBC catalog from bundle..."
	@opm render bundle/ > catalog/toolhive-operator/catalog.yaml
	@echo "✅ Catalog generated from bundle"
```

### Recommendation 3: Update Development Registry References

**Action**: Change image references from ghcr.io/stacklok to quay.io/roddiekieley in:
- catalog.yaml bundle image field
- examples/catalogsource-olmv1.yaml catalog image field
- examples/subscription.yaml sourceNamespace field

**Impact**:
- Catalog will reference development bundle image
- Examples will work with development registry
- Subscription will correctly find catalog in openshift-marketplace

### Recommendation 4: Document PackageManifest Verification

**Action**: Add debugging section to quickstart or README

**Content**:
```markdown
## Verifying Catalog Deployment

After deploying the CatalogSource, verify PackageManifest creation:

```bash
# Check CatalogSource status
oc get catalogsource -n openshift-marketplace toolhive-catalog

# Verify PackageManifest created
oc get packagemanifest toolhive-operator

# Inspect operator metadata
oc get packagemanifest toolhive-operator -o jsonpath='{.status.channels[0].currentCSVDesc.displayName}'
# Expected: "ToolHive Operator"
```

If PackageManifest is missing, check catalog pod logs for errors.
```

---

## Alternatives Considered and Rejected

### Alternative 1: Keep Manual Catalog and Add CSV Manually

**Approach**: Manually base64-encode CSV and add as olm.bundle.object property

**Rejected Because**:
- Extremely error-prone (base64 encoding large YAML files)
- Difficult to maintain (CSV changes require re-encoding)
- No validation during encoding
- opm render provides this automatically and correctly

### Alternative 2: Use Different Channel Name to Match Common Patterns

**Approach**: Change channel from "fast" to "stable" for better convention

**Rejected Because**:
- Channel name is cosmetic and doesn't affect OperatorHub display
- "fast" is a valid channel name
- Changing it provides no technical benefit for this issue
- Bundle annotations already specify "fast" channel

### Alternative 3: Add displayName to olm.package Schema

**Approach**: Add a displayName field to package metadata

**Rejected Because**:
- olm.package schema doesn't support displayName field
- OLM expects displayName from CSV, not package metadata
- This would not solve the root cause (missing CSV in bundle)

### Alternative 4: Modify CatalogSource to Include Package Metadata

**Approach**: Add package metadata fields to CatalogSource spec

**Rejected Because**:
- CatalogSource only configures catalog source, not package content
- Package metadata belongs in catalog.yaml served via gRPC
- This is not how OLM architecture works

---

## Next Steps

Proceed to Phase 1: Design & Contracts

**Required Artifacts**:
1. **data-model.md**: Document the complete FBC schema structure with CSV embedding
2. **contracts/catalog-complete.yaml**: Example of correctly rendered catalog with CSV
3. **quickstart.md**: Add opm render workflow and PackageManifest verification steps

**Implementation Tasks**:
1. Run `opm render bundle/ > catalog/toolhive-operator/catalog.yaml`
2. Update bundle image reference to quay.io/roddiekieley
3. Update CatalogSource example to use quay.io/roddiekieley
4. Fix Subscription sourceNamespace to openshift-marketplace
5. Validate catalog with `opm validate catalog/`
6. Test deployment and verify PackageManifest creation

---

## References

**OLM Documentation**:
- OLM v1 File-Based Catalog Specification: https://olm.operatorframework.io/docs/reference/file-based-catalogs/
- OLM Package Schemas: https://olm.operatorframework.io/docs/reference/catalog-templates/
- PackageManifest API: https://olm.operatorframework.io/docs/concepts/crds/packagemanifest/

**Internal Specs**:
- Spec 001 (Build OLMv1 FBC): Initial catalog creation approach
- Spec 006 (Executable Catalog Image): Multi-stage build with opm serve

**Tools**:
- opm (Operator Package Manager): Catalog rendering and validation
- grpcurl: gRPC API testing
- operator-sdk: Bundle generation and validation
