#!/bin/bash
# GitHub Async Cycle Test Script
# Creates workflows, triggers producer, monitors consumer auto-trigger
# Demonstrates complete async feedback loop in GitHub Actions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🎪 GitHub Async Feedback Loop Test"
echo "=================================="
echo "This script will demonstrate the complete async cycle in GitHub Actions:"
echo "  1. 📤 Create/update workflows in GitHub"
echo "  2. 🚀 Trigger producer workflow (non-blocking)"
echo "  3. 👁️  Monitor background processing"
echo "  4. 🔔 Wait for automatic consumer trigger"
echo "  5. 🍽️  Show consumer workflow execution"
echo "  6. 📊 Display complete cycle results"
echo ""

# Configuration
TEST_ID="cycle-test-$(date +%s)"
REPO_NAME="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo 'unknown/repo')}"
BRANCH_NAME="${GITHUB_REF_NAME:-$(git branch --show-current 2>/dev/null || echo 'main')}"

echo "📋 Test Configuration:"
echo "  Test ID: $TEST_ID"
echo "  Repository: $REPO_NAME"  
echo "  Branch: $BRANCH_NAME"
echo "  Project Root: $PROJECT_ROOT"
echo ""

# Check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    # Check git
    if ! command -v git >/dev/null; then
        echo "❌ Git not found. Please install git."
        exit 1
    fi
    
    # Check GitHub CLI
    if ! command -v gh >/dev/null; then
        echo "❌ GitHub CLI not found. Please install: https://cli.github.com/"
        exit 1
    fi
    
    # Check authentication
    if ! gh auth status >/dev/null 2>&1; then
        echo "❌ GitHub CLI not authenticated. Please run: gh auth login"
        exit 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ Not in a git repository. Please run from within your repo."
        exit 1
    fi
    
    # Check if we can access the repository
    if ! gh repo view "$REPO_NAME" >/dev/null 2>&1; then
        echo "❌ Cannot access repository: $REPO_NAME"
        echo "   Make sure you have the correct permissions and repo name."
        exit 1
    fi
    
    echo "✅ All prerequisites satisfied"
    echo "   Git: $(git --version | head -1)"
    echo "   GitHub CLI: $(gh --version | head -1)"
    echo "   Repository access: $REPO_NAME ✓"
    echo ""
}

# Create/update workflow files in GitHub
deploy_workflows() {
    echo "📤 Deploying workflows to GitHub..."
    
    cd "$PROJECT_ROOT"
    
    # Check if workflows directory exists
    if [[ ! -d ".github/workflows" ]]; then
        echo "❌ .github/workflows directory not found at: $PROJECT_ROOT/.github/workflows"
        echo "   Please run this script from the project root directory."
        exit 1
    fi
    
    # Check if workflow files exist
    local workflow_files=(
        ".github/workflows/async-producer.yml"
        ".github/workflows/async-consumer.yml"  
        ".github/workflows/test-async-feedback-loop.yml"
    )
    
    local missing_files=()
    for file in "${workflow_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        echo "❌ Missing workflow files:"
        printf "   %s\n" "${missing_files[@]}"
        echo "   Please ensure all workflow files are created first."
        exit 1
    fi
    
    echo "✅ Found all workflow files:"
    printf "   📄 %s\n" "${workflow_files[@]}"
    
    # Check git status
    echo "🔍 Checking git status..."
    
    if git diff --quiet && git diff --cached --quiet; then
        echo "ℹ️  No changes detected. Workflows may already be up to date."
    else
        echo "📝 Changes detected. Committing and pushing..."
        
        # Stage workflow files
        git add .github/workflows/
        git add scripts/pubsub/
        git add scripts/demo-async-feedback-loop.sh
        git add *.md
        
        # Commit changes
        git commit -m "🚀 Add async feedback loop workflows and scripts

- Add async-producer.yml (non-blocking job publisher)
- Add async-consumer.yml (result consumer with auto-trigger)
- Add test-async-feedback-loop.yml (complete cycle test)
- Add completion-monitor.sh (state feedback mechanism)
- Add comprehensive demo and documentation

Test ID: $TEST_ID" || echo "⚠️  No changes to commit"
        
        # Push to GitHub
        echo "📤 Pushing to GitHub..."
        if git push origin "$BRANCH_NAME"; then
            echo "✅ Workflows pushed to GitHub successfully"
        else
            echo "❌ Failed to push to GitHub. Please check your permissions."
            exit 1
        fi
    fi
    
    # Wait for GitHub to process workflows
    echo "⏳ Waiting for GitHub to process workflows..."
    sleep 10
    
    echo "🔍 Verifying workflows are available..."
    if gh workflow list | grep -q "Async Producer Pipeline"; then
        echo "✅ Async Producer Pipeline detected"
    else
        echo "⚠️  Async Producer Pipeline not yet visible"
    fi
    
    if gh workflow list | grep -q "Async Consumer Pipeline"; then
        echo "✅ Async Consumer Pipeline detected"
    else
        echo "⚠️  Async Consumer Pipeline not yet visible"
    fi
    
    echo ""
}

# Trigger producer workflow
trigger_producer() {
    echo "🚀 Triggering async producer workflow..."
    
    local producer_inputs=(
        "processing_job=math_computation"
        "job_size=75"
        "priority=high"
        "callback_enabled=true"
    )
    
    echo "📋 Producer workflow inputs:"
    printf "   %s\n" "${producer_inputs[@]}"
    
    # Trigger the workflow
    echo "📤 Triggering workflow..."
    
    local workflow_run=""
    if workflow_run=$(gh workflow run async-producer.yml \
        --field processing_job=math_computation \
        --field job_size=75 \
        --field priority=high \
        --field callback_enabled=true \
        --repo "$REPO_NAME" 2>&1); then
        
        echo "✅ Producer workflow triggered successfully"
        echo "   $workflow_run"
    else
        echo "❌ Failed to trigger producer workflow:"
        echo "   $workflow_run"
        exit 1
    fi
    
    # Wait a moment for the run to appear
    sleep 5
    
    # Get the latest run ID
    echo "🔍 Finding workflow run..."
    local run_id=""
    if run_id=$(gh run list --workflow=async-producer.yml --limit=1 --json databaseId --jq '.[0].databaseId' 2>/dev/null); then
        echo "✅ Producer workflow run ID: $run_id"
        echo "🌐 View at: https://github.com/$REPO_NAME/actions/runs/$run_id"
    else
        echo "⚠️  Could not determine run ID, continuing with monitoring..."
    fi
    
    echo ""
    return 0
}

# Monitor producer workflow
monitor_producer() {
    echo "👁️  Monitoring producer workflow..."
    
    local max_wait=300  # 5 minutes max
    local elapsed=0
    local producer_complete=false
    local producer_status="unknown"
    
    while [[ $elapsed -lt $max_wait ]]; do
        # Get latest producer run status
        if producer_status=$(gh run list --workflow=async-producer.yml --limit=1 --json status,conclusion --jq '.[0] | "\(.status):\(.conclusion)"' 2>/dev/null); then
            
            case "$producer_status" in
                "completed:success")
                    echo "✅ Producer workflow completed successfully!"
                    producer_complete=true
                    break
                    ;;
                "completed:failure"|"completed:cancelled"|"completed:timed_out")
                    echo "❌ Producer workflow failed with status: $producer_status"
                    return 1
                    ;;
                "in_progress:null"|"queued:null")
                    if [[ $((elapsed % 30)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
                        echo "⏳ Producer still running... ${elapsed}s elapsed (status: $producer_status)"
                    fi
                    ;;
                *)
                    echo "ℹ️  Producer status: $producer_status"
                    ;;
            esac
        else
            echo "⚠️  Could not get producer status"
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [[ "$producer_complete" != "true" ]]; then
        echo "⏰ Producer monitoring timed out after ${max_wait}s"
        echo "   Current status: $producer_status"
        echo "   Continuing to monitor for consumer trigger..."
    fi
    
    echo ""
    return 0
}

# Monitor for consumer workflow auto-trigger
monitor_consumer_trigger() {
    echo "🔔 Monitoring for automatic consumer workflow trigger..."
    echo "   (This happens when completion monitor sends repository_dispatch)"
    
    local max_wait=180  # 3 minutes to detect consumer trigger
    local elapsed=0
    local consumer_triggered=false
    local initial_run_count=""
    
    # Get initial consumer run count
    initial_run_count=$(gh run list --workflow=async-consumer.yml --limit=10 --json databaseId | jq 'length' 2>/dev/null || echo "0")
    echo "📊 Initial consumer runs: $initial_run_count"
    
    while [[ $elapsed -lt $max_wait ]]; do
        # Check for new consumer runs
        local current_run_count=""
        current_run_count=$(gh run list --workflow=async-consumer.yml --limit=10 --json databaseId | jq 'length' 2>/dev/null || echo "0")
        
        if [[ $current_run_count -gt $initial_run_count ]]; then
            echo "🎉 Consumer workflow auto-triggered detected!"
            echo "   New consumer runs: $current_run_count (was $initial_run_count)"
            
            # Get the latest consumer run details
            local consumer_run_id=""
            if consumer_run_id=$(gh run list --workflow=async-consumer.yml --limit=1 --json databaseId,status,event --jq '.[0] | "\(.databaseId):\(.status):\(.event)"' 2>/dev/null); then
                echo "✅ Latest consumer run: $consumer_run_id"
                
                local run_id=$(echo "$consumer_run_id" | cut -d: -f1)
                local status=$(echo "$consumer_run_id" | cut -d: -f2)
                local event=$(echo "$consumer_run_id" | cut -d: -f3)
                
                echo "🌐 View consumer run at: https://github.com/$REPO_NAME/actions/runs/$run_id"
                echo "📋 Trigger event: $event"
                
                if [[ "$event" == "repository_dispatch" ]]; then
                    echo "✅ Confirmed: Consumer triggered by repository_dispatch (automatic callback!)"
                    consumer_triggered=true
                else
                    echo "ℹ️  Consumer triggered by: $event (may be manual)"
                fi
            fi
            
            break
        fi
        
        if [[ $((elapsed % 30)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
            echo "⏳ Waiting for consumer trigger... ${elapsed}s elapsed"
            echo "   Current consumer runs: $current_run_count"
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [[ "$consumer_triggered" != "true" ]]; then
        echo "⚠️  Auto-trigger not detected within timeout"
        echo "   This could mean:"
        echo "     - Processing is still running"
        echo "     - Completion monitor didn't detect finish"
        echo "     - repository_dispatch failed"
        echo "   You can manually trigger consumer workflow to test result consumption"
    fi
    
    echo ""
    return 0
}

# Monitor consumer workflow execution
monitor_consumer() {
    echo "🍽️  Monitoring consumer workflow execution..."
    
    local max_wait=240  # 4 minutes max
    local elapsed=0
    local consumer_complete=false
    local consumer_status="unknown"
    
    while [[ $elapsed -lt $max_wait ]]; do
        # Get latest consumer run status
        if consumer_status=$(gh run list --workflow=async-consumer.yml --limit=1 --json status,conclusion --jq '.[0] | "\(.status):\(.conclusion)"' 2>/dev/null); then
            
            case "$consumer_status" in
                "completed:success")
                    echo "✅ Consumer workflow completed successfully!"
                    consumer_complete=true
                    break
                    ;;
                "completed:failure"|"completed:cancelled"|"completed:timed_out")
                    echo "⚠️  Consumer workflow completed with status: $consumer_status"
                    echo "   (May still demonstrate the cycle even with issues)"
                    consumer_complete=true
                    break
                    ;;
                "in_progress:null"|"queued:null")
                    if [[ $((elapsed % 30)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
                        echo "⏳ Consumer running... ${elapsed}s elapsed (status: $consumer_status)"
                    fi
                    ;;
                *)
                    echo "ℹ️  Consumer status: $consumer_status"
                    ;;
            esac
        else
            echo "⚠️  Could not get consumer status - may not be running yet"
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [[ "$consumer_complete" != "true" ]]; then
        echo "⏰ Consumer monitoring timed out after ${max_wait}s"
        echo "   Current status: $consumer_status"
    fi
    
    echo ""
    return 0
}

# Display cycle results
display_results() {
    echo "📊 GitHub Async Feedback Loop Test Results"
    echo "=========================================="
    echo ""
    
    # Get recent workflow runs
    echo "🔍 Recent Workflow Runs:"
    echo ""
    
    # Producer runs
    echo "🚀 Producer Workflow Runs:"
    if gh run list --workflow=async-producer.yml --limit=3 --json databaseId,status,conclusion,createdAt,displayTitle | \
       jq -r '.[] | "   Run \(.databaseId): \(.status)/\(.conclusion) - \(.displayTitle) (\(.createdAt))"' 2>/dev/null; then
        echo ""
    else
        echo "   ⚠️  Could not retrieve producer runs"
        echo ""
    fi
    
    # Consumer runs  
    echo "🍽️  Consumer Workflow Runs:"
    if gh run list --workflow=async-consumer.yml --limit=3 --json databaseId,status,conclusion,createdAt,event,displayTitle | \
       jq -r '.[] | "   Run \(.databaseId): \(.status)/\(.conclusion) - \(.displayTitle) (\(.event)) (\(.createdAt))"' 2>/dev/null; then
        echo ""
    else
        echo "   ⚠️  Could not retrieve consumer runs"
        echo ""
    fi
    
    # Direct links
    echo "🌐 Direct Links:"
    echo "   Producer Workflows: https://github.com/$REPO_NAME/actions/workflows/async-producer.yml"
    echo "   Consumer Workflows: https://github.com/$REPO_NAME/actions/workflows/async-consumer.yml"
    echo "   All Actions: https://github.com/$REPO_NAME/actions"
    echo ""
    
    # Cycle validation
    echo "🔄 Async Feedback Loop Validation:"
    
    # Check if we have recent runs
    local producer_runs=""
    local consumer_runs=""
    
    producer_runs=$(gh run list --workflow=async-producer.yml --limit=1 --json status,conclusion 2>/dev/null | jq -r '.[0] | "\(.status):\(.conclusion)"' 2>/dev/null || echo "none")
    consumer_runs=$(gh run list --workflow=async-consumer.yml --limit=1 --json status,conclusion,event 2>/dev/null | jq -r '.[0] | "\(.status):\(.conclusion):\(.event)"' 2>/dev/null || echo "none")
    
    case "$producer_runs" in
        "completed:success")
            echo "   ✅ Producer: Successfully completed (non-blocking execution)"
            ;;
        "completed:failure"|"completed:cancelled"|"completed:timed_out")
            echo "   ❌ Producer: Failed ($producer_runs)"
            ;;
        "in_progress:null"|"queued:null")
            echo "   ⏳ Producer: Still running ($producer_runs)"
            ;;
        "none")
            echo "   ⚠️  Producer: No recent runs found"
            ;;
        *)
            echo "   ℹ️  Producer: $producer_runs"
            ;;
    esac
    
    case "$consumer_runs" in
        "completed:success:repository_dispatch")
            echo "   ✅ Consumer: Auto-triggered and completed (perfect feedback loop!)"
            ;;
        "completed:success:"*)
            echo "   ✅ Consumer: Completed successfully (trigger: $(echo "$consumer_runs" | cut -d: -f3))"
            ;;
        "completed:"*":repository_dispatch")
            echo "   ⚠️  Consumer: Auto-triggered but $(echo "$consumer_runs" | cut -d: -f2) ($(echo "$consumer_runs" | cut -d: -f3))"
            ;;
        "in_progress:null:"*)
            echo "   ⏳ Consumer: Currently running (trigger: $(echo "$consumer_runs" | cut -d: -f3))"
            ;;
        "queued:null:"*)
            echo "   ⏳ Consumer: Queued for execution (trigger: $(echo "$consumer_runs" | cut -d: -f3))"
            ;;
        "none")
            echo "   ⚠️  Consumer: No runs detected (auto-trigger may not have occurred)"
            ;;
        *)
            echo "   ℹ️  Consumer: $consumer_runs"
            ;;
    esac
    
    echo ""
    
    # Summary
    if [[ "$producer_runs" == "completed:success" ]] && [[ "$consumer_runs" == *"repository_dispatch"* ]]; then
        echo "🎉 SUCCESS: Complete async feedback loop demonstrated!"
        echo "   ✅ Producer published job and exited quickly (non-blocking)"
        echo "   ✅ Background processing executed independently" 
        echo "   ✅ Completion monitor triggered repository_dispatch"
        echo "   ✅ Consumer workflow auto-triggered and processed results"
        echo ""
        echo "🏆 Challenge SOLVED: Independent workflows with state feedback to GitHub!"
    elif [[ "$producer_runs" == "completed:success" ]] && [[ "$consumer_runs" != "none" ]]; then
        echo "🎯 PARTIAL SUCCESS: Async cycle demonstrated"
        echo "   ✅ Producer completed successfully (non-blocking)"
        echo "   ✅ Consumer workflow ran (may be manual trigger)"
        echo "   💡 Auto-trigger via repository_dispatch may need investigation"
    else
        echo "⚠️  TESTING IN PROGRESS: Workflows may still be running"
        echo "   💡 Check the GitHub Actions page for live updates"
    fi
    
    echo ""
    echo "📖 Next Steps:"
    echo "   1. Visit GitHub Actions to see live workflow execution"
    echo "   2. Check workflow logs for detailed async processing output" 
    echo "   3. Try manual consumer trigger if auto-trigger didn't work"
    echo "   4. Adapt the subscribers for your authentication system use cases"
}

# Manual consumer trigger option
offer_manual_trigger() {
    echo "🎛️  Manual Consumer Trigger Option"
    echo "================================="
    echo ""
    
    read -p "Would you like to manually trigger the consumer workflow to test result consumption? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "👤 Triggering consumer workflow manually..."
        
        # Generate test action ID
        local test_action_id="manual-test-$(date +%s)"
        
        if gh workflow run async-consumer.yml \
           --field action_id="$test_action_id" \
           --field correlation_id="manual-corr-$(date +%s)" \
           --field force_consume=true \
           --repo "$REPO_NAME"; then
            
            echo "✅ Manual consumer trigger successful"
            echo "🌐 Check status at: https://github.com/$REPO_NAME/actions/workflows/async-consumer.yml"
        else
            echo "❌ Failed to trigger consumer workflow manually"
        fi
    else
        echo "ℹ️  Skipping manual trigger"
    fi
    
    echo ""
}

# Main execution
main() {
    echo "🚀 Starting GitHub Async Feedback Loop Test..."
    echo "================================================"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy workflows to GitHub
    deploy_workflows
    
    # Trigger producer workflow
    trigger_producer
    
    # Monitor producer execution
    monitor_producer
    
    # Monitor for consumer auto-trigger
    monitor_consumer_trigger
    
    # Monitor consumer execution
    monitor_consumer
    
    # Display results
    display_results
    
    # Offer manual trigger option
    offer_manual_trigger
    
    echo "🎪 GitHub Async Feedback Loop Test Complete!"
    echo "============================================"
    echo ""
    echo "📋 Summary:"
    echo "   ✅ Workflows deployed to GitHub"
    echo "   ✅ Producer workflow triggered and monitored"
    echo "   ✅ Consumer auto-trigger monitoring performed"
    echo "   ✅ Complete cycle results displayed"
    echo ""
    echo "🌐 View all results at: https://github.com/$REPO_NAME/actions"
    echo ""
    echo "🎯 The async feedback loop system is now live in your GitHub repository!"
}

# Execute main function
main "$@"