#!/bin/bash
# Script to scale GitHub Actions runners dynamically
# Usage: ./scale-runners.sh <repository> <min> <max>

set -e

REPO_NAME="$1"
MIN_RUNNERS="$2"
MAX_RUNNERS="$3"

if [ -z "$REPO_NAME" ] || [ -z "$MIN_RUNNERS" ] || [ -z "$MAX_RUNNERS" ]; then
    echo "Usage: $0 <repository-name> <min-runners> <max-runners>"
    echo "Example: $0 project-beta-frontend 2 20"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VALUES_FILE="$REPO_ROOT/values/repositories.yaml"

echo "📊 Scaling runners for $REPO_NAME: min=$MIN_RUNNERS, max=$MAX_RUNNERS"

# Update the repositories.yaml file
if grep -q "name: $REPO_NAME" "$VALUES_FILE"; then
    # Use yq to update the values (install with: pip install yq)
    if command -v yq >/dev/null 2>&1; then
        yq eval "(.repositories[] | select(.name == \"$REPO_NAME\") | .scaling.minRunners) = $MIN_RUNNERS" -i "$VALUES_FILE"
        yq eval "(.repositories[] | select(.name == \"$REPO_NAME\") | .scaling.maxRunners) = $MAX_RUNNERS" -i "$VALUES_FILE"
    else
        echo "⚠️ yq not found. Attempting sed update..."
        # Fallback to sed (less reliable)
        sed -i "/name: $REPO_NAME/,/scaling:/{/minRunners:/s/: .*/: $MIN_RUNNERS/}" "$VALUES_FILE"
        sed -i "/name: $REPO_NAME/,/scaling:/{/maxRunners:/s/: .*/: $MAX_RUNNERS/}" "$VALUES_FILE"
    fi

    echo "✅ Updated $VALUES_FILE"

    # Commit and push the change
    cd "$REPO_ROOT"
    git add "$VALUES_FILE"
    git commit -m "Scale $REPO_NAME runners: min=$MIN_RUNNERS, max=$MAX_RUNNERS

Adjusted runner scaling parameters via automated script.

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"
    git push

    echo "🚀 Changes pushed. ArgoCD will sync automatically."

    # Optional: Force immediate sync
    if command -v argocd >/dev/null 2>&1; then
        echo "🔄 Triggering immediate ArgoCD sync..."
        argocd app sync "$REPO_NAME-runners" --prune
    fi
else
    echo "❌ Repository $REPO_NAME not found in $VALUES_FILE"
    exit 1
fi