#!/bin/bash

# Generate TLS Certificates for MongoDB Enterprise Security - VAULT ENABLED
# This version retrieves passwords from Vault instead of hardcoding them

set -e

CERT_DIR="$(dirname "$0")"
cd "$CERT_DIR"

# Vault configuration
VAULT_ADDR="http://localhost:8200"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_CONTAINER="dev-vault"

echo "🔐 Generating MongoDB TLS Certificates with Vault-managed passwords..."

# Function to get password from Vault
get_vault_secret() {
    local path="$1"
    local field="$2"
    
    docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" \
        "$VAULT_CONTAINER" vault kv get -field="$field" "$path" 2>/dev/null || {
        echo "❌ Failed to retrieve $field from Vault path $path"
        exit 1
    }
}

# Get passwords from Vault
echo "🏦 Retrieving passwords from Vault..."
TRUSTSTORE_PASSWORD=$(get_vault_secret "secret/mongodb-tls" "truststore_password")
KEYSTORE_PASSWORD=$(get_vault_secret "secret/mongodb-tls" "keystore_password")
P12_PASSWORD=$(get_vault_secret "secret/mongodb-tls" "p12_password")

echo "✅ Passwords retrieved from Vault"

# Create CA private key
openssl genrsa -out ca.key 4096

# Create CA certificate
openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/C=US/ST=CA/L=San Francisco/O=WhiteStartups/OU=IT/CN=MongoDB-CA"

# Create server private key
openssl genrsa -out mongodb-server.key 4096

# Create server certificate signing request
openssl req -new -key mongodb-server.key -out mongodb-server.csr -subj "/C=US/ST=CA/L=San Francisco/O=WhiteStartups/OU=IT/CN=localhost"

# Create server certificate signed by CA
openssl x509 -req -days 365 -in mongodb-server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out mongodb-server.crt

# Create client private key
openssl genrsa -out mongodb-client.key 4096

# Create client certificate signing request  
openssl req -new -key mongodb-client.key -out mongodb-client.csr -subj "/C=US/ST=CA/L=San Francisco/O=WhiteStartups/OU=IT/CN=auth-cache-client"

# Create client certificate signed by CA
openssl x509 -req -days 365 -in mongodb-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out mongodb-client.crt

# Combine server key and cert for MongoDB
cat mongodb-server.key mongodb-server.crt > mongodb-server.pem

# Combine client key and cert for Java client
cat mongodb-client.key mongodb-client.crt > mongodb-client.pem

# Set proper permissions
chmod 600 *.key *.pem
chmod 644 *.crt

# Create Java truststore with Vault password
keytool -import -trustcacerts -file ca.crt -keystore mongodb-truststore.jks -storepass "$TRUSTSTORE_PASSWORD" -noprompt -alias mongodb-ca

# Convert client cert to PKCS12 with Vault password
openssl pkcs12 -export -in mongodb-client.crt -inkey mongodb-client.key -out mongodb-client.p12 -name mongodb-client -passout pass:"$P12_PASSWORD"

# Import to Java keystore with Vault passwords
keytool -importkeystore -deststorepass "$KEYSTORE_PASSWORD" -destkeypass "$KEYSTORE_PASSWORD" -destkeystore mongodb-keystore.jks -srckeystore mongodb-client.p12 -srcstoretype PKCS12 -srcstorepass "$P12_PASSWORD" -alias mongodb-client

# Clean up CSR files
rm -f *.csr *.srl

echo "✅ MongoDB TLS Certificates Generated with Vault-managed passwords:"
echo "   📄 CA Certificate: ca.crt"
echo "   🔐 Server Certificate: mongodb-server.pem"  
echo "   👤 Client Certificate: mongodb-client.pem"
echo "   ☕ Java Truststore: mongodb-truststore.jks"
echo "   ☕ Java Keystore: mongodb-keystore.jks"
echo ""
echo "🏦 Passwords managed by Vault:"
echo "   Truststore: Retrieved from secret/mongodb-tls/truststore_password"
echo "   Keystore: Retrieved from secret/mongodb-tls/keystore_password"
echo "   P12: Retrieved from secret/mongodb-tls/p12_password"
echo ""
echo "🔒 No passwords stored in files or version control!"