#!/usr/bin/env bash

set -euo

missing=0
_require_env() {
  if [ -z "$2" ]; then
    echo "Missing required environment variable: $1" >&2
    missing=1
  fi
}

_require_env AKS_RESOURCE_GROUP "${AKS_RESOURCE_GROUP:-}"
_require_env AZURE_AKS_CLUSTER_NAME "${AZURE_AKS_CLUSTER_NAME:-}"
_require_env GITHUB_USERNAME "${GITHUB_USERNAME:-}"
_require_env GITHUB_REPO_NAME "${GITHUB_REPO_NAME:-}"
_require_env GITHUB_TOKEN "${GITHUB_TOKEN:-}"

if [ "$missing" -ne 0 ]; then
  echo "Set them with: azd env set <NAME> <value>" >&2
  echo "GITHUB_TOKEN must be a PAT with 'repo' scope:" >&2
  echo "https://fluxcd.io/flux/installation/bootstrap/github/#github-pat" >&2
  exit 1
fi

# get and set credentials.
az aks get-credentials \
  --resource-group "$AKS_RESOURCE_GROUP" \
  --name "$AZURE_AKS_CLUSTER_NAME" \
  --overwrite-existing

if kubectl --context="$AZURE_AKS_CLUSTER_NAME" \
  get gitrepository flux-system -n flux-system >/dev/null 2>&1; then
  echo "Flux is already bootstrapped on '$AZURE_AKS_CLUSTER_NAME'; skipping bootstrap."
  exit 0
fi

echo "Bootstrapping Flux on '$AZURE_AKS_CLUSTER_NAME'..."
flux bootstrap github \
  --components-extra=source-watcher \
  --context="$AZURE_AKS_CLUSTER_NAME" \
  --owner="$GITHUB_USERNAME" \
  --repository="$GITHUB_REPO_NAME" \
  --branch=main \
  --personal \
  --token-auth \
  --path=k8s/clusters/demo-cluster
