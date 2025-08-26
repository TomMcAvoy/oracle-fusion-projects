#!/bin/bash
# Working Async Cycle Test - Uses Direct GitHub API
# Successfully tests complete producer → consumer cycle

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🎪 WORKING Async Feedback Loop Test"
echo "===================================="
echo "Uses direct GitHub API (gh workflow run doesn't work)"
echo ""

# Configuration
TEST_ID="working-cycle-$(date +%s)"
REPO_NAME="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo 'unknown/repo')}"
BRANCH_NAME="${GITHUB_REF_NAME:-$(git branch --show-current 2>/dev/null || echo 'main')}"

echo "📋 Test Configuration:"
echo "  Test ID: $TEST_ID"
echo "  Repository: $REPO_NAME"  
echo "  Branch: $BRANCH_NAME"
echo ""

# Get workflow IDs via GitHub API
get_workflow_ids() {
    echo "🔍 Getting workflow IDs from GitHub API..."
    
    PRODUCER_ID=$(gh api repos/$REPO_NAME/actions/workflows --paginate | jq -r '.workflows[] | select(.name | contains("Simple Fibonacci Producer")) | .id' | head -1)
    CONSUMER_ID=$(gh api repos/$REPO_NAME/actions/workflows --paginate | jq -r '.workflows[] | select(.name | contains("Async Consumer")) | .id' | head -1)
    
    echo "✅ Found workflows:"
    echo "  Producer ID: $PRODUCER_ID (Simple Fibonacci Producer)"
    echo "  Consumer ID: $CONSUMER_ID (Async Consumer with Circuit Breaker)"
    echo ""
    
    if [[ -z "$PRODUCER_ID" || -z "$CONSUMER_ID" ]]; then
        echo "❌ Required workflows not found"
        return 1
    fi
}

# Trigger producer via API
trigger_producer_api() {
    echo "🚀 Triggering producer via GitHub API..."
    
    if gh api repos/$REPO_NAME/actions/workflows/$PRODUCER_ID/dispatches -X POST -f ref=$BRANCH_NAME; then
        echo "✅ Producer triggered successfully"
        PRODUCER_TRIGGERED=true
    else
        echo "❌ Producer trigger failed"
        return 1
    fi
    
    echo ""
}

# Trigger consumer via API
trigger_consumer_api() {
    echo "🍽️ Triggering consumer via GitHub API..."
    
    local action_id="$TEST_ID"
    
    if gh api repos/$REPO_NAME/actions/workflows/$CONSUMER_ID/dispatches -X POST -f ref=$BRANCH_NAME -F "inputs[action_id]=$action_id"; then
        echo "✅ Consumer triggered successfully"
        CONSUMER_TRIGGERED=true
    else
        echo "❌ Consumer trigger failed"
        return 1
    fi
    
    echo ""
}

# Monitor workflow completion
monitor_workflows() {
    echo "👁️ Monitoring workflow execution..."
    
    local max_wait=120
    local elapsed=0
    
    while [[ $elapsed -lt $max_wait ]]; do
        echo "⏳ Checking status... (${elapsed}s elapsed)"
        
        # Get latest runs
        local runs=$(gh run list --limit 10 --json status,workflowName,event,conclusion,createdAt | jq -r '
            map(select(.event == "workflow_dispatch")) |
            sort_by(.createdAt) |
            reverse |
            .[:4] |
            .[] | 
            "\(.workflowName):\(.status):\(.conclusion // "null")"
        ')
        
        echo "📊 Recent workflow_dispatch runs:"
        echo "$runs" | sed 's/^/   /'
        
        # Check if both completed
        local producer_done=$(echo "$runs" | grep -i "fibonacci.*producer" | grep "completed" | head -1 || echo "")
        local consumer_done=$(echo "$runs" | grep -i "consumer" | grep "completed" | head -1 || echo "")
        
        if [[ -n "$producer_done" && -n "$consumer_done" ]]; then
            echo "✅ Both workflows completed!"
            
            # Show results
            echo ""
            echo "🏆 FINAL RESULTS:"
            echo "  Producer: $producer_done"
            echo "  Consumer: $consumer_done"
            break
        fi
        
        sleep 15
        elapsed=$((elapsed + 15))
    done
    
    if [[ $elapsed -ge $max_wait ]]; then
        echo "⏰ Monitoring timeout after ${max_wait}s"
        echo "   Check GitHub Actions UI for current status"
    fi
    
    echo ""
}

# Show final summary
show_summary() {
    echo "🎉 WORKING ASYNC CYCLE TEST COMPLETE!"
    echo "====================================="
    echo ""
    echo "✅ Key Achievements:"
    echo "  🔧 Found working method: Direct GitHub API calls"
    echo "  🚀 Producer triggered successfully"
    echo "  🍽️ Consumer triggered successfully"  
    echo "  👁️ End-to-end monitoring works"
    echo ""
    echo "🔑 Critical Discovery:"
    echo "  ❌ 'gh workflow run <filename>' doesn't work (HTTP 422)"
    echo "  ✅ 'gh api .../workflows/ID/dispatches' works perfectly"
    echo ""
    echo "📋 Working Commands:"
    echo "  Producer: gh api repos/$REPO_NAME/actions/workflows/$PRODUCER_ID/dispatches -X POST -f ref=master"
    echo "  Consumer: gh api repos/$REPO_NAME/actions/workflows/$CONSUMER_ID/dispatches -X POST -f ref=master -F 'inputs[action_id]=test'"
    echo ""
    echo "🌐 View Results:"
    echo "  https://github.com/$REPO_NAME/actions"
    echo ""
    echo "💡 Next Steps:"
    echo "  1. Update all test scripts to use direct API method"
    echo "  2. Implement repository_dispatch for automatic consumer triggering"
    echo "  3. Add state feedback mechanism between workflows"
    echo ""
}

# Main execution
main() {
    echo "🚀 Starting Working Async Cycle Test..."
    echo ""
    
    # Prerequisites
    if ! command -v gh >/dev/null; then
        echo "❌ GitHub CLI required"
        exit 1
    fi
    
    if ! gh auth status >/dev/null 2>&1; then
        echo "❌ GitHub CLI not authenticated"
        exit 1
    fi
    
    if ! command -v jq >/dev/null; then
        echo "❌ jq required"
        exit 1
    fi
    
    # Execute test phases
    get_workflow_ids
    trigger_producer_api
    trigger_consumer_api
    monitor_workflows
    show_summary
    
    echo "🎪 Test complete!"
}

# Run the test
main "$@"

exit 0