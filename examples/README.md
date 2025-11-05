# ToolHive Operator - Deployment Examples

This directory contains example Kubernetes/OpenShift manifests for deploying the ToolHive Operator.

## CatalogSource Examples

CatalogSources tell OLM (Operator Lifecycle Manager) where to find operator catalogs. Choose the appropriate example based on your OpenShift version.

### Decision Tree: Which CatalogSource Should I Use?

```
Are you running OpenShift 4.19 or newer?
│
├─ YES → Use catalogsource-olmv1.yaml
│         ✅ Recommended (modern, supported)
│         ✅ File-Based Catalog (FBC)
│         ✅ No deprecated components
│
└─ NO  → Are you running OpenShift 4.15-4.18?
          │
          ├─ YES → Use catalogsource-olmv0.yaml
          │         ⚠️  Legacy support only
          │         ⚠️  Uses deprecated SQLite index
          │         ⚠️  Will be sunset when 4.18 reaches EOL
          │
          └─ NO  → Unsupported OpenShift version
                    Please upgrade to 4.15+ to use ToolHive Operator
```

## File Descriptions

### catalogsource-olmv1.yaml (Recommended)

**For**: OpenShift 4.19+ (modern OLM)

**Description**: References a File-Based Catalog (FBC) image. The catalog image IS the index/catalog image - no additional wrapper needed.

**Quick Start**:
```bash
# Deploy the CatalogSource
kubectl apply -f examples/catalogsource-olmv1.yaml

# Verify
kubectl get catalogsource -n olm toolhive-catalog

# Install operator via OperatorHub UI or:
kubectl apply -f examples/subscription.yaml
```

**Image**: `ghcr.io/stacklok/toolhive/operator-catalog:v0.4.2`

**See**: Full documentation in [catalogsource-olmv1.yaml](catalogsource-olmv1.yaml)

---

### catalogsource-olmv0.yaml (Legacy)

**For**: OpenShift 4.15-4.18 (legacy OLM)

**Description**: References a SQLite-based index image that wraps the bundle image. Required for older OpenShift versions.

**⚠️ Deprecation Notice**: This approach uses deprecated `opm index` commands and will be sunset when OpenShift 4.18 reaches end-of-life (Q1 2026).

**Quick Start**:
```bash
# 1. Build the OLMv0 index image
make index-olmv0-build

# 2. Deploy the CatalogSource
kubectl apply -f examples/catalogsource-olmv0.yaml

# 3. Verify
kubectl get catalogsource -n olm toolhive-catalog-olmv0

# 4. Install operator via OperatorHub UI or:
kubectl apply -f examples/subscription.yaml
```

**Image**: `ghcr.io/stacklok/toolhive/operator-index:v0.4.2`

**See**: Full documentation in [catalogsource-olmv0.yaml](catalogsource-olmv0.yaml)

---

### subscription.yaml

**Description**: Example Subscription resource for installing the ToolHive Operator after deploying a CatalogSource.

**Usage**:
```bash
# After deploying a CatalogSource (olmv1 or olmv0), install the operator:
kubectl apply -f examples/subscription.yaml

# Verify installation:
kubectl get csv -n toolhive-system
kubectl get pods -n toolhive-system
```

**Note**: The subscription references the catalog name `toolhive-catalog` for OLMv1 or `toolhive-catalog-olmv0` for OLMv0. Update the `source` field if using the OLMv0 variant.

---

## OpenShift Version Compatibility Matrix

| OpenShift Version | CatalogSource to Use | OLM Version | Status |
|-------------------|---------------------|-------------|--------|
| 4.19+ | `catalogsource-olmv1.yaml` | OLMv1 FBC | ✅ Recommended |
| 4.18 | `catalogsource-olmv0.yaml` | OLMv0 SQLite | ⚠️ Legacy (EOL Q1 2026) |
| 4.17 | `catalogsource-olmv0.yaml` | OLMv0 SQLite | ⚠️ Legacy (EOL Q4 2025) |
| 4.16 | `catalogsource-olmv0.yaml` | OLMv0 SQLite | ⚠️ Legacy (EOL Q3 2025) |
| 4.15 | `catalogsource-olmv0.yaml` | OLMv0 SQLite | ⚠️ Legacy (EOL Q2 2025) |
| < 4.15 | Not supported | - | ❌ Unsupported |

## Common Issues and Solutions

### Issue: CatalogSource stuck in "Pending"

**Symptoms**: `kubectl get catalogsource` shows status as pending

**Solutions**:
1. Check image pull authentication:
   ```bash
   kubectl create secret docker-registry quay-secret \
     --docker-server=quay.io \
     --docker-username=<quay-username> \
     --docker-password=<quay-token> \
     -n olm

   # Add to CatalogSource spec:
   # spec:
   #   secrets:
   #   - quay-secret
   ```

2. Check pod logs:
   ```bash
   kubectl logs -n olm -l olm.catalogSource=toolhive-catalog
   ```

### Issue: Operator not appearing in OperatorHub

**Solutions**:
1. Wait 1-2 minutes for OLM to sync
2. Check if CatalogSource pod is running:
   ```bash
   kubectl get pods -n olm | grep toolhive-catalog
   ```
3. Check package manifest:
   ```bash
   kubectl get packagemanifest | grep toolhive
   ```

### Issue: OLMv0 index build fails

**Symptoms**: `make index-olmv0-build` fails with authentication or validation errors

**Solutions**:
1. Authenticate to container registry:
   ```bash
   podman login quay.io
   ```
2. Ensure bundle image exists:
   ```bash
   podman pull ghcr.io/stacklok/toolhive/operator-bundle:v0.4.2
   ```
3. Check `opm` version:
   ```bash
   opm version  # Should be v1.35.0+
   ```

## Additional Resources

- **Quickstart Guide**: [specs/004-registry-database-container/quickstart.md](../specs/004-registry-database-container/quickstart.md)
- **Main README**: [README.md](../README.md)
- **Validation Status**: [VALIDATION.md](../VALIDATION.md)
- **OLM Documentation**: https://olm.operatorframework.io/docs/
- **Operator Framework**: https://operatorframework.io/

## Questions?

For issues or questions:
1. Check the [quickstart guide](../specs/004-registry-database-container/quickstart.md) for detailed deployment instructions
2. Review the [main README](../README.md) for repository overview
3. File an issue in the repository if problems persist
