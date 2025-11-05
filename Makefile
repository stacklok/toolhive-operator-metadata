# Makefile for ToolHive Operator Metadata and OLM Bundle/Catalog
#
# This Makefile provides targets for building, validating, and managing
# OLM bundles and File-Based Catalogs (FBC) for the ToolHive Operator.

# OLMv1 Catalog Image Configuration (Modern OpenShift 4.19+)
# Components can be overridden via environment variables or make arguments:
#   make catalog-build CATALOG_REGISTRY=quay.io CATALOG_ORG=myuser
CATALOG_REGISTRY ?= ghcr.io
CATALOG_ORG ?= stacklok/toolhive
CATALOG_NAME ?= operator-catalog
CATALOG_TAG ?= v0.4.2
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)

# OLMv0 Bundle Image Configuration
# Components can be overridden independently:
#   make bundle-build BUNDLE_REGISTRY=ghcr.io BUNDLE_ORG=stacklok/toolhive BUNDLE_TAG=dev
BUNDLE_REGISTRY ?= ghcr.io
BUNDLE_ORG ?= stacklok/toolhive
BUNDLE_NAME ?= operator-bundle
BUNDLE_TAG ?= v0.4.2
BUNDLE_IMG := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):$(BUNDLE_TAG)

# OLMv0 Index Image Configuration (Legacy OpenShift 4.15-4.18)
# Components can be overridden independently:
#   make index-olmv0-build INDEX_REGISTRY=quay.io INDEX_ORG=myteam
INDEX_REGISTRY ?= ghcr.io
INDEX_ORG ?= stacklok/toolhive
INDEX_NAME ?= operator-index
INDEX_TAG ?= v0.4.2
INDEX_OLMV0_IMG := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):$(INDEX_TAG)

# Build tool configuration
OPM_MODE ?= semver
CONTAINER_TOOL ?= podman

# Upstream operator image configuration
OPERATOR_REGISTRY ?= ghcr.io
OPERATOR_ORG ?= stacklok/toolhive
OPERATOR_NAME ?= operator
OPERATOR_TAG ?= v0.4.2
OPERATOR_IMG := $(OPERATOR_REGISTRY)/$(OPERATOR_ORG)/$(OPERATOR_NAME):$(OPERATOR_TAG)

.PHONY: help
help: ## Display this help message
	@echo "ToolHive Operator Metadata - Available Targets:"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m%-30s\033[0m %s\n", "Target", "Description"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "\033[36m%-30s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: check-icon-deps
check-icon-deps: ## Check icon processing script dependencies
	@echo "Checking icon processing dependencies..."
	@command -v file >/dev/null 2>&1 || { echo "❌ Error: 'file' command not found (required for icon validation)"; exit 1; }
	@command -v identify >/dev/null 2>&1 || { echo "❌ Error: ImageMagick 'identify' command not found (install imagemagick package)"; exit 1; }
	@command -v bc >/dev/null 2>&1 || { echo "❌ Error: 'bc' command not found (install bc package)"; exit 1; }
	@test -x scripts/encode-icon.sh || { echo "❌ Error: scripts/encode-icon.sh not executable"; exit 1; }
	@test -x scripts/validate-icon.sh || { echo "❌ Error: scripts/validate-icon.sh not executable"; exit 1; }
	@echo "✅ All icon processing dependencies present"

.PHONY: check-scorecard-deps
check-scorecard-deps: ## Check scorecard prerequisites
	@echo "Checking scorecard dependencies..."
	@command -v operator-sdk >/dev/null 2>&1 && echo "  ✓ operator-sdk found ($$(operator-sdk version | head -1))" || { echo "  ✗ operator-sdk not found"; echo "    Install: https://sdk.operatorframework.io/docs/installation/"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 && echo "  ✓ kubectl found (version: $$(kubectl version --client -o json 2>/dev/null | grep gitVersion | cut -d'"' -f4))" || command -v oc >/dev/null 2>&1 && echo "  ✓ oc found" || { echo "  ✗ kubectl/oc not found"; echo "    Install kubectl: https://kubernetes.io/docs/tasks/tools/"; exit 1; }
	@kubectl cluster-info >/dev/null 2>&1 && echo "  ✓ Cluster accessible" || { echo "  ✗ Cluster not accessible"; echo "    Setup kind: kind create cluster"; echo "    Or minikube: minikube start"; exit 1; }
	@echo "✅ All scorecard dependencies present"

##@ Kustomize Targets

.PHONY: kustomize-build-default
kustomize-build-default: ## Build default kustomize configuration
	kustomize build config/default

.PHONY: kustomize-build-base
kustomize-build-base: ## Build base (OpenShift) kustomize configuration
	kustomize build config/base

.PHONY: kustomize-validate
kustomize-validate: ## Validate both kustomize builds (constitution compliance)
	@echo "Validating config/default..."
	@kustomize build config/default > /dev/null && echo "✅ config/default build passed"
	@echo "Validating config/base..."
	@kustomize build config/base > /dev/null && echo "✅ config/base build passed"

##@ Download Targets

.PHONY: download
download: ## Generate manifests from kustomize and create downloaded directory structure
	@echo "Generating manifests for version $(OPERATOR_TAG)..."
	@mkdir -p downloaded/toolhive-operator/$(OPERATOR_TAG)
	@echo "Copying CRD files from config/crd/bases/..."
	@cp config/crd/bases/*.yaml downloaded/toolhive-operator/$(OPERATOR_TAG)/
	@echo "Generating ClusterServiceVersion from kustomize..."
	@scripts/generate-csv-from-kustomize.sh $(OPERATOR_TAG) downloaded/toolhive-operator/$(OPERATOR_TAG)/toolhive-operator.clusterserviceversion.yaml
	@if [ -f "downloaded/toolhive-operator/$(OPERATOR_TAG)/toolhive-operator.clusterserviceversion.yaml" ]; then \
		echo "✅ Manifests generated successfully"; \
		echo "Contents:"; \
		ls -lh downloaded/toolhive-operator/$(OPERATOR_TAG)/; \
	else \
		echo "❌ Error: CSV file not found after generation"; \
		exit 1; \
	fi

.PHONY: download-clean
download-clean: ## Remove downloaded manifests
	@echo "Removing downloaded manifests..."
	@rm -rf downloaded/
	@echo "✅ Downloaded manifests removed"

##@ OLM Bundle Targets

.PHONY: bundle
bundle: download ## Generate OLM bundle (CSV, CRDs, metadata) with OpenShift security patches
	@echo "Generating OLM bundle from downloaded operator files..."
	@mkdir -p bundle/manifests bundle/metadata
	@if [ -d "downloaded/toolhive-operator/$(OPERATOR_TAG)" ]; then \
		echo "Copying manifests from downloaded/toolhive-operator/$(OPERATOR_TAG)/..."; \
		cp downloaded/toolhive-operator/$(OPERATOR_TAG)/*.yaml bundle/manifests/; \
		echo "Applying OpenShift security patches to CSV..."; \
		yq eval 'del(.spec.install.spec.deployments[0].spec.template.spec.containers[0].securityContext.runAsUser)' -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml; \
		yq eval '.spec.install.spec.deployments[0].spec.template.spec.securityContext.seccompProfile = {"type": "RuntimeDefault"}' -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml; \
		yq eval 'del(.spec.install.spec.deployments[0].spec.template.spec.containers[0].command)' -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml; \
		echo "Adding leader election RBAC permissions to CSV..."; \
		yq eval '.spec.install.spec.permissions = [{"serviceAccountName": "toolhive-operator-controller-manager", "rules": [{"apiGroups": [""], "resources": ["configmaps"], "verbs": ["get", "list", "watch", "create", "update", "patch", "delete"]}, {"apiGroups": ["coordination.k8s.io"], "resources": ["leases"], "verbs": ["get", "list", "watch", "create", "update", "patch", "delete"]}, {"apiGroups": [""], "resources": ["events"], "verbs": ["create", "patch"]}]}]' -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml; \
		echo "  ✓ Removed hardcoded runAsUser from container securityContext"; \
		echo "  ✓ Added seccompProfile: RuntimeDefault to pod securityContext"; \
		echo "  ✓ Removed explicit command field (using container ENTRYPOINT)"; \
		echo "  ✓ Added leader election RBAC permissions (configmaps, leases, events)"; \
		if [ -n "$(BUNDLE_ICON)" ]; then \
			echo "Validating custom icon: $(BUNDLE_ICON)"; \
			scripts/validate-icon.sh "$(BUNDLE_ICON)" || exit 1; \
			echo "  ✓ Icon validation passed"; \
			echo "Encoding custom bundle icon: $(BUNDLE_ICON)"; \
			ENCODED=$$(scripts/encode-icon.sh "$(BUNDLE_ICON)" 2>bundle_icon_meta.tmp) || exit 1; \
			MEDIATYPE=$$(grep "^MEDIATYPE:" bundle_icon_meta.tmp | cut -d: -f2); \
			yq eval '.spec.icon = [{"base64data": "'"$$ENCODED"'", "mediatype": "'"$$MEDIATYPE"'"}]' \
			  -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml || exit 1; \
			rm -f bundle_icon_meta.tmp; \
			echo "  ✓ Custom icon encoded and injected"; \
		else \
			echo "Using default icon from icons/toolhive-icon-honey-wide-80x40.png"; \
			ENCODED=$$(scripts/encode-icon.sh "icons/toolhive-icon-honey-wide-80x40.png" 2>bundle_icon_meta.tmp) || exit 1; \
			MEDIATYPE=$$(grep "^MEDIATYPE:" bundle_icon_meta.tmp | cut -d: -f2); \
			yq eval '.spec.icon = [{"base64data": "'"$$ENCODED"'", "mediatype": "'"$$MEDIATYPE"'"}]' \
			  -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml || exit 1; \
			rm -f bundle_icon_meta.tmp; \
		fi; \
		echo "Copying scorecard configuration..."; \
		mkdir -p bundle/tests/scorecard; \
		cp config/scorecard/config.yaml bundle/tests/scorecard/config.yaml; \
		echo "  ✓ Scorecard configuration copied to bundle/tests/scorecard/"; \
		echo "annotations:" > bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.bundle.mediatype.v1: registry+v1" >> bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.bundle.manifests.v1: manifests/" >> bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.bundle.metadata.v1: metadata/" >> bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.bundle.package.v1: toolhive-operator" >> bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.bundle.channels.v1: fast" >> bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.bundle.channel.default.v1: fast" >> bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.test.config.v1: tests/scorecard/" >> bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.test.mediatype.v1: scorecard+v1" >> bundle/metadata/annotations.yaml; \
		echo "✅ Bundle generated successfully with OpenShift patches applied"; \
		echo "Contents:"; \
		ls -lh bundle/manifests/ bundle/metadata/; \
	else \
		echo "❌ Error: downloaded/toolhive-operator/$(OPERATOR_TAG)/ directory not found"; \
		echo "This should not happen as 'download' is a prerequisite for bundle."; \
		exit 1; \
	fi

.PHONY: bundle-validate
bundle-validate: ## Validate OLM bundle with operator-sdk
	@echo "Validating bundle structure..."
	@if [ -d "bundle/manifests" ] && [ -d "bundle/metadata" ]; then \
		echo "✅ Bundle directory structure valid"; \
	else \
		echo "❌ Bundle directory structure invalid"; \
		exit 1; \
	fi
	@echo "Validating bundle manifests..."
	@if [ -f "bundle/manifests/toolhive-operator.clusterserviceversion.yaml" ]; then \
		echo "✅ CSV present"; \
	else \
		echo "❌ CSV missing"; \
		exit 1; \
	fi
	@echo "Bundle validation: manual checks passed"
	@echo "Note: For full operator-sdk validation, run: operator-sdk bundle validate ./bundle"

##@ OLM Catalog Targets (OLMv1 - Modern OpenShift 4.19+)
#
# These targets work with File-Based Catalog (FBC) images for modern OLM.
# The catalog image IS the index/catalog image - no wrapper needed.
# For legacy OpenShift 4.15-4.18, see "OLM Index Targets (OLMv0)" below.

.PHONY: catalog
catalog: bundle ## Generate FBC catalog metadata from bundle
	@echo "Generating FBC catalog from bundle..."
	@mkdir -p catalog/toolhive-operator
	@echo "---" > catalog/toolhive-operator/catalog.yaml
	@echo "# Package Schema - defines the toolhive-operator package" >> catalog/toolhive-operator/catalog.yaml
	@echo "schema: olm.package" >> catalog/toolhive-operator/catalog.yaml
	@echo "name: toolhive-operator" >> catalog/toolhive-operator/catalog.yaml
	@echo "defaultChannel: fast" >> catalog/toolhive-operator/catalog.yaml
	@echo "description: |" >> catalog/toolhive-operator/catalog.yaml
	@echo "  ToolHive Operator manages Model Context Protocol (MCP) servers and registries." >> catalog/toolhive-operator/catalog.yaml
	@echo "" >> catalog/toolhive-operator/catalog.yaml
	@echo "  The operator provides custom resources for:" >> catalog/toolhive-operator/catalog.yaml
	@echo "  - MCPRegistry: Manages registries of MCP server definitions" >> catalog/toolhive-operator/catalog.yaml
	@echo "  - MCPServer: Manages individual MCP server instances" >> catalog/toolhive-operator/catalog.yaml
	@echo "" >> catalog/toolhive-operator/catalog.yaml
	@echo "  MCP enables AI assistants to securely access external tools and data sources." >> catalog/toolhive-operator/catalog.yaml
	@if [ -n "$(CATALOG_ICON)" ]; then \
		echo "Validating custom catalog icon: $(CATALOG_ICON)"; \
		scripts/validate-icon.sh "$(CATALOG_ICON)" || exit 1; \
		echo "  ✓ Catalog icon validation passed"; \
		echo "Encoding custom catalog icon: $(CATALOG_ICON)"; \
		ENCODED=$$(scripts/encode-icon.sh "$(CATALOG_ICON)" 2>catalog_icon_meta.tmp) || exit 1; \
		MEDIATYPE=$$(grep "^MEDIATYPE:" catalog_icon_meta.tmp | cut -d: -f2); \
		echo "icon:" >> catalog/toolhive-operator/catalog.yaml; \
		echo "  base64data: $$ENCODED" >> catalog/toolhive-operator/catalog.yaml; \
		echo "  mediatype: $$MEDIATYPE" >> catalog/toolhive-operator/catalog.yaml; \
		rm -f catalog_icon_meta.tmp; \
		echo "  ✓ Custom catalog icon encoded and injected"; \
	else \
		echo "Using default catalog icon from icons/toolhive-icon-honey-wide-80x40.png"; \
		ENCODED=$$(scripts/encode-icon.sh "icons/toolhive-icon-honey-wide-80x40.png" 2>catalog_icon_meta.tmp) || exit 1; \
		MEDIATYPE=$$(grep "^MEDIATYPE:" catalog_icon_meta.tmp | cut -d: -f2); \
		echo "icon:" >> catalog/toolhive-operator/catalog.yaml; \
		echo "  base64data: $$ENCODED" >> catalog/toolhive-operator/catalog.yaml; \
		echo "  mediatype: $$MEDIATYPE" >> catalog/toolhive-operator/catalog.yaml; \
		rm -f catalog_icon_meta.tmp; \
	fi
	@echo "" >> catalog/toolhive-operator/catalog.yaml
	@echo "---" >> catalog/toolhive-operator/catalog.yaml
	@echo "# Channel Schema - defines the fast release channel" >> catalog/toolhive-operator/catalog.yaml
	@echo "schema: olm.channel" >> catalog/toolhive-operator/catalog.yaml
	@echo "name: fast" >> catalog/toolhive-operator/catalog.yaml
	@echo "package: toolhive-operator" >> catalog/toolhive-operator/catalog.yaml
	@echo "entries:" >> catalog/toolhive-operator/catalog.yaml
	@echo "  - name: toolhive-operator.v0.4.2" >> catalog/toolhive-operator/catalog.yaml
	@echo "    # Initial release - no replaces/skips" >> catalog/toolhive-operator/catalog.yaml
	@echo "" >> catalog/toolhive-operator/catalog.yaml
	@echo "---" >> catalog/toolhive-operator/catalog.yaml
	@echo "# Bundle Schema - generated by opm render with embedded bundle objects" >> catalog/toolhive-operator/catalog.yaml
	@echo "# Note: image field removed - using embedded olm.bundle.object data only" >> catalog/toolhive-operator/catalog.yaml
	@echo "# Icon inheritance: opm render automatically embeds the CSV (with custom/default icon)" >> catalog/toolhive-operator/catalog.yaml
	@echo "#   into olm.bundle.object, so catalog inherits whatever icon was set in bundle target" >> catalog/toolhive-operator/catalog.yaml
	@opm render bundle/ -o yaml | sed '1d' | sed '/^image:/d' >> catalog/toolhive-operator/catalog.yaml
	@echo "Converting olm.bundle.object JSON to YAML encoding..."
	@scripts/convert-catalog-json-to-yaml.sh catalog/toolhive-operator/catalog.yaml
	@echo "✅ Catalog generated successfully with embedded bundle objects (YAML-encoded)"
	@echo "Contents:"
	@ls -lh catalog/toolhive-operator/

.PHONY: catalog-validate
catalog-validate: ## Validate FBC catalog with opm
	@echo "Validating FBC catalog..."
	@opm validate catalog/
	@echo "✅ FBC catalog validation passed"

.PHONY: catalog-validate-existing
catalog-validate-existing: ## Validate existing OLMv1 catalog (no rebuild needed)
	@echo "Validating existing OLMv1 FBC catalog..."
	@opm validate catalog/
	@echo "✅ OLMv1 catalog validation passed"
	@echo "   The catalog image is already a valid index/catalog image."
	@echo "   No additional index wrapper needed for OLMv1."

.PHONY: catalog-build
catalog-build: catalog-validate ## Build catalog container image
	@echo "Building catalog container image: $(CATALOG_IMG)"
	$(CONTAINER_TOOL) build -f Containerfile.catalog -t $(CATALOG_IMG) .
	$(CONTAINER_TOOL) tag $(CATALOG_IMG) $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest
	@echo "✅ Catalog image built: $(CATALOG_IMG)"
	@$(CONTAINER_TOOL) images $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME)

.PHONY: catalog-push
catalog-push: ## Push catalog image to registry
	@echo "Pushing catalog image: $(CATALOG_IMG)"
	$(CONTAINER_TOOL) push $(CATALOG_IMG)
	$(CONTAINER_TOOL) push $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest
	@echo "✅ Catalog image pushed"

.PHONY: catalog-inspect
catalog-inspect: ## Inspect built catalog image contents and metadata
	@echo "=== Catalog Image Inspection: $(CATALOG_IMG) ==="
	@echo ""
	@echo "--- Labels ---"
	@$(CONTAINER_TOOL) inspect $(CATALOG_IMG) | jq -r '.[0].Config.Labels | to_entries | map(select(.key | startswith("org.opencontainers.image") or startswith("operators.operatorframework"))) | sort_by(.key) | .[] | "  \(.key) = \(.value)"'
	@echo ""
	@echo "--- Entrypoint & Command ---"
	@$(CONTAINER_TOOL) inspect $(CATALOG_IMG) | jq -r '.[0].Config | "  ENTRYPOINT: \(.Entrypoint)\n  CMD: \(.Cmd)"'
	@echo ""
	@echo "--- Catalog Contents (/configs) ---"
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) find /configs -type f
	@echo ""
	@echo "--- Cache Contents (/tmp/cache) ---"
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "du -sh /tmp/cache && find /tmp/cache -type f | wc -l | xargs echo '  Files:'"
	@echo ""
	@echo "--- Binaries ---"
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "ls -lh /bin/opm /bin/grpc_health_probe 2>/dev/null || echo '  Error: binaries not found'"
	@echo ""

.PHONY: catalog-test-local
catalog-test-local: ## Start catalog registry-server locally for testing
	@echo "Starting catalog registry-server locally..."
	@echo "  Image: $(CATALOG_IMG)"
	@echo "  Port: 50051 (gRPC)"
	@echo ""
	@if $(CONTAINER_TOOL) ps -a | grep -q catalog-test-local; then \
		echo "⚠️  Removing existing catalog-test-local container..."; \
		$(CONTAINER_TOOL) rm -f catalog-test-local; \
	fi
	@$(CONTAINER_TOOL) run -d -p 50051:50051 --name catalog-test-local $(CATALOG_IMG)
	@echo ""
	@echo "Waiting for registry-server startup..."
	@sleep 3
	@$(CONTAINER_TOOL) logs catalog-test-local | grep -q "serving registry" && echo "✅ Registry-server is running" || echo "⚠️  Server may not be ready yet"
	@echo ""
	@echo "Test commands:"
	@echo "  grpcurl -plaintext localhost:50051 api.Registry/ListPackages"
	@echo "  grpcurl -plaintext localhost:50051 grpc.health.v1.Health/Check"
	@echo ""
	@echo "View logs:"
	@echo "  podman logs -f catalog-test-local"
	@echo ""
	@echo "Stop and remove:"
	@echo "  make catalog-test-local-stop"
	@echo ""

.PHONY: catalog-test-local-stop
catalog-test-local-stop: ## Stop and remove local catalog test container
	@echo "Stopping catalog-test-local container..."
	@$(CONTAINER_TOOL) stop catalog-test-local 2>/dev/null || true
	@$(CONTAINER_TOOL) rm catalog-test-local 2>/dev/null || true
	@echo "✅ Container removed"

.PHONY: catalog-validate-executable
catalog-validate-executable: ## Validate executable catalog image has required components
	@echo "=== Validating Executable Catalog Image ==="
	@echo "  Image: $(CATALOG_IMG)"
	@echo ""
	@echo "Checking for required binaries..."
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "test -x /bin/opm && echo '  ✅ /bin/opm present'" || (echo "  ❌ /bin/opm missing or not executable" && exit 1)
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "test -x /bin/grpc_health_probe && echo '  ✅ /bin/grpc_health_probe present'" || (echo "  ❌ /bin/grpc_health_probe missing or not executable" && exit 1)
	@echo ""
	@echo "Checking for catalog metadata..."
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "test -f /configs/toolhive-operator/catalog.yaml && echo '  ✅ catalog.yaml present'" || (echo "  ❌ catalog.yaml missing" && exit 1)
	@echo ""
	@echo "Checking for pre-built cache..."
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "test -d /tmp/cache && echo '  ✅ /tmp/cache directory exists'" || (echo "  ❌ /tmp/cache missing" && exit 1)
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "find /tmp/cache -type f | grep -q . && echo '  ✅ Cache files present'" || (echo "  ❌ Cache is empty" && exit 1)
	@echo ""
	@echo "Checking image configuration..."
	@$(CONTAINER_TOOL) inspect $(CATALOG_IMG) | jq -e '.[0].Config.Entrypoint == ["/bin/opm"]' >/dev/null && echo "  ✅ ENTRYPOINT configured correctly" || (echo "  ❌ ENTRYPOINT incorrect" && exit 1)
	@$(CONTAINER_TOOL) inspect $(CATALOG_IMG) | jq -e '.[0].Config.Cmd == ["serve", "/configs", "--cache-dir=/tmp/cache"]' >/dev/null && echo "  ✅ CMD configured correctly" || (echo "  ❌ CMD incorrect" && exit 1)
	@echo ""
	@echo "Checking OLM labels..."
	@$(CONTAINER_TOOL) inspect $(CATALOG_IMG) | jq -e '.[0].Config.Labels."operators.operatorframework.io.index.configs.v1" == "/configs"' >/dev/null && echo "  ✅ OLM config label present" || (echo "  ❌ OLM config label missing or incorrect" && exit 1)
	@echo ""
	@echo "✅ All validation checks passed - catalog image is executable"

##@ OLM Bundle Image Targets

.PHONY: bundle-validate-sdk
bundle-validate-sdk: ## Validate OLM bundle with operator-sdk
	@echo "Validating bundle with operator-sdk..."
	operator-sdk --plugins go.kubebuilder.io/v4 bundle validate ./bundle
	@echo "✅ Bundle validation passed"

.PHONY: bundle-build
bundle-build: bundle-validate-sdk ## Build bundle container image
	@echo "Building bundle container image: $(BUNDLE_IMG)"
	$(CONTAINER_TOOL) build -f Containerfile.bundle -t $(BUNDLE_IMG) .
	$(CONTAINER_TOOL) tag $(BUNDLE_IMG) $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):latest
	@echo "✅ Bundle image built: $(BUNDLE_IMG)"
	@$(CONTAINER_TOOL) images $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME)

.PHONY: bundle-push
bundle-push: ## Push bundle image to registry
	@echo "Pushing bundle image: $(BUNDLE_IMG)"
	$(CONTAINER_TOOL) push $(BUNDLE_IMG)
	$(CONTAINER_TOOL) push $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):latest
	@echo "✅ Bundle image pushed"

.PHONY: bundle-all
bundle-all: bundle-validate-sdk bundle-build ## Run complete bundle workflow (validate, build)
	@echo ""
	@echo "========================================="
	@echo "✅ Complete bundle workflow finished"
	@echo "========================================="
	@echo ""
	@echo "Next steps:"
	@echo "  1. Push bundle image: make bundle-push"
	@echo "  2. Build OLMv0 index: make index-olmv0-build"
	@echo "  3. Deploy to cluster: create CatalogSource referencing index image"
	@echo ""

##@ OLM Index Targets (OLMv0 - Legacy OpenShift 4.15-4.18)
#
# ⚠️  DEPRECATION NOTICE: SQLite-based index images are deprecated by operator-framework.
# These targets are for legacy OpenShift compatibility ONLY.
#
# Key differences from OLMv1:
#   - OLMv0 bundle images MUST be wrapped in a SQLite index image
#   - Use `opm index add` (deprecated) to create index from bundle
#   - Index contains SQLite database at /database/index.db
#   - Separate image name: index-olmv0 (vs catalog for OLMv1)
#
# DO NOT mix OLMv0 and OLMv1 formats for the same operator version.
# Use EITHER catalog targets (OLMv1) OR index-olmv0 targets (OLMv0), not both.
#
# Sunset timeline: When OpenShift 4.18 reaches EOL (Q1 2026), remove these targets.

.PHONY: index-olmv0-build
index-olmv0-build: ## Build OLMv0 index image (SQLite-based, deprecated)
	@echo "⚠️  Building OLMv0 index image (SQLite-based, deprecated)"
	@echo "   Use only for legacy OpenShift 4.15-4.18 compatibility"
	@echo ""
	@echo "Checking for local bundle image: $(BUNDLE_IMG)"
	@if $(CONTAINER_TOOL) inspect $(BUNDLE_IMG) >/dev/null 2>&1; then \
		echo "  ✓ Bundle image found locally"; \
	else \
		echo "  ✗ Bundle image not found locally"; \
		echo "  Pulling bundle image from registry..."; \
		$(CONTAINER_TOOL) pull $(BUNDLE_IMG) || { \
			echo "  ❌ Failed to pull bundle image"; \
			echo "  Please build the bundle image first with: make bundle-build"; \
			exit 1; \
		}; \
		echo "  ✓ Bundle image pulled successfully"; \
	fi
	@echo ""
	@echo "Building index referencing bundle: $(BUNDLE_IMG)"
	opm index add \
		--bundles $(BUNDLE_IMG) \
		--tag $(INDEX_OLMV0_IMG) \
		--mode $(OPM_MODE) \
		--container-tool $(CONTAINER_TOOL) \
		--permissive
	@echo ""
	@echo "✅ OLMv0 index image built: $(INDEX_OLMV0_IMG)"
	@$(CONTAINER_TOOL) images $(INDEX_OLMV0_IMG)
	@echo ""
	@echo "Tagging as latest..."
	$(CONTAINER_TOOL) tag $(INDEX_OLMV0_IMG) $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest
	@echo "✅ Also tagged: $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest"

.PHONY: index-olmv0-validate
index-olmv0-validate: ## Validate OLMv0 index image
	@echo "Validating OLMv0 index image..."
	@echo "Exporting package manifest from index..."
	@opm index export \
		--index=$(INDEX_OLMV0_IMG) \
		--package=toolhive-operator > /tmp/toolhive-index-olmv0-export.yaml
	@echo ""
	@echo "✅ OLMv0 index validation passed"
	@echo "   Package manifest exported to /tmp/toolhive-index-olmv0-export.yaml"
	@echo ""
	@echo "Package summary:"
	@if command -v yq > /dev/null 2>&1; then \
		yq eval '.metadata.name, .spec.channels[].name, .spec.channels[].currentCSV' /tmp/toolhive-index-olmv0-export.yaml; \
	else \
		echo "   (install yq for formatted output)"; \
		grep -E '(name:|currentCSV:)' /tmp/toolhive-index-olmv0-export.yaml | head -5; \
	fi

.PHONY: index-olmv0-push
index-olmv0-push: ## Push OLMv0 index image to registry
	@echo "Pushing OLMv0 index image: $(INDEX_OLMV0_IMG)"
	$(CONTAINER_TOOL) push $(INDEX_OLMV0_IMG)
	$(CONTAINER_TOOL) push $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest
	@echo "✅ OLMv0 index image pushed"
	@echo "   - $(INDEX_OLMV0_IMG)"
	@echo "   - $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest"

.PHONY: index-olmv0-all
index-olmv0-all: index-olmv0-build index-olmv0-validate index-olmv0-push ## Run complete OLMv0 index workflow
	@echo ""
	@echo "========================================="
	@echo "✅ Complete OLMv0 index workflow finished"
	@echo "========================================="
	@echo ""
	@echo "⚠️  REMINDER: SQLite-based indexes are deprecated"
	@echo "   Use only for legacy OpenShift 4.15-4.18 deployments"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Deploy CatalogSource: kubectl apply -f examples/catalogsource-olmv0.yaml"
	@echo "  2. Verify catalog: kubectl get catalogsource -n olm toolhive-catalog-olmv0"
	@echo "  3. Check OperatorHub for ToolHive Operator"
	@echo ""

.PHONY: index-clean
index-clean: ## Remove local OLMv0 index images
	@echo "Removing OLMv0 index images..."
	-$(CONTAINER_TOOL) rmi $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):$(INDEX_TAG)
	-$(CONTAINER_TOOL) rmi $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest
	@echo "✅ OLMv0 index images removed"

.PHONY: index-validate-all
index-validate-all: catalog-validate index-olmv0-validate ## Validate both OLMv1 catalog and OLMv0 index
	@echo ""
	@echo "========================================="
	@echo "✅ All index/catalog validations passed"
	@echo "========================================="
	@echo ""
	@echo "Validated:"
	@echo "  ✅ OLMv1 FBC Catalog (modern OpenShift 4.19+)"
	@echo "  ✅ OLMv0 SQLite Index (legacy OpenShift 4.15-4.18)"
	@echo ""

##@ Complete OLM Workflow

.PHONY: olm-all
olm-all: kustomize-validate bundle bundle-validate catalog catalog-validate catalog-build index-olmv0-build ## Run complete OLM workflow (build and validate everything)
	@echo ""
	@echo "========================================="
	@echo "✅ Complete OLM workflow finished"
	@echo "========================================="
	@echo ""
	@echo "Generated artifacts:"
	@echo "  ✅ Bundle (bundle/)"
	@echo "  ✅ OLMv1 Catalog (catalog/)"
	@echo "  ✅ Catalog Image ($(CATALOG_IMG))"
	@echo "  ✅ OLMv0 Index Image ($(INDEX_OLMV0_IMG))"
	@echo ""
	@echo "Next steps:"
	@echo "  Modern OpenShift (4.19+):"
	@echo "    1. Push catalog: make catalog-push"
	@echo "    2. Deploy: kubectl apply -f examples/catalogsource-olmv1.yaml"
	@echo ""
	@echo "  Legacy OpenShift (4.15-4.18):"
	@echo "    1. Push index: make index-olmv0-push"
	@echo "    2. Deploy: kubectl apply -f examples/catalogsource-olmv0.yaml"
	@echo ""

##@ Validation & Compliance

.PHONY: validate-icon
validate-icon: ## Validate custom icon file (ICON_FILE=path/to/icon)
	@if [ -z "$(ICON_FILE)" ]; then \
		echo "❌ Error: ICON_FILE parameter required"; \
		echo "Usage: make validate-icon ICON_FILE=/path/to/your-icon.png"; \
		exit 1; \
	fi
	@echo "Validating icon: $(ICON_FILE)"
	@scripts/validate-icon.sh "$(ICON_FILE)" && echo "✅ Icon validation passed" || exit 1

.PHONY: scorecard-test
scorecard-test: bundle ## Run scorecard tests against bundle
	@echo "Running scorecard tests..."
	@if [ ! -d "bundle/manifests" ]; then \
		echo "❌ Error: Bundle directory not found at ./bundle"; \
		echo "Run 'make bundle' to generate the bundle first."; \
		exit 1; \
	fi
	@$(MAKE) check-scorecard-deps
	@echo ""
	@echo "Executing scorecard tests against bundle/..."
	@operator-sdk scorecard bundle/ -o text || { echo ""; echo "❌ Scorecard tests failed"; exit 1; }
	@echo ""
	@echo "✅ All scorecard tests passed"

.PHONY: constitution-check
constitution-check: kustomize-validate ## Verify constitution compliance
	@echo "Checking CRD immutability (constitution III)..."
	@git diff --exit-code config/crd/ && echo "✅ CRDs unchanged" || (echo "❌ CRDs have been modified"; exit 1)
	@echo "Constitution compliance: ✅ PASSED"

.PHONY: verify-version-consistency
verify-version-consistency: ## Verify all version references are consistent
	@scripts/verify-version-consistency.sh $(OPERATOR_TAG)

.PHONY: validate-all
validate-all: verify-version-consistency constitution-check bundle-validate bundle-validate-sdk catalog-validate index-olmv0-validate ## Run all validation checks
	@echo ""
	@echo "========================================="
	@echo "✅ All validations passed"
	@echo "========================================="
	@echo ""
	@echo "Validated components:"
	@echo "  ✅ Version consistency across all files"
	@echo "  ✅ Constitution compliance (kustomize builds, CRD immutability)"
	@echo "  ✅ OLMv0 Bundle structure and manifests"
	@echo "  ✅ OLMv1 FBC Catalog"
	@echo "  ✅ OLMv0 SQLite Index"
	@echo ""

##@ Cleanup

.PHONY: clean
clean: ## Clean generated bundle and catalog artifacts
	@echo "Cleaning generated artifacts..."
	rm -rf bundle/
	rm -rf catalog/
	@echo "✅ Cleaned bundle/ and catalog/ directories"

.PHONY: clean-images
clean-images: ## Remove local catalog and index container images
	@echo "Removing catalog, bundle, and index images..."
	-$(CONTAINER_TOOL) rmi $(CATALOG_IMG)
	-$(CONTAINER_TOOL) rmi $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest
	-$(CONTAINER_TOOL) rmi $(BUNDLE_IMG)
	-$(CONTAINER_TOOL) rmi $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):latest
	-$(CONTAINER_TOOL) rmi $(INDEX_OLMV0_IMG)
	-$(CONTAINER_TOOL) rmi $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest
	@echo "✅ Catalog, bundle, and index images removed"

.PHONY: clean-all
clean-all: clean clean-images download-clean ## Clean all generated artifacts, images, and downloaded files
	@echo ""
	@echo "========================================="
	@echo "✅ Complete cleanup finished"
	@echo "========================================="
	@echo ""
	@echo "Cleaned:"
	@echo "  ✅ Bundle directory (bundle/)"
	@echo "  ✅ Catalog directory (catalog/)"
	@echo "  ✅ Downloaded manifests (downloaded/)"
	@echo "  ✅ All container images (catalog, bundle, index)"
	@echo ""
	@echo "Repository is now clean. Run 'make olm-all' to rebuild everything."
	@echo ""

##@ Documentation

.PHONY: show-image-vars
show-image-vars: ## Display effective image variable values (for debugging overrides)
	@echo "=== Container Image Variables ==="
	@echo ""
	@echo "Catalog Image (OLMv1):"
	@echo "  CATALOG_REGISTRY = $(CATALOG_REGISTRY)"
	@echo "  CATALOG_ORG      = $(CATALOG_ORG)"
	@echo "  CATALOG_NAME     = $(CATALOG_NAME)"
	@echo "  CATALOG_TAG      = $(CATALOG_TAG)"
	@echo "  CATALOG_IMG      = $(CATALOG_IMG)"
	@echo ""
	@echo "Bundle Image (OLMv0):"
	@echo "  BUNDLE_REGISTRY  = $(BUNDLE_REGISTRY)"
	@echo "  BUNDLE_ORG       = $(BUNDLE_ORG)"
	@echo "  BUNDLE_NAME      = $(BUNDLE_NAME)"
	@echo "  BUNDLE_TAG       = $(BUNDLE_TAG)"
	@echo "  BUNDLE_IMG       = $(BUNDLE_IMG)"
	@echo ""
	@echo "Index Image (OLMv0):"
	@echo "  INDEX_REGISTRY   = $(INDEX_REGISTRY)"
	@echo "  INDEX_ORG        = $(INDEX_ORG)"
	@echo "  INDEX_NAME       = $(INDEX_NAME)"
	@echo "  INDEX_TAG        = $(INDEX_TAG)"
	@echo "  INDEX_OLMV0_IMG  = $(INDEX_OLMV0_IMG)"
	@echo ""
	@echo "Upstream Operator Image:"
	@echo "  OPERATOR_REGISTRY = $(OPERATOR_REGISTRY)"
	@echo "  OPERATOR_ORG      = $(OPERATOR_ORG)"
	@echo "  OPERATOR_NAME     = $(OPERATOR_NAME)"
	@echo "  OPERATOR_TAG      = $(OPERATOR_TAG)"
	@echo "  OPERATOR_IMG      = $(OPERATOR_IMG)"
	@echo ""
	@echo "Override example:"
	@echo "  make catalog-build CATALOG_REGISTRY=quay.io CATALOG_ORG=myuser"

.PHONY: show-catalog
show-catalog: ## Display catalog metadata
	@echo "=== OLM Package Schema ==="
	@yq eval 'select(.schema == "olm.package")' catalog/toolhive-operator/catalog.yaml
	@echo ""
	@echo "=== OLM Channel Schema ==="
	@yq eval 'select(.schema == "olm.channel")' catalog/toolhive-operator/catalog.yaml
	@echo ""
	@echo "=== OLM Bundle Schema ==="
	@yq eval 'select(.schema == "olm.bundle")' catalog/toolhive-operator/catalog.yaml

.PHONY: show-csv
show-csv: ## Display CSV metadata
	@yq eval '.metadata.name, .spec.version, .spec.displayName, .spec.description' bundle/manifests/toolhive-operator.clusterserviceversion.yaml

##@ Quick Reference

.PHONY: quick-start
quick-start: ## Quick start: validate and build everything
	@echo "Quick start: Running full OLM workflow..."
	@$(MAKE) olm-all

.DEFAULT_GOAL := help
