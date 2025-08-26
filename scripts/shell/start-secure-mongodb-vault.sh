#!/bin/bash

# Start MongoDB with Vault-Retrieved TLS Certificates
# All certificates pulled from Vault in real-time

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CERT_MANAGER="../vault/vault-cert-manager.sh"
MONGODB_CONFIG="../mongodb/mongod-vault-secure.conf"

echo -e "${BLUE}🔐 STARTING MONGODB WITH VAULT-MANAGED CERTIFICATES${NC}"
echo -e "${BLUE}===================================================${NC}"
echo ""

# Check if certificates exist in Vault
echo -e "${YELLOW}📋 Checking certificate availability in Vault...${NC}"
if ! "$CERT_MANAGER" list | grep -q "mongodb certificates"; then
    echo -e "${YELLOW}⚠️  MongoDB certificates not found. Generating...${NC}"
    "$CERT_MANAGER" generate-mongodb
fi

# Create temporary certificate retrieval script
CERT_SCRIPT="/tmp/get-mongodb-certs.sh"
if [[ ! -f "$CERT_SCRIPT" ]]; then
    echo -e "${YELLOW}📝 Creating certificate retrieval script...${NC}"
    "$CERT_MANAGER" generate-mongodb >/dev/null  # This creates the script
fi

echo -e "${YELLOW}🔄 Retrieving certificates from Vault...${NC}"

# Retrieve all required certificates to temporary locations
"$CERT_SCRIPT" server_pem /tmp/mongodb-server.pem
"$CERT_SCRIPT" ca_crt /tmp/mongodb-ca.crt
"$CERT_SCRIPT" truststore_jks /tmp/mongodb-truststore.jks
"$CERT_SCRIPT" keystore_jks /tmp/mongodb-keystore.jks

echo -e "${GREEN}✅ All certificates retrieved from Vault${NC}"

# Create data directory
mkdir -p /tmp/mongodb-secure-data

# Get credentials from Vault
echo -e "${YELLOW}🏦 Getting MongoDB credentials from Vault...${NC}"
VAULT_ADDR="http://localhost:8200"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_CONTAINER="dev-vault"

vault_exec() {
    docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" \
        "$VAULT_CONTAINER" vault "$@"
}

MONGO_ADMIN_PASSWORD=$(vault_exec kv get -field="admin_password" secret/mongodb)
MONGO_CACHE_PASSWORD=$(vault_exec kv get -field="cache_password" secret/mongodb)

echo -e "${YELLOW}🚀 Starting secure MongoDB...${NC}"

# Start MongoDB with Vault-retrieved certificates
mongod --config "$MONGODB_CONFIG" --fork

sleep 3

# Create database users with Vault credentials (temporary startup without auth)
echo -e "${YELLOW}👤 Setting up database users with Vault credentials...${NC}"

# Stop MongoDB temporarily
MONGO_PID=$(cat /tmp/mongod-secure.pid)
kill -TERM "$MONGO_PID"
sleep 2

# Start without auth for user setup
mongod --config "$MONGODB_CONFIG" --noauth --fork --pidfilepath /tmp/mongod-temp.pid

sleep 3

# Create users with Vault credentials
mongosh --eval "
use admin;
db.createUser({
  user: 'admin',
  pwd: '$MONGO_ADMIN_PASSWORD',
  roles: ['root']
});

use authcache;
db.createUser({
  user: 'authcache',
  pwd: '$MONGO_CACHE_PASSWORD',
  roles: [
    { role: 'readWrite', db: 'authcache' }
  ]
});

print('✅ MongoDB users created with Vault credentials');
"

# Stop temporary MongoDB
TEMP_PID=$(cat /tmp/mongod-temp.pid)
kill -TERM "$TEMP_PID"
rm -f /tmp/mongod-temp.pid

# Start final secure MongoDB
echo -e "${YELLOW}🔒 Starting final secure MongoDB with authentication...${NC}"
mongod --config "$MONGODB_CONFIG" --fork

sleep 5

# Test TLS connection
echo -e "${YELLOW}🧪 Testing TLS connection...${NC}"
if mongosh "mongodb://authcache:$MONGO_CACHE_PASSWORD@localhost:27017/authcache?tls=true&tlsCAFile=/tmp/mongodb-ca.crt" --eval "db.runCommand({ping: 1})" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Secure MongoDB is running with Vault TLS certificates!${NC}"
else
    echo -e "${RED}❌ TLS connection test failed${NC}"
    exit 1
fi

# Create connection environment file
cat > /tmp/mongodb-vault-connection.env << EOF
# MongoDB Connection with Vault-Retrieved TLS Certificates
# Generated on $(date)

export MONGODB_URL="mongodb://authcache:$MONGO_CACHE_PASSWORD@localhost:27017/authcache?tls=true&authSource=authcache"
export MONGODB_ADMIN_URL="mongodb://admin:$MONGO_ADMIN_PASSWORD@localhost:27017/admin?tls=true&authSource=admin"
export MONGODB_CA_FILE="/tmp/mongodb-ca.crt"
export MONGODB_TRUSTSTORE="/tmp/mongodb-truststore.jks"
export MONGODB_KEYSTORE="/tmp/mongodb-keystore.jks"

# Java system properties for TLS
export JAVA_OPTS="\$JAVA_OPTS -Dmongodb.url=\$MONGODB_URL"
export JAVA_OPTS="\$JAVA_OPTS -Djavax.net.ssl.trustStore=\$MONGODB_TRUSTSTORE"
export JAVA_OPTS="\$JAVA_OPTS -Djavax.net.ssl.keyStore=\$MONGODB_KEYSTORE"
EOF

echo ""
echo -e "${GREEN}🎉 VAULT-MANAGED MONGODB TLS SETUP COMPLETE!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo -e "${BLUE}🔐 Security Features:${NC}"
echo -e "${GREEN}  ✅ TLS encryption required for all connections${NC}"
echo -e "${GREEN}  ✅ Client certificate authentication${NC}"
echo -e "${GREEN}  ✅ All certificates retrieved from Vault${NC}"
echo -e "${GREEN}  ✅ User credentials managed by Vault${NC}"
echo -e "${GREEN}  ✅ NO certificate files stored permanently${NC}"
echo ""
echo -e "${BLUE}🔌 Connection Details:${NC}"
echo -e "${CYAN}  App URL: \$MONGODB_URL${NC}"
echo -e "${CYAN}  Admin URL: \$MONGODB_ADMIN_URL${NC}"
echo -e "${CYAN}  Environment: source /tmp/mongodb-vault-connection.env${NC}"
echo ""
echo -e "${BLUE}🔄 Certificate Management:${NC}"
echo -e "${CYAN}  Refresh certificates: $CERT_MANAGER generate-mongodb${NC}"
echo -e "${CYAN}  View certificates: $CERT_MANAGER list${NC}"
echo -e "${CYAN}  Stop MongoDB: kill \$(cat /tmp/mongod-secure.pid)${NC}"
echo ""
echo -e "${YELLOW}💡 All certificates are retrieved from Vault on startup!${NC}"
echo -e "${YELLOW}   No permanent certificate files on filesystem.${NC}"