#!/bin/bash
# Cancel specific or all in-progress workflow runs via GitHub REST API

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Cancel GitHub Actions workflow runs via REST API"
    echo ""
    echo "Options:"
    echo "  --all, -a          Cancel all in-progress runs"
    echo "  --run-id ID        Cancel specific run by ID"
    echo "  --workflow NAME    Cancel runs for specific workflow"
    echo "  --help, -h         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --all                           # Cancel all in-progress runs"
    echo "  $0 --run-id 12345678              # Cancel specific run"
    echo "  $0 --workflow 'CI-CD Pipeline'    # Cancel specific workflow runs"
}

# Default options
CANCEL_ALL=false
RUN_ID=""
WORKFLOW_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all|-a)
            CANCEL_ALL=true
            shift
            ;;
        --run-id)
            RUN_ID="$2"
            shift 2
            ;;
        --workflow)
            WORKFLOW_NAME="$2"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

echo "🛑 CANCEL GITHUB WORKFLOW RUNS"
echo "==============================="

# Check if token file exists
TOKEN_FILE="$PROJECT_ROOT/.secrets/.token"
if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "❌ Token file not found: $TOKEN_FILE"
    exit 1
fi

# Load token
TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r')
REPO_NAME="${GITHUB_REPOSITORY:-TomMcAvoy/oracle-fusion-projects}"

echo "🔐 Repository: $REPO_NAME"

# Function to cancel a workflow run
cancel_run() {
    local run_id=$1
    local workflow_name=${2:-"Unknown"}
    
    echo "Cancelling run: $run_id ($workflow_name)"
    response_code=$(curl -s -w "%{http_code}" -X POST -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/$REPO_NAME/actions/runs/$run_id/cancel")
    
    if [[ "$response_code" == "202" ]]; then
        echo " ✅ Cancelled successfully"
    else
        echo " ❌ Failed (HTTP: $response_code)"
    fi
}

if [[ "$CANCEL_ALL" == true ]]; then
    echo ""
    echo "🔍 Finding all in-progress runs..."
    
    IN_PROGRESS_RUNS=$(curl -s -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/$REPO_NAME/actions/runs?status=in_progress&per_page=100" \
        | jq -r '.workflow_runs[] | "\(.id) \(.workflow_name)"')
    
    if [[ -n "$IN_PROGRESS_RUNS" ]]; then
        echo "$IN_PROGRESS_RUNS" | while IFS=' ' read -r run_id workflow_name; do
            if [[ -n "$run_id" ]]; then
                cancel_run "$run_id" "$workflow_name"
            fi
        done
    else
        echo "✅ No in-progress runs found"
    fi
    
elif [[ -n "$RUN_ID" ]]; then
    echo ""
    echo "🎯 Cancelling specific run: $RUN_ID"
    cancel_run "$RUN_ID"
    
elif [[ -n "$WORKFLOW_NAME" ]]; then
    echo ""
    echo "🔍 Finding in-progress runs for workflow: $WORKFLOW_NAME"
    
    WORKFLOW_RUNS=$(curl -s -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/$REPO_NAME/actions/runs?status=in_progress&per_page=100" \
        | jq -r --arg workflow "$WORKFLOW_NAME" \
        '.workflow_runs[] | select(.workflow_name == $workflow) | "\(.id) \(.workflow_name)"')
    
    if [[ -n "$WORKFLOW_RUNS" ]]; then
        echo "$WORKFLOW_RUNS" | while IFS=' ' read -r run_id workflow_name; do
            if [[ -n "$run_id" ]]; then
                cancel_run "$run_id" "$workflow_name"
            fi
        done
    else
        echo "✅ No in-progress runs found for workflow: $WORKFLOW_NAME"
    fi
    
else
    echo "❌ No action specified. Use --all, --run-id, or --workflow"
    show_usage
    exit 1
fi

echo ""
echo "✅ Cancel operation completed!"