#!/bin/bash

# Convert all GitHub workflows from hosted runners to self-hosted runners
# This will replace 'runs-on: ubuntu-latest' with 'runs-on: [self-hosted, linux, vault]'

set -e

echo "🔄 CONVERTING ALL WORKFLOWS TO SELF-HOSTED RUNNERS"
echo "=================================================="
echo ""

WORKFLOWS_DIR="/home/tom/GitHub/oracle-fusion-projects/.github/workflows"

# Check if workflows directory exists
if [[ ! -d "$WORKFLOWS_DIR" ]]; then
    echo "❌ Workflows directory not found: $WORKFLOWS_DIR"
    exit 1
fi

echo "📋 Found workflows directory: $WORKFLOWS_DIR"
echo ""

# Find all workflow files currently using ubuntu-latest
echo "🔍 STEP 1: Analyzing current runner usage"
echo "=========================================="

HOSTED_RUNNER_FILES=$(grep -l "runs-on: ubuntu-latest" "$WORKFLOWS_DIR"/*.yml 2>/dev/null || echo "")

if [[ -z "$HOSTED_RUNNER_FILES" ]]; then
    echo "✅ All workflows already using self-hosted runners!"
    exit 0
fi

echo "📋 Files using GitHub hosted runners:"
echo "$HOSTED_RUNNER_FILES" | while read -r file; do
    if [[ -n "$file" ]]; then
        echo "   • $(basename "$file")"
    fi
done

echo ""
echo "🔄 STEP 2: Converting to self-hosted runners"
echo "============================================"

# Convert each file
echo "$HOSTED_RUNNER_FILES" | while read -r file; do
    if [[ -n "$file" && -f "$file" ]]; then
        filename=$(basename "$file")
        echo "Converting: $filename"
        
        # Create backup
        cp "$file" "$file.backup"
        
        # Replace ubuntu-latest with self-hosted runner labels
        sed -i 's/runs-on: ubuntu-latest/runs-on: [self-hosted, linux, vault]/g' "$file"
        
        # Count changes
        CHANGES=$(grep -c "runs-on: \[self-hosted, linux, vault\]" "$file" || echo "0")
        echo "   ✅ Updated $CHANGES runner configurations"
    fi
done

echo ""
echo "🔍 STEP 3: Verification"
echo "======================"

# Verify changes
echo "📊 Remaining hosted runners:"
REMAINING=$(grep -l "runs-on: ubuntu-latest" "$WORKFLOWS_DIR"/*.yml 2>/dev/null || echo "")

if [[ -z "$REMAINING" ]]; then
    echo "✅ SUCCESS: All workflows converted to self-hosted runners!"
else
    echo "⚠️ Some files still using hosted runners:"
    echo "$REMAINING"
fi

echo ""
echo "📋 Self-hosted runner usage:"
SELF_HOSTED_COUNT=$(grep -c "runs-on: \[self-hosted, linux, vault\]" "$WORKFLOWS_DIR"/*.yml 2>/dev/null || echo "0")
echo "   • Files using self-hosted runners: $SELF_HOSTED_COUNT configurations"

echo ""
echo "🎯 CONVERSION COMPLETE!"
echo "======================"
echo "✅ All workflows converted to use self-hosted runner"
echo "🏷️ Runner labels: [self-hosted, linux, vault]"
echo ""
echo "📱 Next Steps:"
echo "   1. Start your self-hosted runner:"
echo "      cd ~/actions-runner-oracle-fusion-projects && ./run.sh"
echo "   2. Verify runner status:"
echo "      gh api repos/TomMcAvoy/oracle-fusion-projects/actions/runners"
echo "   3. Test a workflow:"
echo "      mvn validate -Pwildfly-async-start -N"