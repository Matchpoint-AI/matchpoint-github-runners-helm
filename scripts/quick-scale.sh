#!/bin/bash
# Quick scaling script for immediate adjustments
# No Git commits - direct kubectl commands for emergency scaling

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_color() {
    echo -e "${2}${1}${NC}"
}

show_usage() {
    echo "Quick Scale - Immediate runner adjustments (bypasses GitOps)"
    echo ""
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  up <repo> <count>        Scale up by count"
    echo "  down <repo> <count>      Scale down by count"
    echo "  set <repo> <min> <max>   Set exact min/max"
    echo "  boost <repo>             2x current max (temporary)"
    echo "  pause <repo>             Set to 0 (temporary)"
    echo "  status                   Show all runners"
    echo ""
    echo "Examples:"
    echo "  $0 up frontend 10        # Add 10 more frontend runners"
    echo "  $0 set api 5 30          # Set API to min=5, max=30"
    echo "  $0 boost frontend        # Double frontend capacity NOW"
    echo "  $0 pause beta            # Stop beta runners temporarily"
    echo ""
    echo "⚠️  WARNING: These changes bypass GitOps and will be overridden"
    echo "    by the next ArgoCD sync. Use for emergencies only!"
}

get_namespace() {
    local repo=$1
    case $repo in
        frontend)
            echo "arc-frontend-runners"
            ;;
        api)
            echo "arc-api-runners-v2"
            ;;
        beta)
            echo "arc-beta-runners-new"
            ;;
        *)
            echo "arc-${repo}-runners"
            ;;
    esac
}

scale_up() {
    local repo=$1
    local count=$2
    local namespace=$(get_namespace $repo)

    print_color "⬆️  Scaling up $repo by $count runners..." "$BLUE"

    # Get current max
    current_max=$(kubectl get autoscalingrunnerset -n $namespace -o jsonpath='{.items[0].spec.maxRunners}' 2>/dev/null || echo 10)
    new_max=$((current_max + count))

    kubectl patch autoscalingrunnerset -n $namespace \
        $(kubectl get autoscalingrunnerset -n $namespace -o name | cut -d/ -f2) \
        --type merge \
        -p "{\"spec\":{\"maxRunners\":$new_max}}"

    print_color "✅ Scaled $repo to max=$new_max (was $current_max)" "$GREEN"
}

scale_down() {
    local repo=$1
    local count=$2
    local namespace=$(get_namespace $repo)

    print_color "⬇️  Scaling down $repo by $count runners..." "$BLUE"

    # Get current max and min
    current_max=$(kubectl get autoscalingrunnerset -n $namespace -o jsonpath='{.items[0].spec.maxRunners}' 2>/dev/null || echo 10)
    current_min=$(kubectl get autoscalingrunnerset -n $namespace -o jsonpath='{.items[0].spec.minRunners}' 2>/dev/null || echo 0)

    new_max=$((current_max - count))
    if [ $new_max -lt $current_min ]; then
        new_max=$current_min
    fi

    kubectl patch autoscalingrunnerset -n $namespace \
        $(kubectl get autoscalingrunnerset -n $namespace -o name | cut -d/ -f2) \
        --type merge \
        -p "{\"spec\":{\"maxRunners\":$new_max}}"

    print_color "✅ Scaled $repo to max=$new_max (was $current_max)" "$GREEN"
}

scale_set() {
    local repo=$1
    local min=$2
    local max=$3
    local namespace=$(get_namespace $repo)

    print_color "🎯 Setting $repo to min=$min max=$max..." "$BLUE"

    kubectl patch autoscalingrunnerset -n $namespace \
        $(kubectl get autoscalingrunnerset -n $namespace -o name | cut -d/ -f2) \
        --type merge \
        -p "{\"spec\":{\"minRunners\":$min,\"maxRunners\":$max}}"

    print_color "✅ Set $repo to min=$min max=$max" "$GREEN"
}

scale_boost() {
    local repo=$1
    local namespace=$(get_namespace $repo)

    print_color "🚀 Boosting $repo capacity (2x)..." "$YELLOW"

    # Get current max
    current_max=$(kubectl get autoscalingrunnerset -n $namespace -o jsonpath='{.items[0].spec.maxRunners}' 2>/dev/null || echo 10)
    new_max=$((current_max * 2))

    kubectl patch autoscalingrunnerset -n $namespace \
        $(kubectl get autoscalingrunnerset -n $namespace -o name | cut -d/ -f2) \
        --type merge \
        -p "{\"spec\":{\"maxRunners\":$new_max}}"

    print_color "✅ Boosted $repo to max=$new_max (was $current_max)" "$GREEN"
    print_color "⚠️  Remember to scale back down after the peak!" "$YELLOW"
}

scale_pause() {
    local repo=$1
    local namespace=$(get_namespace $repo)

    print_color "⏸️  Pausing $repo runners..." "$YELLOW"

    kubectl patch autoscalingrunnerset -n $namespace \
        $(kubectl get autoscalingrunnerset -n $namespace -o name | cut -d/ -f2) \
        --type merge \
        -p "{\"spec\":{\"minRunners\":0,\"maxRunners\":0}}"

    print_color "✅ Paused $repo (set to 0)" "$GREEN"
}

show_status() {
    print_color "\n📊 Current Runner Status:" "$BLUE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    kubectl get autoscalingrunnerset -A --no-headers 2>/dev/null | while read line; do
        namespace=$(echo $line | awk '{print $1}')
        name=$(echo $line | awk '{print $2}')
        min=$(echo $line | awk '{print $3}')
        max=$(echo $line | awk '{print $4}')
        current=$(echo $line | awk '{print $5}')
        pending=$(echo $line | awk '{print $7}')
        running=$(echo $line | awk '{print $8}')

        # Color code based on utilization
        if [ "$current" = "$max" ]; then
            color=$RED  # At capacity
        elif [ "$running" -gt "0" ]; then
            color=$GREEN  # Active
        else
            color=$NC  # Idle
        fi

        printf "${color}%-25s${NC} Min:%-3s Max:%-3s Current:%-3s Running:%-3s Pending:%-3s\n" \
            "$name" "$min" "$max" "${current:-0}" "${running:-0}" "${pending:-0}"
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Show totals
    total_current=$(kubectl get autoscalingrunnerset -A --no-headers 2>/dev/null | awk '{sum+=$5} END {print sum}')
    total_running=$(kubectl get autoscalingrunnerset -A --no-headers 2>/dev/null | awk '{sum+=$8} END {print sum}')
    total_max=$(kubectl get autoscalingrunnerset -A --no-headers 2>/dev/null | awk '{sum+=$4} END {print sum}')

    printf "%-25s Current:%-3s Running:%-3s MaxCapacity:%-3s\n" \
        "TOTAL" "${total_current:-0}" "${total_running:-0}" "${total_max:-0}"

    # Show cluster capacity
    echo ""
    print_color "🖥️  Cluster Resources:" "$BLUE"
    kubectl top nodes --no-headers 2>/dev/null | head -5 | while read line; do
        node=$(echo $line | awk '{print $1}')
        cpu=$(echo $line | awk '{print $3}')
        mem=$(echo $line | awk '{print $5}')
        printf "  %-30s CPU:%-5s Memory:%-5s\n" "$node" "$cpu" "$mem"
    done
}

# Main script
case "$1" in
    up)
        if [ -z "$2" ] || [ -z "$3" ]; then
            print_color "❌ Usage: $0 up <repo> <count>" "$RED"
            exit 1
        fi
        scale_up "$2" "$3"
        ;;
    down)
        if [ -z "$2" ] || [ -z "$3" ]; then
            print_color "❌ Usage: $0 down <repo> <count>" "$RED"
            exit 1
        fi
        scale_down "$2" "$3"
        ;;
    set)
        if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
            print_color "❌ Usage: $0 set <repo> <min> <max>" "$RED"
            exit 1
        fi
        scale_set "$2" "$3" "$4"
        ;;
    boost)
        if [ -z "$2" ]; then
            print_color "❌ Usage: $0 boost <repo>" "$RED"
            exit 1
        fi
        scale_boost "$2"
        ;;
    pause)
        if [ -z "$2" ]; then
            print_color "❌ Usage: $0 pause <repo>" "$RED"
            exit 1
        fi
        scale_pause "$2"
        ;;
    status)
        show_status
        ;;
    help|--help|-h|"")
        show_usage
        ;;
    *)
        print_color "❌ Unknown command: $1" "$RED"
        show_usage
        exit 1
        ;;
esac

if [ "$1" != "status" ] && [ "$1" != "help" ] && [ "$1" != "--help" ] && [ "$1" != "-h" ] && [ -n "$1" ]; then
    echo ""
    print_color "⚠️  This change bypasses GitOps and is TEMPORARY!" "$YELLOW"
    print_color "    Next ArgoCD sync will revert to Git configuration." "$YELLOW"
    print_color "    For permanent changes, use: ./scale-runners.sh" "$YELLOW"
fi