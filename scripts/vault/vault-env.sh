#!/bin/bash
# 🔐 Vault Environment Variable Manager
# Dynamically loads secrets from Vault into environment variables

set -e

echo "🔐 Loading environment variables from Vault..."

# Check if Vault is available
if ! docker exec dev-vault vault status >/dev/null 2>&1; then
    echo "❌ Vault not available"
    exit 1
fi

# Function to get secret from Vault
get_vault_secret() {
    local path=$1
    local key=$2
    docker exec -e VAULT_ADDR=http://localhost:8200 -e VAULT_TOKEN=root \
        dev-vault vault kv get -field="$key" "secret/$path" 2>/dev/null
}

# Load GitHub credentials
export GITHUB_TOKEN=$(get_vault_secret "git/github" "token")
export GITHUB_USERNAME=$(get_vault_secret "git/github" "username")

# Load GitLab credentials  
export GITLAB_TOKEN=$(get_vault_secret "git/gitlab" "token")
export GITLAB_USERNAME=$(get_vault_secret "git/gitlab" "username")

# Legacy compatibility
export GITHUB_PAT="$GITHUB_TOKEN"

echo "✅ Environment variables loaded from Vault:"
echo "   GITHUB_USERNAME: $GITHUB_USERNAME"
echo "   GITHUB_TOKEN: ${GITHUB_TOKEN:0:10}..."
echo "   GITLAB_USERNAME: $GITLAB_USERNAME" 
echo "   GITLAB_TOKEN: ${GITLAB_TOKEN:0:10}..."

# Execute command with loaded environment
if [ $# -gt 0 ]; then
    echo ""
    echo "🚀 Executing: $*"
    exec "$@"
fi
