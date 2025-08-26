#!/bin/bash

# Script to help create GitLab repository

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}🦊 CREATE GITLAB REPOSITORY${NC}"
echo -e "${BOLD}${BLUE}===========================${NC}"

echo -e "${YELLOW}📋 The GitLab repository needs to be created first.${NC}"
echo ""
echo -e "${BLUE}🔧 Options to create the repository:${NC}"
echo ""
echo -e "${BOLD}Option 1: Create via GitLab Web UI (Recommended)${NC}"
echo -e "${BLUE}1. Go to: https://gitlab.com/projects/new${NC}"
echo -e "${BLUE}2. Click 'Import project'${NC}" 
echo -e "${BLUE}3. Click 'Repo by URL'${NC}"
echo -e "${BLUE}4. Git repository URL: https://github.com/TomMcAvoy/oracle-fusion-projects.git${NC}"
echo -e "${BLUE}5. Project name: oracle-fusion-projects${NC}"
echo -e "${BLUE}6. Visibility: Choose your preference${NC}"
echo -e "${BLUE}7. Click 'Create project'${NC}"
echo ""

echo -e "${BOLD}Option 2: Create empty repository${NC}"
echo -e "${BLUE}1. Go to: https://gitlab.com/projects/new${NC}"
echo -e "${BLUE}2. Click 'Create blank project'${NC}"
echo -e "${BLUE}3. Project name: oracle-fusion-projects${NC}"
echo -e "${BLUE}4. Uncheck 'Initialize repository with a README'${NC}"
echo -e "${BLUE}5. Click 'Create project'${NC}"
echo ""

echo -e "${BOLD}Option 3: Create via GitLab API${NC}"
echo -e "${BLUE}Using your token to create the repository automatically...${NC}"

# Read token
TOKEN_FILE=".secrets/.gitlab_token"
if [[ -f "$TOKEN_FILE" ]]; then
    GITLAB_TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r ')
    
    echo ""
    echo -e "${YELLOW}🚀 Attempting to create repository via API...${NC}"
    
    RESPONSE=$(curl -s -X POST \
        "https://gitlab.com/api/v4/projects" \
        -H "Authorization: Bearer $GITLAB_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "oracle-fusion-projects",
            "description": "Distributed Authentication System with LDAP integration",
            "visibility": "private",
            "initialize_with_readme": false
        }')
    
    if echo "$RESPONSE" | grep -q '"id"'; then
        echo -e "${GREEN}✅ GitLab repository created successfully!${NC}"
        echo -e "${GREEN}✅ URL: https://gitlab.com/TomMcAvoy/oracle-fusion-projects${NC}"
        echo ""
        echo -e "${BLUE}🎯 Now you can test the dual commit:${NC}"
        echo -e "${BLUE}./scripts/git/dual-commit.sh 'Test after repository creation'${NC}"
    else
        echo -e "${RED}❌ API creation failed. Error response:${NC}"
        echo "$RESPONSE"
        echo ""
        echo -e "${YELLOW}💡 Please create the repository manually using Option 1 above.${NC}"
    fi
else
    echo -e "${RED}❌ Token file not found: $TOKEN_FILE${NC}"
fi

echo ""
echo -e "${BLUE}📋 After creating the repository, test with:${NC}"
echo -e "${BLUE}./scripts/git/dual-commit.sh 'Test dual commit after repo creation'${NC}"