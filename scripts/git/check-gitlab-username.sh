#!/bin/bash

# Helper script to determine GitLab username and test authentication

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}🦊 GITLAB USERNAME & AUTH CHECKER${NC}"
echo -e "${BOLD}${BLUE}===================================${NC}"

echo -e "${YELLOW}You logged in with: thomas.mcavoy@whitestartups.com${NC}"
echo -e "${YELLOW}But your GitLab username might be different...${NC}"
echo ""

echo -e "${BLUE}🔍 Step 1: Find Your GitLab Username${NC}"
echo -e "${BLUE}Go to: https://gitlab.com/-/profile${NC}"
echo -e "${BLUE}Look for the 'Username' field (not email)${NC}"
echo ""

read -p "Enter your GitLab username (from the profile page): " GITLAB_USERNAME

if [[ -z "$GITLAB_USERNAME" ]]; then
    echo -e "${RED}❌ Username cannot be empty${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🔐 Step 2: Choose Authentication Method${NC}"
echo "1. Personal Access Token (recommended)"
echo "2. SSH Key"
echo ""
read -p "Choose method (1 or 2): " -n 1 -r
echo ""

case $REPLY in
    1)
        echo -e "${BLUE}Setting up Personal Access Token...${NC}"
        echo ""
        echo -e "${YELLOW}📋 To create a token:${NC}"
        echo -e "${YELLOW}1. Go to: https://gitlab.com/-/profile/personal_access_tokens${NC}"
        echo -e "${YELLOW}2. Token name: oracle-fusion-projects${NC}"
        echo -e "${YELLOW}3. Scopes: read_repository, write_repository${NC}"
        echo -e "${YELLOW}4. Create token and copy it${NC}"
        echo ""
        read -p "Enter your GitLab Personal Access Token: " -s GITLAB_TOKEN
        echo ""
        
        if [[ -z "$GITLAB_TOKEN" ]]; then
            echo -e "${RED}❌ Token cannot be empty${NC}"
            exit 1
        fi
        
        # Update GitLab remote with token
        GITLAB_URL="https://${GITLAB_USERNAME}:${GITLAB_TOKEN}@gitlab.com/whitestartups.com/e-commerce/oracle-fusion-projects.git"
        git remote set-url gitlab "$GITLAB_URL"
        
        echo -e "${GREEN}✅ GitLab remote updated with token authentication${NC}"
        ;;
        
    2)
        echo -e "${BLUE}Setting up SSH Key...${NC}"
        
        # Check if SSH key exists
        if [[ ! -f ~/.ssh/id_ed25519 ]]; then
            echo -e "${YELLOW}⚠️  No SSH key found. Creating one...${NC}"
            ssh-keygen -t ed25519 -C "thomas.mcavoy@whitestartups.com"
        fi
        
        echo ""
        echo -e "${YELLOW}📋 Add this public key to GitLab:${NC}"
        echo -e "${YELLOW}Go to: https://gitlab.com/-/profile/keys${NC}"
        echo -e "${YELLOW}Paste this key:${NC}"
        echo ""
        cat ~/.ssh/id_ed25519.pub
        echo ""
        read -p "Press Enter after adding the key to GitLab..."
        
        # Update GitLab remote for SSH
        GITLAB_SSH_URL="git@gitlab.com:whitestartups.com/e-commerce/oracle-fusion-projects.git"
        git remote set-url gitlab "$GITLAB_SSH_URL"
        
        echo -e "${GREEN}✅ GitLab remote updated with SSH authentication${NC}"
        ;;
        
    *)
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}🧪 Step 3: Testing Authentication...${NC}"

if git ls-remote gitlab &>/dev/null; then
    echo -e "${GREEN}✅ GitLab authentication: SUCCESS${NC}"
    echo -e "${GREEN}✅ Repository access: CONFIRMED${NC}"
    
    echo ""
    echo -e "${BOLD}${GREEN}🎉 AUTHENTICATION SETUP COMPLETE!${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo ""
    echo -e "${BLUE}🚀 Now you can use dual commit:${NC}"
    echo -e "${BLUE}./scripts/git/dual-commit.sh 'Your commit message'${NC}"
    
else
    echo -e "${RED}❌ GitLab authentication: FAILED${NC}"
    echo ""
    echo -e "${YELLOW}💡 Troubleshooting Tips:${NC}"
    echo -e "${YELLOW}1. Double-check your username: $GITLAB_USERNAME${NC}"
    echo -e "${YELLOW}2. Verify the token has correct permissions${NC}"
    echo -e "${YELLOW}3. Make sure the GitLab repository exists:${NC}"
    echo -e "${YELLOW}   https://gitlab.com/whitestartups.com/e-commerce/oracle-fusion-projects${NC}"
    echo ""
    echo -e "${YELLOW}If repository doesn't exist, create it first on GitLab!${NC}"
fi

echo ""
echo -e "${BLUE}🔗 Current remotes:${NC}"
git remote -v