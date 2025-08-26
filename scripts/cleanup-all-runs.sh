#!/bin/bash

# Complete GitHub Actions Workflow Run Cleanup Script
# Deletes all workflow runs to clean up the repository

echo "🗑️ GITHUB ACTIONS CLEANUP SCRIPT"
echo "================================="
echo ""

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found"
    echo "💡 Install with: sudo apt install gh"
    exit 1
fi

# Check authentication
if ! gh auth status &>/dev/null; then
    echo "❌ Not authenticated with GitHub"
    echo "💡 Run: gh auth login"
    exit 1
fi

echo "🔍 Current workflow runs:"
gh run list --limit=10 2>/dev/null || { echo "❌ Failed to list runs"; exit 1; }
echo ""

read -p "🗑️ Delete ALL workflow runs? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled by user"
    exit 0
fi

echo "🗑️ Deleting all workflow runs..."
echo ""

# Get all run IDs and delete them in batches
BATCH_SIZE=20
TOTAL_DELETED=0

while true; do
    # Get next batch of run IDs
    RUN_IDS=$(gh run list --limit=$BATCH_SIZE --json databaseId --jq '.[].databaseId' 2>/dev/null)
    
    if [[ -z "$RUN_IDS" ]]; then
        break
    fi
    
    # Delete each run in the batch
    BATCH_COUNT=0
    for RUN_ID in $RUN_IDS; do
        if gh run delete "$RUN_ID" 2>/dev/null; then
            echo "✓ Deleted run: $RUN_ID"
            BATCH_COUNT=$((BATCH_COUNT + 1))
            TOTAL_DELETED=$((TOTAL_DELETED + 1))
        else
            echo "⚠️ Failed to delete run: $RUN_ID (may be protected or in-progress)"
        fi
    done
    
    echo "📊 Batch complete: $BATCH_COUNT deleted"
    
    # Small delay to avoid rate limiting
    sleep 2
    
    # Check if we have more runs
    REMAINING=$(gh run list --limit=1 --json databaseId --jq 'length' 2>/dev/null)
    if [[ "$REMAINING" == "0" ]]; then
        break
    fi
done

echo ""
echo "✅ CLEANUP SUMMARY"
echo "=================="
echo "🗑️ Total runs deleted: $TOTAL_DELETED"
echo ""
echo "🔍 Remaining runs:"
gh run list --limit=5 2>/dev/null || echo "   (No runs remaining or unable to list)"
echo ""
echo "✅ Cleanup completed!"