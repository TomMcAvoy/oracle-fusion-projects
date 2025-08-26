#!/bin/bash

# Setup GitLab remote using token from .secrets/.gitlab_token

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}🔐 SETUP GITLAB WITH SECURE TOKEN${NC}"
echo -e "${BOLD}${BLUE}===================================${NC}"

# Check if token file exists
TOKEN_FILE=".secrets/.gitlab_token"
if [[ ! -f "$TOKEN_FILE" ]]; then
    echo -e "${RED}❌ Token file not found: $TOKEN_FILE${NC}"
    exit 1
fi

# Read token from file
GITLAB_TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r ')

if [[ -z "$GITLAB_TOKEN" ]]; then
    echo -e "${RED}❌ Token file is empty: $TOKEN_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Token loaded from $TOKEN_FILE${NC}"

# GitLab username and repository
GITLAB_USERNAME="TomMcAvoy"
GITLAB_REPO="https://gitlab.com/TomMcAvoy/oracle-fusion-projects.git"

echo -e "${BLUE}📋 Setting up GitLab remote:${NC}"
echo -e "${BLUE}   Username: $GITLAB_USERNAME${NC}"
echo -e "${BLUE}   Repository: $GITLAB_REPO${NC}"

# Remove existing gitlab remote
git remote remove gitlab 2>/dev/null || true

# Add gitlab remote with token
GITLAB_URL_WITH_TOKEN="https://${GITLAB_USERNAME}:${GITLAB_TOKEN}@gitlab.com/TomMcAvoy/oracle-fusion-projects.git"
git remote add gitlab "$GITLAB_URL_WITH_TOKEN"

echo -e "${GREEN}✅ GitLab remote configured with secure token${NC}"

# Test connection
echo -e "${BLUE}🧪 Testing GitLab connection...${NC}"
if git ls-remote gitlab &>/dev/null; then
    echo -e "${GREEN}✅ GitLab connection: SUCCESS${NC}"
    echo -e "${GREEN}✅ Authentication: WORKING${NC}"
else
    echo -e "${RED}❌ GitLab connection: FAILED${NC}"
    echo -e "${YELLOW}💡 Check if the GitLab repository exists:${NC}"
    echo -e "${YELLOW}   https://gitlab.com/TomMcAvoy/oracle-fusion-projects${NC}"
fi

echo ""
echo -e "${BLUE}📋 Current remotes:${NC}"
git remote -v

echo ""
echo -e "${BOLD}${GREEN}🚀 READY FOR DUAL COMMIT!${NC}"
echo -e "${GREEN}Use: ./scripts/git/dual-commit.sh 'Your message'${NC}"