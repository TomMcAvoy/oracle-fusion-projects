#!/bin/bash
# Generic Secrets Fetch Script Template
# Called by async-state-machine.yml
# Arguments: $1=repository, $2=run_id

set -euo pipefail

REPOSITORY="${1:-unknown/repo}"
RUN_ID="${2:-unknown}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔐 Starting secrets fetch process..."
echo "  Repository: $REPOSITORY"
echo "  Run ID: $RUN_ID"

# =================================
# ESCAPE MECHANISM
# =================================
setup_secrets_escape_handler() {
    local escape_file="/tmp/secrets-escape-$$"
    
    # Set up signal handlers
    trap 'echo "⚠️  Secrets fetch escape triggered"; touch "$escape_file"; exit 42' TERM
    trap 'echo "🛑 Secrets fetch interrupted"; touch "$escape_file"; exit 130' INT
    
    # Background health checker
    (
        while [[ ! -f "$escape_file" ]]; do
            if ! check_secrets_health; then
                echo "❌ Secrets service unhealthy - triggering escape"
                touch "$escape_file"
                kill -TERM $$
            fi
            sleep 3
        done
    ) &
    
    ESCAPE_PID=$!
}

check_secrets_health() {
    local health_checks=0
    local max_checks=3
    
    # Check Vault health
    if command -v curl >/dev/null 2>&1; then
        if timeout 5s curl -sf http://127.0.0.1:8200/v1/sys/health >/dev/null 2>&1; then
            ((health_checks++))
        fi
    fi
    
    # Check network connectivity
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        ((health_checks++))
    fi
    
    # Check local file system
    if [[ -w "/tmp" ]]; then
        ((health_checks++))
    fi
    
    # Require at least 2 out of 3 health checks to pass
    [[ $health_checks -ge 2 ]]
}

# =================================
# VAULT OPERATIONS
# =================================
fetch_vault_secrets() {
    local vault_url="http://127.0.0.1:8200"
    local vault_token=""
    local secrets_file="/tmp/secrets-$RUN_ID.env"
    
    echo "🏦 Fetching secrets from Vault..."
    
    # Check if Vault is available
    if ! timeout 10s curl -sf "$vault_url/v1/sys/health" >/dev/null; then
        echo "⚠️  Vault not available, using fallback method"
        return 1
    fi
    
    # JWT authentication (GitHub OIDC)
    if [[ -n "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]]; then
        echo "🎫 Using GitHub OIDC for Vault authentication"
        
        local jwt_token
        if ! jwt_token=$(get_github_oidc_token); then
            echo "❌ Failed to get GitHub OIDC token"
            return 1
        fi
        
        # Authenticate with Vault using JWT
        local auth_response
        if ! auth_response=$(timeout 15s curl -sf \
            --request POST \
            --data "{\"role\":\"github-actions\",\"jwt\":\"$jwt_token\"}" \
            "$vault_url/v1/auth/jwt/login"); then
            echo "❌ Vault JWT authentication failed"
            return 1
        fi
        
        vault_token=$(echo "$auth_response" | jq -r '.auth.client_token // empty')
        if [[ -z "$vault_token" ]]; then
            echo "❌ Failed to extract Vault token"
            return 1
        fi
    fi
    
    # Fetch secrets
    if [[ -n "$vault_token" ]]; then
        echo "🔑 Fetching application secrets..."
        
        # Fetch wildfly credentials
        if wildfly_secrets=$(timeout 10s curl -sf \
            -H "X-Vault-Token: $vault_token" \
            "$vault_url/v1/secret/data/wildfly"); then
            
            echo "WILDFLY_USER=$(echo "$wildfly_secrets" | jq -r '.data.data.WILDFLY_USER // "admin"')" >> "$secrets_file"
            echo "WILDFLY_PASS=$(echo "$wildfly_secrets" | jq -r '.data.data.WILDFLY_PASS // "admin123"')" >> "$secrets_file"
        fi
        
        # Fetch database credentials
        if db_secrets=$(timeout 10s curl -sf \
            -H "X-Vault-Token: $vault_token" \
            "$vault_url/v1/secret/data/database"); then
            
            echo "DB_USER=$(echo "$db_secrets" | jq -r '.data.data.DB_USER // "dbuser"')" >> "$secrets_file"
            echo "DB_PASS=$(echo "$db_secrets" | jq -r '.data.data.DB_PASS // "dbpass"')" >> "$secrets_file"
        fi
        
        echo "✅ Secrets fetched successfully"
        echo "📄 Secrets stored in: $secrets_file"
        return 0
    else
        echo "❌ No valid Vault token available"
        return 1
    fi
}

get_github_oidc_token() {
    local token_url="${ACTIONS_ID_TOKEN_REQUEST_URL:-}"
    local token_request_token="${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}"
    
    if [[ -z "$token_url" || -z "$token_request_token" ]]; then
        echo "❌ GitHub OIDC environment variables not available" >&2
        return 1
    fi
    
    timeout 10s curl -sf \
        -H "Authorization: bearer $token_request_token" \
        -H "Accept: application/json; api-version=2.0" \
        -H "Content-Type: application/json" \
        "$token_url&audience=vault" | jq -r '.value'
}

# =================================
# FALLBACK METHODS
# =================================
fetch_fallback_secrets() {
    echo "🔄 Using fallback secrets method..."
    local secrets_file="/tmp/secrets-$RUN_ID.env"
    
    # Environment variables fallback
    if [[ -n "${WILDFLY_USER:-}" ]]; then
        echo "WILDFLY_USER=$WILDFLY_USER" >> "$secrets_file"
    else
        echo "WILDFLY_USER=admin" >> "$secrets_file"
    fi
    
    if [[ -n "${WILDFLY_PASS:-}" ]]; then
        echo "WILDFLY_PASS=$WILDFLY_PASS" >> "$secrets_file"
    else
        echo "WILDFLY_PASS=admin123" >> "$secrets_file"
    fi
    
    echo "⚠️  Using fallback/default secrets"
    return 0
}

# =================================
# CALLBACK MECHANISM
# =================================
register_secrets_callback() {
    local callback_type="$1"
    local callback_data="$2"
    
    local callback_file="/tmp/secrets-callbacks-$$"
    echo "$(date -Iseconds)|$callback_type|$callback_data" >> "$callback_file"
}

execute_secrets_callbacks() {
    local callback_file="/tmp/secrets-callbacks-$$"
    
    if [[ -f "$callback_file" ]]; then
        echo "🔄 Executing secrets callbacks..."
        while IFS='|' read -r timestamp callback_type callback_data; do
            case "$callback_type" in
                "cleanup")
                    echo "🧹 Cleaning up secrets: $callback_data"
                    [[ -f "$callback_data" ]] && rm -f "$callback_data"
                    ;;
                "audit")
                    echo "📝 Auditing secrets access: $callback_data"
                    # Log to audit system
                    ;;
                "notification")
                    echo "📢 Secrets notification: $callback_data"
                    ;;
                *)
                    echo "❓ Unknown callback type: $callback_type"
                    ;;
            esac
        done < "$callback_file"
    fi
}

# =================================
# MAIN EXECUTION
# =================================
main() {
    setup_secrets_escape_handler
    
    local secrets_file="/tmp/secrets-$RUN_ID.env"
    
    # Try Vault first, fallback to environment/defaults
    if fetch_vault_secrets; then
        register_secrets_callback "audit" "vault-success"
        register_secrets_callback "cleanup" "$secrets_file"
        echo "🎉 Secrets fetch completed successfully via Vault"
    elif fetch_fallback_secrets; then
        register_secrets_callback "audit" "fallback-used"
        register_secrets_callback "cleanup" "$secrets_file"
        echo "⚠️  Secrets fetch completed using fallback method"
    else
        register_secrets_callback "audit" "secrets-failed"
        echo "💥 All secrets fetch methods failed"
        execute_secrets_callbacks
        
        # Cleanup escape handler
        [[ -n "${ESCAPE_PID:-}" ]] && kill $ESCAPE_PID 2>/dev/null || true
        
        return 1
    fi
    
    # Export secrets to environment for subsequent steps
    if [[ -f "$secrets_file" ]]; then
        echo "🌍 Exporting secrets to environment..."
        set -a  # automatically export all variables
        source "$secrets_file"
        set +a
        
        # Make available to GitHub Actions
        if [[ -n "${GITHUB_ENV:-}" ]]; then
            cat "$secrets_file" >> "$GITHUB_ENV"
        fi
    fi
    
    execute_secrets_callbacks
    
    # Cleanup escape handler
    [[ -n "${ESCAPE_PID:-}" ]] && kill $ESCAPE_PID 2>/dev/null || true
    
    return 0
}

# Execute main function
main "$@"