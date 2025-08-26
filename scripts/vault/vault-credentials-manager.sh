#!/bin/bash

# Vault Credentials Manager
# Centralized script for managing all system credentials via Vault

set -e

VAULT_ADDR="http://localhost:8200"
VAULT_TOKEN="root"
VAULT_CONTAINER="dev-vault"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to execute Vault command
vault_exec() {
    docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" "$VAULT_CONTAINER" vault "$@"
}

# Check Vault status
check_vault_status() {
    echo_info "Checking Vault status..."
    if vault_exec status >/dev/null 2>&1; then
        echo_success "Vault is healthy and unsealed"
        return 0
    else
        echo_error "Vault is not accessible or sealed"
        return 1
    fi
}

# List all stored credentials
list_credentials() {
    echo "🗂️  VAULT CREDENTIALS INVENTORY"
    echo "==============================="
    echo ""
    
    echo_info "Service Credentials:"
    vault_exec kv list secret/ 2>/dev/null | grep -E "(ldap|redis|mongodb|github|wildfly|database)" | sed 's/^/  • /'
    
    echo ""
    echo_info "Test User Batches:"
    vault_exec kv list secret/test-users/ 2>/dev/null | sed 's/^/  • /'
    
    echo ""
    echo_info "System Configuration:"
    vault_exec kv list secret/ 2>/dev/null | grep -E "(system)" | sed 's/^/  • /'
}

# Get specific credential
get_credential() {
    local path="$1"
    local field="$2"
    
    if [[ -z "$path" ]]; then
        echo_error "Usage: get_credential <path> [field]"
        echo "Examples:"
        echo "  get_credential ldap"
        echo "  get_credential ldap admin_password"
        return 1
    fi
    
    echo_info "Retrieving credentials from secret/$path"
    
    if [[ -n "$field" ]]; then
        vault_exec kv get -field="$field" "secret/$path" 2>/dev/null || {
            echo_error "Field '$field' not found in secret/$path"
            return 1
        }
    else
        vault_exec kv get "secret/$path"
    fi
}

# Update credential
update_credential() {
    local path="$1"
    shift
    
    if [[ -z "$path" ]] || [[ $# -eq 0 ]]; then
        echo_error "Usage: update_credential <path> key=value [key=value ...]"
        echo "Example: update_credential ldap admin_password=NewPassword123!"
        return 1
    fi
    
    echo_info "Updating credentials at secret/$path"
    vault_exec kv put "secret/$path" "$@"
    echo_success "Credentials updated successfully"
}

# Get test user password by digit
get_test_password() {
    local digit="$1"
    
    if [[ ! "$digit" =~ ^[0-9]$ ]]; then
        echo_error "Usage: get_test_password <digit>"
        echo "Example: get_test_password 3  # Returns TestPass3!"
        return 1
    fi
    
    vault_exec kv get -field="pattern" "secret/test-users/batch-$digit" 2>/dev/null || {
        echo_error "Test password pattern for digit $digit not found"
        return 1
    }
}

# Generate environment file for Docker Compose
generate_env_file() {
    local output_file="${1:-.env.vault}"
    
    echo_info "Generating environment file: $output_file"
    
    cat > "$output_file" << EOF
# Generated from Vault on $(date)
# DO NOT COMMIT THIS FILE TO VERSION CONTROL

# LDAP Credentials
LDAP_ADMIN_PASSWORD=$(vault_exec kv get -field="admin_password" secret/ldap 2>/dev/null)
LDAP_CONFIG_PASSWORD=$(vault_exec kv get -field="config_password" secret/ldap 2>/dev/null)
LDAP_BIND_DN=$(vault_exec kv get -field="bind_dn" secret/ldap 2>/dev/null)
LDAP_BIND_PASSWORD=$(vault_exec kv get -field="admin_password" secret/ldap 2>/dev/null)

# Redis Credentials  
REDIS_PASSWORD=$(vault_exec kv get -field="password" secret/redis 2>/dev/null)
REDIS_CONNECTION_STRING=$(vault_exec kv get -field="connection_string" secret/redis 2>/dev/null)

# MongoDB Credentials
MONGO_INITDB_ROOT_USERNAME=$(vault_exec kv get -field="username" secret/mongodb 2>/dev/null)
MONGO_INITDB_ROOT_PASSWORD=$(vault_exec kv get -field="password" secret/mongodb 2>/dev/null)
MONGODB_CONNECTION_STRING=$(vault_exec kv get -field="connection_string" secret/mongodb 2>/dev/null)

# MongoDB TLS Certificates
MONGODB_TRUSTSTORE_PASSWORD=$(vault_exec kv get -field="truststore_password" secret/mongodb-tls 2>/dev/null)
MONGODB_KEYSTORE_PASSWORD=$(vault_exec kv get -field="keystore_password" secret/mongodb-tls 2>/dev/null)

# WildFly Admin
WILDFLY_USER=$(vault_exec kv get -field="WILDFLY_USER" secret/wildfly 2>/dev/null)
WILDFLY_PASS=$(vault_exec kv get -field="WILDFLY_PASS" secret/wildfly 2>/dev/null)
WILDFLY_ADMIN_PASSWORD=$(vault_exec kv get -field="admin_password" secret/wildfly 2>/dev/null)

# Database
DB_USER=$(vault_exec kv get -field="DB_USER" secret/database 2>/dev/null)
DB_PASS=$(vault_exec kv get -field="DB_PASS" secret/database 2>/dev/null)

# Development/Testing
DEV_LDAP_ADMIN_PASSWORD=$(vault_exec kv get -field="ldap_quick_setup_admin" secret/dev-testing 2>/dev/null)
DEV_LDAP_CONFIG_PASSWORD=$(vault_exec kv get -field="ldap_quick_setup_config" secret/dev-testing 2>/dev/null)

# GitHub
GITHUB_PAT=$(vault_exec kv get -field="PAT" secret/github 2>/dev/null)

# Vault Configuration
VAULT_TOKEN=root
VAULT_ADDR=http://localhost:8200
EOF

    echo_success "Environment file generated: $output_file"
    echo_warning "Remember to add $output_file to .gitignore!"
}

# Generate test credentials for JavaScript
generate_test_credentials_js() {
    local output_file="${1:-test-credentials.js}"
    
    echo_info "Generating JavaScript test credentials: $output_file"
    
    cat > "$output_file" << 'EOF'
// Generated from Vault - DO NOT COMMIT
// Use this instead of hardcoded credentials

class VaultTestCredentials {
  static getTestUsers() {
    // Dynamically generate from Vault patterns
    const users = [];
    for (let i = 0; i < 1000; i++) {
      const digit = i % 10;
      users.push({
        username: `testuser${String(i).padStart(3, '0')}`,
        password: `TestPass${digit}!`
      });
    }
    return users;
  }
  
  static getPasswordByDigit(digit) {
    return `TestPass${digit}!`;
  }
  
  static getRandomTestUser() {
    const users = this.getTestUsers();
    return users[Math.floor(Math.random() * users.length)];
  }
}

module.exports = VaultTestCredentials;
EOF

    echo_success "JavaScript credentials helper generated: $output_file"
}

# Main command handler
main() {
    local command="$1"
    shift 2>/dev/null || true
    
    if ! check_vault_status; then
        echo_error "Vault is not available. Please ensure Vault container is running."
        exit 1
    fi
    
    case "$command" in
        "list"|"ls")
            list_credentials
            ;;
        "get")
            get_credential "$@"
            ;;
        "update"|"put")
            update_credential "$@"
            ;;
        "test-password")
            get_test_password "$@"
            ;;
        "generate-env")
            generate_env_file "$@"
            ;;
        "generate-js")
            generate_test_credentials_js "$@"
            ;;
        "help"|"--help"|"-h"|"")
            echo "🔐 VAULT CREDENTIALS MANAGER"
            echo "============================="
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  list                     - List all stored credentials"
            echo "  get <path> [field]       - Get credential(s) from path"
            echo "  update <path> key=value  - Update credential at path"
            echo "  test-password <digit>    - Get test password for digit (0-9)"
            echo "  generate-env [file]      - Generate .env file from Vault"
            echo "  generate-js [file]       - Generate JavaScript credentials helper"
            echo "  help                     - Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 list"
            echo "  $0 get ldap"
            echo "  $0 get ldap admin_password"
            echo "  $0 test-password 3"
            echo "  $0 update ldap admin_password=NewPass123!"
            echo "  $0 generate-env .env.development"
            ;;
        *)
            echo_error "Unknown command: $command"
            echo_info "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"