#!/bin/bash
set -e

# Deploy all GitHub Actions runners for Matchpoint-AI
# Usage: ./scripts/deploy-all.sh <github-token>

if [ -z "$1" ]; then
    echo "Usage: $0 <github-token>"
    echo "Please provide a GitHub token with repo and admin:org permissions"
    exit 1
fi

GITHUB_TOKEN="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Deploying GitHub Actions Runner Scale Sets for Matchpoint-AI"

# 1. Deploy the controller
echo "📦 Installing GitHub Actions Runner Scale Set Controller..."
cd "$REPO_ROOT/charts/github-actions-controller"
helm dependency update
helm upgrade --install arc . \
    -n arc-systems \
    --create-namespace \
    --wait

# 2. Deploy frontend runners
echo "🌐 Installing Frontend Runners..."
cd "$REPO_ROOT/charts/github-actions-runners"
helm dependency update
helm upgrade --install arc-frontend-runners . \
    -f "$REPO_ROOT/examples/frontend-runners-values.yaml" \
    --set gha-runner-scale-set.githubConfigSecret.github_token="$GITHUB_TOKEN" \
    -n arc-frontend-runners \
    --create-namespace \
    --wait

# 3. Deploy API runners
echo "🔧 Installing API Runners..."
helm upgrade --install arc-api-runners . \
    -f "$REPO_ROOT/examples/api-runners-values.yaml" \
    --set gha-runner-scale-set.githubConfigSecret.github_token="$GITHUB_TOKEN" \
    -n arc-api-runners \
    --create-namespace \
    --wait

# 4. Deploy org-level runners
echo "🧪 Installing Organization Runners..."
helm upgrade --install arc-runners . \
    -f "$REPO_ROOT/examples/runners-values.yaml" \
    --set gha-runner-scale-set.githubConfigSecret.github_token="$GITHUB_TOKEN" \
    -n arc-runners \
    --create-namespace \
    --wait

echo "✅ All runners deployed successfully!"
echo ""
echo "📊 Status check:"
kubectl get autoscalingrunnerset -A
echo ""
echo "🔍 To monitor runner pods:"
echo "kubectl get pods -n arc-frontend-runners"
echo "kubectl get pods -n arc-api-runners"
echo "kubectl get pods -n arc-runners"