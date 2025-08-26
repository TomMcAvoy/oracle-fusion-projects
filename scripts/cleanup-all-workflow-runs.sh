#!/bin/bash
# GitHub Actions Workflow Run Cleanup Utility
# Uses GitHub REST API to cancel and delete all workflow runs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🗑️ GITHUB ACTIONS WORKFLOW RUN CLEANUP"
echo "======================================="

# Check if token file exists
TOKEN_FILE="$PROJECT_ROOT/.secrets/.token"
if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "❌ Token file not found: $TOKEN_FILE"
    echo "Please create your GitHub Personal Access Token first."
    exit 1
fi

# Load token
echo "🔐 Loading GitHub PAT..."
TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r')
if [[ -z "$TOKEN" ]]; then
    echo "❌ Token file is empty"
    exit 1
fi

# Configuration
REPO_NAME="${GITHUB_REPOSITORY:-TomMcAvoy/oracle-fusion-projects}"
echo "✅ Token loaded - Repository: $REPO_NAME"
echo ""

# Function to get workflow runs
get_workflow_runs() {
    local page=${1:-1}
    local per_page=${2:-50}
    curl -s -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/$REPO_NAME/actions/runs?per_page=$per_page&page=$page"
}

# Function to cancel a workflow run
cancel_workflow_run() {
    local run_id=$1
    local response_code=$(curl -s -w "%{http_code}" -X POST -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/$REPO_NAME/actions/runs/$run_id/cancel")
    echo "$response_code"
}

# Function to delete a workflow run
delete_workflow_run() {
    local run_id=$1
    local response_code=$(curl -s -w "%{http_code}" -X DELETE -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/$REPO_NAME/actions/runs/$run_id")
    echo "$response_code"
}

# Step 1: Get all workflow runs
echo "🔍 Step 1: Getting all workflow runs via API..."
get_workflow_runs 1 100 | jq -r '.workflow_runs[] | "\(.id) \(.status) \(.conclusion // "null") \(.workflow_name)"' | head -20

echo ""
read -p "Continue with cleanup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Step 2: Cancel all in-progress runs
echo ""
echo "🛑 Step 2: Cancelling all in_progress runs via API..."
IN_PROGRESS_RUNS=$(get_workflow_runs 1 100 | jq -r '.workflow_runs[] | select(.status == "in_progress") | .id')

if [[ -n "$IN_PROGRESS_RUNS" ]]; then
    echo "$IN_PROGRESS_RUNS" | while read -r run_id; do
        if [[ -n "$run_id" ]]; then
            echo "Cancelling run: $run_id"
            response=$(cancel_workflow_run "$run_id")
            if [[ "$response" == "202" ]]; then
                echo " ✅ Cancelled"
            else
                echo " ❌ Failed (HTTP: $response)"
            fi
        fi
    done
    echo "⏳ Waiting 10 seconds for cancellations..."
    sleep 10
else
    echo "No in-progress runs found."
fi

# Step 3: Delete all runs (multiple pages)
echo ""
echo "🗑️ Step 3: Deleting ALL runs via API..."

DELETED_COUNT=0
PAGE=1
MAX_PAGES=10

while [[ $PAGE -le $MAX_PAGES ]]; do
    echo "Processing page $PAGE..."
    
    RUNS=$(get_workflow_runs $PAGE 100 | jq -r '.workflow_runs[] | .id')
    
    if [[ -z "$RUNS" ]]; then
        echo "No more runs found on page $PAGE"
        break
    fi
    
    echo "$RUNS" | while read -r run_id; do
        if [[ -n "$run_id" ]]; then
            echo "Deleting run: $run_id"
            response=$(delete_workflow_run "$run_id")
            if [[ "$response" == "204" ]]; then
                echo " ✅ Deleted"
                ((DELETED_COUNT++))
            else
                echo " ❌ Failed (HTTP: $response)"
            fi
            sleep 0.3  # Rate limiting
        fi
    done
    
    ((PAGE++))
done

# Final verification
echo ""
echo "🔍 Final verification - checking for remaining runs..."
REMAINING_RUNS=$(get_workflow_runs 1 10 | jq '.workflow_runs | length')

echo ""
echo "📊 CLEANUP RESULTS:"
echo "=================="
echo "🗑️ Processed up to $((PAGE-1)) pages"
echo "📋 Remaining runs: $REMAINING_RUNS"

if [[ "$REMAINING_RUNS" == "0" ]]; then
    echo "🎉 SUCCESS: ALL WORKFLOW RUNS DELETED!"
    echo "✅ Repository workflow history is clean"
else
    echo "⚠️ Some runs may remain. You can run this script again."
    echo "📋 Remaining runs:"
    get_workflow_runs 1 10 | jq -r '.workflow_runs[] | "\(.id) \(.status) \(.workflow_name)"'
fi

echo ""
echo "✅ Cleanup utility completed!"