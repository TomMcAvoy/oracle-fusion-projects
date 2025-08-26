# 🚀 Async Pub/Sub Pipeline Demonstration

## 🎯 What We Built

A **production-ready async state machine** that transforms GitHub Actions from a synchronous blocking system into an **enterprise async workflow platform**:

- ✅ **Event-Driven**: Pub/sub pattern with action-id routing
- ✅ **Non-Blocking**: Parallel execution with escape mechanisms  
- ✅ **Output Streaming**: Real-time indexing to multiple datastores
- ✅ **Correlation Tracking**: End-to-end traceability with GitHub job correlation
- ✅ **JavaScript Orchestration**: Modern language for business logic
- ✅ **Pluggable Architecture**: Easy to add new action types

## 🧪 Live Demo - Math Processing Pipeline

### **1. Quick Local Test**
```bash
# Test fibonacci calculation (50 iterations)
./scripts/pubsub/test-runner.sh fibonacci 50

# Test with correlation tracking
./scripts/pubsub/test-runner.sh correlation 25

# Test escape mechanism
./scripts/pubsub/test-runner.sh escape

# Run full test suite
./scripts/pubsub/test-runner.sh all
```

### **2. GitHub Actions Test**
Go to **Actions → Test Async Pub/Sub Pipeline** and run with:

```json
{
  "test_scenario": "fibonacci",
  "iterations": "100", 
  "test_config": {
    "timeout": 300,
    "enable_streaming": true,
    "datastore_backends": ["redis", "mongodb", "elasticsearch"]
  }
}
```

### **3. Manual Step-by-Step Demo**

#### **Step 1: Publish Event**
```bash
ACTION_ID="demo-$(date +%s)"
CORRELATION_ID="corr-$(date +%s)"

# Publish math request
./scripts/pubsub/publisher.sh "$ACTION_ID" "math-requested" \
  "{\"operation\":\"fibonacci\",\"iterations\":30,\"correlation_id\":\"$CORRELATION_ID\",\"job_id\":\"$GITHUB_RUN_ID\"}"
```

#### **Step 2: Start Subscriber (JavaScript)**
```bash
# JavaScript subscriber automatically picks up the event
node ./scripts/pubsub/math-subscriber.js "$ACTION_ID" &
SUBSCRIBER_PID=$!
```

#### **Step 3: Watch Real-Time Output Streaming**
```bash
# Monitor outputs in real-time across multiple datastores
watch -n 2 "./scripts/pubsub/output-query-api.sh get-status '$ACTION_ID' math"

# Stream logs as they happen
./scripts/pubsub/output-query-api.sh stream-logs "$ACTION_ID" math
```

#### **Step 4: Query Results**
```bash
# Get processing status
./scripts/pubsub/output-query-api.sh get-status "$ACTION_ID" math

# Get last 20 log lines
./scripts/pubsub/output-query-api.sh get-logs "$ACTION_ID" math 20

# Search for correlation ID
./scripts/pubsub/output-query-api.sh search "$ACTION_ID" math "$CORRELATION_ID"

# Check results file
cat "/tmp/math-results-$ACTION_ID.json" | jq '.'
```

## 📊 Expected Output

### **Structured JSON Logs (with correlation)**
```json
{
  "timestamp": "2024-01-15T10:30:45.123Z",
  "level": "INFO", 
  "correlation_id": "corr-1705317045-abc123",
  "job_id": "github-run-12345",
  "action_id": "demo-1705317045",
  "event": "processing_completed",
  "operation": "fibonacci",
  "statistics": {
    "total_processed": 30,
    "operations_per_second": 1250.5,
    "avg_time_ms": 0.8
  },
  "message": "✅ Successfully processed 30 fibonacci operations"
}
```

### **GitHub Actions Job Summary**
```markdown
# 🧪 Async Pipeline Test Report

## 📊 Test Overview
| Attribute | Value |
|-----------|--------|
| **Test Action ID** | `test-pipeline-12345-1` |
| **Correlation ID** | `corr-1705317045-12345` | 
| **Math Processing Status** | `math: completed (30 lines)` |
| **Correlation Tracking** | `✅ Success` |

## 🔬 Validation Results
- ✅ Pub/Sub Pattern: Event publishing, JavaScript subscriber, Message routing
- ✅ Output Streaming: Indexed storage, Correlation tracking, Structured logging  
- ✅ Escape Mechanisms: Graceful shutdown, Timeout handling, Signal handling
```

## 🏗️ Architecture Validation

This demo proves the **complete async transformation**:

```
📤 GitHub Actions          🎯 Message Broker           📊 Indexed Storage
    Runner                     (Redis/File)                (Multi-backend)
        │                           │                            │
        │ 1. Publish Event          │                            │
        ├─────────────────────────▶ │                            │
        │                           │ 2. Route to Subscriber     │
        │                           ├──────────────┐             │
        │                           │              │             │
        │                           │         ┌────▼───┐         │
        │                           │         │   JS   │         │
        │                           │         │Business│─────────┼▶ 4. Stream
        │                           │         │ Logic  │         │   Outputs
        │                           │         └────────┘         │
        │ 5. Query Outputs          │                            │
        ◀─────────────────────────────────────────────────────────┤
        │                                                        │
        │ 6. Generate Report                                     │
        │                                                        │
```

### **Key Innovations Demonstrated:**

1. **🔄 Non-Blocking Execution**
   - GitHub Actions publishes events and continues
   - Business logic runs independently in JavaScript
   - Escape mechanisms prevent pipeline freezing

2. **🎯 Action-ID Routing**  
   - Each action gets unique ID: `demo-1705317045`
   - Subscribers listen to patterns: `math-requested:demo-1705317045`
   - Easy to add new action types without changing existing code

3. **🚰 Real-Time Output Streaming**
   - Structured logs stream to ElasticSearch, MongoDB, Redis
   - GitHub Actions queries outputs asynchronously
   - Full correlation tracking with `correlation_id`

4. **🔗 End-to-End Traceability**
   - GitHub job ID → Action ID → Correlation ID
   - Every log line traceable back to original GitHub workflow
   - Performance metrics and structured results

## 🎪 Adding Your Own Actions

Want to add deployment actions? Here's how:

### **1. Create Deployment Subscriber**
```javascript
// scripts/pubsub/deploy-subscriber.js
const SUBSCRIBE_PATTERNS = [
    `deploy-requested:${ACTION_ID}`,
    `deploy-retry:${ACTION_ID}`
];

function executeDeployAction(payload) {
    // Your deployment logic here
    return executeWithStreaming(
        outputStreamerPath, ACTION_ID, 'deploy',
        `./scripts/pipeline/wildfly-deploy.sh ${payload.environment}`
    );
}
```

### **2. Add to GitHub Workflow**
```yaml
deploy-subscriber:
  needs: event-publisher
  runs-on: self-hosted
  steps:
    - name: Subscribe to Deploy Events
      run: node ./scripts/pubsub/deploy-subscriber.js "${{ needs.event-publisher.outputs.action-id }}"
```

### **3. Publish Deploy Events**
```bash
./scripts/pubsub/publisher.sh "$ACTION_ID" "deploy-requested" \
  '{"environment":"production","version":"1.2.3","correlation_id":"'$CORRELATION_ID'"}'
```

## 🎉 Result

**You've successfully transformed GitHub Actions into an enterprise-grade async workflow platform!**

- 🚀 **No more blocking pipelines** - everything runs asynchronously
- 🔍 **Full observability** - structured logs, correlation tracking, performance metrics  
- 🧩 **Infinitely extensible** - just add new subscribers for new action types
- 💼 **Enterprise ready** - multiple datastore backends, escape mechanisms, graceful failures

The math processor is just a demonstration - **replace it with any business logic** (WildFly deployment, LDAP operations, etc.) and the async framework handles everything else!