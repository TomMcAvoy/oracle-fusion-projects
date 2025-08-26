#!/bin/bash

# Workflow YAML Validation Script
# Run this BEFORE attempting to execute any workflows

echo "🔍 VALIDATING WORKFLOW YAML SYNTAX"
echo "=================================="
echo ""

WORKFLOW_DIR="/home/tom/GitHub/oracle-fusion-projects/.github/workflows"
VALIDATION_FAILED=0

# Function to validate a single workflow file
validate_workflow() {
    local workflow_file="$1"
    local filename=$(basename "$workflow_file")
    
    echo -n "Validating $filename... "
    
    # Check if file exists
    if [[ ! -f "$workflow_file" ]]; then
        echo "❌ FILE NOT FOUND"
        return 1
    fi
    
    # Validate YAML syntax
    if python3 -c "
import yaml
import sys
try:
    with open('$workflow_file', 'r') as f:
        content = yaml.safe_load(f)
    print('✅ VALID')
    sys.exit(0)
except yaml.YAMLError as e:
    print(f'❌ YAML ERROR: {e}')
    sys.exit(1)
except Exception as e:
    print(f'❌ ERROR: {e}')
    sys.exit(1)
" 2>/dev/null; then
        return 0
    else
        VALIDATION_FAILED=1
        return 1
    fi
}

# Validate all workflow files
echo "📂 Workflow directory: $WORKFLOW_DIR"
echo ""

# List of key workflow files to validate
WORKFLOWS=(
    "$WORKFLOW_DIR/fibonacci-simple.yml"
    "$WORKFLOW_DIR/fibonacci-producer.yml" 
    "$WORKFLOW_DIR/async-consumer.yml"
    "$WORKFLOW_DIR/async-state-machine.yml"
    "$WORKFLOW_DIR/pubsub-async-pipeline.yml"
)

# Validate each workflow
for workflow in "${WORKFLOWS[@]}"; do
    if [[ -f "$workflow" ]]; then
        validate_workflow "$workflow"
    fi
done

echo ""
echo "📋 VALIDATION SUMMARY"
echo "===================="

if [[ $VALIDATION_FAILED -eq 0 ]]; then
    echo "✅ ALL WORKFLOWS HAVE VALID YAML SYNTAX!"
    echo "🚀 Safe to run workflows with 'gh workflow run'"
    echo ""
    echo "Available workflows:"
    gh workflow list 2>/dev/null | head -10 || echo "   (Run 'gh workflow list' to see available workflows)"
else
    echo "❌ SOME WORKFLOWS HAVE YAML SYNTAX ERRORS!"
    echo "🚨 FIX YAML ERRORS BEFORE RUNNING WORKFLOWS!"
    echo ""
    echo "💡 Common YAML issues to check:"
    echo "   - Missing colons after keys"
    echo "   - Incorrect indentation (use 2 spaces)"
    echo "   - Unmatched quotes or brackets"
    echo "   - Invalid characters in values"
    exit 1
fi