#!/bin/sh
# Test Vault OIDC authentication configuration

set -e

export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="${VAULT_DEV_ROOT_TOKEN_ID:-root}"

# Check Vault status
vault status

# List enabled auth methods
vault auth list

# Read OIDC config
vault read auth/oidc/config

# List OIDC roles
vault list auth/oidc/role

# Show details for github-actions role
vault read auth/oidc/role/github-actions

echo "OIDC authentication configuration test complete."
