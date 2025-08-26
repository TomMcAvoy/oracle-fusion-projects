#!/bin/bash

# WildFly Async Stop Script for Maven Integration
# Stops/cancels running WildFly async workflows

set -e

echo "🛑 STOPPING WILDFLY ASYNC SYSTEM VIA MAVEN"
echo "==========================================="
echo ""

# Check if GitHub CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Error: GitHub CLI not authenticated"
    echo "   Run: gh auth login"
    exit 1
fi

echo "🔍 Finding running WildFly workflows..."
echo ""

# Get running workflows
RUNNING_WORKFLOWS=$(gh run list --status=in_progress --json databaseId,workflowName,status --limit 20 | \
    jq -r '.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0")) | "\(.databaseId)|\(.workflowName)|\(.status)"')

if [[ -z "$RUNNING_WORKFLOWS" ]]; then
    echo "✅ No running WildFly async workflows found"
    echo ""
    echo "📊 Recent WildFly workflow runs:"
    gh run list --limit 5 --json workflowName,status,conclusion,createdAt | \
        jq -r '.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0")) | "   \(.workflowName): \(.status) - \(.conclusion // "running") - \(.createdAt)"'
    echo ""
    echo "💡 If you want to cancel completed workflows, use:"
    echo "   gh run cancel <run-id>"
    exit 0
fi

echo "📋 Running WildFly async workflows:"
echo "$RUNNING_WORKFLOWS" | while IFS='|' read -r run_id workflow_name status; do
    echo "   🔄 $workflow_name (ID: $run_id) - $status"
done
echo ""

# Ask for confirmation
read -p "🤔 Cancel all running WildFly workflows? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🛑 Cancelling running WildFly workflows..."
    echo ""
    
    CANCELLED_COUNT=0
    echo "$RUNNING_WORKFLOWS" | while IFS='|' read -r run_id workflow_name status; do
        echo "   🛑 Cancelling: $workflow_name (ID: $run_id)"
        if gh run cancel "$run_id" 2>/dev/null; then
            echo "      ✅ Successfully cancelled"
            ((CANCELLED_COUNT++))
        else
            echo "      ⚠️ Failed to cancel (may already be stopping)"
        fi
    done
    
    echo ""
    echo "✅ Cancellation requests sent"
    echo ""
    echo "⏰ Waiting for workflows to stop..."
    sleep 5
    
    echo "📊 Updated workflow status:"
    gh run list --limit 5 --json workflowName,status,conclusion,createdAt | \
        jq -r '.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0")) | "   \(.workflowName): \(.status) - \(.conclusion // "running") - \(.createdAt)"'
    
else
    echo "❌ Cancelled - no workflows stopped"
    exit 1
fi

echo ""
echo "🎯 Additional Stop Commands:"
echo "=========================="
echo ""
echo "🔧 Stop local WildFly server:"
echo "   mvn wildfly:shutdown"
echo "   # or"
echo "   ./scripts/shell/wildfly-stop.sh"
echo ""
echo "🔧 Stop Docker services:"
echo "   docker-compose down"
echo ""
echo "🔧 Cancel specific workflow run:"
echo "   gh run cancel <run-id>"
echo ""
echo "🔧 View all workflow runs:"
echo "   gh run list --limit 10"

echo ""
echo "🛑 WildFly Async System Stop Complete!"