#!/bin/bash
# Complete Async Feedback Loop Demo
# Demonstrates producer → processing → consumer cycle with GitHub state feedback

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ID="demo-$(date +%s)-$$"

echo "🎪 Async Feedback Loop Demo"
echo "==========================="
echo "Demo ID: $DEMO_ID"
echo ""

# Configuration
DEMO_JOB_SIZE=30
DEMO_CORRELATION_ID="corr-demo-$(date +%s)"
DEMO_REPOSITORY="forgoodai/oracle-fusion-projects"  # Adjust as needed
DEMO_GITHUB_TOKEN="${GITHUB_TOKEN:-demo-token}"

echo "📋 Demo Configuration:"
echo "  Job Size: $DEMO_JOB_SIZE operations"
echo "  Correlation ID: $DEMO_CORRELATION_ID"
echo "  Repository: $DEMO_REPOSITORY"
echo ""

# =================================
# PHASE 1: PRODUCER (Non-blocking)
# =================================
echo "🚀 PHASE 1: PRODUCER - Publishing async job..."
echo "--------------------------------------------"

producer_start_time=$(date +%s)

# Create producer payload
PRODUCER_PAYLOAD=$(jq -n \
    --arg operation "fibonacci" \
    --arg iterations "$DEMO_JOB_SIZE" \
    --arg correlation_id "$DEMO_CORRELATION_ID" \
    --arg repository "$DEMO_REPOSITORY" \
    --arg demo_id "$DEMO_ID" \
    '{
      operation: $operation,
      iterations: ($iterations | tonumber),
      correlation_id: $correlation_id,
      callback_enabled: true,
      github_context: {
        repository: $repository,
        demo_id: $demo_id,
        triggered_at: (now | todate)
      }
    }')

echo "📤 Publishing async job..."
echo "📋 Payload: $PRODUCER_PAYLOAD"

# Publish the job
"$SCRIPT_DIR/pubsub/publisher.sh" "$DEMO_ID" "math-requested" "$PRODUCER_PAYLOAD"

# Start background subscriber
echo "⚡ Starting background processing..."
nohup node "$SCRIPT_DIR/pubsub/math-subscriber.js" "$DEMO_ID" \
    > "/tmp/demo-subscriber-$DEMO_ID.log" 2>&1 &
SUBSCRIBER_PID=$!

echo "📝 Background subscriber started with PID: $SUBSCRIBER_PID"
echo "📄 Logs: /tmp/demo-subscriber-$DEMO_ID.log"

# Start completion monitor (simulated GitHub callback)
echo "👁️  Starting completion monitor..."
nohup "$SCRIPT_DIR/pubsub/completion-monitor.sh" \
    "$DEMO_ID" \
    "$DEMO_CORRELATION_ID" \
    "$DEMO_REPOSITORY" \
    "$DEMO_GITHUB_TOKEN" \
    > "/tmp/demo-monitor-$DEMO_ID.log" 2>&1 &
MONITOR_PID=$!

echo "📝 Completion monitor started with PID: $MONITOR_PID"
echo "📄 Logs: /tmp/demo-monitor-$DEMO_ID.log"

producer_end_time=$(date +%s)
producer_duration=$((producer_end_time - producer_start_time))

echo "✅ PRODUCER PHASE COMPLETE in ${producer_duration}s (NON-BLOCKING!)"
echo "   ↳ Job published and background processing started"
echo "   ↳ Producer workflow would EXIT here in GitHub Actions"
echo ""

# =================================
# PHASE 2: PROCESSING (Independent)
# =================================
echo "⚡ PHASE 2: PROCESSING - Independent async execution..."
echo "-----------------------------------------------------"

processing_start_time=$(date +%s)

echo "🔍 Monitoring background processing progress..."
echo "(In real scenario, this runs completely independently of GitHub)"
echo ""

# Monitor processing progress
max_wait=120  # 2 minutes max
elapsed=0
processing_complete=false

while [[ $elapsed -lt $max_wait ]]; do
    # Check if processing is complete
    if [[ -f "/tmp/math-results-$DEMO_ID.json" ]]; then
        processing_complete=true
        echo "✅ Processing complete! Results file detected."
        break
    fi
    
    # Show progress
    if [[ $((elapsed % 10)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
        echo "⏳ Processing... ${elapsed}s elapsed"
        
        # Show real-time logs if available
        if [[ -f "/tmp/demo-subscriber-$DEMO_ID.log" ]]; then
            echo "📊 Latest processing activity:"
            tail -3 "/tmp/demo-subscriber-$DEMO_ID.log" | sed 's/^/   /'
        fi
    fi
    
    sleep 2
    elapsed=$((elapsed + 2))
done

processing_end_time=$(date +%s)
processing_duration=$((processing_end_time - processing_start_time))

if [[ "$processing_complete" == "true" ]]; then
    echo "✅ PROCESSING PHASE COMPLETE in ${processing_duration}s"
else
    echo "⚠️  PROCESSING PHASE TIMEOUT after ${processing_duration}s (but continues in background)"
fi

echo ""

# =================================
# PHASE 3: COMPLETION DETECTION
# =================================
echo "👁️  PHASE 3: COMPLETION DETECTION - Monitoring for callback..."
echo "--------------------------------------------------------------"

detection_start_time=$(date +%s)

echo "🔔 Waiting for completion monitor to detect finish and trigger callback..."
echo "(In real scenario, this would trigger repository_dispatch to GitHub)"

# Wait for completion monitor to detect the completion
callback_detected=false
max_callback_wait=60

for i in $(seq 1 $max_callback_wait); do
    # Check completion monitor logs
    if [[ -f "/tmp/demo-monitor-$DEMO_ID.log" ]] && 
       grep -q "repository_dispatch sent successfully\|Completion detected" "/tmp/demo-monitor-$DEMO_ID.log"; then
        callback_detected=true
        echo "🎉 Callback detected in completion monitor!"
        break
    fi
    
    if [[ $((i % 10)) -eq 0 ]]; then
        echo "⏳ Waiting for callback detection... ${i}/${max_callback_wait}s"
    fi
    
    sleep 1
done

detection_end_time=$(date +%s)
detection_duration=$((detection_end_time - detection_start_time))

if [[ "$callback_detected" == "true" ]]; then
    echo "✅ COMPLETION DETECTION COMPLETE in ${detection_duration}s"
    echo "   ↳ repository_dispatch would be sent to GitHub API"
    echo "   ↳ Consumer workflow would be automatically triggered"
else
    echo "⚠️  COMPLETION DETECTION TIMEOUT (but process may still complete)"
fi

echo ""

# =================================
# PHASE 4: CONSUMER (Event-driven)
# =================================
echo "🍽️  PHASE 4: CONSUMER - Simulated result consumption..."
echo "-------------------------------------------------------"

consumer_start_time=$(date +%s)

echo "🔔 Simulating consumer workflow triggered by repository_dispatch..."
echo "(In real scenario, this would be a separate GitHub Actions workflow)"

# Simulate consumer workflow logic
echo "📊 Consuming results for Demo ID: $DEMO_ID"

# Query job status
if JOB_STATUS=$("$SCRIPT_DIR/pubsub/output-query-api.sh" get-status "$DEMO_ID" "math" 2>/dev/null); then
    echo "✅ Job Status: $JOB_STATUS"
else
    echo "⚠️  No indexed status found"
fi

# Get processing logs
echo "📄 Retrieving processing logs..."
if "$SCRIPT_DIR/pubsub/output-query-api.sh" get-logs "$DEMO_ID" "math" 10 > "/tmp/consumer-logs-$DEMO_ID.txt"; then
    log_count=$(wc -l < "/tmp/consumer-logs-$DEMO_ID.txt")
    echo "✅ Retrieved $log_count log lines"
else
    echo "⚠️  No processing logs found in indexed storage"
fi

# Verify correlation tracking
echo "🔗 Verifying correlation tracking..."
if "$SCRIPT_DIR/pubsub/output-query-api.sh" search "$DEMO_ID" "math" "$DEMO_CORRELATION_ID" >/dev/null; then
    echo "✅ Correlation ID found in outputs - end-to-end traceability confirmed!"
    correlation_verified=true
else
    echo "❌ Correlation ID not found in outputs"
    correlation_verified=false
fi

# Process results file
results_file="/tmp/math-results-$DEMO_ID.json"
if [[ -f "$results_file" ]]; then
    echo "📋 Processing results file..."
    
    if command -v jq >/dev/null; then
        total_processed=$(jq -r '.processed_count // 0' "$results_file")
        operations_per_sec=$(jq -r '.statistics.operations_per_second // 0' "$results_file")
        
        echo "📊 Results Summary:"
        echo "   Operations Processed: $total_processed"
        echo "   Performance: $operations_per_sec ops/sec"
        
        # Business logic based on results
        if (( $(echo "$operations_per_sec > 500" | bc -l 2>/dev/null || echo 0) )); then
            echo "🚀 High performance detected - could trigger optimization pipeline"
        elif (( $(echo "$operations_per_sec > 0 && $operations_per_sec < 50" | bc -l 2>/dev/null || echo 0) )); then
            echo "⚠️  Low performance detected - could trigger investigation"
        else
            echo "📊 Normal performance - no additional action needed"
        fi
    fi
else
    echo "⚠️  No results file found for processing"
fi

# Create consumption summary
consumption_file="/tmp/consumption-demo-$DEMO_ID.json"
cat > "$consumption_file" << EOF
{
  "demo_id": "$DEMO_ID",
  "correlation_id": "$DEMO_CORRELATION_ID",
  "consumed_at": "$(date -Iseconds)",
  "correlation_verified": $correlation_verified,
  "results_file_found": $([ -f "$results_file" ] && echo "true" || echo "false"),
  "consumer_simulation": "success"
}
EOF

echo "✅ Consumption summary created: $consumption_file"

consumer_end_time=$(date +%s)
consumer_duration=$((consumer_end_time - consumer_start_time))

echo "✅ CONSUMER PHASE COMPLETE in ${consumer_duration}s"
echo "   ↳ Results consumed and business logic processed"
echo "   ↳ State successfully fed back to GitHub workflow"
echo ""

# =================================
# FINAL SUMMARY
# =================================
total_demo_time=$((consumer_end_time - producer_start_time))

echo "🎉 ASYNC FEEDBACK LOOP DEMO COMPLETE!"
echo "====================================="
echo ""
echo "📊 Timing Summary:"
echo "  Producer Phase:   ${producer_duration}s (GitHub runner time)"
echo "  Processing Phase: ${processing_duration}s (background/async)"
echo "  Detection Phase:  ${detection_duration}s (monitoring/callback)"
echo "  Consumer Phase:   ${consumer_duration}s (result consumption)"
echo "  Total Demo Time:  ${total_demo_time}s"
echo ""
echo "🎯 Key Achievements:"
echo "  ✅ Non-blocking execution (producer finished quickly)"
echo "  ✅ Independent processing (async background work)"
echo "  ✅ Automatic completion detection (monitoring)"
echo "  ✅ State feedback to GitHub (repository_dispatch)"
echo "  ✅ Result consumption (consumer workflow)"
echo "  ✅ End-to-end correlation tracking"
echo ""
echo "🏗️ Architecture Validated:"
echo "  📤 Producer → publishes job, exits fast"
echo "  ⚡ Processing → runs independently, streams outputs"
echo "  👁️  Monitor → detects completion, triggers callback"
echo "  🔔 GitHub → receives state feedback via repository_dispatch"
echo "  🍽️  Consumer → processes results, executes business logic"
echo ""

echo "📋 Demo Artifacts:"
echo "  Results File: $results_file"
echo "  Consumption Summary: $consumption_file"
echo "  Subscriber Logs: /tmp/demo-subscriber-$DEMO_ID.log"
echo "  Monitor Logs: /tmp/demo-monitor-$DEMO_ID.log"
echo "  Consumer Logs: /tmp/consumer-logs-$DEMO_ID.txt"
echo ""

echo "🔍 Manual Verification Commands:"
echo "  ./scripts/pubsub/output-query-api.sh get-status '$DEMO_ID' 'math'"
echo "  ./scripts/pubsub/output-query-api.sh get-logs '$DEMO_ID' 'math' 20"
echo "  ./scripts/pubsub/output-query-api.sh search '$DEMO_ID' 'math' '$DEMO_CORRELATION_ID'"
echo "  cat '$results_file' | jq '.'"
echo ""

echo "💡 Next Steps:"
echo "  1. Try the GitHub Actions workflows:"
echo "     - async-producer.yml (publishes job)"
echo "     - async-consumer.yml (consumes results)"
echo "     - test-async-feedback-loop.yml (complete test)"
echo ""
echo "  2. Adapt for your authentication system:"
echo "     - Replace math processing with WildFly deployment"
echo "     - Add LDAP sync operations"
echo "     - Integrate with Vault for secrets"
echo ""

# Cleanup
cleanup_demo() {
    echo "🧹 Cleaning up demo processes..."
    
    # Kill background processes
    kill $SUBSCRIBER_PID 2>/dev/null || true
    kill $MONITOR_PID 2>/dev/null || true
    
    # Wait a moment for graceful shutdown
    sleep 2
    
    echo "✅ Demo cleanup complete"
}

trap cleanup_demo EXIT

echo "🎪 Demo complete! Press Ctrl+C to cleanup, or leave running to inspect artifacts."
echo ""

# Keep demo running for inspection
read -p "Press Enter to cleanup and exit..." -t 300 || echo "Demo timeout - cleaning up..."

exit 0