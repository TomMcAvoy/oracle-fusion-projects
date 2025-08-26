#!/bin/bash

# Vault Certificate Management System
# Generates, stores, and retrieves all certificates and keys from Vault
# NO certificate content stored in filesystem - everything in Vault

set -e

# Configuration
VAULT_ADDR="http://localhost:8200"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_CONTAINER="dev-vault"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
echo_success() { echo -e "${GREEN}✅ $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }

# Execute Vault command
vault_exec() {
    docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" \
        "$VAULT_CONTAINER" vault "$@"
}

# Check if Vault is healthy
check_vault() {
    if ! docker ps | grep -q "$VAULT_CONTAINER"; then
        echo_error "Vault container not running. Start with: docker-compose up -d"
        exit 1
    fi
    
    if ! vault_exec status >/dev/null 2>&1; then
        echo_error "Vault is not accessible or unsealed"
        exit 1
    fi
}

# Get certificate parameters from Vault
get_cert_params() {
    local service="$1"
    local param="$2"
    
    vault_exec kv get -field="$param" "secret/${service}-certs" 2>/dev/null || {
        echo_error "Failed to get $param for $service from Vault"
        exit 1
    }
}

# Store certificate content in Vault
store_cert_content() {
    local service="$1"
    local cert_type="$2"
    local content="$3"
    
    # Encode content to handle multiline certificates
    local encoded_content=$(echo "$content" | base64 -w 0)
    
    vault_exec kv patch "secret/${service}-keys" "${cert_type}=${encoded_content}" >/dev/null 2>&1
}

# Retrieve certificate content from Vault
get_cert_content() {
    local service="$1"
    local cert_type="$2"
    
    local encoded_content=$(vault_exec kv get -field="$cert_type" "secret/${service}-keys" 2>/dev/null)
    if [[ -n "$encoded_content" ]]; then
        echo "$encoded_content" | base64 -d
        return 0
    else
        return 1
    fi
}

# Generate MongoDB certificates and store in Vault
generate_mongodb_certs() {
    echo_info "Generating MongoDB TLS certificates with Vault parameters..."
    
    # Get parameters from Vault
    CA_SUBJECT=$(get_cert_params "mongodb" "ca_subject")
    SERVER_SUBJECT=$(get_cert_params "mongodb" "server_subject") 
    CLIENT_SUBJECT=$(get_cert_params "mongodb" "client_subject")
    KEY_SIZE=$(get_cert_params "mongodb" "key_size")
    CERT_DAYS=$(get_cert_params "mongodb" "cert_days")
    
    # Get passwords from Vault
    TRUSTSTORE_PASSWORD=$(vault_exec kv get -field="truststore_password" secret/mongodb-tls)
    KEYSTORE_PASSWORD=$(vault_exec kv get -field="keystore_password" secret/mongodb-tls)
    P12_PASSWORD=$(vault_exec kv get -field="p12_password" secret/mongodb-tls)
    
    # Create temporary directory for certificate generation
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    echo_info "Generating certificates in temporary directory: $TEMP_DIR"
    
    # Generate CA private key and certificate
    openssl genrsa -out ca.key "$KEY_SIZE"
    openssl req -new -x509 -days "$CERT_DAYS" -key ca.key -out ca.crt -subj "$CA_SUBJECT"
    
    # Generate server private key and certificate
    openssl genrsa -out mongodb-server.key "$KEY_SIZE"
    openssl req -new -key mongodb-server.key -out mongodb-server.csr -subj "$SERVER_SUBJECT"
    openssl x509 -req -days "$CERT_DAYS" -in mongodb-server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out mongodb-server.crt
    
    # Generate client private key and certificate
    openssl genrsa -out mongodb-client.key "$KEY_SIZE"
    openssl req -new -key mongodb-client.key -out mongodb-client.csr -subj "$CLIENT_SUBJECT"
    openssl x509 -req -days "$CERT_DAYS" -in mongodb-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out mongodb-client.crt
    
    # Create combined PEM files
    cat mongodb-server.key mongodb-server.crt > mongodb-server.pem
    cat mongodb-client.key mongodb-client.crt > mongodb-client.pem
    
    # Create Java keystores with Vault passwords
    keytool -import -trustcacerts -file ca.crt -keystore mongodb-truststore.jks -storepass "$TRUSTSTORE_PASSWORD" -noprompt -alias mongodb-ca
    openssl pkcs12 -export -in mongodb-client.crt -inkey mongodb-client.key -out mongodb-client.p12 -name mongodb-client -passout pass:"$P12_PASSWORD"
    keytool -importkeystore -deststorepass "$KEYSTORE_PASSWORD" -destkeypass "$KEYSTORE_PASSWORD" -destkeystore mongodb-keystore.jks -srckeystore mongodb-client.p12 -srcstoretype PKCS12 -srcstorepass "$P12_PASSWORD" -alias mongodb-client
    
    echo_info "Storing certificate content in Vault..."
    
    # Store all certificate content in Vault (NOT on filesystem)
    store_cert_content "mongodb" "ca_key" "$(cat ca.key)"
    store_cert_content "mongodb" "ca_crt" "$(cat ca.crt)"
    store_cert_content "mongodb" "server_key" "$(cat mongodb-server.key)"
    store_cert_content "mongodb" "server_crt" "$(cat mongodb-server.crt)"
    store_cert_content "mongodb" "server_pem" "$(cat mongodb-server.pem)"
    store_cert_content "mongodb" "client_key" "$(cat mongodb-client.key)"
    store_cert_content "mongodb" "client_crt" "$(cat mongodb-client.crt)"
    store_cert_content "mongodb" "client_pem" "$(cat mongodb-client.pem)"
    store_cert_content "mongodb" "truststore_jks" "$(cat mongodb-truststore.jks | base64 -w 0)"
    store_cert_content "mongodb" "keystore_jks" "$(cat mongodb-keystore.jks | base64 -w 0)"
    store_cert_content "mongodb" "client_p12" "$(cat mongodb-client.p12 | base64 -w 0)"
    
    # Clean up temporary files
    cd /
    rm -rf "$TEMP_DIR"
    
    echo_success "MongoDB certificates generated and stored in Vault"
    echo_warning "NO certificate files stored on filesystem - all in Vault!"
}

# Retrieve certificate to temporary location
retrieve_cert() {
    local service="$1" 
    local cert_type="$2"
    local output_path="$3"
    
    if get_cert_content "$service" "$cert_type" > "$output_path" 2>/dev/null; then
        echo_success "Retrieved $cert_type for $service to $output_path"
        return 0
    else
        echo_error "Failed to retrieve $cert_type for $service"
        return 1
    fi
}

# Create real-time certificate retrieval script
create_cert_retrieval_script() {
    local service="$1"
    local script_name="get-${service}-certs.sh"
    
    cat > "/tmp/$script_name" << EOF
#!/bin/bash
# Real-time certificate retrieval for $service
# Generated by Vault Certificate Manager

VAULT_ADDR="$VAULT_ADDR"
VAULT_TOKEN="\${VAULT_TOKEN:-root}"
VAULT_CONTAINER="$VAULT_CONTAINER"

vault_exec() {
    docker exec -e VAULT_ADDR="\$VAULT_ADDR" -e VAULT_TOKEN="\$VAULT_TOKEN" \\
        "\$VAULT_CONTAINER" vault "\$@"
}

get_cert_content() {
    local cert_type="\$1"
    local encoded_content=\$(vault_exec kv get -field="\$cert_type" "secret/${service}-keys" 2>/dev/null)
    if [[ -n "\$encoded_content" ]]; then
        echo "\$encoded_content" | base64 -d
        return 0
    else
        return 1
    fi
}

# Usage: $script_name <cert_type> [output_file]
CERT_TYPE="\$1"
OUTPUT_FILE="\$2"

if [[ -z "\$CERT_TYPE" ]]; then
    echo "Usage: $script_name <cert_type> [output_file]"
    echo "Available cert types for $service:"
    vault_exec kv get -format=json "secret/${service}-keys" | jq -r '.data.data | keys[]' 2>/dev/null | sort
    exit 1
fi

if [[ -n "\$OUTPUT_FILE" ]]; then
    get_cert_content "\$CERT_TYPE" > "\$OUTPUT_FILE"
    echo "Certificate \$CERT_TYPE written to \$OUTPUT_FILE"
else
    get_cert_content "\$CERT_TYPE"
fi
EOF
    
    chmod +x "/tmp/$script_name"
    echo_success "Created certificate retrieval script: /tmp/$script_name"
}

# List all certificates in Vault
list_certificates() {
    echo_info "Certificate Inventory in Vault:"
    echo "================================"
    
    for service in mongodb ldap wildfly; do
        echo ""
        echo_info "$service certificates:"
        if vault_exec kv get -format=json "secret/${service}-keys" >/dev/null 2>&1; then
            vault_exec kv get -format=json "secret/${service}-keys" 2>/dev/null | \
                jq -r '.data.data | keys[]' | sort | sed 's/^/  • /'
        else
            echo "  (Not yet generated)"
        fi
    done
}

# Generate LDAP certificates
generate_ldap_certs() {
    echo_info "Generating LDAP TLS certificates..."
    
    CA_SUBJECT=$(get_cert_params "ldap" "ca_subject")
    SERVER_SUBJECT=$(get_cert_params "ldap" "server_subject") 
    CLIENT_SUBJECT=$(get_cert_params "ldap" "client_subject")
    KEY_SIZE=$(get_cert_params "ldap" "key_size")
    CERT_DAYS=$(get_cert_params "ldap" "cert_days")
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Generate LDAP certificates
    openssl genrsa -out ca.key "$KEY_SIZE"
    openssl req -new -x509 -days "$CERT_DAYS" -key ca.key -out ca.crt -subj "$CA_SUBJECT"
    
    openssl genrsa -out ldap-server.key "$KEY_SIZE"
    openssl req -new -key ldap-server.key -out ldap-server.csr -subj "$SERVER_SUBJECT"
    openssl x509 -req -days "$CERT_DAYS" -in ldap-server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out ldap-server.crt
    
    openssl genrsa -out ldap-client.key "$KEY_SIZE"
    openssl req -new -key ldap-client.key -out ldap-client.csr -subj "$CLIENT_SUBJECT"
    openssl x509 -req -days "$CERT_DAYS" -in ldap-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out ldap-client.crt
    
    # Store in Vault
    store_cert_content "ldap" "ca_key" "$(cat ca.key)"
    store_cert_content "ldap" "ca_crt" "$(cat ca.crt)"
    store_cert_content "ldap" "server_key" "$(cat ldap-server.key)"
    store_cert_content "ldap" "server_crt" "$(cat ldap-server.crt)"
    store_cert_content "ldap" "client_key" "$(cat ldap-client.key)"
    store_cert_content "ldap" "client_crt" "$(cat ldap-client.crt)"
    
    cd / && rm -rf "$TEMP_DIR"
    echo_success "LDAP certificates stored in Vault"
}

# Generate WildFly certificates
generate_wildfly_certs() {
    echo_info "Generating WildFly TLS certificates..."
    
    CA_SUBJECT=$(get_cert_params "wildfly" "ca_subject")
    SERVER_SUBJECT=$(get_cert_params "wildfly" "server_subject")
    KEYSTORE_ALIAS=$(get_cert_params "wildfly" "keystore_alias")
    KEY_SIZE=$(get_cert_params "wildfly" "key_size")
    CERT_DAYS=$(get_cert_params "wildfly" "cert_days")
    
    # Get WildFly passwords
    WILDFLY_KEYSTORE_PASSWORD=$(vault_exec kv get -field="admin_password" secret/wildfly)
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Generate WildFly certificates
    openssl genrsa -out ca.key "$KEY_SIZE"
    openssl req -new -x509 -days "$CERT_DAYS" -key ca.key -out ca.crt -subj "$CA_SUBJECT"
    
    openssl genrsa -out wildfly-server.key "$KEY_SIZE"
    openssl req -new -key wildfly-server.key -out wildfly-server.csr -subj "$SERVER_SUBJECT"
    openssl x509 -req -days "$CERT_DAYS" -in wildfly-server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out wildfly-server.crt
    
    # Create PKCS12 keystore for WildFly
    openssl pkcs12 -export -in wildfly-server.crt -inkey wildfly-server.key -out wildfly-server.p12 -name "$KEYSTORE_ALIAS" -passout pass:"$WILDFLY_KEYSTORE_PASSWORD"
    
    # Store in Vault
    store_cert_content "wildfly" "ca_key" "$(cat ca.key)"
    store_cert_content "wildfly" "ca_crt" "$(cat ca.crt)"
    store_cert_content "wildfly" "server_key" "$(cat wildfly-server.key)"
    store_cert_content "wildfly" "server_crt" "$(cat wildfly-server.crt)"
    store_cert_content "wildfly" "server_p12" "$(cat wildfly-server.p12 | base64 -w 0)"
    
    cd / && rm -rf "$TEMP_DIR"
    echo_success "WildFly certificates stored in Vault"
}

# Main function
main() {
    case "$1" in
        "generate-mongodb")
            check_vault
            generate_mongodb_certs
            create_cert_retrieval_script "mongodb"
            ;;
        "generate-ldap")
            check_vault
            generate_ldap_certs
            create_cert_retrieval_script "ldap"
            ;;
        "generate-wildfly")
            check_vault
            generate_wildfly_certs
            create_cert_retrieval_script "wildfly"
            ;;
        "generate-all")
            check_vault
            generate_mongodb_certs
            generate_ldap_certs
            generate_wildfly_certs
            for service in mongodb ldap wildfly; do
                create_cert_retrieval_script "$service"
            done
            echo_success "All certificates generated and stored in Vault!"
            ;;
        "list")
            check_vault
            list_certificates
            ;;
        "retrieve")
            if [[ $# -lt 3 ]]; then
                echo_error "Usage: $0 retrieve <service> <cert_type> [output_file]"
                exit 1
            fi
            check_vault
            if [[ -n "$4" ]]; then
                retrieve_cert "$2" "$3" "$4"
            else
                get_cert_content "$2" "$3"
            fi
            ;;
        *)
            echo "Vault Certificate Management System"
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  generate-mongodb   Generate MongoDB TLS certificates"
            echo "  generate-ldap      Generate LDAP TLS certificates"  
            echo "  generate-wildfly   Generate WildFly TLS certificates"
            echo "  generate-all       Generate all service certificates"
            echo "  list              List all certificates in Vault"
            echo "  retrieve <service> <cert_type> [file]  Retrieve specific certificate"
            echo ""
            echo "Examples:"
            echo "  $0 generate-all"
            echo "  $0 list"
            echo "  $0 retrieve mongodb ca_crt /tmp/ca.crt"
            echo "  /tmp/get-mongodb-certs.sh server_pem /tmp/mongodb-server.pem"
            ;;
    esac
}

main "$@"