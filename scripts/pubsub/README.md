# Async Pub/Sub Pipeline with Indexed Output Streaming

## 🏗️ Architecture Overview

This system solves the **blocking pipeline problem** by implementing an **asynchronous pub/sub pattern** with **indexed output streaming**. Business logic is completely decoupled from GitHub Actions runners.

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  GitHub Actions │    │  Message Broker │    │ Indexed Storage │
│     Runner      │    │  (Redis/File)   │    │ (Multi-backend) │
│                 │    │                 │    │                 │
│ 1. Publish      │───▶│ 2. Event Queue  │    │ 4. Query API    │
│    Events       │    │                 │    │                 │
│                 │    │ 3. Subscribers  │───▶│ 📊 ElasticSearch│
│ 5. Query        │◄───┤    Execute      │    │ 🍃 MongoDB      │
│    Outputs      │    │    Business     │    │ 📡 Redis Streams│
│                 │    │    Logic        │    │ ☁️  S3 + Lambda │
│ 6. Generate     │    │                 │    │ 📦 GitHub Arts  │
│    Reports      │    │ 🚰 Output       │    │                 │
└─────────────────┘    │    Streamer     │    └─────────────────┘
                       └─────────────────┘
```

## 🔄 Message Flow

### 1. **Event Publishing**
```bash
# GitHub Actions Runner publishes events
./scripts/pubsub/publisher.sh "action-123" "build-requested" '{"branch":"main","commit":"abc123"}'
```

### 2. **Pattern-Based Subscription**
```bash
# Build subscriber listens for specific patterns
SUBSCRIBE_PATTERNS=(
    "build-requested:action-123"
    "build-retry:action-123"  
)
```

### 3. **Business Logic Execution with Output Streaming**
```bash
# Execute business logic with async output streaming
./scripts/pubsub/output-streamer.sh "action-123" "build" \
    "mvn clean install"
```

### 4. **Asynchronous Output Retrieval**
```bash
# GitHub Actions queries outputs independently
./scripts/pubsub/output-query-api.sh get-logs "action-123" "build" 100
```

## 🎯 Key Benefits

### ✅ **Non-Blocking Architecture**
- Each stage runs independently 
- Failures in one stage don't block others
- Escape mechanisms prevent infinite waits

### ✅ **Pluggable Actions** 
- Add new actions by creating new subscribers
- Subscribe to action-id patterns
- Zero impact on existing workflows

### ✅ **Indexed Output Storage**
- Real-time streaming to multiple backends
- Searchable logs and structured data
- GitHub can query outputs asynchronously

### ✅ **Enterprise Scalability**
- Redis pub/sub for high throughput
- ElasticSearch for log analytics  
- S3 for long-term archival
- MongoDB for structured queries

## 📊 Output Storage Backends

### **ElasticSearch** (Primary - Log Analytics)
```json
{
  "action_id": "pipeline-123-build",
  "stage": "build", 
  "status": "completed",
  "output_lines": [
    {"line": "[INFO] Building project...", "timestamp": "2024-01-01T10:00:00Z"},
    {"line": "[INFO] Tests passed: 45/45", "timestamp": "2024-01-01T10:05:00Z"}
  ],
  "metadata": {"repository": "org/repo", "run_id": "12345"}
}
```

### **MongoDB** (Structured Data)
```javascript
{
  _id: "pipeline-123-build-456",
  action_id: "pipeline-123", 
  stage: "build",
  command: "mvn clean install",
  output_stream: [
    {line_number: 1, content: "[INFO] Building...", timestamp: ISODate("...")},
    {line_number: 2, content: "[INFO] Success", timestamp: ISODate("...")}
  ],
  metadata: {repository: "org/repo", indexed_at: ISODate("...")}
}
```

### **Redis Streams** (Real-time)
```bash
XADD pipeline:action-123:build * type "output" line_number "1" content "[INFO] Building..." timestamp "2024-01-01T10:00:00Z"
```

## 🚀 Usage Examples

### **Adding New Action Types**

1. **Create Subscriber Script**:
```bash
#!/bin/bash
# scripts/pubsub/deploy-subscriber.sh

SUBSCRIBE_PATTERNS=(
    "deploy-requested:$1"
    "deploy-retry:$1"
)

execute_deploy_action() {
    # Your deployment logic here
    "$SCRIPT_DIR/output-streamer.sh" "$ACTION_ID" "deploy" \
        "kubectl apply -f k8s/"
}
```

2. **Add to GitHub Actions**:
```yaml
deploy-subscriber:
  needs: event-publisher
  runs-on: self-hosted
  steps:
    - name: Subscribe to Deploy Events
      run: ./scripts/pubsub/deploy-subscriber.sh "${{ needs.event-publisher.outputs.action-id }}"
```

### **Querying Outputs**

```bash
# Get current status
./scripts/pubsub/output-query-api.sh get-status "action-123" "build"

# Get last 100 log lines  
./scripts/pubsub/output-query-api.sh get-logs "action-123" "build" 100

# Search for errors
./scripts/pubsub/output-query-api.sh search "action-123" "build" "error|exception"

# Stream logs in real-time
./scripts/pubsub/output-query-api.sh stream-logs "action-123" "build"
```

### **Escape Mechanisms**

```bash
# Business logic can escape gracefully
if check_prerequisites_failed; then
    echo "Prerequisites failed - triggering escape"
    exit 42  # Special escape code
fi

# Timeout-based escapes
timeout 300s ./long-running-process.sh || {
    if [[ $? == 124 ]]; then
        echo "Process timed out - escaped"
        exit 42
    fi
}
```

## 🔧 Configuration

### **Environment Variables**
```bash
# Message Broker
REDIS_URL="redis://127.0.0.1:6379"
MESSAGE_BROKER="redis"  # redis, file, webhook

# Output Storage
ELASTICSEARCH_URL="http://127.0.0.1:9200" 
MONGODB_URL="mongodb://127.0.0.1:27017/pipeline_outputs"
S3_BUCKET="pipeline-outputs-bucket"

# Workflow Settings
PIPELINE_TIMEOUT=300
RETRY_ATTEMPTS=2
ESCAPE_ENABLED=true
```

### **GitHub Actions Input**
```yaml
workflow_dispatch:
  inputs:
    action_config:
      default: '{"timeout": 300, "message_broker": "redis", "stream_enabled": true}'
```

## 🎪 Complete Example

```yaml
# Trigger with custom config
{
  "timeout": 600,
  "message_broker": "redis", 
  "retry_policy": "exponential",
  "stream_enabled": true,
  "datastore_backends": ["elasticsearch", "mongodb", "s3"]
}
```

**Result**: 
- ⚡ Non-blocking parallel execution
- 📊 Real-time searchable outputs  
- 🔍 Async querying from GitHub Actions
- 🚪 Graceful escapes prevent pipeline freezing
- 🧩 Easily extensible with new action types

## 🚪 Escape Patterns

| Exit Code | Meaning | Action |
|-----------|---------|---------|
| `0` | Success | Continue pipeline |
| `42` | Graceful escape | Mark as escaped, continue |
| `124` | Timeout | Mark as timeout, continue |  
| `130` | Interrupted | Mark as interrupted, continue |
| `1-41, 43-123, 125-129, 131+` | Hard failure | Mark as failed, stop |

This architecture transforms GitHub Actions from a **synchronous blocking system** into an **asynchronous event-driven platform** that rivals GitLab CI/CD's capabilities.