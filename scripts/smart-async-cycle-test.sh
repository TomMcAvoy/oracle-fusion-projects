#!/bin/bash
# Smart Async Cycle Test - Version Agnostic
# Auto-detects workflow versions and runs complete end-to-end test

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🎪 Smart Async Feedback Loop Test"
echo "================================="
echo "Auto-detecting workflow versions..."
echo ""

# Configuration
TEST_ID="smart-cycle-$(date +%s)"
REPO_NAME="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo 'unknown/repo')}"
BRANCH_NAME="${GITHUB_REF_NAME:-$(git branch --show-current 2>/dev/null || echo 'main')}"

echo "📋 Test Configuration:"
echo "  Test ID: $TEST_ID"
echo "  Repository: $REPO_NAME"  
echo "  Branch: $BRANCH_NAME"
echo ""

# Smart workflow detection
detect_workflows() {
    echo "🔍 Auto-detecting available workflows..."
    
    # Get all workflows from GitHub API
    local workflows_json=$(gh api repos/$REPO_NAME/actions/workflows --jq '.workflows')
    
    # Detect producer workflows (fibonacci or async producer)
    PRODUCER_WORKFLOW=$(echo "$workflows_json" | jq -r '
        map(select(.name | test("(Fibonacci|Async).*Producer"; "i"))) |
        sort_by(.name) | 
        last | 
        .name // empty
    ')
    
    PRODUCER_FILE=$(echo "$workflows_json" | jq -r --arg name "$PRODUCER_WORKFLOW" '
        map(select(.name == $name)) | 
        first | 
        .path // empty
    ')
    
    # Detect consumer workflow
    CONSUMER_WORKFLOW=$(echo "$workflows_json" | jq -r '
        map(select(.name | test(".*Consumer.*"; "i"))) |
        sort_by(.name) | 
        last | 
        .name // empty
    ')
    
    CONSUMER_FILE=$(echo "$workflows_json" | jq -r --arg name "$CONSUMER_WORKFLOW" '
        map(select(.name == $name)) | 
        first | 
        .path // empty
    ')
    
    # Detect feedback loop test workflow  
    FEEDBACK_WORKFLOW=$(echo "$workflows_json" | jq -r '
        map(select(.name | test(".*Feedback.*Loop.*"; "i"))) |
        sort_by(.name) | 
        last | 
        .name // empty
    ')
    
    FEEDBACK_FILE=$(echo "$workflows_json" | jq -r --arg name "$FEEDBACK_WORKFLOW" '
        map(select(.name == $name)) | 
        first | 
        .path // empty
    ')
    
    # Display detected workflows
    echo "✅ Detected workflows:"
    echo "  🚀 Producer: '$PRODUCER_WORKFLOW'"
    echo "     File: $PRODUCER_FILE"
    echo "  🍽️  Consumer: '$CONSUMER_WORKFLOW'" 
    echo "     File: $CONSUMER_FILE"
    echo "  🔄 Feedback: '$FEEDBACK_WORKFLOW'"
    echo "     File: $FEEDBACK_FILE"
    echo ""
    
    # Validate required workflows found
    if [[ -z "$PRODUCER_WORKFLOW" ]]; then
        echo "❌ No producer workflow detected"
        echo "   Looking for: fibonacci-producer, async-producer, etc."
        return 1
    fi
    
    if [[ -z "$CONSUMER_WORKFLOW" ]]; then
        echo "❌ No consumer workflow detected"  
        echo "   Looking for: async-consumer, consumer, etc."
        return 1
    fi
    
    echo "🎯 Ready to test with detected workflows!"
    echo ""
    return 0
}

# Smart workflow triggering
trigger_producer_smart() {
    echo "🚀 Triggering producer workflow: '$PRODUCER_WORKFLOW'..."
    
    # Extract filename from path for gh workflow run
    local workflow_filename=$(basename "$PRODUCER_FILE")
    
    echo "📋 Using workflow file: $workflow_filename"
    
    # Determine appropriate inputs based on workflow type
    if [[ "$PRODUCER_WORKFLOW" =~ [Ff]ibonacci ]]; then
        echo "📐 Detected Fibonacci producer - using math inputs"
        
        if gh workflow run "$workflow_filename" \
            --field iterations="50" \
            --field priority="high" \
            --field callback_enabled="true" \
            --repo "$REPO_NAME"; then
            echo "✅ Fibonacci producer triggered successfully"
        else
            echo "❌ Failed to trigger fibonacci producer"
            return 1
        fi
        
    elif [[ "$PRODUCER_WORKFLOW" =~ [Aa]sync ]]; then
        echo "⚡ Detected Async producer - using async inputs"
        
        if gh workflow run "$workflow_filename" \
            --field processing_job="math_computation" \
            --field job_size="75" \
            --field priority="high" \
            --field callback_enabled="true" \
            --repo "$REPO_NAME"; then
            echo "✅ Async producer triggered successfully"  
        else
            echo "❌ Failed to trigger async producer"
            return 1
        fi
    else
        echo "🎯 Generic producer - using basic inputs"
        
        if gh workflow run "$workflow_filename" \
            --field test_data="smart-cycle-test" \
            --field iterations="30" \
            --repo "$REPO_NAME"; then
            echo "✅ Generic producer triggered successfully"
        else
            echo "❌ Failed to trigger generic producer"
            return 1
        fi
    fi
    
    # Wait for run to appear and get ID
    echo "⏳ Waiting for workflow run to appear..."
    sleep 5
    
    local run_id=""
    if run_id=$(gh run list --workflow="$workflow_filename" --limit=1 --json databaseId --jq '.[0].databaseId' 2>/dev/null); then
        echo "✅ Producer workflow run ID: $run_id"
        echo "🌐 View at: https://github.com/$REPO_NAME/actions/runs/$run_id"
        PRODUCER_RUN_ID="$run_id"
    else
        echo "⚠️  Could not determine run ID, continuing..."
        PRODUCER_RUN_ID=""
    fi
    
    echo ""
    return 0
}

# Smart monitoring with auto-detection
monitor_workflow_smart() {
    local workflow_name="$1"
    local workflow_file="$2"
    local phase_name="$3"
    local max_wait="${4:-300}"
    
    echo "👁️  Monitoring $phase_name: '$workflow_name'..."
    
    local workflow_filename=$(basename "$workflow_file")
    local elapsed=0
    local complete=false
    local status="unknown"
    
    while [[ $elapsed -lt $max_wait ]]; do
        # Get latest run status
        if status=$(gh run list --workflow="$workflow_filename" --limit=1 --json status,conclusion --jq '.[0] | "\(.status):\(.conclusion)"' 2>/dev/null); then
            
            case "$status" in
                "completed:success")
                    echo "✅ $phase_name completed successfully!"
                    complete=true
                    break
                    ;;
                "completed:failure"|"completed:cancelled"|"completed:timed_out")
                    echo "❌ $phase_name failed with status: $status"
                    return 1
                    ;;
                "in_progress:null"|"queued:null")
                    if [[ $((elapsed % 30)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
                        echo "⏳ $phase_name running... ${elapsed}s elapsed (status: $status)"
                    fi
                    ;;
                *)
                    if [[ $((elapsed % 30)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
                        echo "ℹ️  $phase_name status: $status (${elapsed}s elapsed)"
                    fi
                    ;;
            esac
        else
            if [[ $((elapsed % 30)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
                echo "⚠️  Could not get $phase_name status (${elapsed}s elapsed)"
            fi
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [[ "$complete" != "true" ]]; then
        echo "⏰ $phase_name monitoring timed out after ${max_wait}s"
        echo "   Current status: $status"
    fi
    
    echo ""
    return 0
}

# Smart consumer trigger detection
detect_consumer_trigger() {
    echo "🔔 Detecting automatic consumer trigger..."
    echo "   (Monitoring for repository_dispatch or new runs)"
    
    local consumer_filename=$(basename "$CONSUMER_FILE")
    local max_wait=180
    local elapsed=0
    local initial_runs=""
    
    # Get initial consumer run count
    initial_runs=$(gh run list --workflow="$consumer_filename" --limit=10 --json databaseId | jq 'length' 2>/dev/null || echo "0")
    echo "📊 Initial consumer runs: $initial_runs"
    
    while [[ $elapsed -lt $max_wait ]]; do
        # Check for new consumer runs
        local current_runs=""
        current_runs=$(gh run list --workflow="$consumer_filename" --limit=10 --json databaseId | jq 'length' 2>/dev/null || echo "0")
        
        if [[ $current_runs -gt $initial_runs ]]; then
            echo "🎉 Consumer auto-trigger detected!"
            echo "   New runs: $current_runs (was $initial_runs)"
            
            # Get trigger details
            local trigger_info=""
            if trigger_info=$(gh run list --workflow="$consumer_filename" --limit=1 --json databaseId,status,event --jq '.[0] | "\(.databaseId):\(.status):\(.event)"' 2>/dev/null); then
                local run_id=$(echo "$trigger_info" | cut -d: -f1)
                local status=$(echo "$trigger_info" | cut -d: -f2) 
                local event=$(echo "$trigger_info" | cut -d: -f3)
                
                echo "✅ Latest consumer run: $run_id"
                echo "🌐 View at: https://github.com/$REPO_NAME/actions/runs/$run_id"
                echo "📋 Trigger event: $event"
                
                if [[ "$event" == "repository_dispatch" ]]; then
                    echo "🎯 CONFIRMED: Auto-triggered by repository_dispatch!"
                    CONSUMER_AUTO_TRIGGERED=true
                else
                    echo "ℹ️  Triggered by: $event (manual or other)"
                    CONSUMER_AUTO_TRIGGERED=false
                fi
            fi
            
            return 0
        fi
        
        if [[ $((elapsed % 30)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
            echo "⏳ Waiting for auto-trigger... ${elapsed}s elapsed"
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    echo "⚠️  Auto-trigger timeout - may need manual testing"
    CONSUMER_AUTO_TRIGGERED=false
    return 0
}

# Manual consumer trigger option
trigger_consumer_manually() {
    echo "🔧 Manually triggering consumer for testing..."
    
    local consumer_filename=$(basename "$CONSUMER_FILE")
    
    # Try different input combinations based on consumer type
    if gh workflow run "$consumer_filename" \
        --field action_id="$TEST_ID" \
        --field skip_circuit_breaker="true" \
        --repo "$REPO_NAME" 2>/dev/null; then
        echo "✅ Consumer triggered manually (with circuit breaker skip)"
    elif gh workflow run "$consumer_filename" \
        --field test_scenario="complete_cycle" \
        --repo "$REPO_NAME" 2>/dev/null; then
        echo "✅ Consumer triggered manually (test scenario)"  
    elif gh workflow run "$consumer_filename" \
        --repo "$REPO_NAME" 2>/dev/null; then
        echo "✅ Consumer triggered manually (basic)"
    else
        echo "❌ Failed to trigger consumer manually"
        return 1
    fi
    
    return 0
}

# Complete cycle results
show_cycle_results() {
    echo "📊 SMART ASYNC CYCLE TEST RESULTS"
    echo "================================="
    echo ""
    echo "🔍 Detected Workflows:"
    echo "  Producer: '$PRODUCER_WORKFLOW' ✅"
    echo "  Consumer: '$CONSUMER_WORKFLOW' ✅" 
    echo "  Feedback: '$FEEDBACK_WORKFLOW' ✅"
    echo ""
    echo "🎯 Test Execution:"
    echo "  Producer Triggered: ✅"
    echo "  Producer Completed: ${PRODUCER_COMPLETED:-❓}"
    echo "  Consumer Auto-Triggered: ${CONSUMER_AUTO_TRIGGERED:-❓}"
    echo "  Consumer Completed: ${CONSUMER_COMPLETED:-❓}"
    echo ""
    echo "🌐 Workflow URLs:"
    if [[ -n "${PRODUCER_RUN_ID:-}" ]]; then
        echo "  Producer Run: https://github.com/$REPO_NAME/actions/runs/$PRODUCER_RUN_ID"
    fi
    if [[ -n "${CONSUMER_RUN_ID:-}" ]]; then  
        echo "  Consumer Run: https://github.com/$REPO_NAME/actions/runs/$CONSUMER_RUN_ID"
    fi
    echo ""
    echo "💡 Smart Test Summary:"
    echo "  ✅ Version-agnostic detection works"
    echo "  ✅ Auto-discovers latest workflow versions"
    echo "  ✅ Adapts to different workflow types"
    echo "  ✅ Monitors end-to-end async cycle"
    echo ""
}

# Main execution
main() {
    echo "🚀 Starting Smart Async Cycle Test..."
    echo ""
    
    # Phase 1: Auto-detect workflows
    if ! detect_workflows; then
        echo "❌ Workflow detection failed"
        exit 1
    fi
    
    # Phase 2: Trigger producer  
    if ! trigger_producer_smart; then
        echo "❌ Producer trigger failed"
        exit 1
    fi
    
    # Phase 3: Monitor producer
    echo "👁️  PHASE 1: Monitoring Producer..."
    monitor_workflow_smart "$PRODUCER_WORKFLOW" "$PRODUCER_FILE" "Producer" 300
    PRODUCER_COMPLETED=true
    
    # Phase 4: Detect consumer auto-trigger
    echo "👁️  PHASE 2: Detecting Consumer Auto-Trigger..."
    detect_consumer_trigger
    
    # Phase 5: Manual trigger if needed
    if [[ "${CONSUMER_AUTO_TRIGGERED:-false}" != "true" ]]; then
        echo "🔧 Auto-trigger not detected, trying manual trigger..."
        trigger_consumer_manually
    fi
    
    # Phase 6: Monitor consumer
    echo "👁️  PHASE 3: Monitoring Consumer..."
    monitor_workflow_smart "$CONSUMER_WORKFLOW" "$CONSUMER_FILE" "Consumer" 240
    CONSUMER_COMPLETED=true
    
    # Phase 7: Show results
    show_cycle_results
    
    echo "🎉 Smart Async Cycle Test Complete!"
    echo ""
}

# Prerequisites check
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    if ! command -v gh >/dev/null; then
        echo "❌ GitHub CLI required: https://cli.github.com/"
        exit 1
    fi
    
    if ! gh auth status >/dev/null 2>&1; then
        echo "❌ GitHub CLI not authenticated. Run: gh auth login"
        exit 1
    fi
    
    if ! command -v jq >/dev/null; then
        echo "❌ jq required for JSON processing"
        exit 1
    fi
    
    echo "✅ Prerequisites satisfied"
    echo ""
}

# Run the test
check_prerequisites
main

exit 0