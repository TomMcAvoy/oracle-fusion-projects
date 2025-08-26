#!/bin/bash

# Quick script to fix GitLab remote URL

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}🔧 FIX GITLAB REMOTE${NC}"
echo -e "${BOLD}${BLUE}===================${NC}"

echo -e "${BLUE}📋 Current remotes:${NC}"
git remote -v
echo ""

echo -e "${YELLOW}🦊 Enter the CORRECT GitLab repository URL:${NC}"
echo -e "${YELLOW}Format: https://gitlab.com/username/repository-name.git${NC}"
echo -e "${YELLOW}Or:     https://gitlab.com/group/subgroup/repository-name.git${NC}"
echo ""
read -p "GitLab URL: " CORRECT_GITLAB_URL

if [[ -z "$CORRECT_GITLAB_URL" ]]; then
    echo -e "${RED}❌ URL cannot be empty${NC}"
    exit 1
fi

# Remove current gitlab remote
echo -e "${BLUE}🗑️  Removing old GitLab remote...${NC}"
git remote remove gitlab 2>/dev/null || true

# Add correct gitlab remote
echo -e "${BLUE}➕ Adding correct GitLab remote...${NC}"
git remote add gitlab "$CORRECT_GITLAB_URL"

echo -e "${GREEN}✅ GitLab remote updated!${NC}"
echo ""

echo -e "${BLUE}📋 New remote configuration:${NC}"
git remote -v
echo ""

echo -e "${BLUE}🧪 Testing GitLab connection...${NC}"
if git ls-remote gitlab &>/dev/null; then
    echo -e "${GREEN}✅ GitLab connection: SUCCESS${NC}"
else
    echo -e "${YELLOW}⚠️  GitLab connection: FAILED (needs authentication)${NC}"
    echo -e "${YELLOW}Run: ./scripts/git/check-gitlab-username.sh to set up auth${NC}"
fi

echo ""
echo -e "${BOLD}${GREEN}🚀 Ready to use dual commit!${NC}"