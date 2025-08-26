#!/bin/bash

# WildFly Async Start Script for Maven Integration
# Triggers the unified async WildFly system via GitHub Actions

set -e

echo "🚀 STARTING WILDFLY ASYNC SYSTEM VIA MAVEN"
echo "=========================================="
echo ""

# Configuration
JOB_TYPE=${1:-"full_build_deploy"}
TARGET_ENVIRONMENT=${2:-"development"}
PRIORITY=${3:-"normal"}
SKIP_TESTS=${4:-"false"}

echo "📋 Configuration:"
echo "   Job Type: $JOB_TYPE"
echo "   Environment: $TARGET_ENVIRONMENT"
echo "   Priority: $PRIORITY"
echo "   Skip Tests: $SKIP_TESTS"
echo ""

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# Check if GitHub CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Error: GitHub CLI not authenticated"
    echo "   Run: gh auth login"
    exit 1
fi

echo "🔧 METHOD 1: GitHub CLI Trigger (Recommended)"
echo "============================================="

# Try GitHub CLI first
if gh workflow run wildfly-async-producer-v3.0.0.yml \
    --field job_type="$JOB_TYPE" \
    --field target_environment="$TARGET_ENVIRONMENT" \
    --field priority="$PRIORITY" \
    --field skip_tests="$SKIP_TESTS" 2>/dev/null; then
    
    echo "✅ Successfully triggered WildFly Async Producer v3.0.0"
    echo ""
    echo "🔍 Monitoring workflow execution..."
    sleep 5
    
    # Show recent runs
    echo "📊 Recent workflow runs:"
    gh run list --limit 3 --json workflowName,status,conclusion,createdAt | \
        jq -r '.[] | "   \(.workflowName): \(.status) - \(.conclusion // "running") - \(.createdAt)"'
    echo ""
    echo "🎯 Monitor progress at: https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name')/actions"
    
else
    echo "⚠️ GitHub CLI trigger failed, trying API method..."
    echo ""
    echo "🔧 METHOD 2: Direct API Trigger"
    echo "==============================="
    
    # Get token and repository info
    TOKEN=$(gh auth token)
    REPO_INFO=$(gh repo view --json owner,name)
    OWNER=$(echo "$REPO_INFO" | jq -r '.owner.login')
    REPO_NAME=$(echo "$REPO_INFO" | jq -r '.name')
    
    # API trigger
    RESPONSE=$(curl -s -X POST \
        -H "Authorization: token $TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$OWNER/$REPO_NAME/actions/workflows/wildfly-async-producer-v3.0.0.yml/dispatches" \
        -d "{\"ref\": \"master\", \"inputs\": {\"job_type\": \"$JOB_TYPE\", \"target_environment\": \"$TARGET_ENVIRONMENT\", \"priority\": \"$PRIORITY\", \"skip_tests\": \"$SKIP_TESTS\"}}")
    
    if [[ -z "$RESPONSE" ]]; then
        echo "✅ Successfully triggered WildFly Async Producer v3.0.0 via API"
        echo ""
        echo "⏰ Waiting for workflow to start..."
        sleep 10
        
        echo "📊 Recent workflow runs:"
        gh run list --limit 3 --json workflowName,status,conclusion,createdAt | \
            jq -r '.[] | "   \(.workflowName): \(.status) - \(.conclusion // "running") - \(.createdAt)"'
        echo ""
        echo "🎯 Monitor progress at: https://github.com/$OWNER/$REPO_NAME/actions"
        
    else
        echo "❌ API trigger failed: $RESPONSE"
        echo ""
        echo "🔧 METHOD 3: Auto-trigger via Git Push"
        echo "====================================="
        echo "   Alternative: Make a commit to trigger auto-build"
        echo "   git commit --allow-empty -m 'Trigger WildFly async system'"
        echo "   git push origin master"
        exit 1
    fi
fi

echo ""
echo "🎉 WildFly Async System Started!"
echo "================================"
echo ""
echo "🔄 What happens next:"
echo "   1. Producer publishes job via repository_dispatch"
echo "   2. Consumer receives event with circuit breaker check"
echo "   3. If allowed, consumer processes WildFly $JOB_TYPE"
echo "   4. Results available in GitHub Actions"
echo ""
echo "⏰ Expected timeline:"
echo "   • Producer: ~2-3 minutes (fast, non-blocking)"
echo "   • Consumer: ~15-20 minutes (full WildFly processing)"
echo ""
echo "📱 Use 'mvn wildfly:status-async' to check progress"

echo "🚀 STARTING WILDFLY ASYNC SYSTEM VIA MAVEN"
echo "=========================================="
echo ""

# Configuration
JOB_TYPE=${1:-"full_build_deploy"}
TARGET_ENVIRONMENT=${2:-"development"}
PRIORITY=${3:-"normal"}
SKIP_TESTS=${4:-"false"}

echo "📋 Configuration:"
echo "   Job Type: $JOB_TYPE"
echo "   Environment: $TARGET_ENVIRONMENT"
echo "   Priority: $PRIORITY"
echo "   Skip Tests: $SKIP_TESTS"
echo ""

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# Check if GitHub CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Error: GitHub CLI not authenticated"
    echo "   Run: gh auth login"
    exit 1
fi

echo "🔧 METHOD 1: GitHub CLI Trigger (Recommended)"
echo "============================================="

# Try GitHub CLI first
if gh workflow run wildfly-async-producer-v3.0.0.yml \
    --field job_type="$JOB_TYPE" \
    --field target_environment="$TARGET_ENVIRONMENT" \
    --field priority="$PRIORITY" \
    --field skip_tests="$SKIP_TESTS" 2>/dev/null; then
    
    echo "✅ Successfully triggered WildFly Async Producer v3.0.0"
    echo ""
    echo "🔍 Monitoring workflow execution..."
    sleep 5
    
    # Show recent runs
    echo "📊 Recent workflow runs:"
    gh run list --limit 3 --json workflowName,status,conclusion,createdAt | \
        jq -r '.[] | "   \(.workflowName): \(.status) - \(.conclusion // "running") - \(.createdAt)"'
    echo ""
    echo "🎯 Monitor progress at: https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name')/actions"
    
else
    echo "⚠️ GitHub CLI trigger failed, trying API method..."
    echo ""
    echo "🔧 METHOD 2: Direct API Trigger"
    echo "==============================="
    
    # Get token and repository info
    TOKEN=$(gh auth token)
    REPO_INFO=$(gh repo view --json owner,name)
    OWNER=$(echo "$REPO_INFO" | jq -r '.owner.login')
    REPO_NAME=$(echo "$REPO_INFO" | jq -r '.name')
    
    # API trigger
    RESPONSE=$(curl -s -X POST \
        -H "Authorization: token $TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$OWNER/$REPO_NAME/actions/workflows/wildfly-async-producer-v3.0.0.yml/dispatches" \
        -d "{\"ref\": \"master\", \"inputs\": {\"job_type\": \"$JOB_TYPE\", \"target_environment\": \"$TARGET_ENVIRONMENT\", \"priority\": \"$PRIORITY\", \"skip_tests\": \"$SKIP_TESTS\"}}")
    
    if [[ -z "$RESPONSE" ]]; then
        echo "✅ Successfully triggered WildFly Async Producer v3.0.0 via API"
        echo ""
        echo "⏰ Waiting for workflow to start..."
        sleep 10
        
        echo "📊 Recent workflow runs:"
        gh run list --limit 3 --json workflowName,status,conclusion,createdAt | \
            jq -r '.[] | "   \(.workflowName): \(.status) - \(.conclusion // "running") - \(.createdAt)"'
        echo ""
        echo "🎯 Monitor progress at: https://github.com/$OWNER/$REPO_NAME/actions"
        
    else
        echo "❌ API trigger failed: $RESPONSE"
        echo ""
        echo "🔧 METHOD 3: Auto-trigger via Git Push"
        echo "====================================="
        echo "   Alternative: Make a commit to trigger auto-build"
        echo "   git commit --allow-empty -m 'Trigger WildFly async system'"
        echo "   git push origin master"
        exit 1
    fi
fi

echo ""
echo "🎉 WildFly Async System Started!"
echo "================================"
echo ""
echo "🔄 What happens next:"
echo "   1. Producer publishes job via repository_dispatch"
echo "   2. Consumer receives event with circuit breaker check"
echo "   3. If allowed, consumer processes WildFly $JOB_TYPE"
echo "   4. Results available in GitHub Actions"
echo ""
echo "⏰ Expected timeline:"
echo "   • Producer: ~2-3 minutes (fast, non-blocking)"
echo "   • Consumer: ~15-20 minutes (full WildFly processing)"
echo ""
echo "📱 Use 'mvn wildfly:status-async' to check progress"