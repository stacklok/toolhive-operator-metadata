# Contract: Rollback Procedure

**Feature**: 011-v0-2-17
**Purpose**: Define guaranteed rollback capability from v0.3.11 to v0.2.17
**Requirement**: NFR-005

## Rollback Guarantee

The version upgrade MUST be fully reversible by reverting version number changes only. No data migration, schema changes, or manual cleanup should be required.

---

## Rollback Triggers

Rollback should be initiated if any of the following occur:

1. **Validation Failures**:
   - Scorecard tests fail (any of 6 tests)
   - Bundle validation fails
   - Catalog validation fails
   - Constitution check fails

2. **Deployment Failures**:
   - Operator fails to start with v0.3.11 images
   - CRD reconciliation errors occur
   - Breaking API changes discovered

3. **Compatibility Issues**:
   - v0.3.11 introduces unexpected behavior
   - OpenShift compatibility problems
   - Image availability issues

4. **Runtime Failures**:
   - Cosign signature verification failures (v3.10.1 incompatibility)
   - Container image pull failures with attestation errors
   - MCPServer pods fail to start with image validation errors

---

## Pre-Rollback Checklist

Before initiating rollback:

- [ ] Document the failure reason
- [ ] Capture error logs/messages
- [ ] Verify v0.2.17 manifests still exist in downloaded/toolhive-operator/0.2.17/
- [ ] Confirm git history shows the upgrade commit
- [ ] Ensure no manual edits were made outside git-tracked files

---

## Rollback Procedure

### Step 1: Git Revert

```bash
# Identify the version upgrade commit
git log --oneline --grep="v0.3.11" -n 5

# Revert the commit (creates new revert commit)
git revert <commit-hash>

# OR: Reset to previous commit (rewrites history - use with caution)
# git reset --hard HEAD~1
```

**Verification**:
```bash
# Check version references reverted
grep -r "v0.2.17" config/base/params.env config/manager/manager.yaml Makefile
# Expected: All show v0.2.17

# Check git status
git status
# Expected: Clean working tree or staged revert commit
```

---

### Step 2: Regenerate Bundle

```bash
# Clean existing bundle
make clean-bundle

# Regenerate with v0.2.17 references
make bundle
```

**Verification**:
```bash
# Check bundle references v0.2.17
grep "v0.2.17" bundle/manifests/toolhive-operator.clusterserviceversion.yaml
# Expected: CSV references v0.2.17 images

# Validate bundle structure
operator-sdk bundle validate bundle/
# Expected: All validation tests pass
```

---

### Step 3: Validate Rollback

```bash
# Run comprehensive validation
make validate-all
```

**Expected Results**:

1. **Kustomize Builds** (SC-001):
   ```bash
   kustomize build config/base    # Exit 0
   kustomize build config/default # Exit 0
   ```

2. **Bundle Validation** (SC-002):
   ```bash
   operator-sdk bundle validate bundle/
   # Output: All validation tests have completed successfully
   ```

3. **Scorecard Tests** (SC-004):
   ```bash
   make scorecard-test
   # Output: ✅ All scorecard tests passed (6/6)
   ```

4. **Constitution Check** (SC-005):
   ```bash
   make constitution-check
   # Output: Constitution compliance: ✅ PASSED
   ```

---

### Step 4: Rebuild Catalog (Optional)

```bash
# Rebuild catalog with v0.2.17 bundle reference
make catalog-build

# Validate catalog
opm validate catalog/
```

---

### Step 5: Verify Rollback Completion

**File Verification**:
```bash
# Configuration files
grep "toolhive-operator-image2" config/base/params.env
# Expected: ghcr.io/stacklok/toolhive/operator:v0.2.17

grep "toolhive-proxy-image" config/base/params.env
# Expected: ghcr.io/stacklok/toolhive/proxyrunner:v0.2.17

grep "CATALOG_TAG" Makefile | head -1
# Expected: CATALOG_TAG ?= v0.2.17

# Generated manifests
grep -c "v0.3.11" bundle/manifests/*
# Expected: 0 (zero occurrences)

grep -c "v0.2.17" bundle/manifests/*
# Expected: >0 (multiple occurrences)
```

**Validation Summary**:
```bash
echo "=== Rollback Validation Summary ==="
echo "Kustomize builds: $(kustomize build config/base > /dev/null 2>&1 && echo PASS || echo FAIL)"
echo "Bundle validates: $(operator-sdk bundle validate bundle/ 2>&1 | grep -q 'completed successfully' && echo PASS || echo FAIL)"
echo "CRDs unchanged: $(git diff --exit-code config/crd/ > /dev/null 2>&1 && echo PASS || echo FAIL)"
echo "v0.2.17 active: $(grep -q 'v0.2.17' config/base/params.env && echo PASS || echo FAIL)"
echo "v0.3.11 removed: $(! grep -q 'v0.3.11' bundle/manifests/* 2>/dev/null && echo PASS || echo FAIL)"
```

---

## Rollback Success Criteria

Rollback is considered successful when:

1. ✅ All file references show v0.2.17 (zero v0.3.11 references)
2. ✅ `kustomize build` succeeds for both config/base and config/default
3. ✅ `operator-sdk bundle validate` passes
4. ✅ `make scorecard-test` passes all 6 tests
5. ✅ `make constitution-check` passes
6. ✅ Git history shows revert commit or reset to pre-upgrade state
7. ✅ Downloaded manifests at downloaded/toolhive-operator/0.2.17/ are intact

---

## Rollback Time Expectations

| Step | Expected Duration | Cumulative Time |
|------|------------------|-----------------|
| 1. Git revert | <1 minute | 1 minute |
| 2. Regenerate bundle | 2-5 minutes | 6 minutes |
| 3. Validate rollback | 3-5 minutes | 11 minutes |
| 4. Rebuild catalog (optional) | 2-3 minutes | 14 minutes |
| 5. Verify completion | 1 minute | 15 minutes |

**Total Rollback Time**: **Under 15 minutes** from decision to validated v0.2.17 configuration

---

## Rollback Failure Scenarios

If rollback fails, escalate with:

### Scenario 1: Git Revert Creates Conflicts

**Symptom**: `git revert` reports merge conflicts

**Resolution**:
```bash
# Abort revert
git revert --abort

# Manual revert approach
git diff <commit-hash>~1 <commit-hash> > upgrade.patch
patch -R -p1 < upgrade.patch

# Or: Manual file edits
# Edit config/base/params.env: v0.3.11 → v0.2.17
# Edit config/manager/manager.yaml: v0.3.11 → v0.2.17
# Edit Makefile: v0.3.11 → v0.2.17
```

### Scenario 2: Bundle Generation Fails

**Symptom**: `make bundle` fails with errors

**Resolution**:
```bash
# Verify Makefile variables
grep "TAG" Makefile | grep "v0.2.17"

# Verify downloaded manifests exist
ls -la downloaded/toolhive-operator/0.2.17/

# Force clean rebuild
make clean
make bundle FORCE=true
```

### Scenario 3: Validation Fails After Rollback

**Symptom**: Scorecard or bundle validation fails

**Resolution**:
1. Compare current bundle with known-good v0.2.17 bundle
2. Check for manual edits outside version changes
3. Re-clone repository and redo rollback from clean state
4. Consult git history for unexpected changes

### Scenario 4: Cosign Runtime Failures (v3.10.1 Incompatibility)

**Symptom**: After v0.3.11 deployment to cluster:
- Operator logs show "signature verification failed" errors
- Container image pull failures with attestation/verification errors
- MCPServer pods stuck in `ImagePullBackOff` or `ErrImagePull` state
- Events show: `Failed to pull image: signature verify failed`

**Detection**:
```bash
# Check operator logs
kubectl logs -n opendatahub deployment/toolhive-operator-controller-manager | grep -i "signature\|cosign\|verify"

# Check MCPServer pod events
kubectl get events -n opendatahub --field-selector involvedObject.kind=Pod | grep -i "image\|pull"
```

**Root Cause**: Cosign downgrade from v4 to v3.10.1 in v0.3.11 is incompatible with cluster's image signing/verification infrastructure

**Resolution**:
1. **Immediate**: Initiate rollback to v0.2.17 using standard procedure (Steps 1-5)
2. **Verify**: After rollback, confirm operator logs no longer show signature errors
3. **Document**: Capture full error messages and cosign version info
4. **Escalate**: Report to upstream ToolHive project with evidence
5. **Wait**: Do not retry v0.3.11 until upstream addresses cosign compatibility

**Note**: This failure mode cannot be detected by build/validation tests (T010-T013); only appears in live cluster runtime.

---

## Post-Rollback Actions

After successful rollback:

1. **Document Failure**: Update issue tracker with:
   - Why v0.3.11 upgrade failed
   - Error messages/logs
   - Rollback timestamp
   - Next steps (fix, wait for upstream, etc.)

2. **Communicate**: Notify stakeholders that v0.2.17 is active

3. **Preserve Evidence**: Keep logs and error messages for investigation

4. **Plan Next Attempt**: Determine when to retry upgrade (after upstream fix, after testing, etc.)

---

## Rollback Contract Guarantees

This rollback procedure guarantees:

1. **Time Bound**: Rollback completes in under 15 minutes
2. **Data Safety**: No data loss or corruption
3. **State Consistency**: v0.2.17 configuration identical to pre-upgrade
4. **Validation**: All validation steps pass after rollback
5. **Repeatability**: Procedure can be executed multiple times
6. **Automation**: No manual intervention beyond executing commands

**Contract Version**: 1.0
**Last Validated**: 2025-10-21
