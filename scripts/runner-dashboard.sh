#!/bin/bash
# Real-time runner monitoring dashboard
# Shows runner status, queue times, and resource usage

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
REFRESH_INTERVAL=${1:-5}  # Default 5 seconds

clear_screen() {
    clear
    printf "\033[0;0H"
}

print_header() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                     GitHub Actions Runner Dashboard                      ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

get_runner_status() {
    echo -e "${BOLD}${BLUE}📊 Runner Status${NC}"
    echo "┌────────────────────────┬─────┬─────┬─────────┬─────────┬─────────┐"
    echo "│ Repository             │ Min │ Max │ Current │ Running │ Pending │"
    echo "├────────────────────────┼─────┼─────┼─────────┼─────────┼─────────┤"

    local total_min=0
    local total_max=0
    local total_current=0
    local total_running=0
    local total_pending=0

    kubectl get autoscalingrunnerset -A --no-headers 2>/dev/null | while read line; do
        namespace=$(echo $line | awk '{print $1}')
        name=$(echo $line | awk '{print $2}' | sed 's/arc-//' | sed 's/-runners//')
        min=$(echo $line | awk '{print $3}')
        max=$(echo $line | awk '{print $4}')
        current=$(echo $line | awk '{print $5}')
        pending=$(echo $line | awk '{print $7}')
        running=$(echo $line | awk '{print $8}')

        # Default to 0 if empty
        min=${min:-0}
        max=${max:-0}
        current=${current:-0}
        pending=${pending:-0}
        running=${running:-0}

        # Color coding
        if [ "$current" = "$max" ] && [ "$max" != "0" ]; then
            status_color=$RED  # At capacity
        elif [ "$running" -gt "0" ]; then
            status_color=$GREEN  # Active
        elif [ "$pending" -gt "0" ]; then
            status_color=$YELLOW  # Starting
        else
            status_color=$NC  # Idle
        fi

        printf "│ ${status_color}%-22s${NC} │ %3s │ %3s │ %7s │ %7s │ %7s │\n" \
            "$name" "$min" "$max" "$current" "$running" "$pending"

        total_min=$((total_min + min))
        total_max=$((total_max + max))
        total_current=$((total_current + current))
        total_running=$((total_running + running))
        total_pending=$((total_pending + pending))
    done

    echo "├────────────────────────┼─────┼─────┼─────────┼─────────┼─────────┤"
    printf "│ ${BOLD}%-22s${NC} │ %3s │ %3s │ %7s │ %7s │ %7s │\n" \
        "TOTAL" "$total_min" "$total_max" "$total_current" "$total_running" "$total_pending"
    echo "└────────────────────────┴─────┴─────┴─────────┴─────────┴─────────┘"
}

get_resource_usage() {
    echo ""
    echo -e "${BOLD}${BLUE}💻 Cluster Resources${NC}"
    echo "┌─────────────────────────────┬──────────┬──────────┬──────────┐"
    echo "│ Node                        │ CPU Used │ CPU Cap. │ Memory % │"
    echo "├─────────────────────────────┼──────────┼──────────┼──────────┤"

    kubectl top nodes --no-headers 2>/dev/null | head -5 | while read line; do
        node=$(echo $line | awk '{print $1}' | cut -c1-27)
        cpu_used=$(echo $line | awk '{print $2}')
        cpu_percent=$(echo $line | awk '{print $3}')
        mem_percent=$(echo $line | awk '{print $5}')

        # Color code based on usage
        if [[ ${cpu_percent%\%} -gt 80 ]]; then
            cpu_color=$RED
        elif [[ ${cpu_percent%\%} -gt 60 ]]; then
            cpu_color=$YELLOW
        else
            cpu_color=$GREEN
        fi

        if [[ ${mem_percent%\%} -gt 80 ]]; then
            mem_color=$RED
        elif [[ ${mem_percent%\%} -gt 60 ]]; then
            mem_color=$YELLOW
        else
            mem_color=$GREEN
        fi

        printf "│ %-27s │ %8s │ ${cpu_color}%8s${NC} │ ${mem_color}%8s${NC} │\n" \
            "$node" "$cpu_used" "$cpu_percent" "$mem_percent"
    done

    echo "└─────────────────────────────┴──────────┴──────────┴──────────┘"
}

get_recent_jobs() {
    echo ""
    echo -e "${BOLD}${BLUE}🏃 Recent Runner Activity${NC}"
    echo "┌────────────────────┬─────────────────────┬──────────┬──────────┐"
    echo "│ Runner Pod         │ Repository          │ Status   │ Duration │"
    echo "├────────────────────┼─────────────────────┼──────────┼──────────┤"

    # Get runner pods from all namespaces
    kubectl get pods -A -l app.kubernetes.io/component=runner --no-headers 2>/dev/null | \
        head -10 | while read line; do
        namespace=$(echo $line | awk '{print $1}')
        pod=$(echo $line | awk '{print $2}' | cut -c1-18)
        status=$(echo $line | awk '{print $4}')
        age=$(echo $line | awk '{print $6}')

        # Extract repo name from namespace
        repo=$(echo $namespace | sed 's/arc-//' | sed 's/-runners.*//')

        # Color based on status
        case "$status" in
            Running)
                status_color=$GREEN
                ;;
            Completed)
                status_color=$BLUE
                ;;
            Error|Failed|CrashLoopBackOff)
                status_color=$RED
                ;;
            *)
                status_color=$YELLOW
                ;;
        esac

        printf "│ %-18s │ %-19s │ ${status_color}%-8s${NC} │ %8s │\n" \
            "$pod" "$repo" "$status" "$age"
    done

    echo "└────────────────────┴─────────────────────┴──────────┴──────────┘"
}

get_queue_status() {
    echo ""
    echo -e "${BOLD}${BLUE}⏱️  Queue Metrics${NC}"

    # Check for pending workflow runs (requires gh CLI)
    if command -v gh >/dev/null 2>&1; then
        echo "┌────────────────────────┬─────────┬──────────┬────────────┐"
        echo "│ Repository             │ Queued  │ Running  │ Completed  │"
        echo "├────────────────────────┼─────────┼──────────┼────────────┤"

        for repo in "project-beta-frontend" "project-beta-api" "project-beta"; do
            if gh api repos/Matchpoint-AI/$repo/actions/runs --jq '.workflow_runs[0:10]' 2>/dev/null | \
               jq -r '.[] | .status' 2>/dev/null | grep -q .; then

                queued=$(gh api repos/Matchpoint-AI/$repo/actions/runs --jq '.workflow_runs[0:10] | map(select(.status == "queued")) | length' 2>/dev/null || echo 0)
                running=$(gh api repos/Matchpoint-AI/$repo/actions/runs --jq '.workflow_runs[0:10] | map(select(.status == "in_progress")) | length' 2>/dev/null || echo 0)
                completed=$(gh api repos/Matchpoint-AI/$repo/actions/runs --jq '.workflow_runs[0:10] | map(select(.status == "completed")) | length' 2>/dev/null || echo 0)

                # Color coding
                if [ "$queued" -gt "3" ]; then
                    queue_color=$RED
                elif [ "$queued" -gt "1" ]; then
                    queue_color=$YELLOW
                else
                    queue_color=$GREEN
                fi

                printf "│ %-22s │ ${queue_color}%7s${NC} │ %8s │ %10s │\n" \
                    "${repo:0:22}" "$queued" "$running" "$completed"
            fi
        done

        echo "└────────────────────────┴─────────┴──────────┴────────────┘"
    else
        echo "  GitHub CLI not available - install 'gh' for queue metrics"
    fi
}

show_recommendations() {
    echo ""
    echo -e "${BOLD}${MAGENTA}💡 Recommendations${NC}"

    # Check for scaling recommendations
    local total_current=$(kubectl get autoscalingrunnerset -A --no-headers 2>/dev/null | awk '{sum+=$5} END {print sum}')
    local total_max=$(kubectl get autoscalingrunnerset -A --no-headers 2>/dev/null | awk '{sum+=$4} END {print sum}')
    local total_running=$(kubectl get autoscalingrunnerset -A --no-headers 2>/dev/null | awk '{sum+=$8} END {print sum}')

    if [ "$total_current" = "$total_max" ] && [ "$total_max" != "0" ]; then
        echo -e "  ${YELLOW}⚠️  At maximum capacity! Consider scaling up.${NC}"
        echo "     Run: ./scripts/scale-all-runners.sh peak"
    elif [ "$total_running" = "0" ] && [ "$total_current" -gt "5" ]; then
        echo -e "  ${GREEN}💰 All runners idle. Consider scaling down to save costs.${NC}"
        echo "     Run: ./scripts/scale-all-runners.sh economy"
    fi

    # Check node resource usage
    local high_cpu_nodes=$(kubectl top nodes --no-headers 2>/dev/null | awk '$3 ~ /%/ {gsub(/%/, "", $3); if($3 > 80) print $1}' | wc -l)
    if [ "$high_cpu_nodes" -gt "0" ]; then
        echo -e "  ${YELLOW}⚠️  $high_cpu_nodes nodes at >80% CPU. Monitor closely.${NC}"
    fi
}

main_loop() {
    while true; do
        clear_screen
        print_header

        echo -e "${NC}Last Update: $(date '+%Y-%m-%d %H:%M:%S') | Refresh: ${REFRESH_INTERVAL}s | Press Ctrl+C to exit${NC}"
        echo ""

        get_runner_status
        get_resource_usage
        get_recent_jobs
        get_queue_status
        show_recommendations

        sleep $REFRESH_INTERVAL
    done
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${GREEN}Dashboard stopped.${NC}"; exit 0' INT

# Check kubectl availability
if ! command -v kubectl >/dev/null 2>&1; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster.${NC}"
    echo "Please check your KUBECONFIG settings."
    exit 1
fi

# Start the dashboard
main_loop