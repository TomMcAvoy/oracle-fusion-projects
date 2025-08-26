#!/bin/bash
# Test Runner - Automated testing for async pub/sub pipeline
# Usage: test-runner.sh [test_type] [iterations] [options...]

set -euo pipefail

TEST_TYPE="${1:-all}"
ITERATIONS="${2:-50}"
OPTIONS="${3:-{}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Async Pipeline Test Runner"
echo "=============================="
echo "Test Type: $TEST_TYPE"
echo "Iterations: $ITERATIONS"
echo "Options: $OPTIONS"

# Generate unique test action ID
TEST_ACTION_ID="test-$(date +%s)-$$"
CORRELATION_ID="corr-$(date +%s)-$(uuidgen | cut -d- -f1)"

echo "🆔 Test Action ID: $TEST_ACTION_ID"
echo "🔗 Correlation ID: $CORRELATION_ID"

# =================================
# TEST SCENARIOS
# =================================
run_fibonacci_test() {
    echo "🔢 Running Fibonacci Test..."
    
    # Publish fibonacci request
    "$SCRIPT_DIR/publisher.sh" "$TEST_ACTION_ID" "math-requested" \
        "{\"operation\":\"fibonacci\",\"iterations\":$ITERATIONS,\"correlation_id\":\"$CORRELATION_ID\",\"test_type\":\"fibonacci\"}"
    
    # Start subscriber in background
    node "$SCRIPT_DIR/math-subscriber.js" "$TEST_ACTION_ID" &
    SUBSCRIBER_PID=$!
    
    # Wait for completion with timeout
    if timeout 120s wait $SUBSCRIBER_PID; then
        echo "✅ Fibonacci test completed"
        return 0
    else
        echo "❌ Fibonacci test timed out"
        kill $SUBSCRIBER_PID 2>/dev/null || true
        return 1
    fi
}

run_prime_test() {
    echo "🔍 Running Prime Number Test..."
    
    "$SCRIPT_DIR/publisher.sh" "$TEST_ACTION_ID" "math-requested" \
        "{\"operation\":\"prime\",\"iterations\":$ITERATIONS,\"correlation_id\":\"$CORRELATION_ID\",\"test_type\":\"prime\"}"
    
    node "$SCRIPT_DIR/math-subscriber.js" "$TEST_ACTION_ID" &
    SUBSCRIBER_PID=$!
    
    if timeout 120s wait $SUBSCRIBER_PID; then
        echo "✅ Prime test completed"
        return 0
    else
        echo "❌ Prime test timed out"
        kill $SUBSCRIBER_PID 2>/dev/null || true
        return 1
    fi
}

run_async_test() {
    echo "⚡ Running Async Operations Test..."
    
    "$SCRIPT_DIR/publisher.sh" "$TEST_ACTION_ID" "math-requested" \
        "{\"operation\":\"async\",\"iterations\":$ITERATIONS,\"correlation_id\":\"$CORRELATION_ID\",\"test_type\":\"async\"}"
    
    node "$SCRIPT_DIR/math-subscriber.js" "$TEST_ACTION_ID" &
    SUBSCRIBER_PID=$!
    
    if timeout 120s wait $SUBSCRIBER_PID; then
        echo "✅ Async test completed"
        return 0
    else
        echo "❌ Async test timed out"
        kill $SUBSCRIBER_PID 2>/dev/null || true
        return 1
    fi
}

run_escape_test() {
    echo "🚪 Running Escape Mechanism Test..."
    
    # Start subscriber
    node "$SCRIPT_DIR/math-subscriber.js" "$TEST_ACTION_ID" &
    SUBSCRIBER_PID=$!
    
    # Publish request
    "$SCRIPT_DIR/publisher.sh" "$TEST_ACTION_ID" "math-requested" \
        "{\"operation\":\"fibonacci\",\"iterations\":1000,\"correlation_id\":\"$CORRELATION_ID\",\"test_type\":\"escape\"}"
    
    # Wait a bit then trigger escape
    sleep 5
    echo "⚠️  Triggering escape mechanism..."
    touch "/tmp/stop-$TEST_ACTION_ID"
    
    # Check if process exits with escape code
    if wait $SUBSCRIBER_PID; then
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 42 ]]; then
            echo "✅ Escape mechanism worked (exit code 42)"
            rm -f "/tmp/stop-$TEST_ACTION_ID"
            return 0
        else
            echo "❌ Unexpected exit code: $EXIT_CODE"
            rm -f "/tmp/stop-$TEST_ACTION_ID"
            return 1
        fi
    else
        echo "❌ Escape test failed"
        rm -f "/tmp/stop-$TEST_ACTION_ID"
        return 1
    fi
}

run_load_test() {
    echo "📈 Running Load Test..."
    
    local concurrent_tests=3
    local pids=()
    
    for i in $(seq 1 $concurrent_tests); do
        local test_id="${TEST_ACTION_ID}-load-$i"
        
        (
            "$SCRIPT_DIR/publisher.sh" "$test_id" "math-requested" \
                "{\"operation\":\"hash\",\"iterations\":$ITERATIONS,\"correlation_id\":\"$CORRELATION_ID-$i\",\"test_type\":\"load\"}"
            
            node "$SCRIPT_DIR/math-subscriber.js" "$test_id"
        ) &
        
        pids+=($!)
    done
    
    # Wait for all concurrent tests
    local failures=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failures++))
        fi
    done
    
    if [[ $failures -eq 0 ]]; then
        echo "✅ Load test completed ($concurrent_tests concurrent tests)"
        return 0
    else
        echo "❌ Load test failed ($failures failures)"
        return 1
    fi
}

run_correlation_test() {
    echo "🔗 Running Correlation Tracking Test..."
    
    "$SCRIPT_DIR/publisher.sh" "$TEST_ACTION_ID" "math-requested" \
        "{\"operation\":\"fibonacci\",\"iterations\":20,\"correlation_id\":\"$CORRELATION_ID\",\"test_type\":\"correlation\",\"extra_data\":{\"test_name\":\"correlation_tracking\",\"timestamp\":\"$(date -Iseconds)\"}}"
    
    node "$SCRIPT_DIR/math-subscriber.js" "$TEST_ACTION_ID" &
    SUBSCRIBER_PID=$!
    
    if timeout 60s wait $SUBSCRIBER_PID; then
        # Wait a bit for outputs to be indexed
        sleep 5
        
        # Search for correlation ID in outputs
        if "$SCRIPT_DIR/output-query-api.sh" search "$TEST_ACTION_ID" "math" "$CORRELATION_ID" >/dev/null; then
            echo "✅ Correlation tracking test passed"
            return 0
        else
            echo "❌ Correlation ID not found in outputs"
            return 1
        fi
    else
        echo "❌ Correlation test timed out"
        kill $SUBSCRIBER_PID 2>/dev/null || true
        return 1
    fi
}

# =================================
# OUTPUT VALIDATION
# =================================
validate_outputs() {
    echo "🔍 Validating outputs..."
    
    # Wait for outputs to be indexed
    sleep 10
    
    # Check if we can query status
    if "$SCRIPT_DIR/output-query-api.sh" get-status "$TEST_ACTION_ID" "math" >/dev/null; then
        echo "✅ Output status query successful"
    else
        echo "⚠️  Output status query failed"
    fi
    
    # Check if we can get logs
    if "$SCRIPT_DIR/output-query-api.sh" get-logs "$TEST_ACTION_ID" "math" 10 >/dev/null; then
        echo "✅ Output logs query successful"
    else
        echo "⚠️  Output logs query failed"
    fi
    
    # Check results file
    local results_file="/tmp/math-results-$TEST_ACTION_ID.json"
    if [[ -f "$results_file" ]]; then
        echo "✅ Results file created: $results_file"
        
        # Extract performance metrics
        if command -v jq >/dev/null; then
            local ops_per_sec=$(jq -r '.statistics.operations_per_second // 0' "$results_file")
            local total_processed=$(jq -r '.processed_count // 0' "$results_file")
            echo "📊 Performance: $ops_per_sec ops/sec, $total_processed total operations"
        fi
    else
        echo "⚠️  Results file not found"
    fi
}

# =================================
# CLEANUP
# =================================
cleanup() {
    echo "🧹 Cleaning up test artifacts..."
    
    # Kill any remaining processes
    pkill -f "math-subscriber.js.*$TEST_ACTION_ID" 2>/dev/null || true
    pkill -f "math-processor.js.*$TEST_ACTION_ID" 2>/dev/null || true
    
    # Remove temp files
    rm -f "/tmp/stop-$TEST_ACTION_ID"
    rm -f "/tmp/math-processed-$TEST_ACTION_ID"
    rm -f "/tmp/math-results-$TEST_ACTION_ID.json"
    
    # Clean up message directories
    rm -rf "/tmp/pipeline-messages/$TEST_ACTION_ID" 2>/dev/null || true
    
    echo "✅ Cleanup completed"
}

# =================================
# MAIN TEST RUNNER
# =================================
main() {
    local test_results=()
    local start_time=$(date +%s)
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    echo "🚀 Starting tests..."
    
    case "$TEST_TYPE" in
        "fibonacci")
            run_fibonacci_test && test_results+=("fibonacci:PASS") || test_results+=("fibonacci:FAIL")
            ;;
        "prime")
            run_prime_test && test_results+=("prime:PASS") || test_results+=("prime:FAIL")
            ;;
        "async")
            run_async_test && test_results+=("async:PASS") || test_results+=("async:FAIL")
            ;;
        "escape")
            run_escape_test && test_results+=("escape:PASS") || test_results+=("escape:FAIL")
            ;;
        "load")
            run_load_test && test_results+=("load:PASS") || test_results+=("load:FAIL")
            ;;
        "correlation")
            run_correlation_test && test_results+=("correlation:PASS") || test_results+=("correlation:FAIL")
            ;;
        "all")
            run_fibonacci_test && test_results+=("fibonacci:PASS") || test_results+=("fibonacci:FAIL")
            run_prime_test && test_results+=("prime:PASS") || test_results+=("prime:FAIL")
            run_async_test && test_results+=("async:PASS") || test_results+=("async:FAIL")
            run_escape_test && test_results+=("escape:PASS") || test_results+=("escape:FAIL")
            run_correlation_test && test_results+=("correlation:PASS") || test_results+=("correlation:FAIL")
            ;;
        *)
            echo "❌ Unknown test type: $TEST_TYPE"
            echo "Available tests: fibonacci, prime, async, escape, load, correlation, all"
            exit 1
            ;;
    esac
    
    # Validate outputs
    validate_outputs
    
    # Generate test report
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "📋 Test Results Summary"
    echo "======================="
    echo "Test Action ID: $TEST_ACTION_ID"
    echo "Correlation ID: $CORRELATION_ID"
    echo "Duration: ${duration}s"
    echo "Results:"
    
    local passed=0
    local failed=0
    
    for result in "${test_results[@]}"; do
        local test_name=$(echo "$result" | cut -d: -f1)
        local test_status=$(echo "$result" | cut -d: -f2)
        
        if [[ "$test_status" == "PASS" ]]; then
            echo "  ✅ $test_name"
            ((passed++))
        else
            echo "  ❌ $test_name"
            ((failed++))
        fi
    done
    
    echo ""
    echo "Summary: $passed passed, $failed failed"
    
    if [[ $failed -eq 0 ]]; then
        echo "🎉 All tests passed!"
        return 0
    else
        echo "💥 Some tests failed!"
        return 1
    fi
}

main "$@"