#!/bin/bash
# Vault Environment Variable Loader (Clean Version)

export GITHUB_TOKEN=$(docker exec -e VAULT_ADDR=http://localhost:8200 -e VAULT_TOKEN=root dev-vault vault kv get -field="token" "secret/git/github" 2>/dev/null)
export GITHUB_USERNAME=$(docker exec -e VAULT_ADDR=http://localhost:8200 -e VAULT_TOKEN=root dev-vault vault kv get -field="username" "secret/git/github" 2>/dev/null)
export GITLAB_TOKEN=$(docker exec -e VAULT_ADDR=http://localhost:8200 -e VAULT_TOKEN=root dev-vault vault kv get -field="token" "secret/git/gitlab" 2>/dev/null)
export GITLAB_USERNAME=$(docker exec -e VAULT_ADDR=http://localhost:8200 -e VAULT_TOKEN=root dev-vault vault kv get -field="username" "secret/git/gitlab" 2>/dev/null)
export GITHUB_PAT="$GITHUB_TOKEN"

echo "Vault environment loaded:"
echo "GITHUB_USERNAME: $GITHUB_USERNAME"  
echo "GITHUB_TOKEN: ${GITHUB_TOKEN:0:15}***"
echo "GITLAB_USERNAME: $GITLAB_USERNAME"
echo "GITLAB_TOKEN: ${GITLAB_TOKEN:0:15}***"
