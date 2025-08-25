FROM hashicorp/vault:1.15.2

# Expose Vault HTTP API
EXPOSE 8200

# Copy OIDC test script into the image
COPY test-oidc.sh /vault/config/test-oidc.sh
