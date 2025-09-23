#!/bin/bash
# Global runner scaling script
# Usage: ./scale-all-runners.sh <preset|multiplier> [custom-value]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    echo -e "${2}${1}${NC}"
}

# Function to show current runner status
show_status() {
    print_color "\n📊 Current Runner Status:" "$BLUE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if command -v kubectl >/dev/null 2>&1; then
        kubectl get autoscalingrunnerset -A --no-headers 2>/dev/null | while read line; do
            namespace=$(echo $line | awk '{print $1}')
            name=$(echo $line | awk '{print $2}')
            min=$(echo $line | awk '{print $3}')
            max=$(echo $line | awk '{print $4}')
            current=$(echo $line | awk '{print $5}')

            printf "%-30s Min: %-3s Max: %-3s Current: %-3s\n" "$name" "$min" "$max" "$current"
        done

        # Calculate totals
        total_current=$(kubectl get autoscalingrunnerset -A --no-headers 2>/dev/null | awk '{sum+=$5} END {print sum}')
        total_max=$(kubectl get autoscalingrunnerset -A --no-headers 2>/dev/null | awk '{sum+=$4} END {print sum}')

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        printf "%-30s Current: %-3s Max Capacity: %-3s\n" "TOTAL" "$total_current" "$total_max"
    else
        print_color "kubectl not available - showing config only" "$YELLOW"
    fi
}

# Function to apply preset
apply_preset() {
    local preset=$1
    print_color "\n🎯 Applying preset: $preset" "$GREEN"

    case $preset in
        normal)
            multiplier=1.0
            max_total=200
            ;;
        economy)
            multiplier=0.3
            max_total=50
            ;;
        peak)
            multiplier=2.0
            max_total=300
            ;;
        emergency)
            multiplier=3.0
            max_total=400
            ;;
        maintenance)
            multiplier=0.1
            max_total=10
            ;;
        *)
            print_color "❌ Unknown preset: $preset" "$RED"
            echo "Available presets: normal, economy, peak, emergency, maintenance"
            exit 1
            ;;
    esac

    update_scaling $multiplier $max_total
}

# Function to apply custom multiplier
apply_multiplier() {
    local multiplier=$1

    # Validate multiplier
    if [[ ! "$multiplier" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        print_color "❌ Invalid multiplier: $multiplier" "$RED"
        exit 1
    fi

    # Calculate max total based on multiplier
    max_total=$(echo "200 * $multiplier" | bc | cut -d. -f1)

    print_color "\n🔧 Applying custom multiplier: ${multiplier}x" "$GREEN"
    update_scaling $multiplier $max_total
}

# Function to update scaling configuration
update_scaling() {
    local multiplier=$1
    local max_total=$2

    print_color "  Multiplier: ${multiplier}x" "$YELLOW"
    print_color "  Max Total: $max_total runners" "$YELLOW"

    # Update global-scaling.yaml
    if command -v yq >/dev/null 2>&1; then
        yq eval ".scaling.globalMultiplier = $multiplier" -i "$REPO_ROOT/values/global-scaling.yaml"
        yq eval ".scaling.absolute.maxTotalRunners = $max_total" -i "$REPO_ROOT/values/global-scaling.yaml"

        # Update repositories.yaml with new multiplier
        # Read current values and apply multiplier
        while IFS= read -r repo; do
            name=$(echo "$repo" | yq eval '.name' -)
            base_min=$(echo "$repo" | yq eval '.scaling.minRunners' -)
            base_max=$(echo "$repo" | yq eval '.scaling.maxRunners' -)

            new_min=$(echo "$base_min * $multiplier" | bc | cut -d. -f1)
            new_max=$(echo "$base_max * $multiplier" | bc | cut -d. -f1)

            # Ensure we don't exceed per-repo maximum
            if [ "$new_max" -gt "50" ]; then
                new_max=50
            fi

            # Ensure min doesn't exceed max
            if [ "$new_min" -gt "$new_max" ]; then
                new_min=$new_max
            fi

            print_color "  $name: min=$new_min max=$new_max" "$NC"

            # Update the actual values file
            yq eval "(.repositories[] | select(.name == \"$name\") | .scaling.minRunners) = $new_min" -i "$REPO_ROOT/values/repositories.yaml"
            yq eval "(.repositories[] | select(.name == \"$name\") | .scaling.maxRunners) = $new_max" -i "$REPO_ROOT/values/repositories.yaml"
        done < <(yq eval '.repositories[]' "$REPO_ROOT/values/repositories.yaml")

    else
        print_color "⚠️  yq not found. Please install with: pip install yq" "$YELLOW"
        print_color "    Manual update required in values/global-scaling.yaml" "$YELLOW"
        exit 1
    fi

    print_color "\n✅ Configuration updated" "$GREEN"
}

# Function to commit and push changes
commit_changes() {
    cd "$REPO_ROOT"

    if [ -n "$(git status --porcelain values/)" ]; then
        git add values/global-scaling.yaml values/repositories.yaml
        git commit -m "Scale all runners: ${1}

Applied scaling adjustment across all runner configurations.
Multiplier: ${multiplier}x
Max Total: ${max_total} runners

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"

        print_color "\n📤 Pushing changes to Git..." "$BLUE"
        git push

        print_color "✅ Changes pushed. ArgoCD will sync automatically." "$GREEN"
    else
        print_color "ℹ️  No changes to commit" "$YELLOW"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <command> [value]"
    echo ""
    echo "Commands:"
    echo "  status                    Show current runner status"
    echo "  normal                    Normal capacity (1x)"
    echo "  economy                   Cost-saving mode (0.3x)"
    echo "  peak                      High demand (2x)"
    echo "  emergency                 Critical load (3x)"
    echo "  maintenance              Minimal capacity (0.1x)"
    echo "  <multiplier>             Custom multiplier (e.g., 1.5)"
    echo ""
    echo "Examples:"
    echo "  $0 status                # Show current status"
    echo "  $0 peak                  # Apply peak preset"
    echo "  $0 1.5                   # Scale to 1.5x capacity"
    echo "  $0 economy               # Switch to economy mode"
}

# Main script logic
if [ -z "$1" ]; then
    show_usage
    exit 1
fi

case "$1" in
    status)
        show_status
        ;;
    normal|economy|peak|emergency|maintenance)
        show_status
        apply_preset "$1"
        commit_changes "$1 preset"
        show_status
        ;;
    [0-9]*.[0-9]*|[0-9]*)
        show_status
        apply_multiplier "$1"
        commit_changes "multiplier ${1}x"
        show_status
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_color "❌ Unknown command: $1" "$RED"
        show_usage
        exit 1
        ;;
esac

# Show cost estimate
if [ "$1" != "status" ]; then
    echo ""
    print_color "💰 Estimated Cost Impact:" "$BLUE"
    # Rough estimates (adjust based on your cloud provider)
    base_cost=100 # Base cost for 1x capacity
    new_cost=$(echo "$base_cost * ${multiplier:-1}" | bc)
    print_color "  Estimated monthly: \$${new_cost}" "$YELLOW"
fi