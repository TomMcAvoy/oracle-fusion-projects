#!/bin/bash
# Output Query API - GitHub Actions queries outputs from indexed datastore
# Usage: output-query-api.sh <action> <action-id> [stage] [options...]

set -euo pipefail

ACTION="$1"  # get-status, get-logs, stream-logs, search
ACTION_ID="$2"
STAGE="${3:-all}"
shift 2; [[ $# -gt 0 ]] && shift 1

echo "🔍 Querying outputs: $ACTION for $ACTION_ID/$STAGE"

# =================================
# ELASTICSEARCH QUERIES
# =================================
query_elasticsearch() {
    local action="$1"
    local index_pattern="pipeline-outputs-*"
    local base_url="$ELASTICSEARCH_URL/$index_pattern/_search"
    
    case "$action" in
        "get-status")
            local query=$(jq -n \
                --arg action_id "$ACTION_ID" \
                --arg stage "$STAGE" \
                '{
                    query: {
                        bool: {
                            must: [
                                {term: {"action_id.keyword": $action_id}},
                                ($stage != "all" | if . then {term: {"stage.keyword": $stage}} else empty end)
                            ]
                        }
                    },
                    _source: ["action_id", "stage", "status", "started_at", "completed_at", "total_lines"],
                    sort: [{"started_at": {"order": "desc"}}]
                }')
                
            curl -sf -X GET "$base_url" \
                -H "Content-Type: application/json" \
                -d "$query" | jq -r '
                    .hits.hits[] | 
                    "\(.fields.stage[0] // .fields.stage): \(.fields.status[0] // .fields.status) (\(.fields.total_lines[0] // 0) lines)"
                '
            ;;
            
        "get-logs")
            local lines="${1:-100}"
            local query=$(jq -n \
                --arg action_id "$ACTION_ID" \
                --arg stage "$STAGE" \
                --arg size "$lines" \
                '{
                    query: {
                        bool: {
                            must: [
                                {term: {"action_id.keyword": $action_id}},
                                ($stage != "all" | if . then {term: {"stage.keyword": $stage}} else empty end)
                            ]
                        }
                    },
                    _source: ["output_lines"],
                    sort: [{"started_at": {"order": "desc"}}],
                    size: ($size | tonumber)
                }')
                
            curl -sf -X GET "$base_url" \
                -H "Content-Type: application/json" \
                -d "$query" | jq -r '.hits.hits[].fields.output_lines[]?.line // empty'
            ;;
            
        "search")
            local search_term="$1"
            local query=$(jq -n \
                --arg action_id "$ACTION_ID" \
                --arg term "$search_term" \
                '{
                    query: {
                        bool: {
                            must: [
                                {term: {"action_id.keyword": $action_id}},
                                {
                                    nested: {
                                        path: "output_lines",
                                        query: {
                                            match: {"output_lines.line": $term}
                                        }
                                    }
                                }
                            ]
                        }
                    },
                    highlight: {
                        fields: {"output_lines.line": {}}
                    }
                }')
                
            curl -sf -X GET "$base_url" \
                -H "Content-Type: application/json" \
                -d "$query" | jq -r '.hits.hits[] | .highlight["output_lines.line"][]?'
            ;;
    esac
}

# =================================
# MONGODB QUERIES
# =================================
query_mongodb() {
    local action="$1"
    local collection="pipeline_outputs"
    
    case "$action" in
        "get-status")
            local filter="{action_id: '$ACTION_ID'"
            [[ "$STAGE" != "all" ]] && filter="$filter, stage: '$STAGE'"
            filter="$filter}"
            
            mongosh "$MONGODB_URL" --eval "
                db.$collection.find(
                    $filter,
                    {action_id: 1, stage: 1, status: 1, started_at: 1, completed_at: 1, 'output_stream.length': 1}
                ).sort({started_at: -1})
            " | jq -r '.[] | "\(.stage): \(.status) (\(.output_stream | length) lines)"'
            ;;
            
        "get-logs")
            local lines="${1:-100}"
            mongosh "$MONGODB_URL" --eval "
                db.$collection.findOne(
                    {action_id: '$ACTION_ID', stage: '$STAGE'},
                    {output_stream: {\$slice: -$lines}}
                )
            " | jq -r '.output_stream[]?.content // empty'
            ;;
            
        "search")
            local search_term="$1"
            mongosh "$MONGODB_URL" --eval "
                db.$collection.find(
                    {
                        action_id: '$ACTION_ID',
                        'output_stream.content': {\$regex: '$search_term', \$options: 'i'}
                    }
                )
            " | jq -r '.[] | .output_stream[] | select(.content | test("'$search_term'"; "i")) | .content'
            ;;
    esac
}

# =================================
# REDIS STREAMS QUERIES
# =================================
query_redis_streams() {
    local action="$1"
    local stream_key="pipeline:$ACTION_ID:$STAGE"
    
    case "$action" in
        "get-status")
            # Get latest status from stream
            redis-cli XREVRANGE "$stream_key" + - COUNT 1 | \
            awk '/type.*completed|running/ {print $2":"$4}'
            ;;
            
        "get-logs")
            local count="${1:-100}"
            redis-cli XRANGE "$stream_key" - + | \
            grep -A1 "type.*output" | \
            grep "content" | \
            cut -d' ' -f2- | \
            tail -n "$count"
            ;;
            
        "stream-logs")
            echo "📡 Streaming logs from Redis..."
            redis-cli XREAD STREAMS "$stream_key" 0-0 | \
            while read -r line; do
                if echo "$line" | grep -q "type.*output"; then
                    echo "$line" | grep "content" | cut -d' ' -f2-
                fi
            done
            ;;
    esac
}

# =================================
# S3 QUERIES
# =================================
query_s3() {
    local action="$1"
    
    case "$action" in
        "get-status")
            aws s3 cp "s3://$S3_BUCKET/metadata/$ACTION_ID/$STAGE.json" - 2>/dev/null | \
            jq -r '"\(.stage): \(.status)"'
            ;;
            
        "get-logs")
            local s3_key=$(aws s3 ls "s3://$S3_BUCKET/$ACTION_ID/$STAGE/" --recursive | \
                          awk '{print $4}' | head -1)
            
            if [[ -n "$s3_key" ]]; then
                aws s3 cp "s3://$S3_BUCKET/$s3_key" - 2>/dev/null | \
                cut -d'|' -f2- | \
                tail -n "${1:-100}"
            fi
            ;;
    esac
}

# =================================
# GITHUB ARTIFACTS QUERIES
# =================================
query_github_artifacts() {
    local action="$1"
    local artifact_name="pipeline-output-$ACTION_ID-$STAGE"
    
    if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
        local artifact_file="$GITHUB_WORKSPACE/pipeline-output-$STAGE.log"
        
        case "$action" in
            "get-status")
                if [[ -f "$artifact_file" ]]; then
                    echo "$STAGE: completed ($(wc -l < "$artifact_file") lines)"
                else
                    echo "$STAGE: not found"
                fi
                ;;
                
            "get-logs")
                [[ -f "$artifact_file" ]] && tail -n "${1:-100}" "$artifact_file"
                ;;
        esac
    fi
}

# =================================
# UNIFIED QUERY INTERFACE
# =================================
main() {
    local results_found=false
    
    echo "🔍 Trying multiple data sources..."
    
    # Try ElasticSearch first
    if curl -sf "$ELASTICSEARCH_URL" >/dev/null 2>&1; then
        echo "📊 Querying ElasticSearch..."
        if query_elasticsearch "$ACTION" "$@"; then
            results_found=true
        fi
    fi
    
    # Try MongoDB
    if command -v mongosh >/dev/null 2>&1; then
        echo "🍃 Querying MongoDB..."
        if query_mongodb "$ACTION" "$@"; then
            results_found=true
        fi
    fi
    
    # Try Redis Streams
    if command -v redis-cli >/dev/null 2>&1 && redis-cli ping >/dev/null 2>&1; then
        echo "📡 Querying Redis Streams..."
        if query_redis_streams "$ACTION" "$@"; then
            results_found=true
        fi
    fi
    
    # Try S3
    if command -v aws >/dev/null 2>&1; then
        echo "☁️  Querying S3..."
        if query_s3 "$ACTION" "$@"; then
            results_found=true
        fi
    fi
    
    # Try GitHub Artifacts fallback
    echo "📦 Querying GitHub Artifacts..."
    if query_github_artifacts "$ACTION" "$@"; then
        results_found=true
    fi
    
    if $results_found; then
        echo "✅ Query completed successfully"
        return 0
    else
        echo "❌ No results found in any datastore"
        return 1
    fi
}

main "$@"