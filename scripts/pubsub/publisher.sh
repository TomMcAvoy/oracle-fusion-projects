#!/bin/bash
# Generic Message Publisher
# Usage: publisher.sh <action-id> <event-type> <payload-json>

set -euo pipefail

ACTION_ID="$1"
EVENT_TYPE="$2"
PAYLOAD="${3:-{}}"
TIMESTAMP=$(date -Iseconds)

# Message format: action-id:event-type:timestamp:payload
MESSAGE="$ACTION_ID:$EVENT_TYPE:$TIMESTAMP:$PAYLOAD"

echo "📤 Publishing: $EVENT_TYPE for action $ACTION_ID"

# =================================
# REDIS PUB/SUB
# =================================
publish_redis() {
    local channel="pipeline-events"
    local pattern_channel="$EVENT_TYPE:$ACTION_ID"
    
    if command -v redis-cli >/dev/null 2>&1; then
        # Publish to general channel
        echo "$MESSAGE" | redis-cli -x PUBLISH "$channel" || return 1
        
        # Publish to pattern-specific channel for targeted subscriptions
        echo "$MESSAGE" | redis-cli -x PUBLISH "$pattern_channel" || return 1
        
        # Store in action-specific list for persistence
        echo "$MESSAGE" | redis-cli -x LPUSH "action:$ACTION_ID:events" || return 1
        redis-cli EXPIRE "action:$ACTION_ID:events" 3600 || return 1  # 1 hour TTL
        
        echo "✅ Published to Redis channels: $channel, $pattern_channel"
        return 0
    else
        echo "❌ Redis not available"
        return 1
    fi
}

# =================================
# FILE-BASED FALLBACK
# =================================
publish_file() {
    local message_dir="/tmp/pipeline-messages"
    local action_dir="$message_dir/$ACTION_ID"
    local event_file="$action_dir/$EVENT_TYPE.json"
    local global_events="$message_dir/global-events.log"
    
    mkdir -p "$action_dir"
    
    # Write event to action-specific file
    echo "$MESSAGE" > "$event_file"
    
    # Append to global events log
    echo "$MESSAGE" >> "$global_events"
    
    # Create pattern-based symlinks for easy subscription
    local pattern_dir="$message_dir/patterns/$EVENT_TYPE"
    mkdir -p "$pattern_dir"
    ln -sf "$event_file" "$pattern_dir/$ACTION_ID.json"
    
    echo "✅ Published to file system: $event_file"
    return 0
}

# =================================
# WEBHOOK FALLBACK
# =================================
publish_webhook() {
    local webhook_url="${WEBHOOK_ENDPOINT:-}"
    
    if [[ -n "$webhook_url" ]]; then
        local webhook_payload=$(jq -n \
            --arg action_id "$ACTION_ID" \
            --arg event_type "$EVENT_TYPE" \
            --arg timestamp "$TIMESTAMP" \
            --argjson payload "$PAYLOAD" \
            '{
                action_id: $action_id,
                event_type: $event_type,
                timestamp: $timestamp,
                payload: $payload
            }')
        
        if timeout 10s curl -sf -X POST "$webhook_url" \
            -H "Content-Type: application/json" \
            -d "$webhook_payload"; then
            echo "✅ Published to webhook: $webhook_url"
            return 0
        else
            echo "❌ Webhook publish failed"
            return 1
        fi
    fi
    
    return 1
}

# =================================
# MAIN PUBLISHING LOGIC
# =================================
main() {
    local success=false
    
    # Try Redis first
    if publish_redis; then
        success=true
    fi
    
    # Always use file system as backup/persistence
    if publish_file; then
        success=true
    fi
    
    # Try webhook if configured
    publish_webhook || true
    
    if $success; then
        echo "🎉 Message published successfully"
        return 0
    else
        echo "💥 All publishing methods failed"
        return 1
    fi
}

main "$@"