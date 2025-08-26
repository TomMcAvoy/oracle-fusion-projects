#!/bin/bash

# Dual Platform Git Commit Script
# Commits and pushes to both GitHub and GitLab

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
GITHUB_REMOTE="origin"
GITLAB_REMOTE="gitlab"
DEFAULT_BRANCH="main"

echo -e "${BOLD}${BLUE}🔄 DUAL PLATFORM GIT COMMIT${NC}"
echo -e "${BOLD}${BLUE}===========================${NC}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not a git repository${NC}"
    exit 1
fi

# Get commit message from arguments or prompt
if [[ $# -eq 0 ]]; then
    echo -e "${YELLOW}📝 Enter commit message:${NC}"
    read -r COMMIT_MSG
else
    COMMIT_MSG="$*"
fi

if [[ -z "$COMMIT_MSG" ]]; then
    echo -e "${RED}❌ Commit message cannot be empty${NC}"
    exit 1
fi

echo -e "${BLUE}📝 Commit message: ${COMMIT_MSG}${NC}"
echo ""

# Check for uncommitted changes
if [[ -z "$(git status --porcelain)" ]]; then
    echo -e "${YELLOW}⚠️  No changes to commit${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
else
    # Show what will be committed
    echo -e "${BLUE}📋 Changes to commit:${NC}"
    git status --short
    echo ""
fi

# Stage all changes
echo -e "${BLUE}📦 Staging changes...${NC}"
git add .

# Commit changes
echo -e "${BLUE}💾 Committing changes...${NC}"
git commit -m "$COMMIT_MSG" || {
    echo -e "${YELLOW}⚠️  Nothing to commit (already up to date)${NC}"
}

# Push to GitHub
echo -e "${BLUE}🐙 Pushing to GitHub...${NC}"
if git push $GITHUB_REMOTE $DEFAULT_BRANCH; then
    echo -e "${GREEN}✅ GitHub push successful${NC}"
else
    echo -e "${RED}❌ GitHub push failed${NC}"
    GITHUB_FAILED=true
fi

# Push to GitLab (if remote exists)
if git remote get-url $GITLAB_REMOTE &>/dev/null; then
    echo -e "${BLUE}🦊 Pushing to GitLab...${NC}"
    if git push $GITLAB_REMOTE $DEFAULT_BRANCH; then
        echo -e "${GREEN}✅ GitLab push successful${NC}"
    else
        echo -e "${RED}❌ GitLab push failed${NC}"
        GITLAB_FAILED=true
    fi
else
    echo -e "${YELLOW}⚠️  GitLab remote not configured (run setup-dual-remotes.sh first)${NC}"
    GITLAB_FAILED=true
fi

# Summary
echo ""
echo -e "${BOLD}${BLUE}📊 SUMMARY${NC}"
echo -e "${BLUE}==========${NC}"
echo -e "${GREEN}✅ Committed: $COMMIT_MSG${NC}"

if [[ -z "$GITHUB_FAILED" ]]; then
    echo -e "${GREEN}✅ GitHub: Pushed successfully${NC}"
else
    echo -e "${RED}❌ GitHub: Push failed${NC}"
fi

if [[ -z "$GITLAB_FAILED" ]]; then
    echo -e "${GREEN}✅ GitLab: Pushed successfully${NC}"
else
    echo -e "${RED}❌ GitLab: Push failed${NC}"
fi

# Show remote URLs
echo ""
echo -e "${BLUE}🔗 Remote URLs:${NC}"
git remote -v | grep -E "(origin|gitlab)" | while read remote url direction; do
    if [[ "$direction" == "(push)" ]]; then
        echo -e "${BLUE}   $remote: $url${NC}"
    fi
done