# 🔐 Vault Environment Variable Management

## Overview
All secrets are stored in HashiCorp Vault and dynamically loaded as environment variables when needed.

## Usage Patterns

### 1. Load Environment for Current Shell
```bash
# Load Vault secrets into current environment
source <(./scripts/vault/vault-env.sh)

# Now use environment variables normally
echo $GITHUB_TOKEN
mvn clean install
```

### 2. Run Applications with Vault Environment
```bash
# Maven build with secrets
./scripts/vault/run-with-vault.sh mvn clean install

# Docker Compose with secrets  
./scripts/vault/vault-env.sh docker-compose up -d

# Node.js application with secrets
./scripts/vault/run-with-vault.sh node server.js
```

### 3. CI/CD Integration
```yaml
# GitHub Actions
- name: Load Vault Environment
  run: source <(./scripts/vault/vault-env.sh)

- name: Build with secrets
  run: mvn clean install
```

### 4. Docker Integration
```bash
# Run containers with Vault-loaded environment
./scripts/vault/vault-env.sh docker-compose \
  -f docker-compose.yml \
  -f docker-compose.vault-env.yml \
  up -d
```

## Security Benefits

✅ **No secrets in files**: All in encrypted Vault  
✅ **Dynamic loading**: Secrets loaded only when needed  
✅ **Audit trail**: All access logged by Vault  
✅ **Rotation ready**: Easy token updates in Vault  
✅ **Environment isolation**: Different environments, different Vault paths  

## Available Environment Variables

- `GITHUB_TOKEN`: GitHub Personal Access Token
- `GITHUB_USERNAME`: GitHub username  
- `GITLAB_TOKEN`: GitLab Personal Access Token
- `GITLAB_USERNAME`: GitLab username
- `GITHUB_PAT`: Legacy GitHub PAT (same as GITHUB_TOKEN)

## Token Management

```bash
# Update tokens in Vault
./scripts/vault/vault-credentials-manager.sh update git/github token=NEW_TOKEN

# View token info
./scripts/vault/vault-credentials-manager.sh get git/github

# List all tokens
./scripts/vault/vault-credentials-manager.sh list
```
