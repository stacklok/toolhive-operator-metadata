# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains Kubernetes/OpenShift manifest metadata for the ToolHive Operator, which manages MCP (Model Context Protocol) servers and registries. It uses Kustomize for manifest customization and is built with Kubebuilder v3.

The operator manages two primary custom resources:
- **MCPRegistry** (`mcpregistries.toolhive.stacklok.dev`) - Manages registries of MCP servers
- **MCPServer** (`mcpservers.toolhive.stacklok.dev`) - Manages individual MCP server instances

## Building Manifests

Build kustomize manifests using:

```shell
# Build base configuration
kustomize build config/base

# Build default configuration
kustomize build config/default
```

## Repository Structure

- **config/base/** - OpenShift-specific customizations with ConfigMap-based parameter management
  - `params.env` - Container image references (toolhive-operator-image, toolhive-proxy-image)
  - `openshift_env_var_patch.yaml` - Adds OPERATOR_OPENSHIFT env var
  - `openshift_sec_patches.yaml` - Security context patches (seccompProfile, removes runAsUser)
  - `openshift_res_utilization.yaml` - Increased resource limits for OpenShift
  - `remove-namespace.yaml` - Namespace removal patch
  - Target namespace: `opendatahub`

- **config/default/** - Standard Kubebuilder configuration
  - Target namespace: `toolhive-operator-system`
  - Name prefix: `toolhive-operator-`
  - Resources: CRDs, RBAC, manager deployment, metrics service

- **config/manager/** - Controller deployment manifests
  - Default images: `ghcr.io/stacklok/toolhive/operator:v0.3.11` and `ghcr.io/stacklok/toolhive/proxyrunner:v0.3.11`
  - Metrics port: 8080, Health port: 8081

- **config/crd/** - Custom Resource Definitions for MCPRegistry and MCPServer

- **config/rbac/** - Service accounts, roles, and bindings

- **config/prometheus/** - ServiceMonitor for metrics (commented out by default)

- **config/network-policy/** - Network policies for metrics endpoint (commented out by default)

## Configuration Architecture

The repository uses a two-layer kustomize approach:

1. **config/default** - Base Kubebuilder-generated manifests
2. **config/base** - OpenShift overlay that references default and applies:
   - Image replacements via ConfigMap substitution
   - OpenShift-specific security patches
   - Resource limit adjustments
   - Environment variable additions

Image versions are configured in `config/base/params.env` and applied via kustomize replacements to both the operator container and the TOOLHIVE_RUNNER_IMAGE environment variable.

## Current Git Context

- Current branch: `bundle`
- Main branch: `main`
- Recent work includes: OpenShift manifest customizations, environment variable patches, pod namespace configuration
