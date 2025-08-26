#!/bin/bash

# Comprehensive GitHub Actions Workflow Cleanup via API
# Cancels and deletes ALL workflow runs

set -e

echo "🧹 GITHUB ACTIONS COMPLETE CLEANUP"
echo "==================================="
echo ""

# Check GitHub CLI authentication
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Error: GitHub CLI not authenticated"
    echo "   Run: gh auth login"
    exit 1
fi

# Get repository info
REPO=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')
echo "🎯 Repository: $REPO"
echo ""

echo "📊 STEP 1: INVENTORY - What we have"
echo "===================================="

# Get total count
TOTAL_RUNS=$(gh api repos/$REPO/actions/runs --paginate | jq '.workflow_runs | length')
echo "📋 Total workflow runs found: $TOTAL_RUNS"

# Show recent runs
echo ""
echo "📋 Recent runs (last 10):"
gh run list --limit 10 --json databaseId,status,workflowName,createdAt,conclusion | \
  jq -r '.[] | "  \(.databaseId) | \(.status) | \(.conclusion // "pending") | \(.workflowName)"'

echo ""
echo "🛑 STEP 2: CANCEL ALL RUNNING WORKFLOWS"
echo "======================================="

# Cancel all in-progress runs
RUNNING_RUNS=$(gh api repos/$REPO/actions/runs -q '.workflow_runs[] | select(.status == "in_progress") | .id')

if [[ -n "$RUNNING_RUNS" ]]; then
    echo "🔄 Found running workflows. Cancelling..."
    echo "$RUNNING_RUNS" | while read -r run_id; do
        if [[ -n "$run_id" ]]; then
            echo "  Cancelling run ID: $run_id"
            if gh api repos/$REPO/actions/runs/$run_id/cancel -X POST >/dev/null 2>&1; then
                echo "    ✅ Cancelled"
            else
                echo "    ⚠️ Could not cancel (may already be finished)"
            fi
        fi
    done
    echo "⏳ Waiting 5 seconds for cancellations to process..."
    sleep 5
else
    echo "✅ No running workflows found"
fi

echo ""
echo "🗑️ STEP 3: DELETE ALL WORKFLOW RUNS"
echo "===================================="

# Function to delete workflow runs in batches
delete_runs_batch() {
    local page=$1
    echo "Processing batch $page..."
    
    # Get run IDs for this page
    local run_ids=$(gh api "repos/$REPO/actions/runs?per_page=100&page=$page" -q '.workflow_runs[].id')
    
    if [[ -z "$run_ids" ]]; then
        echo "  No more runs found"
        return 1
    fi
    
    local deleted_count=0
    echo "$run_ids" | while read -r run_id; do
        if [[ -n "$run_id" ]]; then
            printf "  Deleting run $run_id... "
            if gh api repos/$REPO/actions/runs/$run_id -X DELETE >/dev/null 2>&1; then
                echo "✅"
                ((deleted_count++))
            else
                echo "❌ (may not be deletable yet)"
            fi
            sleep 0.2  # Rate limiting
        fi
    done
    
    return 0
}

# Delete runs in batches
echo "🔄 Starting batch deletion..."
page=1
max_pages=20

while [[ $page -le $max_pages ]]; do
    if ! delete_runs_batch $page; then
        break
    fi
    ((page++))
done

echo ""
echo "🔍 STEP 4: VERIFICATION"
echo "======================="

# Check remaining runs
sleep 2
REMAINING_RUNS=$(gh api repos/$REPO/actions/runs -q '.workflow_runs | length')
echo "📊 Remaining workflow runs: $REMAINING_RUNS"

if [[ "$REMAINING_RUNS" == "0" ]]; then
    echo ""
    echo "🎉 SUCCESS! ALL WORKFLOW RUNS DELETED!"
    echo "✅ Your repository workflow history is completely clean"
else
    echo ""
    echo "⚠️ Some runs remain (may be too recent to delete immediately)"
    echo "📋 Remaining runs:"
    gh run list --limit 5 --json databaseId,status,workflowName,createdAt | \
      jq -r '.[] | "  \(.databaseId) | \(.status) | \(.workflowName)"'
    echo ""
    echo "💡 You can run this script again in a few minutes to clean remaining runs"
fi

echo ""
echo "📊 CLEANUP SUMMARY:"
echo "==================="
echo "📋 Original total: $TOTAL_RUNS runs"
echo "📋 Remaining: $REMAINING_RUNS runs"
echo "✅ Deleted: $((TOTAL_RUNS - REMAINING_RUNS)) runs"
echo ""
echo "🎯 Cleanup completed!"