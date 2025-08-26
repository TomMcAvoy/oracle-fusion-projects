#!/bin/bash

# Real-time GitHub Actions Workflow Monitor
# Shows live status of running workflows with auto-refresh

set -e

echo "📊 GITHUB ACTIONS WORKFLOW MONITOR"
echo "=================================="
echo ""

# Check dependencies
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo "❌ Not authenticated with GitHub"
    exit 1
fi

# Configuration
REFRESH_INTERVAL=10
MAX_RUNS=20
AUTO_REFRESH=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--refresh)
            REFRESH_INTERVAL="$2"
            shift 2
            ;;
        -n|--no-auto)
            AUTO_REFRESH=false
            shift
            ;;
        -l|--limit)
            MAX_RUNS="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -r, --refresh SECONDS    Refresh interval (default: 10)"
            echo "  -n, --no-auto           Disable auto-refresh"
            echo "  -l, --limit NUMBER      Max runs to show (default: 20)"
            echo "  -h, --help              Show help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

cd "/home/tom/GitHub/oracle-fusion-projects"

# Function to display workflow status
show_workflow_status() {
    clear
    echo "📊 GITHUB ACTIONS WORKFLOW MONITOR"
    echo "=================================="
    echo "🔄 Auto-refresh: $AUTO_REFRESH (${REFRESH_INTERVAL}s)"
    echo "📅 Updated: $(date '+%H:%M:%S')"
    echo ""
    
    # Get detailed run information
    echo "🏃 ACTIVE/RECENT WORKFLOW RUNS"
    echo "=============================="
    
    local runs=$(gh run list --limit="$MAX_RUNS" --json status,conclusion,name,createdAt,updatedAt,displayTitle,event,databaseId 2>/dev/null)
    
    if [[ "$runs" == "[]" || -z "$runs" ]]; then
        echo "📭 No workflow runs found"
        return
    fi
    
    # Parse and display runs
    echo "$runs" | jq -r '
        .[] | 
        (if .status == "completed" then
            if .conclusion == "success" then "✅"
            elif .conclusion == "failure" then "❌"
            elif .conclusion == "cancelled" then "⚠️"
            else "❓"
            end
        elif .status == "in_progress" then "🏃"
        elif .status == "queued" then "⏳"
        else "❓"
        end) as $icon |
        
        (.createdAt | fromdateiso8601 | strftime("%H:%M:%S")) as $time |
        (.name | if length > 25 then .[0:22] + "..." else . end) as $short_name |
        (.displayTitle | if length > 40 then .[0:37] + "..." else . end) as $short_title |
        
        "\($icon) \($short_name) | \($short_title) | \(.status) | \($time)"
    ' | column -t -s '|'
    
    echo ""
    
    # Show summary statistics
    echo "📈 SUMMARY STATISTICS"
    echo "===================="
    
    local total=$(echo "$runs" | jq length)
    local running=$(echo "$runs" | jq '[.[] | select(.status == "in_progress")] | length')
    local queued=$(echo "$runs" | jq '[.[] | select(.status == "queued")] | length')
    local success=$(echo "$runs" | jq '[.[] | select(.status == "completed" and .conclusion == "success")] | length')
    local failed=$(echo "$runs" | jq '[.[] | select(.status == "completed" and .conclusion == "failure")] | length')
    local cancelled=$(echo "$runs" | jq '[.[] | select(.status == "completed" and .conclusion == "cancelled")] | length')
    
    echo "📊 Total runs: $total"
    echo "🏃 Running: $running"
    echo "⏳ Queued: $queued"
    echo "✅ Success: $success"
    echo "❌ Failed: $failed"
    echo "⚠️ Cancelled: $cancelled"
    
    # Show runner status
    echo ""
    echo "🤖 RUNNER STATUS"
    echo "==============="
    local runners=$(gh api repos/:owner/:repo/actions/runners --jq '.runners[] | "Name: \(.name) | Status: \(.status) | Busy: \(.busy)"' 2>/dev/null)
    if [[ -n "$runners" ]]; then
        echo "$runners"
    else
        echo "No runners found or API access limited"
    fi
    
    if [[ "$AUTO_REFRESH" == "true" ]]; then
        echo ""
        echo "🔄 Auto-refreshing in ${REFRESH_INTERVAL}s... (Ctrl+C to stop)"
    fi
}

# Function to handle cleanup on exit
cleanup() {
    echo ""
    echo "👋 Monitor stopped"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main monitor loop
if [[ "$AUTO_REFRESH" == "true" ]]; then
    while true; do
        show_workflow_status
        sleep "$REFRESH_INTERVAL"
    done
else
    show_workflow_status
fi