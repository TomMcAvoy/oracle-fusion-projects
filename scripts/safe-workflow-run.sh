#!/bin/bash

# Safe Workflow Runner - Validates YAML before execution
# Usage: ./safe-workflow-run.sh <workflow-name> [additional-args]

WORKFLOW_NAME="$1"
shift  # Remove first argument, keep the rest

if [[ -z "$WORKFLOW_NAME" ]]; then
    echo "Usage: $0 <workflow-name> [additional-args]"
    echo ""
    echo "Example:"
    echo "  $0 fibonacci-simple.yml --field iterations=50"
    echo "  $0 async-consumer.yml --field action_id=test-123"
    exit 1
fi

echo "🔐 SAFE WORKFLOW EXECUTION"
echo "========================="
echo ""
echo "Target workflow: $WORKFLOW_NAME"
echo "Additional args: $*"
echo ""

# Step 1: Validate YAML syntax BEFORE running
echo "🔍 Step 1: Validating YAML syntax..."
WORKFLOW_FILE=".github/workflows/$WORKFLOW_NAME"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
    echo "❌ Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

# Validate YAML
if python3 -c "
import yaml
try:
    with open('$WORKFLOW_FILE', 'r') as f:
        yaml.safe_load(f)
    print('✅ YAML syntax is valid')
except Exception as e:
    print(f'❌ YAML syntax error: {e}')
    exit(1)
"; then
    echo ""
else
    echo "🚨 YAML validation failed - cannot run workflow safely!"
    echo "💡 Fix YAML syntax errors before running"
    exit 1
fi

# Step 2: Check if workflow exists in GitHub
echo "🔍 Step 2: Checking workflow availability..."
if gh workflow list | grep -q "$WORKFLOW_NAME"; then
    echo "✅ Workflow found in GitHub Actions"
    echo ""
else
    echo "⚠️  Workflow not found in GitHub (may need time to sync after push)"
    echo "🔄 Recent workflows:"
    gh workflow list | head -5
    echo ""
fi

# Step 3: Run the workflow safely
echo "🚀 Step 3: Running workflow..."
echo "Command: gh workflow run $WORKFLOW_NAME $*"
echo ""

if gh workflow run "$WORKFLOW_NAME" "$@"; then
    echo ""
    echo "✅ Workflow triggered successfully!"
    echo ""
    echo "🔍 Check status with:"
    echo "  gh run list --limit=5"
    echo ""
    echo "🌐 View in browser:"
    echo "  https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions"
else
    echo ""
    echo "❌ Failed to trigger workflow"
    echo "💡 Possible issues:"
    echo "   - Workflow file has syntax errors"
    echo "   - Missing required inputs"
    echo "   - Workflow not yet synced to GitHub"
    echo "   - Authentication problems"
fi