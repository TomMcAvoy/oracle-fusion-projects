#!/bin/sh
# Wait for Vault to be ready
sleep 5

export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="${VAULT_DEV_ROOT_TOKEN_ID:-root}"

vault auth enable oidc
vault write auth/oidc/config \
    oidc_discovery_url="$OIDC_DISCOVERY_URL" \
    oidc_client_id="$OIDC_CLIENT_ID" \
    oidc_client_secret="$OIDC_CLIENT_SECRET" \
    default_role="github-actions"

vault write auth/oidc/role/github-actions \
    bound_audiences="$OIDC_CLIENT_ID" \
    allowed_redirect_uris="http://localhost:8250/oidc/callback" \
    user_claim="email" \
    policies="default" \
    ttl="1h"
