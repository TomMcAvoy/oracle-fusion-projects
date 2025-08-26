#!/bin/bash

# WildFly Async Deploy Script for Maven Integration
# Triggers deployment via the unified async WildFly system

set -e

echo "🚀 WILDFLY ASYNC DEPLOYMENT VIA MAVEN"
echo "====================================="
echo ""

# Configuration
TARGET_ENVIRONMENT=${1:-"development"}
SKIP_TESTS=${2:-"false"}
PRIORITY=${3:-"normal"}
SKIP_BUILD=${4:-"false"}

echo "📋 Deployment Configuration:"
echo "   Target Environment: $TARGET_ENVIRONMENT"
echo "   Skip Tests: $SKIP_TESTS"
echo "   Priority: $PRIORITY"
echo "   Skip Build: $SKIP_BUILD"
echo ""

# Determine job type based on parameters
if [[ "$SKIP_BUILD" == "true" ]]; then
    JOB_TYPE="deploy_only"
    echo "🎯 Job Type: deploy_only (using pre-built artifacts)"
else
    JOB_TYPE="full_build_deploy"
    echo "🎯 Job Type: full_build_deploy (build + deploy)"
fi

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

# Environment validation
if [[ "$TARGET_ENVIRONMENT" == "production" ]]; then
    echo "⚠️  PRODUCTION DEPLOYMENT WARNING"
    echo "================================="
    echo ""
    echo "🚨 You are about to deploy to PRODUCTION!"
    echo "   Environment: $TARGET_ENVIRONMENT"
    echo "   Job Type: $JOB_TYPE"
    echo ""
    read -p "🤔 Are you sure you want to proceed? (yes/NO): " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "❌ Production deployment cancelled"
        exit 1
    fi
    
    echo "🔒 Production deployment confirmed"
    PRIORITY="urgent"  # Escalate production deploys
    echo "   Priority elevated to: $PRIORITY"
    echo ""
fi

echo "🔧 Starting Async Deployment Process"
echo "===================================="
echo ""

# Check current system status first
echo "🔍 Checking system status..."
RUNNING_COUNT=$(gh run list --status=in_progress --json workflowName | \
    jq '[.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0"))] | length')

if [[ "$RUNNING_COUNT" -gt 0 ]]; then
    echo "⚠️  Warning: $RUNNING_COUNT WildFly workflow(s) currently running"
    echo ""
    gh run list --status=in_progress --json workflowName,createdAt,url | \
        jq -r '.[] | select(.workflowName | test("WildFly.*v3\\.0\\.0")) | "   🔄 \(.workflowName) - \(.url)"'
    echo ""
    
    if [[ "$PRIORITY" != "urgent" ]]; then
        read -p "🤔 Continue with deployment? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Deployment cancelled"
            exit 1
        fi
    fi
fi

echo "🚀 Triggering WildFly Async Producer..."
echo ""

# Trigger the async workflow
if gh workflow run wildfly-async-producer-v3.0.0.yml \
    --field job_type="$JOB_TYPE" \
    --field target_environment="$TARGET_ENVIRONMENT" \
    --field priority="$PRIORITY" \
    --field skip_tests="$SKIP_TESTS" 2>/dev/null; then
    
    echo "✅ Successfully triggered WildFly Async Producer v3.0.0"
    echo ""
    echo "🔄 Deployment Process Started"
    echo "============================"
    echo ""
    echo "📋 What happens next:"
    echo "   1. Producer validates deployment request"
    echo "   2. Producer publishes job via repository_dispatch"
    echo "   3. Consumer receives event with circuit breaker check"
    echo "   4. If allowed, consumer processes WildFly deployment"
    echo "   5. Deployment results available in GitHub Actions"
    echo ""
    
    echo "⏰ Monitoring deployment progress..."
    sleep 5
    
    # Show recent runs
    echo "📊 Recent workflow runs:"
    gh run list --limit 3 --json workflowName,status,conclusion,createdAt | \
        jq -r '.[] | "   \(.workflowName): \(.status) - \(.conclusion // "running") - \(.createdAt)"'
    echo ""
    
    echo "🎯 Monitor deployment at: https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name')/actions"
    
    # Estimated timeline
    echo ""
    echo "⏰ Expected Timeline:"
    echo "===================="
    if [[ "$JOB_TYPE" == "deploy_only" ]]; then
        echo "   • Producer: ~2-3 minutes (validation + job publication)"
        echo "   • Consumer: ~5-8 minutes (deployment only)"
        echo "   • Total: ~7-11 minutes"
    else
        echo "   • Producer: ~2-3 minutes (validation + job publication)"
        echo "   • Consumer: ~15-20 minutes (build + test + deploy)"
        echo "   • Total: ~17-23 minutes"
    fi
    
    echo ""
    echo "📱 Use 'mvn wildfly:status-async' to check progress"
    echo "📱 Use 'mvn wildfly:stop-async' to cancel if needed"
    
else
    echo "❌ Failed to trigger deployment workflow"
    echo ""
    echo "🔧 Troubleshooting Options:"
    echo "=========================="
    echo ""
    echo "1️⃣ Try direct GitHub CLI:"
    echo "   gh workflow run wildfly-async-producer-v3.0.0.yml \\"
    echo "     --field job_type=$JOB_TYPE \\"
    echo "     --field target_environment=$TARGET_ENVIRONMENT"
    echo ""
    echo "2️⃣ Try auto-trigger via git push:"
    echo "   git commit --allow-empty -m 'Trigger async deployment to $TARGET_ENVIRONMENT'"
    echo "   git push origin master"
    echo ""
    echo "3️⃣ Check authentication:"
    echo "   gh auth status"
    echo "   gh auth refresh"
    echo ""
    exit 1
fi

echo ""
echo "🎉 Async Deployment Initiated!"
echo "=============================="
echo ""
echo "🎯 Deployment Summary:"
echo "   • Job Type: $JOB_TYPE"
echo "   • Environment: $TARGET_ENVIRONMENT"
echo "   • Priority: $PRIORITY"
echo "   • Skip Tests: $SKIP_TESTS"
echo "   • Circuit Breaker: Active"
echo ""
echo "✅ Your WildFly authentication system is being deployed"
echo "   via the unified async architecture with full protection!"