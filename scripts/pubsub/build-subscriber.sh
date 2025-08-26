#!/bin/bash
# Build Subscriber - Subscribes to build-requested events
# Usage: build-subscriber.sh <action-id>

set -euo pipefail

ACTION_ID="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBSCRIBER_ID="build-subscriber-$$"

echo "🎯 Build subscriber starting for action: $ACTION_ID"

# =================================
# SUBSCRIPTION PATTERNS
# =================================
SUBSCRIBE_PATTERNS=(
    "build-requested:$ACTION_ID"
    "build-retry:$ACTION_ID"
)

# =================================
# MESSAGE PROCESSING
# =================================
process_build_message() {
    local message="$1"
    local action_id event_type timestamp payload
    
    # Parse message: action-id:event-type:timestamp:payload
    IFS=':' read -r action_id event_type timestamp payload <<< "$message"
    
    echo "📨 Processing: $event_type for $action_id at $timestamp"
    
    case "$event_type" in
        "build-requested"|"build-retry")
            execute_build_action "$payload"
            ;;
        *)
            echo "❓ Unknown event type: $event_type"
            return 1
            ;;
    esac
}

execute_build_action() {
    local payload="$1"
    
    echo "🔨 Executing build action..."
    echo "📋 Payload: $payload"
    
    # Extract build parameters from payload
    local event_name branch commit_sha
    event_name=$(echo "$payload" | jq -r '.event_name // "push"')
    branch=$(echo "$payload" | jq -r '.branch // "main"')
    commit_sha=$(echo "$payload" | jq -r '.commit_sha // "unknown"')
    
    # Publish build-started event
    "$SCRIPT_DIR/publisher.sh" "$ACTION_ID" "build-started" \
        "{\"subscriber_id\":\"$SUBSCRIBER_ID\",\"started_at\":\"$(date -Iseconds)\"}"
    
    # Execute build with output streaming to indexed datastore
    local build_result=0
    
    echo "🚰 Starting build with output streaming..."
    if "$SCRIPT_DIR/output-streamer.sh" "$ACTION_ID" "build" \
        "timeout 240s '$SCRIPT_DIR/../pipeline/build.sh' '$event_name' 'refs/heads/$branch'"; then
        echo "✅ Build completed successfully"
        
        # Publish success event
        "$SCRIPT_DIR/publisher.sh" "$ACTION_ID" "build-completed" \
            "{\"subscriber_id\":\"$SUBSCRIBER_ID\",\"completed_at\":\"$(date -Iseconds)\",\"result\":\"success\"}"
        
        build_result=0
    else
        build_result=$?
        echo "❌ Build failed with exit code: $build_result"
        
        # Check if it was an escape (exit code 42)
        if [[ $build_result -eq 42 ]]; then
            echo "⚠️  Build escaped gracefully"
            "$SCRIPT_DIR/publisher.sh" "$ACTION_ID" "build-escaped" \
                "{\"subscriber_id\":\"$SUBSCRIBER_ID\",\"escaped_at\":\"$(date -Iseconds)\",\"reason\":\"graceful_escape\"}"
        else
            echo "💥 Build failed"
            "$SCRIPT_DIR/publisher.sh" "$ACTION_ID" "build-failed" \
                "{\"subscriber_id\":\"$SUBSCRIBER_ID\",\"failed_at\":\"$(date -Iseconds)\",\"exit_code\":$build_result}"
        fi
    fi
    
    return $build_result
}

# =================================
# REDIS SUBSCRIBER
# =================================
subscribe_redis() {
    echo "📡 Starting Redis subscriber..."
    
    # Build pattern string for redis subscription
    local patterns=""
    for pattern in "${SUBSCRIBE_PATTERNS[@]}"; do
        patterns="$patterns $pattern"
    done
    
    redis-cli PSUBSCRIBE $patterns | while read -r type pattern channel message; do
        if [[ "$type" == "pmessage" ]]; then
            echo "📥 Received message on pattern $pattern: $message"
            
            if process_build_message "$message"; then
                echo "✅ Message processed successfully"
                break  # Exit after successful processing
            else
                echo "❌ Message processing failed"
            fi
        fi
    done
}

# =================================
# FILE-BASED SUBSCRIBER
# =================================
subscribe_file() {
    echo "📁 Starting file-based subscriber..."
    
    local message_dir="/tmp/pipeline-messages"
    local action_dir="$message_dir/$ACTION_ID"
    local processed_file="/tmp/build-processed-$ACTION_ID"
    
    # Polling loop
    local max_wait=300  # 5 minutes
    local elapsed=0
    local interval=2
    
    while [[ $elapsed -lt $max_wait ]]; do
        # Check for build-requested events
        for pattern in "${SUBSCRIBE_PATTERNS[@]}"; do
            local event_type="${pattern%:*}"
            local event_file="$action_dir/$event_type.json"
            
            if [[ -f "$event_file" ]] && [[ ! -f "$processed_file" ]]; then
                echo "📥 Found event file: $event_file"
                
                local message
                if message=$(cat "$event_file"); then
                    touch "$processed_file"  # Mark as processed
                    
                    if process_build_message "$message"; then
                        echo "✅ File-based message processed successfully"
                        return 0
                    else
                        echo "❌ File-based message processing failed"
                        return 1
                    fi
                fi
            fi
        done
        
        sleep $interval
        ((elapsed += interval))
    done
    
    echo "⏰ File-based subscriber timed out after ${max_wait}s"
    return 124
}

# =================================
# MAIN SUBSCRIPTION LOGIC
# =================================
main() {
    # Set up escape handler
    trap 'echo "🛑 Build subscriber interrupted"; exit 130' INT TERM
    
    echo "🎯 Subscribing to patterns: ${SUBSCRIBE_PATTERNS[*]}"
    
    # Try Redis subscription first
    if command -v redis-cli >/dev/null 2>&1 && redis-cli ping >/dev/null 2>&1; then
        if subscribe_redis; then
            echo "🎉 Redis subscription completed"
            return 0
        else
            echo "❌ Redis subscription failed, falling back to file-based"
        fi
    fi
    
    # Fallback to file-based subscription
    if subscribe_file; then
        echo "🎉 File-based subscription completed"
        return 0
    else
        echo "💥 All subscription methods failed"
        return 1
    fi
}

main "$@"