#!/bin/bash

# Comprehensive GitHub Actions Workflow Cycle Runner
# Fires each workflow and goes through entire cycle with monitoring

set -e

echo "🚀 WORKFLOW CYCLE RUNNER"
echo "========================"
echo ""

# Check dependencies
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found"
    echo "💡 Install with: sudo apt install gh"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo "❌ Not authenticated with GitHub"
    echo "💡 Run: gh auth login"
    exit 1
fi

# Configuration
REPO_PATH="/home/tom/GitHub/oracle-fusion-projects"
cd "$REPO_PATH"

# Workflow definitions with their default parameters
declare -A WORKFLOWS=(
    ["simple-test.yml"]="message=CycleTest-$(date +%s)"
    ["fibonacci-simple.yml"]="iterations=25"
    ["async-state-machine.yml"]="stage=all"
    ["pubsub-async-pipeline.yml"]="test_mode=true max_iterations=5"
    ["fibonacci-producer.yml"]="fibonacci_type=standard"
    ["async-producer.yml"]="fibonacci_type=standard"
    ["test-async-pipeline.yml"]="test_scenario=fibonacci iterations=50"
    ["test-async-feedback-loop.yml"]="test_type=end_to_end"
    ["test-validation.yml"]="test_param=CycleValidation"
    ["test-cancellable.yml"]="duration=30"
)

# Function to trigger workflow
trigger_workflow() {
    local workflow_file="$1"
    local params="$2"
    local workflow_name=$(basename "$workflow_file" .yml)
    
    echo "🔥 Triggering: $workflow_file"
    echo "   Parameters: $params"
    
    # Build gh workflow run command
    local cmd="gh workflow run $workflow_file"
    
    # Add parameters
    if [[ -n "$params" ]]; then
        for param in $params; do
            local key=$(echo "$param" | cut -d'=' -f1)
            local value=$(echo "$param" | cut -d'=' -f2-)
            cmd="$cmd --field $key='$value'"
        done
    fi
    
    # Execute the command
    if eval "$cmd" 2>/dev/null; then
        echo "   ✅ Triggered successfully"
        return 0
    else
        echo "   ❌ Failed to trigger"
        return 1
    fi
}

# Function to wait for workflow completion
wait_for_completion() {
    local workflow_file="$1"
    local max_wait="${2:-300}"  # Default 5 minutes
    local start_time=$(date +%s)
    local timeout_time=$((start_time + max_wait))
    
    echo "⏳ Waiting for $workflow_file to complete (max ${max_wait}s)..."
    
    while [ $(date +%s) -lt $timeout_time ]; do
        # Get latest run for this workflow
        local status=$(gh run list --workflow="$workflow_file" --limit=1 --json status,conclusion --jq '.[0] | select(.status == "completed") | .conclusion' 2>/dev/null || echo "")
        
        if [[ -n "$status" ]]; then
            if [[ "$status" == "success" ]]; then
                echo "   ✅ Completed successfully"
                return 0
            elif [[ "$status" == "failure" ]]; then
                echo "   ❌ Failed"
                return 1
            elif [[ "$status" == "cancelled" ]]; then
                echo "   ⚠️ Cancelled"
                return 2
            fi
        fi
        
        # Show progress
        echo -n "."
        sleep 10
    done
    
    echo ""
    echo "   ⏰ Timeout after ${max_wait}s"
    return 3
}

# Function to show current status
show_status() {
    echo ""
    echo "📊 CURRENT WORKFLOW STATUS"
    echo "=========================="
    gh run list --limit=15 2>/dev/null || echo "No runs found"
    echo ""
}

# Function to run single workflow cycle
run_single_workflow() {
    local workflow="$1"
    local params="${WORKFLOWS[$workflow]}"
    
    echo ""
    echo "🎯 RUNNING: $workflow"
    echo "=================="
    
    if trigger_workflow "$workflow" "$params"; then
        if [[ "$MONITOR_MODE" == "true" ]]; then
            wait_for_completion "$workflow" 180
        else
            echo "   ⚡ Triggered (not monitoring completion)"
        fi
    fi
}

# Function to run full cycle
run_full_cycle() {
    echo "🌀 RUNNING FULL WORKFLOW CYCLE"
    echo "=============================="
    echo "Mode: $EXECUTION_MODE"
    echo "Monitor: $MONITOR_MODE"
    echo ""
    
    local total_workflows=${#WORKFLOWS[@]}
    local current=0
    local successful=0
    local failed=0
    
    for workflow in "${!WORKFLOWS[@]}"; do
        current=$((current + 1))
        echo ""
        echo "[$current/$total_workflows] Processing: $workflow"
        
        if run_single_workflow "$workflow"; then
            successful=$((successful + 1))
        else
            failed=$((failed + 1))
        fi
        
        # Sequential mode: wait between workflows
        if [[ "$EXECUTION_MODE" == "sequential" && "$current" -lt "$total_workflows" ]]; then
            echo "   ⏸️ Sequential mode: waiting 30s before next workflow..."
            sleep 30
        fi
        
        # Show status every 3 workflows in parallel mode
        if [[ "$EXECUTION_MODE" == "parallel" && $((current % 3)) -eq 0 ]]; then
            show_status
        fi
    done
    
    echo ""
    echo "🏁 CYCLE COMPLETE"
    echo "================="
    echo "✅ Successful: $successful"
    echo "❌ Failed: $failed"
    echo "📊 Total: $total_workflows"
    show_status
}

# Function to list available workflows
list_workflows() {
    echo "📋 AVAILABLE WORKFLOWS"
    echo "====================="
    local count=1
    for workflow in "${!WORKFLOWS[@]}"; do
        local params="${WORKFLOWS[$workflow]}"
        printf "%2d. %-30s | %s\n" "$count" "$workflow" "$params"
        count=$((count + 1))
    done
    echo ""
}

# Function to run consumer workflows (triggered by producers)
run_consumer_cycle() {
    echo "🔄 RUNNING CONSUMER WORKFLOWS"
    echo "============================="
    echo ""
    
    # Generate action ID for this cycle
    local action_id="cycle-$(date +%s)-$$"
    echo "🆔 Cycle Action ID: $action_id"
    echo ""
    
    # Run async-consumer with generated action_id
    echo "🔥 Triggering async-consumer.yml"
    if gh workflow run async-consumer.yml --field action_id="$action_id" --field skip_circuit_breaker=false; then
        echo "   ✅ Consumer triggered with action_id: $action_id"
        
        if [[ "$MONITOR_MODE" == "true" ]]; then
            wait_for_completion "async-consumer.yml" 240
        fi
    else
        echo "   ❌ Failed to trigger consumer"
    fi
}

# Parse command line arguments
EXECUTION_MODE="parallel"  # parallel or sequential
MONITOR_MODE="false"       # true or false
WORKFLOW_FILTER=""         # specific workflow to run
ACTION=""                  # what action to perform

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--monitor)
            MONITOR_MODE="true"
            shift
            ;;
        -s|--sequential)
            EXECUTION_MODE="sequential"
            shift
            ;;
        -w|--workflow)
            WORKFLOW_FILTER="$2"
            shift 2
            ;;
        -l|--list)
            ACTION="list"
            shift
            ;;
        -c|--consumer)
            ACTION="consumer"
            shift
            ;;
        --status)
            ACTION="status"
            shift
            ;;
        --cleanup)
            ACTION="cleanup"
            shift
            ;;
        -h|--help)
            ACTION="help"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Execute based on action
case "$ACTION" in
    "list")
        list_workflows
        exit 0
        ;;
    "status")
        show_status
        exit 0
        ;;
    "consumer")
        run_consumer_cycle
        exit 0
        ;;
    "cleanup")
        echo "🗑️ Cleaning up workflow runs..."
        ./scripts/cleanup-all-runs.sh
        exit 0
        ;;
    "help")
        echo "WORKFLOW CYCLE RUNNER - Usage"
        echo "============================="
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -l, --list       List all available workflows"
        echo "  -m, --monitor    Monitor workflow completion"
        echo "  -s, --sequential Run workflows sequentially (default: parallel)"
        echo "  -w, --workflow   Run specific workflow only"
        echo "  -c, --consumer   Run consumer workflows with generated action_id"
        echo "  --status         Show current workflow status"
        echo "  --cleanup        Clean up all workflow runs"
        echo "  -h, --help       Show this help"
        echo ""
        echo "Examples:"
        echo "  $0                          # Run all workflows in parallel"
        echo "  $0 -m -s                    # Run all sequentially with monitoring"
        echo "  $0 -w simple-test.yml       # Run specific workflow"
        echo "  $0 --status                 # Show current status"
        echo "  $0 --cleanup                # Clean up runs"
        echo ""
        exit 0
        ;;
esac

# Main execution
echo "🚀 Starting Workflow Cycle"
echo "Execution Mode: $EXECUTION_MODE"
echo "Monitor Mode: $MONITOR_MODE"
echo ""

if [[ -n "$WORKFLOW_FILTER" ]]; then
    if [[ -n "${WORKFLOWS[$WORKFLOW_FILTER]}" ]]; then
        echo "🎯 Running single workflow: $WORKFLOW_FILTER"
        run_single_workflow "$WORKFLOW_FILTER"
    else
        echo "❌ Workflow not found: $WORKFLOW_FILTER"
        echo "Available workflows:"
        list_workflows
        exit 1
    fi
else
    # Show what we're about to do
    echo "📋 Will run ${#WORKFLOWS[@]} workflows:"
    list_workflows
    
    read -p "🤔 Continue with full cycle? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_full_cycle
    else
        echo "❌ Cancelled by user"
        exit 0
    fi
fi

echo ""
echo "✅ Workflow cycle runner completed!"