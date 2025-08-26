#!/bin/bash
# Completion Monitor - Monitors for job completion and triggers GitHub repository_dispatch
# Usage: completion-monitor.sh <action_id> <correlation_id> <repository> <github_token>

set -euo pipefail

ACTION_ID="${1:-}"
CORRELATION_ID="${2:-}"
REPOSITORY="${3:-}"
GITHUB_TOKEN="${4:-}"

if [[ -z "$ACTION_ID" || -z "$CORRELATION_ID" || -z "$REPOSITORY" || -z "$GITHUB_TOKEN" ]]; then
    echo "❌ Usage: completion-monitor.sh <action_id> <correlation_id> <repository> <github_token>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_LOG="/tmp/completion-monitor-$ACTION_ID.log"

echo "👁️  Completion Monitor Starting..." | tee -a "$MONITOR_LOG"
echo "🆔 Action ID: $ACTION_ID" | tee -a "$MONITOR_LOG"
echo "🔗 Correlation ID: $CORRELATION_ID" | tee -a "$MONITOR_LOG"
echo "📍 Repository: $REPOSITORY" | tee -a "$MONITOR_LOG"

# Configuration
MAX_WAIT_TIME=1800  # 30 minutes max
CHECK_INTERVAL=10   # Check every 10 seconds
COMPLETION_PATTERNS=(
    "math-completed:$ACTION_ID"
    "fibonacci-completed:$ACTION_ID"  # Fibonacci completion events
    "fibonacci-failed:$ACTION_ID"     # Fibonacci failure events  
    "math-escaped:$ACTION_ID"
    "math-failed:$ACTION_ID"
    "data-processing-completed:$ACTION_ID"
    "ml-training-completed:$ACTION_ID"
    "batch-processing-completed:$ACTION_ID"
)

elapsed=0
completion_detected=false
final_status=""
final_payload=""

echo "🔍 Monitoring for completion patterns: ${COMPLETION_PATTERNS[*]}" | tee -a "$MONITOR_LOG"

# Monitor Redis for completion events (primary method)
monitor_redis_completion() {
    echo "📡 Starting Redis completion monitoring..." | tee -a "$MONITOR_LOG"
    
    # Use redis-cli to monitor for completion patterns
    timeout $((MAX_WAIT_TIME + 60)) redis-cli PSUBSCRIBE "${COMPLETION_PATTERNS[@]}" | while read -r line; do
        echo "📥 Redis line: $line" | tee -a "$MONITOR_LOG"
        
        # Parse Redis pmessage format  
        if [[ "$line" == *"pmessage"* ]]; then
            # Extract message from Redis pmessage format
            message=$(echo "$line" | cut -d' ' -f4-)
            echo "📨 Completion message detected: $message" | tee -a "$MONITOR_LOG"
            
            # Parse message format: action_id:event_type:timestamp:payload
            IFS=':' read -r msg_action msg_event msg_time msg_payload <<< "$message"
            
            if [[ "$msg_action" == "$ACTION_ID" ]]; then
                echo "✅ Completion detected for our action!" | tee -a "$MONITOR_LOG"
                echo "$msg_event:$msg_payload" > "/tmp/completion-result-$ACTION_ID"
                break
            fi
        fi
    done 2>&1 | tee -a "$MONITOR_LOG"
}

# Monitor file-based completion (fallback method)
monitor_file_completion() {
    echo "📁 Starting file-based completion monitoring..." | tee -a "$MONITOR_LOG"
    
    local message_dir="/tmp/pipeline-messages/$ACTION_ID"
    
    while [[ $elapsed -lt $MAX_WAIT_TIME ]]; do
        for pattern in "${COMPLETION_PATTERNS[@]}"; do
            local event_type=$(echo "$pattern" | cut -d: -f1)
            local event_file="$message_dir/${event_type}.json"
            
            if [[ -f "$event_file" ]]; then
                echo "📋 Completion file found: $event_file" | tee -a "$MONITOR_LOG"
                local file_content=$(cat "$event_file")
                echo "$event_type:$file_content" > "/tmp/completion-result-$ACTION_ID"
                return 0
            fi
        done
        
        sleep $CHECK_INTERVAL
        elapsed=$((elapsed + CHECK_INTERVAL))
        
        if [[ $((elapsed % 60)) -eq 0 ]]; then
            echo "⏱️  Still monitoring... ${elapsed}s elapsed" | tee -a "$MONITOR_LOG"
        fi
    done
    
    echo "⏰ File-based monitoring timed out after ${MAX_WAIT_TIME}s" | tee -a "$MONITOR_LOG"
    return 1
}

# Check results file for completion
check_results_completion() {
    local results_file="/tmp/math-results-$ACTION_ID.json"
    
    while [[ $elapsed -lt $MAX_WAIT_TIME ]]; do
        if [[ -f "$results_file" ]]; then
            echo "📋 Results file found: $results_file" | tee -a "$MONITOR_LOG"
            
            # Check if the results file indicates completion
            if command -v jq >/dev/null; then
                local completed_at=$(jq -r '.completed_at // empty' "$results_file" 2>/dev/null)
                if [[ -n "$completed_at" ]]; then
                    echo "✅ Job completion detected via results file" | tee -a "$MONITOR_LOG"
                    local results_content=$(cat "$results_file")
                    echo "math-completed:$results_content" > "/tmp/completion-result-$ACTION_ID"
                    return 0
                fi
            fi
        fi
        
        sleep $CHECK_INTERVAL
        elapsed=$((elapsed + CHECK_INTERVAL))
    done
    
    return 1
}

# Trigger GitHub repository_dispatch
trigger_github_callback() {
    local status="$1"
    local payload="$2"
    
    # Get callback type and circuit breaker data from command line arguments
    CALLBACK_TYPE="${5:-async_job_completed}"
    CIRCUIT_BREAKER_DATA="${6:-{}}"
    
    echo "🔔 Triggering GitHub repository_dispatch..." | tee -a "$MONITOR_LOG"
    echo "📋 Event type: $CALLBACK_TYPE" | tee -a "$MONITOR_LOG"
    
    # Create repository_dispatch payload with circuit breaker protection
    local dispatch_payload=$(jq -n \
        --arg event_type "$CALLBACK_TYPE" \
        --arg action_id "$ACTION_ID" \
        --arg correlation_id "$CORRELATION_ID" \
        --arg status "$status" \
        --arg completion_time "$(date -Iseconds)" \
        --arg monitor_pid "$$" \
        --argjson result_payload "$payload" \
        --argjson circuit_data "$CIRCUIT_BREAKER_DATA" \
        '{
          event_type: $event_type,
          client_payload: {
            action_id: $action_id,
            correlation_id: $correlation_id,
            status: $status,
            completion_time: $completion_time,
            monitor_process_id: $monitor_pid,
            result_payload: $result_payload,
            circuit_breaker: $circuit_data
          }
        }')
    
    echo "📤 Dispatch payload:" | tee -a "$MONITOR_LOG"
    echo "$dispatch_payload" | jq '.' | tee -a "$MONITOR_LOG"
    
    # Send repository_dispatch using GitHub API with circuit breaker metadata
    if curl -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPOSITORY/dispatches" \
        -d "$dispatch_payload" 2>&1 | tee -a "$MONITOR_LOG"; then
        
        echo "✅ GitHub repository_dispatch sent successfully!" | tee -a "$MONITOR_LOG"
        echo "🔒 Circuit breaker metadata included for loop prevention" | tee -a "$MONITOR_LOG"
        return 0
    else
        echo "❌ Failed to send repository_dispatch" | tee -a "$MONITOR_LOG"
        return 1
    fi
}

# Main monitoring loop
main_monitor() {
    echo "🚀 Starting completion monitoring..." | tee -a "$MONITOR_LOG"
    
    # Try different monitoring methods in parallel
    (
        # Method 1: Redis monitoring (if available)
        if command -v redis-cli >/dev/null && redis-cli ping >/dev/null 2>&1; then
            monitor_redis_completion
        fi
    ) &
    
    (
        # Method 2: File-based monitoring  
        monitor_file_completion
    ) &
    
    (
        # Method 3: Results file monitoring
        check_results_completion
    ) &
    
    # Wait for any method to detect completion
    wait -n  # Wait for first background job to complete
    
    # Kill other monitoring processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Check if completion was detected
    if [[ -f "/tmp/completion-result-$ACTION_ID" ]]; then
        local completion_data=$(cat "/tmp/completion-result-$ACTION_ID")
        final_status=$(echo "$completion_data" | cut -d: -f1)
        final_payload=$(echo "$completion_data" | cut -d: -f2- || echo '{}')
        
        echo "🎉 Job completion detected!" | tee -a "$MONITOR_LOG"
        echo "📊 Status: $final_status" | tee -a "$MONITOR_LOG"
        echo "📋 Payload: $final_payload" | tee -a "$MONITOR_LOG"
        
        completion_detected=true
        
        # Trigger GitHub callback
        if trigger_github_callback "$final_status" "$final_payload"; then
            echo "✅ Completion monitor successful!" | tee -a "$MONITOR_LOG"
            return 0
        else
            echo "⚠️  GitHub callback failed, but job completed" | tee -a "$MONITOR_LOG"
            return 1
        fi
    else
        echo "⏰ No completion detected within timeout period" | tee -a "$MONITOR_LOG"
        
        # Trigger timeout callback
        local timeout_payload='{"reason":"timeout","elapsed_time":"'$MAX_WAIT_TIME's"}'
        trigger_github_callback "timeout" "$timeout_payload"
        return 1
    fi
}

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up completion monitor..." | tee -a "$MONITOR_LOG"
    
    # Kill any remaining background jobs
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Clean up temp files
    rm -f "/tmp/completion-result-$ACTION_ID"
    
    echo "✅ Completion monitor cleanup complete" | tee -a "$MONITOR_LOG"
}

# Set up cleanup trap
trap cleanup EXIT

# Run the main monitor
if main_monitor; then
    echo "🎉 Completion monitor finished successfully!" | tee -a "$MONITOR_LOG"
    exit 0
else
    echo "❌ Completion monitor failed or timed out" | tee -a "$MONITOR_LOG"
    exit 1
fi