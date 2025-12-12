#!/bin/bash
#
# validate-release-names.sh
#
# Validates that ArgoCD releaseName matches runnerScaleSetName in values files.
# This prevents the critical mismatch that causes runners to register with empty labels.
#
# See: https://github.com/Matchpoint-AI/matchpoint-github-runners-helm/issues/112
# See: https://github.com/Matchpoint-AI/matchpoint-github-runners-helm/issues/89

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Validating ArgoCD releaseName matches runnerScaleSetName..."
echo ""

ERRORS=0

# Function to extract releaseName from ArgoCD Application
get_release_name() {
    local app_file="$1"
    grep -E "^\s*releaseName:" "$app_file" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'"
}

# Function to extract runnerScaleSetName from values file
get_runner_scale_set_name() {
    local values_file="$1"
    grep -E "^\s*runnerScaleSetName:" "$values_file" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'"
}

# Validate arc-runners configuration
echo "Checking arc-runners configuration..."

ARGOCD_APP="$REPO_ROOT/argocd/apps-live/arc-runners.yaml"
VALUES_FILE="$REPO_ROOT/examples/runners-values.yaml"

if [[ -f "$ARGOCD_APP" && -f "$VALUES_FILE" ]]; then
    RELEASE_NAME=$(get_release_name "$ARGOCD_APP")
    SCALE_SET_NAME=$(get_runner_scale_set_name "$VALUES_FILE")

    echo "  ArgoCD releaseName: $RELEASE_NAME"
    echo "  Values runnerScaleSetName: $SCALE_SET_NAME"

    if [[ "$RELEASE_NAME" != "$SCALE_SET_NAME" ]]; then
        echo -e "  ${RED}ERROR: MISMATCH DETECTED!${NC}"
        echo "  releaseName ($RELEASE_NAME) != runnerScaleSetName ($SCALE_SET_NAME)"
        echo ""
        echo "  This will cause runners to register with empty labels!"
        echo "  See: docs/TROUBLESHOOTING_EMPTY_LABELS.md"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "  ${GREEN}OK: Names match${NC}"
    fi
else
    echo -e "  ${YELLOW}SKIP: Files not found${NC}"
fi

echo ""

# Validate arc-frontend-runners configuration
echo "Checking arc-frontend-runners configuration..."

ARGOCD_APP_FRONTEND="$REPO_ROOT/argocd/apps-live/arc-frontend-runners.yaml"
VALUES_FILE_FRONTEND="$REPO_ROOT/examples/frontend-runners-values.yaml"

if [[ -f "$ARGOCD_APP_FRONTEND" && -f "$VALUES_FILE_FRONTEND" ]]; then
    RELEASE_NAME_FE=$(get_release_name "$ARGOCD_APP_FRONTEND")
    SCALE_SET_NAME_FE=$(get_runner_scale_set_name "$VALUES_FILE_FRONTEND")

    echo "  ArgoCD releaseName: $RELEASE_NAME_FE"
    echo "  Values runnerScaleSetName: $SCALE_SET_NAME_FE"

    if [[ "$RELEASE_NAME_FE" != "$SCALE_SET_NAME_FE" ]]; then
        echo -e "  ${RED}ERROR: MISMATCH DETECTED!${NC}"
        echo "  releaseName ($RELEASE_NAME_FE) != runnerScaleSetName ($SCALE_SET_NAME_FE)"
        echo ""
        echo "  This will cause runners to register with empty labels!"
        echo "  See: docs/TROUBLESHOOTING_EMPTY_LABELS.md"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "  ${GREEN}OK: Names match${NC}"
    fi
else
    echo -e "  ${YELLOW}SKIP: Files not found${NC}"
fi

echo ""

# Summary
if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}VALIDATION FAILED: $ERRORS error(s) found${NC}"
    echo ""
    echo "CRITICAL: ArgoCD releaseName MUST match runnerScaleSetName!"
    echo "Mismatched names cause runners to register with empty labels,"
    echo "which means CI jobs will queue indefinitely."
    echo ""
    echo "Fix: Update argocd/apps-live/*.yaml to match the runnerScaleSetName"
    echo "     in the corresponding examples/*-values.yaml file."
    exit 1
else
    echo -e "${GREEN}VALIDATION PASSED: All release names match${NC}"
    exit 0
fi
