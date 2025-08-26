#!/bin/bash

# Quick Workflow Test - Fires a few key workflows for testing

echo "🧪 QUICK WORKFLOW TEST"
echo "====================="
echo ""

cd "/home/tom/GitHub/oracle-fusion-projects"

# Check if workflow runner exists
if [[ ! -f "./scripts/workflow-cycle-runner.sh" ]]; then
    echo "❌ Workflow cycle runner not found"
    exit 1
fi

echo "🎯 Running quick test with 3 simple workflows..."
echo ""

# Test simple workflows first
echo "1️⃣ Testing simple-test.yml..."
./scripts/workflow-cycle-runner.sh -w simple-test.yml

sleep 5

echo ""
echo "2️⃣ Testing fibonacci-simple.yml..."
./scripts/workflow-cycle-runner.sh -w fibonacci-simple.yml

sleep 5

echo ""
echo "3️⃣ Testing test-validation.yml..."
./scripts/workflow-cycle-runner.sh -w test-validation.yml

echo ""
echo "✅ Quick test complete! Check status with:"
echo "   ./scripts/workflow-monitor.sh"
echo "   ./scripts/workflow-cycle-runner.sh --status"