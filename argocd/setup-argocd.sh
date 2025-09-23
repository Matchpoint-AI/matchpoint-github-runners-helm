#!/bin/bash
set -e

# Setup ArgoCD for GitHub Runners management
# Usage: ./argocd/setup-argocd.sh <github-token>

if [ -z "$1" ]; then
    echo "Usage: $0 <github-token>"
    echo "Please provide a GitHub token with repo and admin:org permissions"
    exit 1
fi

GITHUB_TOKEN="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Setting up ArgoCD for GitHub Runners management"

# Get ArgoCD server details
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "📍 ArgoCD Server: $ARGOCD_SERVER"
echo "🔑 Admin Password: $ARGOCD_PASSWORD"

# Login to ArgoCD
echo "🔐 Logging into ArgoCD..."
~/bin/argocd login $ARGOCD_SERVER \
    --username admin \
    --password "$ARGOCD_PASSWORD" \
    --insecure

# Add the GitHub repository
echo "📦 Adding GitHub repository..."
~/bin/argocd repo add https://github.com/Matchpoint-AI/matchpoint-github-runners-helm \
    --type git \
    --insecure-skip-server-verification

# Create a secret for the GitHub token
echo "🔑 Creating GitHub token secret..."
kubectl create secret generic github-token \
    -n argocd \
    --from-literal=token="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

# Configure ArgoCD to use the GitHub token as environment variable
echo "⚙️ Configuring ArgoCD to use GitHub token..."
kubectl patch configmap argocd-cm -n argocd --type merge -p '{
  "data": {
    "application.instanceLabelKey": "argocd.argoproj.io/instance",
    "server.disable.auth": "false",
    "timeout.reconciliation": "180s",
    "timeout.hard.reconciliation": "0",
    "application.resourceTrackingMethod": "annotation+label"
  }
}'

# Patch the repo-server to include the GitHub token
kubectl patch deployment argocd-repo-server -n argocd --type json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "ARGOCD_ENV_GITHUB_TOKEN",
      "valueFrom": {
        "secretKeyRef": {
          "name": "github-token",
          "key": "token"
        }
      }
    }
  }
]'

# Wait for repo-server to restart
echo "⏳ Waiting for repo-server to restart..."
kubectl rollout status deployment/argocd-repo-server -n argocd

# Apply the ArgoCD applications
echo "📝 Creating ArgoCD applications..."

# Apply the controller application
kubectl apply -f "$REPO_ROOT/argocd/applications/arc-controller.yaml"

# Apply the ApplicationSet for all runners
kubectl apply -f "$REPO_ROOT/argocd/applicationset.yaml"

echo "✅ ArgoCD setup complete!"
echo ""
echo "🌐 Access ArgoCD UI: https://$ARGOCD_SERVER"
echo "👤 Username: admin"
echo "🔑 Password: $ARGOCD_PASSWORD"
echo ""
echo "📊 Check application status:"
echo "~/bin/argocd app list"
echo ""
echo "🔄 Sync all applications:"
echo "~/bin/argocd app sync -l argocd.argoproj.io/instance=github-runners"