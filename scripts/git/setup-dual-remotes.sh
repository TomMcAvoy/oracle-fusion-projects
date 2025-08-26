#!/bin/bash

# Setup Script for Dual Platform Git Remotes
# Configures both GitHub and GitLab remotes

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}🔧 DUAL PLATFORM GIT SETUP${NC}"
echo -e "${BOLD}${BLUE}===========================${NC}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not a git repository${NC}"
    echo -e "${YELLOW}Initialize git first: git init${NC}"
    exit 1
fi

# Get current remotes
echo -e "${BLUE}📋 Current remotes:${NC}"
git remote -v || echo "   No remotes configured"
echo ""

# Prompt for GitHub URL
echo -e "${YELLOW}🐙 GitHub Setup:${NC}"
read -p "Enter GitHub repository URL: " GITHUB_URL

if [[ -z "$GITHUB_URL" ]]; then
    echo -e "${RED}❌ GitHub URL is required${NC}"
    exit 1
fi

# Prompt for GitLab URL  
echo -e "${YELLOW}🦊 GitLab Setup:${NC}"
read -p "Enter GitLab repository URL: " GITLAB_URL

if [[ -z "$GITLAB_URL" ]]; then
    echo -e "${RED}❌ GitLab URL is required${NC}"
    exit 1
fi

# Setup method selection
echo ""
echo -e "${YELLOW}🛠️  Setup Method:${NC}"
echo "1. Multiple remotes (origin=GitHub, gitlab=GitLab)"
echo "2. Single remote pushes to both (origin pushes to both platforms)"
echo ""
read -p "Choose method (1 or 2): " -n 1 -r
echo ""

case $REPLY in
    1)
        echo -e "${BLUE}Setting up multiple remotes...${NC}"
        
        # Remove existing remotes
        git remote remove origin 2>/dev/null || true
        git remote remove gitlab 2>/dev/null || true
        
        # Add GitHub as origin
        git remote add origin "$GITHUB_URL"
        echo -e "${GREEN}✅ Added GitHub as 'origin'${NC}"
        
        # Add GitLab as gitlab
        git remote add gitlab "$GITLAB_URL"
        echo -e "${GREEN}✅ Added GitLab as 'gitlab'${NC}"
        
        echo ""
        echo -e "${BLUE}📋 Usage:${NC}"
        echo -e "${BLUE}  Push to GitHub: git push origin main${NC}"
        echo -e "${BLUE}  Push to GitLab: git push gitlab main${NC}"
        echo -e "${BLUE}  Push to both: git push origin main && git push gitlab main${NC}"
        ;;
        
    2)
        echo -e "${BLUE}Setting up single remote for dual push...${NC}"
        
        # Remove existing remotes
        git remote remove origin 2>/dev/null || true
        git remote remove gitlab 2>/dev/null || true
        
        # Add GitHub as origin (for fetching)
        git remote add origin "$GITHUB_URL"
        echo -e "${GREEN}✅ Added GitHub as 'origin' (fetch)${NC}"
        
        # Add GitLab as additional push URL
        git remote set-url origin --add "$GITLAB_URL"
        echo -e "${GREEN}✅ Added GitLab as additional push URL${NC}"
        
        echo ""
        echo -e "${BLUE}📋 Usage:${NC}"
        echo -e "${BLUE}  Push to both: git push origin main${NC}"
        echo -e "${BLUE}  (Single command pushes to both platforms!)${NC}"
        ;;
        
    *)
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
        ;;
esac

# Show final configuration
echo ""
echo -e "${BOLD}${GREEN}✅ SETUP COMPLETE${NC}"
echo -e "${GREEN}===================${NC}"
echo ""
echo -e "${BLUE}🔗 Final remote configuration:${NC}"
git remote -v

# Create helper aliases
echo ""
echo -e "${BLUE}💡 Optional Git Aliases:${NC}"
echo "git config --global alias.push-both '!git push origin main && git push gitlab main'"
echo "git config --global alias.dual-status '!git status && echo && git remote -v'"

# Test connectivity
echo ""
echo -e "${YELLOW}🔍 Testing connectivity...${NC}"

if git ls-remote origin &>/dev/null; then
    echo -e "${GREEN}✅ GitHub connection: OK${NC}"
else
    echo -e "${RED}❌ GitHub connection: FAILED${NC}"
fi

if [[ $REPLY == "1" ]]; then
    if git ls-remote gitlab &>/dev/null; then
        echo -e "${GREEN}✅ GitLab connection: OK${NC}"
    else
        echo -e "${RED}❌ GitLab connection: FAILED${NC}"
    fi
fi

echo ""
echo -e "${BOLD}${BLUE}🚀 READY FOR DUAL PLATFORM DEVELOPMENT!${NC}"