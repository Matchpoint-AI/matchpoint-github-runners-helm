#!/bin/bash
# Script to create GitHub token secret for runners
# This keeps the actual token out of Git while maintaining GitOps

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <github-token>"
    echo "Creates Kubernetes secrets for GitHub runners in all namespaces"
    exit 1
fi

GITHUB_TOKEN="$1"

echo "Creating GitHub token secrets for runners..."

# Create secrets in each namespace
kubectl create secret generic github-runner-token \
    -n argocd \
    --from-literal=token="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic arc-frontend-runners-gha-rs-github-secret \
    -n arc-frontend-runners \
    --from-literal=github_token="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic arc-api-runners-v2-gha-rs-github-secret \
    -n arc-api-runners-v2 \
    --from-literal=github_token="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic arc-beta-runners-new-gha-rs-github-secret \
    -n arc-beta-runners-new \
    --from-literal=github_token="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secrets created successfully"