#!/bin/bash
# Script to create GitHub token secrets for ArgoCD and org-level ARC runners
# This keeps the actual token out of Git while maintaining GitOps

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <github-token>"
    echo "Creates Kubernetes secrets for GitHub runners in all namespaces"
    exit 1
fi

GITHUB_TOKEN="$1"

echo "Creating GitHub token secrets for ArgoCD and org-level runners..."

# Create secrets in required namespaces
kubectl create secret generic github-token \
    -n argocd \
    --from-literal=token="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic arc-org-github-secret \
    -n arc-runners \
    --from-literal=github_token="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secrets created successfully"
