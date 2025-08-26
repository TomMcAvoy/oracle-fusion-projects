#!/bin/bash

# Secure LDAP Setup Script - Uses Vault for credential management
# Replacement for quick-ldap-setup.sh with hardcoded passwords

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VAULT_ADDR="http://localhost:8200"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_CONTAINER="dev-vault"

echo -e "${BLUE}🔐 SECURE LDAP SETUP WITH VAULT CREDENTIALS${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Function to get credential from Vault
get_vault_credential() {
    local path="$1"
    local field="$2"
    
    docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" \
        "$VAULT_CONTAINER" vault kv get -field="$field" "$path" 2>/dev/null || {
        echo -e "${RED}❌ Failed to retrieve $field from $path${NC}"
        exit 1
    }
}

# Check if Vault is available
if ! docker ps | grep -q "$VAULT_CONTAINER"; then
    echo -e "${RED}❌ Vault container not found. Starting Vault...${NC}"
    cd ../sec-devops-tools/docker/vault
    docker-compose up -d
    sleep 5
    cd - >/dev/null
fi

echo -e "${YELLOW}🏦 Retrieving LDAP credentials from Vault...${NC}"

# Get credentials from Vault
LDAP_ADMIN_PASSWORD=$(get_vault_credential "secret/ldap" "admin_password")
LDAP_CONFIG_PASSWORD=$(get_vault_credential "secret/ldap" "config_password")
DEV_ADMIN_PASSWORD=$(get_vault_credential "secret/dev-testing" "ldap_quick_setup_admin")

echo -e "${GREEN}✅ Credentials retrieved from Vault${NC}"

# Create secure docker-compose for LDAP
cat > docker-compose-secure-ldap.yml << EOF
version: '3.8'

services:
  openldap-secure:
    image: osixia/openldap:1.5.0
    container_name: secure-ldap-vault
    hostname: ldap.whitestartups.com
    ports:
      - "389:389"
      - "636:636"
    environment:
      LDAP_ORGANISATION: "White Startups Inc"
      LDAP_DOMAIN: "whitestartups.com"
      LDAP_BASE_DN: "dc=whitestartups,dc=com"
      LDAP_ADMIN_PASSWORD: "$LDAP_ADMIN_PASSWORD"
      LDAP_CONFIG_PASSWORD: "$LDAP_CONFIG_PASSWORD"
      LDAP_READONLY_USER: "false"
      LDAP_RFC2307BIS_SCHEMA: "false"
      LDAP_BACKEND: "mdb"
      LDAP_TLS: "true"
      LDAP_TLS_ENFORCE: "false"
      LDAP_REMOVE_CONFIG_AFTER_SETUP: "true"
      LDAP_LOG_LEVEL: "256"
    volumes:
      - secure_ldap_data:/var/lib/ldap
      - secure_ldap_config:/etc/ldap/slapd.d
      - ../../ldap/ldif:/container/service/slapd/assets/config/bootstrap/ldif/custom
    restart: unless-stopped

volumes:
  secure_ldap_data:
    driver: local
  secure_ldap_config:
    driver: local
EOF

echo -e "${YELLOW}🚀 Starting secure LDAP with Vault credentials...${NC}"
docker compose -f docker-compose-secure-ldap.yml up -d

echo -e "${YELLOW}⏳ Waiting for LDAP to start...${NC}"
sleep 15

# Test connection with Vault-retrieved credentials
echo -e "${YELLOW}🧪 Testing LDAP connection...${NC}"

BIND_DN="cn=admin,dc=whitestartups,dc=com"
BASE_DN="dc=whitestartups,dc=com"

if ldapsearch -x -H "ldap://localhost:389" -D "$BIND_DN" -w "$LDAP_ADMIN_PASSWORD" -b "$BASE_DN" "(objectclass=*)" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ LDAP connection successful with Vault credentials${NC}"
    echo -e "${GREEN}   Admin DN: $BIND_DN${NC}"
    echo -e "${GREEN}   Base DN: $BASE_DN${NC}"
else
    echo -e "${RED}❌ LDAP connection failed${NC}"
    exit 1
fi

# Test a sample user authentication
echo -e "${YELLOW}🧪 Testing user authentication...${NC}"
TEST_USER="uid=admin,ou=people,dc=whitestartups,dc=com"
if ldapsearch -x -H "ldap://localhost:389" -D "$TEST_USER" -w "$LDAP_ADMIN_PASSWORD" -b "dc=whitestartups,dc=com" "(uid=admin)" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ User authentication test successful${NC}"
else
    echo -e "${YELLOW}⚠️  Admin user not found (expected for fresh setup)${NC}"
fi

echo ""
echo -e "${GREEN}🎉 SECURE LDAP SETUP COMPLETE${NC}"
echo -e "${GREEN}=============================${NC}"
echo ""
echo -e "${BLUE}📊 Configuration Summary:${NC}"
echo -e "${BLUE}  LDAP URL: ldap://localhost:389${NC}"
echo -e "${BLUE}  Base DN: dc=whitestartups,dc=com${NC}"
echo -e "${BLUE}  Admin DN: cn=admin,dc=whitestartups,dc=com${NC}"
echo -e "${BLUE}  Credentials: Retrieved securely from Vault${NC}"
echo ""
echo -e "${YELLOW}💡 Security Benefits:${NC}"
echo -e "${YELLOW}  🔐 No hardcoded passwords in scripts${NC}"
echo -e "${YELLOW}  🏦 All credentials managed by Vault${NC}"
echo -e "${YELLOW}  📝 Audit trail for credential access${NC}"
echo -e "${YELLOW}  🔄 Easy credential rotation via Vault${NC}"
echo ""
echo -e "${GREEN}🔧 Management Commands:${NC}"
echo "  View LDAP logs: docker logs secure-ldap-vault"
echo "  Stop LDAP: docker compose -f docker-compose-secure-ldap.yml down"
echo "  Rotate password: ../scripts/vault/vault-credentials-manager.sh update ldap admin_password=NewPassword123!"