#!/bin/bash

# Dual platform commit script using Vault for token management
# Commits to both GitHub and GitLab using Vault-stored credentials

set -e

VAULT_ADDR="http://localhost:8200"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_CONTAINER="dev-vault"

# Colors for output
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

# Check if commit message provided
if [[ -z "$1" ]]; then
    echo -e "${RED}❌ Usage: $0 'Commit message'${NC}"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0 'Add new feature'"
    echo "  $0 'Fix authentication bug'"
    echo "  $0 '🚀 Deploy version 1.2.3'"
    exit 1
fi

COMMIT_MESSAGE="$1"

echo -e "${BOLD}${BLUE}🔄 DUAL PLATFORM GIT COMMIT (VAULT-ENABLED)${NC}"
echo -e "${BOLD}${BLUE}===========================================${NC}"
echo -e "${BLUE}📝 Commit message: $COMMIT_MESSAGE${NC}"
echo ""

# Check Vault status
check_vault() {
    if ! docker ps | grep -q "$VAULT_CONTAINER"; then
        echo -e "${RED}❌ Vault container not running${NC}"
        echo -e "${YELLOW}💡 Start Vault with: cd sec-devops-tools/docker && docker-compose -f docker-compose.vault.yml up -d vault${NC}"
        return 1
    fi
    
    if ! vault_exec status >/dev/null 2>&1; then
        echo -e "${RED}❌ Vault is not accessible${NC}"
        return 1
    fi
    
    return 0
}

# Setup remotes with Vault tokens
setup_vault_remotes() {
    echo -e "${BLUE}🔐 Setting up remotes with Vault-managed tokens...${NC}"
    
    # Get GitLab token from Vault
    local gitlab_token=$(vault_exec kv get -field="token" secret/git/gitlab 2>/dev/null)
    local gitlab_username=$(vault_exec kv get -field="username" secret/git/gitlab 2>/dev/null)
    
    if [[ -n "$gitlab_token" && -n "$gitlab_username" ]]; then
        # Remove and re-add GitLab remote with current token
        git remote remove gitlab 2>/dev/null || true
        git remote add gitlab "https://${gitlab_username}:${gitlab_token}@gitlab.com/${gitlab_username}/oracle-fusion-projects.git"
        echo -e "${GREEN}✅ GitLab remote configured with Vault token${NC}"
    else
        echo -e "${YELLOW}⚠️  GitLab token not found in Vault, keeping existing remote${NC}"
    fi
    
    # GitHub typically works with existing authentication or can be enhanced similarly
    if ! git remote get-url origin >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  GitHub remote not configured${NC}"
    else
        echo -e "${GREEN}✅ GitHub remote already configured${NC}"
    fi
}

# Detect current branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ -z "$CURRENT_BRANCH" ]]; then
    CURRENT_BRANCH="master"
fi

echo -e "${BLUE}🌿 Current branch: $CURRENT_BRANCH${NC}"

# Check for changes
echo -e "${BLUE}📋 Changes to commit:${NC}"
git status --porcelain

if [[ -z "$(git status --porcelain)" ]]; then
    echo -e "${YELLOW}⚠️  No changes to commit${NC}"
    exit 0
fi

# Check Vault before proceeding
if ! check_vault; then
    echo -e "${YELLOW}⚠️  Vault not available, using existing remotes${NC}"
else
    setup_vault_remotes
fi

echo ""

# Stage and commit
echo -e "${BLUE}📦 Staging changes...${NC}"
git add .

echo -e "${BLUE}💾 Committing changes...${NC}"
git commit -m "$COMMIT_MESSAGE"

# Push to GitHub
echo -e "${BLUE}🐙 Pushing to GitHub...${NC}"
if git push origin "$CURRENT_BRANCH"; then
    echo -e "${GREEN}✅ GitHub push successful${NC}"
    GITHUB_SUCCESS=true
else
    echo -e "${RED}❌ GitHub push failed${NC}"
    GITHUB_SUCCESS=false
fi

# Push to GitLab
echo -e "${BLUE}🦊 Pushing to GitLab...${NC}"
if git push gitlab "$CURRENT_BRANCH"; then
    echo -e "${GREEN}✅ GitLab push successful${NC}"
    GITLAB_SUCCESS=true
else
    echo -e "${RED}❌ GitLab push failed${NC}"
    GITLAB_SUCCESS=false
fi

# Summary
echo ""
echo -e "${BOLD}${BLUE}📊 SUMMARY${NC}"
echo -e "${BOLD}${BLUE}===========${NC}"
echo -e "${GREEN}✅ Committed: $COMMIT_MESSAGE${NC}"

if [[ "$GITHUB_SUCCESS" == "true" ]]; then
    echo -e "${GREEN}✅ GitHub: Pushed successfully${NC}"
else
    echo -e "${RED}❌ GitHub: Push failed${NC}"
fi

if [[ "$GITLAB_SUCCESS" == "true" ]]; then
    echo -e "${GREEN}✅ GitLab: Pushed successfully${NC}"
else
    echo -e "${RED}❌ GitLab: Push failed${NC}"
fi

echo ""
echo -e "${BLUE}🔗 Remote URLs:${NC}"
git remote -v | sed 's/^/   /'

# Vault management tips
if check_vault >/dev/null 2>&1; then
    echo ""
    echo -e "${BLUE}🔐 Vault Token Management:${NC}"
    echo -e "${BLUE}• Update GitLab token: ./scripts/vault/vault-credentials-manager.sh update git/gitlab token=NEW_TOKEN${NC}"
    echo -e "${BLUE}• View token info: ./scripts/vault/vault-credentials-manager.sh get git/gitlab${NC}"
    echo -e "${BLUE}• List all tokens: ./scripts/vault/vault-credentials-manager.sh list${NC}"
fi

# Exit with error if any push failed
if [[ "$GITHUB_SUCCESS" != "true" || "$GITLAB_SUCCESS" != "true" ]]; then
    exit 1
fi