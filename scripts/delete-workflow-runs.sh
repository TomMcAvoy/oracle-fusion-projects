#!/bin/bash
# Delete workflow runs via GitHub REST API

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Delete GitHub Actions workflow runs via REST API"
    echo ""
    echo "Options:"
    echo "  --all, -a              Delete ALL runs (DESTRUCTIVE!)"
    echo "  --run-id ID            Delete specific run by ID"
    echo "  --workflow NAME        Delete runs for specific workflow"
    echo "  --status STATUS        Delete runs by status (completed, cancelled, failure, success)"
    echo "  --older-than DAYS      Delete runs older than N days"
    echo "  --dry-run              Show what would be deleted (no actual deletion)"
    echo "  --force                Skip confirmation prompt"
    echo "  --help, -h             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --all --force                        # Delete ALL runs (no prompt)"
    echo "  $0 --workflow 'CI-CD Pipeline'          # Delete specific workflow runs"
    echo "  $0 --status failure --older-than 7      # Delete failed runs older than 7 days"
    echo "  $0 --dry-run --all                      # Preview all deletions"
}

# Default options
DELETE_ALL=false
RUN_ID=""
WORKFLOW_NAME=""
STATUS_FILTER=""
OLDER_THAN_DAYS=""
DRY_RUN=false
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all|-a)
            DELETE_ALL=true
            shift
            ;;
        --run-id)
            RUN_ID="$2"
            shift 2
            ;;
        --workflow)
            WORKFLOW_NAME="$2"
            shift 2
            ;;
        --status)
            STATUS_FILTER="$2"
            shift 2
            ;;
        --older-than)
            OLDER_THAN_DAYS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

echo "🗑️ DELETE GITHUB WORKFLOW RUNS"
echo "==============================="

# Check if token file exists
TOKEN_FILE="$PROJECT_ROOT/.secrets/.token"
if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "❌ Token file not found: $TOKEN_FILE"
    exit 1
fi

# Load token
TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r')
REPO_NAME="${GITHUB_REPOSITORY:-TomMcAvoy/oracle-fusion-projects}"

echo "🔐 Repository: $REPO_NAME"
if [[ "$DRY_RUN" == true ]]; then
    echo "🔍 DRY RUN MODE - No actual deletions will occur"
fi

# Function to delete a workflow run
delete_run() {
    local run_id=$1
    local workflow_name=${2:-"Unknown"}
    local created_at=${3:-"Unknown"}
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would delete: $run_id ($workflow_name) - $created_at"
        return
    fi
    
    echo "Deleting run: $run_id ($workflow_name)"
    response_code=$(curl -s -w "%{http_code}" -X DELETE -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/$REPO_NAME/actions/runs/$run_id")
    
    if [[ "$response_code" == "204" ]]; then
        echo " ✅ Deleted"
    else
        echo " ❌ Failed (HTTP: $response_code)"
    fi
    sleep 0.3  # Rate limiting
}

# Function to get cutoff date
get_cutoff_date() {
    if [[ -n "$OLDER_THAN_DAYS" ]]; then
        if command -v gdate >/dev/null 2>&1; then
            gdate -d "$OLDER_THAN_DAYS days ago" --iso-8601=seconds
        else
            date -d "$OLDER_THAN_DAYS days ago" --iso-8601=seconds 2>/dev/null || \
            date -v-"$OLDER_THAN_DAYS"d +%Y-%m-%dT%H:%M:%S%z
        fi
    fi
}

# Build API URL with filters
API_URL="https://api.github.com/repos/$REPO_NAME/actions/runs?per_page=100"
if [[ -n "$STATUS_FILTER" ]]; then
    API_URL="${API_URL}&status=$STATUS_FILTER"
fi

echo ""
if [[ "$DELETE_ALL" == true ]]; then
    echo "🔍 Finding ALL workflow runs..."
elif [[ -n "$RUN_ID" ]]; then
    echo "🎯 Targeting specific run: $RUN_ID"
elif [[ -n "$WORKFLOW_NAME" ]]; then
    echo "🔍 Finding runs for workflow: $WORKFLOW_NAME"
elif [[ -n "$STATUS_FILTER" ]]; then
    echo "🔍 Finding runs with status: $STATUS_FILTER"
fi

if [[ -n "$OLDER_THAN_DAYS" ]]; then
    CUTOFF_DATE=$(get_cutoff_date)
    echo "📅 Only considering runs older than: $CUTOFF_DATE"
fi

# Get runs to delete
RUNS_TO_DELETE=""
CUTOFF_DATE=$(get_cutoff_date)

if [[ -n "$RUN_ID" ]]; then
    # Single run deletion
    RUNS_TO_DELETE="$RUN_ID Unknown Unknown"
else
    # Multiple runs - fetch from API
    PAGE=1
    while [[ $PAGE -le 5 ]]; do  # Limit to 5 pages (500 runs)
        RESPONSE=$(curl -s -H "Authorization: token $TOKEN" "${API_URL}&page=$PAGE")
        
        PAGE_RUNS=$(echo "$RESPONSE" | jq -r --arg workflow "$WORKFLOW_NAME" --arg cutoff "$CUTOFF_DATE" '
            .workflow_runs[] | 
            select(
                (if $workflow != "" then .workflow_name == $workflow else true end) and
                (if $cutoff != "" then .created_at < $cutoff else true end)
            ) | 
            "\(.id) \(.workflow_name) \(.created_at)"
        ')
        
        if [[ -z "$PAGE_RUNS" ]]; then
            break
        fi
        
        RUNS_TO_DELETE="$RUNS_TO_DELETE"$'\n'"$PAGE_RUNS"
        ((PAGE++))
    done
fi

# Clean up runs list
RUNS_TO_DELETE=$(echo "$RUNS_TO_DELETE" | grep -v '^$' || true)

if [[ -z "$RUNS_TO_DELETE" ]]; then
    echo "✅ No runs found matching criteria"
    exit 0
fi

# Count runs
RUN_COUNT=$(echo "$RUNS_TO_DELETE" | wc -l)
echo "📊 Found $RUN_COUNT runs to delete"

# Show sample if many runs
if [[ $RUN_COUNT -gt 10 ]]; then
    echo ""
    echo "📋 Sample runs (showing first 10):"
    echo "$RUNS_TO_DELETE" | head -10 | while IFS=' ' read -r run_id workflow_name created_at; do
        echo "  $run_id ($workflow_name) - $created_at"
    done
    echo "  ... and $((RUN_COUNT - 10)) more"
else
    echo ""
    echo "📋 Runs to delete:"
    echo "$RUNS_TO_DELETE" | while IFS=' ' read -r run_id workflow_name created_at; do
        echo "  $run_id ($workflow_name) - $created_at"
    done
fi

# Confirmation
if [[ "$FORCE" != true && "$DRY_RUN" != true ]]; then
    echo ""
    read -p "⚠️  Are you sure you want to delete $RUN_COUNT workflow runs? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deletion cancelled."
        exit 0
    fi
fi

# Delete runs
echo ""
DELETED_COUNT=0
FAILED_COUNT=0

echo "$RUNS_TO_DELETE" | while IFS=' ' read -r run_id workflow_name created_at; do
    if [[ -n "$run_id" && "$run_id" != "Unknown" ]]; then
        delete_run "$run_id" "$workflow_name" "$created_at"
        if [[ "$?" == 0 ]]; then
            ((DELETED_COUNT++))
        else
            ((FAILED_COUNT++))
        fi
    fi
done

echo ""
echo "📊 DELETION RESULTS:"
echo "==================="
if [[ "$DRY_RUN" == true ]]; then
    echo "🔍 DRY RUN: Would delete $RUN_COUNT runs"
else
    echo "✅ Deletion process completed"
    echo "📋 Target count: $RUN_COUNT runs"
fi

echo ""
echo "✅ Delete utility completed!"