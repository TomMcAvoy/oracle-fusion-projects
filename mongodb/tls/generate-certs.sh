#!/bin/bash

# Generate TLS Certificates for MongoDB Enterprise Security
# This creates proper certificates for encrypted MongoDB connections

set -e

CERT_DIR="$(dirname "$0")"
cd "$CERT_DIR"

echo "🔐 Generating MongoDB TLS Certificates..."

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

# Create Java truststore and keystore
keytool -import -trustcacerts -file ca.crt -keystore mongodb-truststore.jks -storepass MongoTrust2024! -noprompt -alias mongodb-ca

# Convert client cert to PKCS12 for Java
openssl pkcs12 -export -in mongodb-client.crt -inkey mongodb-client.key -out mongodb-client.p12 -name mongodb-client -passout pass:MongoClient2024!

# Import to Java keystore
keytool -importkeystore -deststorepass MongoClient2024! -destkeypass MongoClient2024! -destkeystore mongodb-keystore.jks -srckeystore mongodb-client.p12 -srcstoretype PKCS12 -srcstorepass MongoClient2024! -alias mongodb-client

# Clean up CSR files
rm -f *.csr *.srl

echo "✅ MongoDB TLS Certificates Generated:"
echo "   📄 CA Certificate: ca.crt"
echo "   🔐 Server Certificate: mongodb-server.pem"  
echo "   👤 Client Certificate: mongodb-client.pem"
echo "   ☕ Java Truststore: mongodb-truststore.jks"
echo "   ☕ Java Keystore: mongodb-keystore.jks"
echo ""
echo "🔑 Store Passwords:"
echo "   Truststore: MongoTrust2024!"
echo "   Keystore: MongoClient2024!"