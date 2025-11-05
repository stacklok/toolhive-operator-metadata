#!/usr/bin/env bash
# Generate ClusterServiceVersion from kustomize configuration
#
# Usage: generate-csv-from-kustomize.sh <version> <output-file>
# Example: generate-csv-from-kustomize.sh v0.4.2 downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml

set -e

VERSION="${1}"
OUTPUT_FILE="${2}"

if [ -z "$VERSION" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: $0 <version> <output-file>"
    echo "Example: $0 v0.4.2 downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml"
    exit 1
fi

# Remove 'v' prefix from version for CSV version field
CSV_VERSION="${VERSION#v}"

# Extract deployment and role from kustomize
DEPLOYMENT_YAML=$(kustomize build config/default | yq eval 'select(.kind == "Deployment" and .metadata.name == "toolhive-operator-controller-manager")' -)
CLUSTER_ROLE_YAML=$(kustomize build config/default | yq eval 'select(.kind == "ClusterRole" and .metadata.name == "toolhive-operator-manager-role")' -)

# Create directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Generate CSV
cat > "$OUTPUT_FILE" <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: ClusterServiceVersion
metadata:
  annotations:
    alm-examples: |-
      []
    capabilities: Basic Install
    categories: AI/Machine Learning, Developer Tools, Networking
    containerImage: ghcr.io/stacklok/toolhive/operator:${VERSION}
    description: Kubernetes operator for managing Model Context Protocol (MCP) servers and registries
    operators.operatorframework.io/builder: operator-sdk-v1.41.0
    operators.operatorframework.io/project_layout: go.kubebuilder.io/v4
    repository: https://github.com/stacklok/toolhive
  name: toolhive-operator.${VERSION}
  namespace: placeholder
spec:
  apiservicedefinitions: {}
  customresourcedefinitions:
    owned:
      - description: MCPExternalAuthConfig configures external authentication providers for MCP servers
        displayName: MCP External Auth Config
        kind: MCPExternalAuthConfig
        name: mcpexternalauthconfigs.toolhive.stacklok.dev
        version: v1alpha1
        resources:
          - kind: Secret
            version: v1
      - description: MCPGroup organizes and manages groups of MCP servers
        displayName: MCP Group
        kind: MCPGroup
        name: mcpgroups.toolhive.stacklok.dev
        version: v1alpha1
        resources:
          - kind: MCPServer
            version: v1alpha1
      - description: MCPRegistry manages registries of MCP server definitions
        displayName: MCP Registry
        kind: MCPRegistry
        name: mcpregistries.toolhive.stacklok.dev
        version: v1alpha1
        resources:
          - kind: ConfigMap
            version: v1
          - kind: MCPServer
            version: v1alpha1
      - description: MCPRemoteProxy configures remote proxy connections for MCP servers
        displayName: MCP Remote Proxy
        kind: MCPRemoteProxy
        name: mcpremoteproxies.toolhive.stacklok.dev
        version: v1alpha1
        resources:
          - kind: Deployment
            version: v1
          - kind: Service
            version: v1
          - kind: Pod
            version: v1
      - description: MCPServer manages individual Model Context Protocol server instances
        displayName: MCP Server
        kind: MCPServer
        name: mcpservers.toolhive.stacklok.dev
        version: v1alpha1
        resources:
          - kind: StatefulSet
            version: v1
          - kind: Service
            version: v1
          - kind: Pod
            version: v1
          - kind: ConfigMap
            version: v1
          - kind: Secret
            version: v1
      - description: MCPToolConfig configures individual tools within MCP servers
        displayName: MCP Tool Config
        kind: MCPToolConfig
        name: mcptoolconfigs.toolhive.stacklok.dev
        version: v1alpha1
        resources:
          - kind: ConfigMap
            version: v1
  description: |
    Toolhive Operator manages Model Context Protocol (MCP) servers and registries on Kubernetes.

    The operator provides custom resources for:
    - **MCPRegistry**: Manages registries of MCP server definitions
    - **MCPServer**: Manages individual MCP server instances
    - **MCPGroup**: Organizes and manages groups of MCP servers
    - **MCPRemoteProxy**: Configures remote proxy connections for MCP servers
    - **MCPExternalAuthConfig**: Configures external authentication providers for MCP servers
    - **MCPToolConfig**: Configures individual tools within MCP servers

    MCP enables AI assistants to securely access external tools and data sources.
  displayName: Toolhive Operator
  icon:
    - base64data: ""
      mediatype: image/png
  install:
    spec:
      clusterPermissions:
        - rules:
$(echo "$CLUSTER_ROLE_YAML" | yq eval '.rules' - | sed 's/^/            /')
          serviceAccountName: toolhive-operator-controller-manager
      deployments:
        - label:
            app.kubernetes.io/managed-by: kustomize
            app.kubernetes.io/name: toolhive-operator
            app.kubernetes.io/part-of: toolhive-operator
            control-plane: controller-manager
          name: toolhive-operator-controller-manager
          spec:
$(echo "$DEPLOYMENT_YAML" | yq eval '.spec' - | sed 's/^/            /')
      permissions:
        - rules:
            - apiGroups:
                - ""
              resources:
                - configmaps
              verbs:
                - get
                - list
                - watch
                - create
                - update
                - patch
                - delete
            - apiGroups:
                - coordination.k8s.io
              resources:
                - leases
              verbs:
                - get
                - list
                - watch
                - create
                - update
                - patch
                - delete
            - apiGroups:
                - ""
              resources:
                - events
              verbs:
                - create
                - patch
          serviceAccountName: toolhive-operator-controller-manager
    strategy: deployment
  installModes:
    - supported: true
      type: OwnNamespace
    - supported: true
      type: SingleNamespace
    - supported: false
      type: MultiNamespace
    - supported: true
      type: AllNamespaces
  keywords:
    - mcp
    - model-context-protocol
    - ai
    - llm
    - developer-tools
  links:
    - name: Toolhive
      url: https://github.com/stacklok/toolhive
    - name: Documentation
      url: https://docs.stacklok.com/
    - name: Discord
      url: https://discord.gg/stacklok
  maintainers:
      name: Stacklok
  maturity: alpha
  minKubeVersion: 1.27.0
  provider:
    name: Stacklok
    url: https://stacklok.com
  replaces: ""
  version: ${CSV_VERSION}
EOF

echo "✅ Generated CSV: $OUTPUT_FILE"
