#!/bin/bash
# Output Streamer - Asynchronously streams outputs to indexed datastore
# Usage: output-streamer.sh <action-id> <stage> <command-to-execute>

set -euo pipefail

ACTION_ID="$1"
STAGE="$2"
shift 2
COMMAND="$@"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STREAM_ID="$ACTION_ID:$STAGE:$$"
START_TIME=$(date -Iseconds)

# =================================
# DATASTORE CONFIGURATION
# =================================
# Priority: ElasticSearch -> MongoDB -> Redis Streams -> S3 -> GitHub Artifacts
ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-http://127.0.0.1:9200}"
MONGODB_URL="${MONGODB_URL:-mongodb://127.0.0.1:27017/pipeline_outputs}"
REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6379}"
S3_BUCKET="${S3_BUCKET:-pipeline-outputs-bucket}"
GITHUB_API_URL="https://api.github.com"

echo "🚰 Output streamer starting for: $ACTION_ID/$STAGE"
echo "📝 Command: $COMMAND"

# =================================
# ELASTICSEARCH STREAMING
# =================================
stream_to_elasticsearch() {
    local index_name="pipeline-outputs-$(date +%Y-%m)"
    local doc_id="$STREAM_ID"
    
    # Initialize document
    local init_doc=$(jq -n \
        --arg action_id "$ACTION_ID" \
        --arg stage "$STAGE" \
        --arg stream_id "$STREAM_ID" \
        --arg started_at "$START_TIME" \
        --arg command "$COMMAND" \
        --arg status "running" \
        '{
            action_id: $action_id,
            stage: $stage,
            stream_id: $stream_id,
            command: $command,
            started_at: $started_at,
            status: $status,
            output_lines: [],
            metadata: {
                repository: env.GITHUB_REPOSITORY // "unknown",
                run_id: env.GITHUB_RUN_ID // "unknown",
                actor: env.GITHUB_ACTOR // "unknown"
            }
        }')
    
    # Create initial document
    curl -sf -X PUT "$ELASTICSEARCH_URL/$index_name/_doc/$doc_id" \
        -H "Content-Type: application/json" \
        -d "$init_doc" || return 1
    
    echo "📊 Initialized ElasticSearch document: $index_name/$doc_id"
    
    # Stream output lines asynchronously
    {
        local line_number=0
        while IFS= read -r line; do
            ((line_number++))
            
            # Batch updates for performance (every 10 lines or 5 seconds)
            local line_doc=$(jq -n \
                --arg line "$line" \
                --arg timestamp "$(date -Iseconds)" \
                --arg line_num "$line_number" \
                '{
                    line: $line,
                    timestamp: $timestamp,
                    line_number: ($line_num | tonumber)
                }')
            
            # Append to output_lines array
            curl -sf -X POST "$ELASTICSEARCH_URL/$index_name/_update/$doc_id" \
                -H "Content-Type: application/json" \
                -d "{\"script\":{\"source\":\"ctx._source.output_lines.add(params.line_doc)\",\"params\":{\"line_doc\":$line_doc}}}" \
                >/dev/null 2>&1 || echo "⚠️  Failed to stream line $line_number to ElasticSearch" >&2
                
        done
        
        # Mark completion
        local end_time=$(date -Iseconds)
        curl -sf -X POST "$ELASTICSEARCH_URL/$index_name/_update/$doc_id" \
            -H "Content-Type: application/json" \
            -d "{\"doc\":{\"status\":\"completed\",\"completed_at\":\"$end_time\",\"total_lines\":$line_number}}" \
            >/dev/null 2>&1
            
    } &
    
    ELASTICSEARCH_PID=$!
    return 0
}

# =================================
# MONGODB STREAMING  
# =================================
stream_to_mongodb() {
    local collection="pipeline_outputs"
    
    # Use MongoDB's change streams for real-time updates
    local init_doc=$(jq -n \
        --arg action_id "$ACTION_ID" \
        --arg stage "$STAGE" \
        --arg stream_id "$STREAM_ID" \
        --arg started_at "$START_TIME" \
        --arg command "$COMMAND" \
        '{
            _id: $stream_id,
            action_id: $action_id,
            stage: $stage,
            command: $command,
            started_at: $started_at,
            status: "running",
            output_stream: [],
            metadata: {
                repository: env.GITHUB_REPOSITORY // "unknown",
                run_id: env.GITHUB_RUN_ID // "unknown",
                indexed_at: now
            }
        }')
    
    # Insert initial document using mongosh
    echo "$init_doc" | mongosh "$MONGODB_URL" --eval "
        db.${collection}.insertOne(JSON.parse(cat()));
        db.${collection}.createIndex({action_id: 1, stage: 1, started_at: -1});
    " >/dev/null || return 1
    
    echo "🍃 Initialized MongoDB document: $collection/$STREAM_ID"
    
    # Stream updates
    {
        local line_number=0
        while IFS= read -r line; do
            ((line_number++))
            
            # Use MongoDB's $push for atomic array updates
            mongosh "$MONGODB_URL" --eval "
                db.${collection}.updateOne(
                    {_id: '$STREAM_ID'},
                    {\$push: {output_stream: {
                        line_number: $line_number,
                        content: '$(echo "$line" | sed "s/'/\\\\'/g")',
                        timestamp: new Date()
                    }}}
                )
            " >/dev/null 2>&1 || echo "⚠️  Failed to stream line $line_number to MongoDB" >&2
            
        done
        
        # Mark completion
        mongosh "$MONGODB_URL" --eval "
            db.${collection}.updateOne(
                {_id: '$STREAM_ID'},
                {\$set: {
                    status: 'completed',
                    completed_at: new Date(),
                    total_lines: $line_number
                }}
            )
        " >/dev/null 2>&1
        
    } &
    
    MONGODB_PID=$!
    return 0
}

# =================================
# REDIS STREAMS
# =================================
stream_to_redis_streams() {
    local stream_key="pipeline:$ACTION_ID:$STAGE"
    
    # Add initial entry
    redis-cli XADD "$stream_key" "*" \
        "type" "init" \
        "stream_id" "$STREAM_ID" \
        "command" "$COMMAND" \
        "started_at" "$START_TIME" \
        "status" "running" >/dev/null || return 1
    
    # Set TTL (7 days)
    redis-cli EXPIRE "$stream_key" 604800 >/dev/null
    
    echo "📡 Initialized Redis stream: $stream_key"
    
    # Stream output
    {
        local line_number=0
        while IFS= read -r line; do
            ((line_number++))
            
            redis-cli XADD "$stream_key" "*" \
                "type" "output" \
                "line_number" "$line_number" \
                "content" "$line" \
                "timestamp" "$(date -Iseconds)" >/dev/null 2>&1 || \
                echo "⚠️  Failed to stream line $line_number to Redis" >&2
                
        done
        
        # Mark completion
        redis-cli XADD "$stream_key" "*" \
            "type" "completed" \
            "total_lines" "$line_number" \
            "completed_at" "$(date -Iseconds)" >/dev/null 2>&1
            
    } &
    
    REDIS_PID=$!
    return 0
}

# =================================
# S3 STREAMING (with Lambda indexing)
# =================================
stream_to_s3() {
    local s3_key="$ACTION_ID/$STAGE/$(date +%s).log"
    local temp_file="/tmp/stream-$STREAM_ID.log"
    
    # Create metadata file
    local metadata_file="/tmp/metadata-$STREAM_ID.json"
    jq -n \
        --arg action_id "$ACTION_ID" \
        --arg stage "$STAGE" \
        --arg stream_id "$STREAM_ID" \
        --arg started_at "$START_TIME" \
        --arg s3_key "$s3_key" \
        '{
            action_id: $action_id,
            stage: $stage,
            stream_id: $stream_id,
            started_at: $started_at,
            s3_key: $s3_key,
            status: "running"
        }' > "$metadata_file"
    
    # Upload metadata
    if aws s3 cp "$metadata_file" "s3://$S3_BUCKET/metadata/$ACTION_ID/$STAGE.json"; then
        echo "☁️  S3 metadata uploaded: s3://$S3_BUCKET/metadata/$ACTION_ID/$STAGE.json"
    else
        return 1
    fi
    
    # Stream to temp file and upload periodically
    {
        while IFS= read -r line; do
            echo "$(date -Iseconds) | $line" >> "$temp_file"
            
            # Upload every 50 lines for near real-time access
            if [[ $(wc -l < "$temp_file") -ge 50 ]]; then
                aws s3 cp "$temp_file" "s3://$S3_BUCKET/$s3_key" >/dev/null 2>&1
            fi
        done
        
        # Final upload
        aws s3 cp "$temp_file" "s3://$S3_BUCKET/$s3_key" >/dev/null 2>&1
        
        # Update metadata
        jq '.status = "completed" | .completed_at = now' "$metadata_file" > "${metadata_file}.tmp" && \
        mv "${metadata_file}.tmp" "$metadata_file"
        aws s3 cp "$metadata_file" "s3://$S3_BUCKET/metadata/$ACTION_ID/$STAGE.json" >/dev/null 2>&1
        
        rm -f "$temp_file" "$metadata_file"
        
    } &
    
    S3_PID=$!
    return 0
}

# =================================
# GITHUB ARTIFACTS FALLBACK
# =================================
stream_to_github_artifacts() {
    local artifact_name="pipeline-output-$ACTION_ID-$STAGE"
    local temp_file="/tmp/github-artifact-$STREAM_ID.log"
    
    echo "📦 Streaming to GitHub artifact: $artifact_name"
    
    # Stream to local file
    {
        while IFS= read -r line; do
            echo "$(date -Iseconds) | $line" >> "$temp_file"
        done
        
        # Upload as GitHub artifact (if in Actions environment)
        if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
            cp "$temp_file" "$GITHUB_WORKSPACE/pipeline-output-$STAGE.log"
            echo "artifact-path=$GITHUB_WORKSPACE/pipeline-output-$STAGE.log" >> "$GITHUB_OUTPUT"
        fi
        
    } &
    
    GITHUB_PID=$!
    return 0
}

# =================================
# MAIN EXECUTION WITH OUTPUT CAPTURE
# =================================
main() {
    local streaming_pids=()
    local streaming_methods=()
    
    echo "🔧 Setting up output streaming..."
    
    # Try multiple streaming targets
    if curl -sf "$ELASTICSEARCH_URL" >/dev/null 2>&1; then
        if stream_to_elasticsearch; then
            streaming_pids+=($ELASTICSEARCH_PID)
            streaming_methods+=("elasticsearch")
        fi
    fi
    
    if command -v mongosh >/dev/null 2>&1; then
        if stream_to_mongodb; then
            streaming_pids+=($MONGODB_PID)
            streaming_methods+=("mongodb")
        fi
    fi
    
    if command -v redis-cli >/dev/null 2>&1 && redis-cli ping >/dev/null 2>&1; then
        if stream_to_redis_streams; then
            streaming_pids+=($REDIS_PID)
            streaming_methods+=("redis-streams")
        fi
    fi
    
    if command -v aws >/dev/null 2>&1; then
        if stream_to_s3; then
            streaming_pids+=($S3_PID)
            streaming_methods+=("s3")
        fi
    fi
    
    # Always have GitHub artifacts as fallback
    if stream_to_github_artifacts; then
        streaming_pids+=($GITHUB_PID)
        streaming_methods+=("github-artifacts")
    fi
    
    echo "📡 Active streaming methods: ${streaming_methods[*]}"
    
    # Execute command with output capture
    echo "🚀 Executing command: $COMMAND"
    
    # Use script command to capture all output including colors
    exec > >(tee >(while IFS= read -r line; do
        echo "$line"  # Original output to stdout
        
        # Send to all streaming processes
        for pid in "${streaming_pids[@]}"; do
            echo "$line" >&"$pid" 2>/dev/null || true
        done
    done))
    
    # Execute the actual command
    local exit_code=0
    eval "$COMMAND" || exit_code=$?
    
    # Close all streaming processes
    for pid in "${streaming_pids[@]}"; do
        exec {pid}>&- 2>/dev/null || true
    done
    
    # Wait for streaming to complete
    for pid in "${streaming_pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
    
    echo "✅ Output streaming completed. Methods used: ${streaming_methods[*]}"
    return $exit_code
}

main "$@"