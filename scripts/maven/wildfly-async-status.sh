#!/bin/bash

# WildFly Async Status Script for Maven Integration
# Shows status of WildFly async workflows and system health

set -e

echo "📊 WILDFLY ASYNC SYSTEM STATUS"
echo "=============================="
echo ""

# Check if GitHub CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Error: GitHub CLI not authenticated"
    echo "   Run: gh auth login"
    exit 1
fi

echo "🔍 WORKFLOW STATUS"
echo "=================="
echo ""

# Get recent WildFly workflows
echo "📋 Recent WildFly Async Workflows:"
WILDFLY_RUNS=$(gh run list --limit 10 --json workflowName,status,conclusion,createdAt,url | \
    jq -r '.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0")) | "\(.workflowName)|\(.status)|\(.conclusion // "running")|\(.createdAt)|\(.url)"')

if [[ -z "$WILDFLY_RUNS" ]]; then
    echo "   ⚠️ No WildFly async workflows found"
else
    echo "$WILDFLY_RUNS" | head -5 | while IFS='|' read -r workflow_name status conclusion created_at url; do
        # Format timestamp
        FORMATTED_TIME=$(date -d "$created_at" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$created_at")
        
        # Status emoji
        if [[ "$status" == "in_progress" ]]; then
            STATUS_EMOJI="🔄"
        elif [[ "$status" == "completed" && "$conclusion" == "success" ]]; then
            STATUS_EMOJI="✅"
        elif [[ "$status" == "completed" && "$conclusion" == "failure" ]]; then
            STATUS_EMOJI="❌"
        else
            STATUS_EMOJI="⏸️"
        fi
        
        echo "   $STATUS_EMOJI $workflow_name"
        echo "      Status: $status - $conclusion"
        echo "      Time: $FORMATTED_TIME"
        echo "      URL: $url"
        echo ""
    done
fi

echo ""
echo "🔄 CURRENTLY RUNNING"
echo "==================="
echo ""

RUNNING_COUNT=$(gh run list --status=in_progress --json workflowName | \
    jq '[.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0"))] | length')

if [[ "$RUNNING_COUNT" -eq 0 ]]; then
    echo "   ✅ No WildFly workflows currently running"
else
    echo "   🔄 $RUNNING_COUNT WildFly workflow(s) currently running:"
    
    gh run list --status=in_progress --json workflowName,createdAt,url | \
        jq -r '.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0")) | "      • \(.workflowName) - \(.url)"'
fi

echo ""
echo "🛡️ CIRCUIT BREAKER STATUS"
echo "========================="
echo ""

# Check recent failure rate
RECENT_RUNS=$(gh run list --limit 10 --json workflowName,conclusion | \
    jq '[.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0")) | .conclusion]')

TOTAL_RECENT=$(echo "$RECENT_RUNS" | jq 'length')
FAILED_RECENT=$(echo "$RECENT_RUNS" | jq '[.[] | select(. == "failure")] | length')

if [[ "$TOTAL_RECENT" -gt 0 ]]; then
    FAILURE_RATE=$(( (FAILED_RECENT * 100) / TOTAL_RECENT ))
    echo "📈 Recent Workflow Statistics (last $TOTAL_RECENT runs):"
    echo "   • Total: $TOTAL_RECENT"
    echo "   • Failed: $FAILED_RECENT"
    echo "   • Failure Rate: $FAILURE_RATE%"
    echo ""
    
    if [[ "$FAILURE_RATE" -gt 50 ]]; then
        echo "   ⚠️  HIGH FAILURE RATE - Circuit breaker may be active"
    elif [[ "$FAILURE_RATE" -gt 25 ]]; then
        echo "   🟡 MODERATE FAILURE RATE - Monitor closely"
    else
        echo "   ✅ HEALTHY FAILURE RATE - System operating normally"
    fi
else
    echo "   📊 No recent workflow data available"
fi

echo ""
echo "🎯 SYSTEM HEALTH"
echo "================"
echo ""

# Check if system components are available
echo "🔧 Component Status:"

# Check git repository
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "   ✅ Git Repository: Connected"
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    echo "      Current Branch: $CURRENT_BRANCH"
else
    echo "   ❌ Git Repository: Not found"
fi

# Check GitHub authentication
if gh auth status >/dev/null 2>&1; then
    echo "   ✅ GitHub CLI: Authenticated"
    GITHUB_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
    echo "      User: $GITHUB_USER"
else
    echo "   ❌ GitHub CLI: Not authenticated"
fi

# Check if workflow files exist
if [[ -f ".github/workflows/wildfly-async-producer-v3.0.0.yml" && -f ".github/workflows/wildfly-async-consumer-v3.0.0.yml" ]]; then
    echo "   ✅ Workflow Files: Present"
    echo "      Producer: wildfly-async-producer-v3.0.0.yml"
    echo "      Consumer: wildfly-async-consumer-v3.0.0.yml"
else
    echo "   ❌ Workflow Files: Missing"
fi

# Check local WildFly installation
if [[ -d "wildfly-37.0.0.Final" ]]; then
    echo "   ✅ WildFly Installation: Found (37.0.0.Final)"
else
    echo "   ⚠️  WildFly Installation: Not found locally"
fi

echo ""
echo "🚀 AVAILABLE ACTIONS"
echo "==================="
echo ""
echo "📋 Maven Commands:"
echo "   mvn wildfly:start-async     # Start async WildFly system"
echo "   mvn wildfly:stop-async      # Stop async WildFly system"
echo "   mvn wildfly:deploy-async    # Deploy via async system"
echo "   mvn wildfly:status-async    # Show this status (current command)"
echo ""
echo "📋 Direct GitHub Commands:"
echo "   gh workflow run wildfly-async-producer-v3.0.0.yml --field job_type=full_build_deploy"
echo "   gh run list --limit 5"
echo "   gh run cancel <run-id>"
echo ""
echo "📋 Job Types Available:"
echo "   • full_build_deploy  # Complete CI-CD pipeline"
echo "   • build_only        # Compilation and packaging only"
echo "   • test_only         # Run tests without build/deploy"
echo "   • deploy_only       # Deploy pre-built artifacts"
echo "   • health_check      # Verify WildFly system health"
echo "   • cache_warmup      # Warm authentication cache"
echo ""
echo "🎯 Monitor at: https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name')/actions"

echo "📊 WILDFLY ASYNC SYSTEM STATUS"
echo "=============================="
echo ""

# Check if GitHub CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Error: GitHub CLI not authenticated"
    echo "   Run: gh auth login"
    exit 1
fi

echo "🔍 WORKFLOW STATUS"
echo "=================="
echo ""

# Get recent WildFly workflows
echo "📋 Recent WildFly Async Workflows:"
WILDFLY_RUNS=$(gh run list --limit 10 --json workflowName,status,conclusion,createdAt,url | \
    jq -r '.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0")) | "\(.workflowName)|\(.status)|\(.conclusion // "running")|\(.createdAt)|\(.url)"')

if [[ -z "$WILDFLY_RUNS" ]]; then
    echo "   ⚠️ No WildFly async workflows found"
else
    echo "$WILDFLY_RUNS" | head -5 | while IFS='|' read -r workflow_name status conclusion created_at url; do
        # Format timestamp
        FORMATTED_TIME=$(date -d "$created_at" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$created_at")
        
        # Status emoji
        if [[ "$status" == "in_progress" ]]; then
            STATUS_EMOJI="🔄"
        elif [[ "$status" == "completed" && "$conclusion" == "success" ]]; then
            STATUS_EMOJI="✅"
        elif [[ "$status" == "completed" && "$conclusion" == "failure" ]]; then
            STATUS_EMOJI="❌"
        else
            STATUS_EMOJI="⏸️"
        fi
        
        echo "   $STATUS_EMOJI $workflow_name"
        echo "      Status: $status - $conclusion"
        echo "      Time: $FORMATTED_TIME"
        echo "      URL: $url"
        echo ""
    done
fi

echo ""
echo "🔄 CURRENTLY RUNNING"
echo "==================="
echo ""

RUNNING_COUNT=$(gh run list --status=in_progress --json workflowName | \
    jq '[.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0"))] | length')

if [[ "$RUNNING_COUNT" -eq 0 ]]; then
    echo "   ✅ No WildFly workflows currently running"
else
    echo "   🔄 $RUNNING_COUNT WildFly workflow(s) currently running:"
    
    gh run list --status=in_progress --json workflowName,createdAt,url | \
        jq -r '.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0")) | "      • \(.workflowName) - \(.url)"'
fi

echo ""
echo "🛡️ CIRCUIT BREAKER STATUS"
echo "========================="
echo ""

# Check recent failure rate
RECENT_RUNS=$(gh run list --limit 10 --json workflowName,conclusion | \
    jq '[.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0")) | .conclusion]')

TOTAL_RECENT=$(echo "$RECENT_RUNS" | jq 'length')
FAILED_RECENT=$(echo "$RECENT_RUNS" | jq '[.[] | select(. == "failure")] | length')

if [[ "$TOTAL_RECENT" -gt 0 ]]; then
    FAILURE_RATE=$(( (FAILED_RECENT * 100) / TOTAL_RECENT ))
    echo "📈 Recent Workflow Statistics (last $TOTAL_RECENT runs):"
    echo "   • Total: $TOTAL_RECENT"
    echo "   • Failed: $FAILED_RECENT"
    echo "   • Failure Rate: $FAILURE_RATE%"
    echo ""
    
    if [[ "$FAILURE_RATE" -gt 50 ]]; then
        echo "   ⚠️  HIGH FAILURE RATE - Circuit breaker may be active"
    elif [[ "$FAILURE_RATE" -gt 25 ]]; then
        echo "   🟡 MODERATE FAILURE RATE - Monitor closely"
    else
        echo "   ✅ HEALTHY FAILURE RATE - System operating normally"
    fi
else
    echo "   📊 No recent workflow data available"
fi

echo ""
echo "🎯 SYSTEM HEALTH"
echo "================"
echo ""

# Check if system components are available
echo "🔧 Component Status:"

# Check git repository
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "   ✅ Git Repository: Connected"
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    echo "      Current Branch: $CURRENT_BRANCH"
else
    echo "   ❌ Git Repository: Not found"
fi

# Check GitHub authentication
if gh auth status >/dev/null 2>&1; then
    echo "   ✅ GitHub CLI: Authenticated"
    GITHUB_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
    echo "      User: $GITHUB_USER"
else
    echo "   ❌ GitHub CLI: Not authenticated"
fi

# Check if workflow files exist
if [[ -f ".github/workflows/wildfly-async-producer-v3.0.0.yml" && -f ".github/workflows/wildfly-async-consumer-v3.0.0.yml" ]]; then
    echo "   ✅ Workflow Files: Present"
    echo "      Producer: wildfly-async-producer-v3.0.0.yml"
    echo "      Consumer: wildfly-async-consumer-v3.0.0.yml"
else
    echo "   ❌ Workflow Files: Missing"
fi

# Check local WildFly installation
if [[ -d "wildfly-37.0.0.Final" ]]; then
    echo "   ✅ WildFly Installation: Found (37.0.0.Final)"
else
    echo "   ⚠️  WildFly Installation: Not found locally"
fi

echo ""
echo "🚀 AVAILABLE ACTIONS"
echo "==================="
echo ""
echo "📋 Maven Commands:"
echo "   mvn wildfly:start-async     # Start async WildFly system"
echo "   mvn wildfly:stop-async      # Stop async WildFly system"
echo "   mvn wildfly:deploy-async    # Deploy via async system"
echo "   mvn wildfly:status-async    # Show this status (current command)"
echo ""
echo "📋 Direct GitHub Commands:"
echo "   gh workflow run wildfly-async-producer-v3.0.0.yml --field job_type=full_build_deploy"
echo "   gh run list --limit 5"
echo "   gh run cancel <run-id>"
echo ""
echo "📋 Job Types Available:"
echo "   • full_build_deploy  # Complete CI-CD pipeline"
echo "   • build_only        # Compilation and packaging only"
echo "   • test_only         # Run tests without build/deploy"
echo "   • deploy_only       # Deploy pre-built artifacts"
echo "   • health_check      # Verify WildFly system health"
echo "   • cache_warmup      # Warm authentication cache"
echo ""
echo "🎯 Monitor at: https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name')/actions"