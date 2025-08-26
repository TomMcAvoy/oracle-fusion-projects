#!/bin/bash
# Test Repository Dispatch with Personal Access Token
# This script uses a PAT with proper permissions for repository_dispatch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔐 TESTING REPOSITORY DISPATCH WITH PAT"
echo "======================================="

# Check if token file exists
TOKEN_FILE="$PROJECT_ROOT/.secrets/.token"
if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "❌ Token file not found: $TOKEN_FILE"
    echo ""
    echo "🔑 Please create your GitHub Personal Access Token:"
    echo "1. Go to: https://github.com/settings/tokens"
    echo "2. Generate new token (classic)"
    echo "3. Select scopes: 'repo' and 'workflow'"
    echo "4. Create the file:"
    echo "   echo 'your_token_here' > .secrets/.token"
    echo ""
    exit 1
fi

# Load token
echo "🔐 Loading GitHub PAT..."
GH_TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r')
if [[ -z "$GH_TOKEN" ]]; then
    echo "❌ Token file is empty"
    exit 1
fi

export GH_TOKEN
echo "✅ Token loaded (length: ${#GH_TOKEN})"

# Configuration
REPO_NAME="${GITHUB_REPOSITORY:-TomMcAvoy/oracle-fusion-projects}"
ACTION_ID="pat-dispatch-test-$(date +%s)"

echo ""
echo "📋 Test Configuration:"
echo "  Repository: $REPO_NAME"
echo "  Action ID: $ACTION_ID"
echo "  Token Type: Personal Access Token"
echo ""

# Test basic GitHub API access first
echo "🧪 Testing GitHub API access..."
if gh api user --jq '.login' >/dev/null 2>&1; then
    USERNAME=$(gh api user --jq '.login')
    echo "✅ GitHub API access confirmed for user: $USERNAME"
else
    echo "❌ GitHub API access failed"
    echo "Check your token permissions and network connection"
    exit 1
fi

# Create repository dispatch payload
echo ""
echo "📤 Creating repository dispatch payload..."
DISPATCH_PAYLOAD=$(jq -n \
    --arg action_id "$ACTION_ID" \
    --arg trigger_time "$(date -Iseconds)" \
    --arg test_type "pat_dispatch_test" \
    '{
        event_type: "fibonacci_job_completed",
        client_payload: {
            action_id: $action_id,
            producer_run_id: "manual-test",
            producer_status: "completed",
            iterations: "25",
            trigger_time: $trigger_time,
            producer_actor: "'$USERNAME'",
            auto_triggered: true,
            test_type: $test_type,
            pipeline_phase: "pat_testing"
        }
    }'
)

echo "✅ Payload created:"
echo "$DISPATCH_PAYLOAD" | jq .

# Send repository dispatch
echo ""
echo "🚀 Sending repository dispatch event..."
if echo "$DISPATCH_PAYLOAD" | gh api repos/$REPO_NAME/dispatches \
    --method POST \
    --input -; then
    echo "✅ Repository dispatch sent successfully!"
    echo "🎯 Consumer should start automatically in ~30 seconds"
    echo "📋 Event type: fibonacci_job_completed"
    echo "🔗 Action ID: $ACTION_ID"
else
    echo "❌ Repository dispatch failed"
    echo "Check token permissions (needs 'repo' and 'workflow' scopes)"
    exit 1
fi

# Wait and check for consumer trigger
echo ""
echo "⏳ Waiting 45 seconds for consumer auto-trigger..."
sleep 45

echo "🔍 Checking for triggered consumer workflows..."
RECENT_CONSUMERS=$(gh run list --limit 5 --json event,workflowName,createdAt,status \
    --jq '.[] | select(.event == "repository_dispatch" and .workflowName | contains("Consumer")) | {workflow: .workflowName, event: .event, created: .createdAt, status: .status}')

if [[ -n "$RECENT_CONSUMERS" ]]; then
    echo "✅ Consumer auto-trigger detected!"
    echo "$RECENT_CONSUMERS" | jq .
    
    echo ""
    echo "🎉 REPOSITORY DISPATCH TEST SUCCESSFUL!"
    echo "✅ PAT has correct permissions"
    echo "✅ Auto-trigger working"
    echo "✅ End-to-end async pipeline operational"
else
    echo "⚠️  Consumer auto-trigger not detected yet"
    echo "This may take up to 2 minutes"
    
    echo ""
    echo "🔍 Recent workflow runs:"
    gh run list --limit 5 --json workflowName,event,status,createdAt \
        --jq '.[] | {workflow: .workflowName, event: .event, status: .status, created: .createdAt}'
fi

echo ""
echo "📊 Test Summary:"
echo "  🔐 PAT Authentication: ✅"
echo "  📤 Repository Dispatch: ✅"
echo "  🍽️ Consumer Auto-Trigger: ${RECENT_CONSUMERS:+✅}"
echo "  🎯 Action ID: $ACTION_ID"

echo ""
echo "🌐 View Results:"
echo "  📊 Actions: https://github.com/$REPO_NAME/actions"
echo "  🔍 Filter by repository_dispatch events"

exit 0