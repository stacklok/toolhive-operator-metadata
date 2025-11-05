# Quick Start: Upgrade ToolHive Operator to v0.3.11

**Feature**: 011-v0-2-17
**Target Time**: 15 minutes (configuration) + 15 minutes (validation)
**Skill Level**: Intermediate (familiar with Kubernetes/OLM)

## Prerequisites

- Git repository cloned and on branch `011-v0-2-17`
- `kustomize` v5.0.0+ installed
- `operator-sdk` v1.30.0+ installed
- `opm` v1.26.0+ installed
- `podman` or `docker` installed
- Kubernetes cluster access (for scorecard tests)

---

## Quick Start (15 minutes)

### Step 1: Update Configuration Files (5 minutes)

```bash
# Update params.env
sed -i 's/v0.2.17/v0.3.11/g' config/base/params.env

# Update manager.yaml
sed -i 's/v0.2.17/v0.3.11/g' config/manager/manager.yaml

# Update Makefile version tags
sed -i 's/CATALOG_TAG ?= v0.2.17/CATALOG_TAG ?= v0.3.11/' Makefile
sed -i 's/BUNDLE_TAG ?= v0.2.17/BUNDLE_TAG ?= v0.3.11/' Makefile
sed -i 's/INDEX_TAG ?= v0.2.17/INDEX_TAG ?= v0.3.11/' Makefile
```

**Verification**:
```bash
# Should show v0.3.11 in all files
grep "v0.3.11" config/base/params.env config/manager/manager.yaml Makefile
```

---

### Step 2: Download v0.3.11 Manifests (5 minutes)

```bash
# Create directory for v0.3.11 manifests
mkdir -p downloaded/toolhive-operator/0.3.11

# Download from GitHub release (example - adjust URL based on actual artifacts)
cd downloaded/toolhive-operator/0.3.11/

# Download ClusterServiceVersion
curl -L -o toolhive-operator.clusterserviceversion.yaml \
  https://raw.githubusercontent.com/stacklok/toolhive/v0.3.11/config/manifests/toolhive-operator.clusterserviceversion.yaml

# Download CRDs
curl -L -o mcpregistries.crd.yaml \
  https://raw.githubusercontent.com/stacklok/toolhive/v0.3.11/config/crd/bases/toolhive.stacklok.dev_mcpregistries.yaml

curl -L -o mcpservers.crd.yaml \
  https://raw.githubusercontent.com/stacklok/toolhive/v0.3.11/config/crd/bases/toolhive.stacklok.dev_mcpservers.yaml

cd ../../..
```

**Note**: If direct URLs don't work, download from GitHub release page manually and place files in the directory.

**Verification**:
```bash
# Check files exist
ls -la downloaded/toolhive-operator/0.3.11/
# Expected: 3 YAML files

# Verify CSV version
grep "version: v0.3.11" downloaded/toolhive-operator/0.3.11/toolhive-operator.clusterserviceversion.yaml
# Expected: Line showing spec.version: v0.3.11
```

---

### Step 3: Validate Configuration (5 minutes)

```bash
# Test kustomize builds
kustomize build config/base > /dev/null && echo "✅ config/base builds"
kustomize build config/default > /dev/null && echo "✅ config/default builds"

# Check for v0.3.11 in output
kustomize build config/base | grep "v0.3.11"
# Expected: Lines showing operator:v0.3.11 and proxyrunner:v0.3.11

# Verify no v0.2.17 remains
! kustomize build config/base | grep -q "v0.2.17" && echo "✅ No v0.2.17 in config/base"
! kustomize build config/default | grep -q "v0.2.17" && echo "✅ No v0.2.17 in config/default"
```

---

## Comprehensive Validation (15 minutes)

### Step 4: Generate and Validate Bundle (5 minutes)

```bash
# Generate bundle from v0.3.11 manifests
make bundle

# Verify bundle contents
echo "Checking bundle image references..."
grep -r "v0.3.11" bundle/manifests/
# Expected: Multiple lines with v0.3.11

# Validate bundle structure
operator-sdk bundle validate bundle/
# Expected: "All validation tests have completed successfully"
```

**Troubleshooting**:
- If bundle generation fails, check downloaded/toolhive-operator/0.3.11/ has all files
- If validation fails, check bundle/metadata/annotations.yaml has correct version

---

### Step 5: Run Scorecard Tests (8 minutes)

```bash
# Check scorecard prerequisites
make check-scorecard-deps
# Expected: All dependencies present

# Run scorecard tests
make scorecard-test
# Expected: All 6 tests pass (1 basic + 5 OLM)
```

**Expected Output**:
```
✅ All scorecard tests passed
- basic-check-spec: pass
- olm-bundle-validation: pass
- olm-crds-have-validation: pass
- olm-crds-have-resources: pass
- olm-spec-descriptors: pass
- olm-status-descriptors: pass
```

**Troubleshooting**:
- If cluster unreachable: Setup local cluster with `kind create cluster`
- If tests fail: Check bundle/manifests/ for correct CSV structure

---

### Step 6: Validate Constitution Compliance (2 minutes)

```bash
# Run constitution check
make constitution-check
# Expected: Constitution compliance: ✅ PASSED

# Verify CRDs unchanged
git diff config/crd/
# Expected: No output (CRDs must not change per constitution principle III)

# Verify both overlays build
kustomize build config/base > /dev/null && \
kustomize build config/default > /dev/null && \
echo "✅ Both overlays build successfully"
```

---

## Documentation Update (Optional - 5 minutes)

```bash
# Update README.md
sed -i 's/v0.2.17/v0.3.11/g' README.md

# Update CLAUDE.md
sed -i 's/v0.2.17/v0.3.11/g' CLAUDE.md

# Update VALIDATION.md
sed -i 's/v0.2.17/v0.3.11/g' VALIDATION.md

# Verify updates
grep "v0.3.11" README.md CLAUDE.md VALIDATION.md
```

---

## Final Verification Checklist

Run this complete verification:

```bash
#!/bin/bash
echo "=== Version Upgrade Validation ==="

# SC-001: Kustomize builds under 5 seconds
echo -n "SC-001 Kustomize builds: "
time kustomize build config/base > /dev/null 2>&1 && \
time kustomize build config/default > /dev/null 2>&1 && \
echo "PASS" || echo "FAIL"

# SC-002: Bundle validation passes
echo -n "SC-002 Bundle validation: "
operator-sdk bundle validate bundle/ 2>&1 | grep -q "completed successfully" && \
echo "PASS" || echo "FAIL"

# SC-004: Scorecard tests pass
echo -n "SC-004 Scorecard tests: "
make scorecard-test > /dev/null 2>&1 && echo "PASS" || echo "FAIL"

# SC-005: Constitution check passes
echo -n "SC-005 Constitution check: "
make constitution-check > /dev/null 2>&1 && echo "PASS" || echo "FAIL"

# SC-008: No v0.2.17 in generated manifests
echo -n "SC-008 No v0.2.17 references: "
! grep -q "v0.2.17" bundle/manifests/* 2>/dev/null && echo "PASS" || echo "FAIL"

# Version consistency check
echo -n "Version consistency: "
OPERATOR_VERSION=$(grep "toolhive-operator-image2" config/base/params.env | grep -o "v[0-9.]*")
PROXY_VERSION=$(grep "toolhive-proxy-image" config/base/params.env | grep -o "v[0-9.]*")
CATALOG_VERSION=$(grep "CATALOG_TAG" Makefile | head -1 | grep -o "v[0-9.]*")

if [ "$OPERATOR_VERSION" == "v0.3.11" ] && \
   [ "$PROXY_VERSION" == "v0.3.11" ] && \
   [ "$CATALOG_VERSION" == "v0.3.11" ]; then
  echo "PASS (all v0.3.11)"
else
  echo "FAIL (versions: op=$OPERATOR_VERSION, proxy=$PROXY_VERSION, cat=$CATALOG_VERSION)"
fi

echo "==================================="
```

**Expected Output**:
```
=== Version Upgrade Validation ===
SC-001 Kustomize builds: PASS
SC-002 Bundle validation: PASS
SC-004 Scorecard tests: PASS
SC-005 Constitution check: PASS
SC-008 No v0.2.17 references: PASS
Version consistency: PASS (all v0.3.11)
===================================
```

---

## Common Issues and Solutions

### Issue 1: "Bundle directory not found"

**Symptom**: `make scorecard-test` fails with bundle not found

**Solution**:
```bash
# Regenerate bundle
make clean-bundle
make bundle
```

---

### Issue 2: "Kustomize build fails with image not found"

**Symptom**: Kustomize fails to find v0.3.11 image

**Solution**:
```bash
# Verify images exist in registry
podman manifest inspect ghcr.io/stacklok/toolhive/operator:v0.3.11
podman manifest inspect ghcr.io/stacklok/toolhive/proxyrunner:v0.3.11

# If images don't exist, wait for upstream to publish or check version number
```

---

### Issue 3: "Scorecard tests fail"

**Symptom**: Scorecard reports test failures

**Solution**:
```bash
# Check bundle structure
operator-sdk bundle validate bundle/

# Verify CSV format
cat bundle/manifests/toolhive-operator.clusterserviceversion.yaml | yq '.spec.version'
# Expected: v0.3.11

# Check scorecard config
cat bundle/tests/scorecard/config.yaml
# Expected: Valid scorecard configuration
```

---

### Issue 4: "CRDs show diff"

**Symptom**: `git diff config/crd/` shows changes

**Solution**:
```bash
# This violates constitution principle III - STOP
# CRDs must NOT change in metadata repository
# Investigate why CRDs changed - this should not happen

# If CRDs legitimately changed upstream:
# 1. Document the breaking change
# 2. Consult with team before proceeding
# 3. May require new feature branch for CRD updates
```

---

## Rollback (If Needed)

If validation fails, rollback to v0.2.17:

```bash
# Find upgrade commit
git log --oneline --grep="v0.3.11" -n 1

# Revert the commit
git revert <commit-hash>

# Regenerate bundle
make bundle

# Validate rollback
make validate-all
```

See [contracts/rollback-procedure.md](contracts/rollback-procedure.md) for detailed rollback guide.

---

## Success Indicators

Upgrade is successful when:

- ✅ All configuration files reference v0.3.11
- ✅ Kustomize builds succeed in under 5 seconds
- ✅ Bundle validates successfully
- ✅ Scorecard tests pass (6/6)
- ✅ Constitution check passes
- ✅ Zero v0.2.17 references in bundle/manifests/
- ✅ Documentation updated to v0.3.11

---

## Next Steps

After successful upgrade:

1. **Commit changes**:
   ```bash
   git add .
   git commit -m "feat: upgrade toolhive operator to v0.3.11

   - Update config/base/params.env image references
   - Update config/manager/manager.yaml image references
   - Update Makefile version tags
   - Download v0.3.11 upstream manifests
   - Update documentation (README.md, CLAUDE.md, VALIDATION.md)

   Validated:
   - Kustomize builds succeed
   - Bundle validation passes
   - Scorecard tests pass (6/6)
   - Constitution compliance verified

   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

2. **Create pull request** (if using PR workflow)

3. **Build and push catalog** (if deploying):
   ```bash
   make catalog-build
   make catalog-push
   ```

4. **Update deployment** (if using GitOps or manual deployment)

---

## Time Summary

| Phase | Time | Cumulative |
|-------|------|------------|
| Configuration updates | 5 min | 5 min |
| Manifest download | 5 min | 10 min |
| Configuration validation | 5 min | 15 min |
| Bundle generation & validation | 5 min | 20 min |
| Scorecard tests | 8 min | 28 min |
| Constitution check | 2 min | 30 min |
| Documentation updates (optional) | 5 min | 35 min |

**Total Time**: **30 minutes** (core), **35 minutes** (with documentation)

This meets SC-006: "Version upgrade completes within 30 minutes from start to validated deployment"
