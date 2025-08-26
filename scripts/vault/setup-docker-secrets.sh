#!/bin/bash

# Setup Docker Secrets from Vault
# Creates secret files for Docker Compose from Vault credentials

set -e

VAULT_ADDR="http://localhost:8200"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_CONTAINER="dev-vault"
SECRETS_DIR="/home/tom/GitHub/oracle-fusion-projects/.env.vault.d"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔐 SETTING UP DOCKER SECRETS FROM VAULT${NC}"
echo -e "${BLUE}=======================================${NC}"

# Create secrets directory
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

vault_exec() {
    docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" \
        "$VAULT_CONTAINER" vault "$@"
}

# Function to create secret file from Vault
create_secret_file() {
    local vault_path="$1"
    local vault_field="$2"
    local file_name="$3"
    
    echo -e "${YELLOW}📝 Creating $file_name...${NC}"
    
    vault_exec kv get -field="$vault_field" "$vault_path" > "$SECRETS_DIR/$file_name"
    chmod 600 "$SECRETS_DIR/$file_name"
    
    echo -e "${GREEN}✅ $file_name created${NC}"
}

# Create all secret files
create_secret_file "secret/ldap" "admin_password" "ldap_admin_password"
create_secret_file "secret/ldap" "config_password" "ldap_config_password"
create_secret_file "secret/redis" "password" "redis_password"
create_secret_file "secret/mongodb" "username" "mongo_root_username"
create_secret_file "secret/mongodb" "password" "mongo_root_password"
create_secret_file "secret/mongodb" "admin_password" "mongo_admin_password"
create_secret_file "secret/mongodb" "cache_password" "mongo_cache_password"
create_secret_file "secret/wildfly" "WILDFLY_USER" "wildfly_user"
create_secret_file "secret/wildfly" "WILDFLY_PASS" "wildfly_password"

echo ""
echo -e "${GREEN}🎉 DOCKER SECRETS SETUP COMPLETE!${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""
echo -e "${BLUE}📁 Secret files location: $SECRETS_DIR${NC}"
echo -e "${BLUE}🔒 File permissions: 600 (owner read/write only)${NC}"
echo ""
echo -e "${YELLOW}📋 Files created:${NC}"
ls -la "$SECRETS_DIR" | sed 's/^/  /'
echo ""
echo -e "${YELLOW}🚀 Ready to start services with:${NC}"
echo -e "${YELLOW}   docker-compose -f docker-compose-vault-certs.yml up -d${NC}"
echo ""
echo -e "${BLUE}🔄 To refresh secrets:${NC}"
echo -e "${BLUE}   1. Update secrets in Vault${NC}"
echo -e "${BLUE}   2. Run this script again${NC}"
echo -e "${BLUE}   3. Restart Docker services${NC}"