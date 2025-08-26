#!/bin/bash

# Setup GitLab authentication using Vault-managed tokens
# Configures GitLab remote with token retrieved from HashiCorp Vault

set -e

VAULT_ADDR="http://localhost:8200"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_CONTAINER="dev-vault"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Function to execute Vault commands
vault_exec() {
    docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" "$VAULT_CONTAINER" vault "$@"
}

echo -e "${BOLD}${BLUE}🔐 SETUP GITLAB WITH VAULT TOKEN${NC}"
echo -e "${BOLD}${BLUE}================================${NC}"
echo -e "${BLUE}🚀 Setting up GitLab authentication using Vault...${NC}"
echo ""

# Check Vault status
echo -e "${BLUE}🔍 Checking Vault status...${NC}"
if ! docker ps | grep -q "$VAULT_CONTAINER"; then
    echo -e "${RED}❌ Vault container not running${NC}"
    echo -e "${YELLOW}💡 Start Vault with: cd sec-devops-tools/docker && docker-compose -f docker-compose.vault.yml up -d vault${NC}"
    exit 1
fi

if ! vault_exec status >/dev/null 2>&1; then
    echo -e "${RED}❌ Vault is not accessible${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Vault is healthy and ready${NC}"
echo ""

# Get GitLab token from Vault
echo -e "${BLUE}🔑 Retrieving GitLab token from Vault...${NC}"
GITLAB_TOKEN=$(vault_exec kv get -field="token" secret/git/gitlab 2>/dev/null)
GITLAB_USERNAME=$(vault_exec kv get -field="username" secret/git/gitlab 2>/dev/null)

if [[ -z "$GITLAB_TOKEN" || -z "$GITLAB_USERNAME" ]]; then
    echo -e "${RED}❌ GitLab token not found in Vault${NC}"
    echo -e "${YELLOW}💡 Run: ./scripts/vault/migrate-tokens-to-vault.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Token retrieved from Vault${NC}"
echo -e "${BLUE}   Username: $GITLAB_USERNAME${NC}"
echo ""

# Configure GitLab remote
echo -e "${BLUE}📋 Setting up GitLab remote:${NC}"
echo -e "${BLUE}   Username: $GITLAB_USERNAME${NC}"
echo -e "${BLUE}   Repository: https://gitlab.com/$GITLAB_USERNAME/oracle-fusion-projects.git${NC}"

# Remove existing GitLab remote if present
git remote remove gitlab 2>/dev/null || true

# Add GitLab remote with token
git remote add gitlab "https://${GITLAB_USERNAME}:${GITLAB_TOKEN}@gitlab.com/${GITLAB_USERNAME}/oracle-fusion-projects.git"

echo -e "${GREEN}✅ GitLab remote configured with Vault-managed token${NC}"
echo ""

# Test connection
echo -e "${BLUE}🧪 Testing GitLab connection...${NC}"
if git ls-remote gitlab >/dev/null 2>&1; then
    echo -e "${GREEN}✅ GitLab connection: SUCCESS${NC}"
    echo -e "${GREEN}✅ Authentication: WORKING${NC}"
    
    # Get token info from Vault for display
    echo -e "${BLUE}🔍 Token info:${NC}"
    CREATED_DATE=$(vault_exec kv get -field="created_date" secret/git/gitlab 2>/dev/null)
    PERMISSIONS=$(vault_exec kv get -field="permissions" secret/git/gitlab 2>/dev/null)
    echo -e "${BLUE}   Created: $CREATED_DATE${NC}"
    echo -e "${BLUE}   Permissions: $PERMISSIONS${NC}"
else
    echo -e "${RED}❌ GitLab connection failed${NC}"
    echo -e "${YELLOW}⚠️  Check your token permissions in Vault${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📋 Current remotes:${NC}"
git remote -v

echo ""
echo -e "${GREEN}🚀 READY FOR DUAL COMMIT!${NC}"
echo -e "${BLUE}Use: ./scripts/git/dual-commit-vault.sh 'Your message'${NC}"

echo ""
echo -e "${BLUE}🔧 Vault Management:${NC}"
echo -e "${BLUE}• View token: ./scripts/vault/vault-credentials-manager.sh get git/gitlab${NC}"
echo -e "${BLUE}• Update token: ./scripts/vault/vault-credentials-manager.sh update git/gitlab token=NEW_TOKEN${NC}"
echo -e "${BLUE}• List all: ./scripts/vault/vault-credentials-manager.sh list${NC}"