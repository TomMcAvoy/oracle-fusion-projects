# 🔐 Quick Vault Environment Usage

## The Problem We Solved
✅ **Before**: Secrets in `.env` files, Git history, environment  
✅ **Now**: All secrets in encrypted Vault, loaded dynamically

## How to Use Environment Variables Now

### Option 1: Load into Current Shell
```bash
# Load Vault secrets into your current environment
source <(./scripts/vault/vault-env.sh)

# Now use normally
echo $GITHUB_TOKEN
mvn clean install  
docker-compose up -d
```

### Option 2: One-Command App Launch  
```bash  
# Run any application with Vault environment loaded
./start-with-vault.sh mvn clean install
./start-with-vault.sh docker-compose up -d
./start-with-vault.sh node server.js
```

### Option 3: Test Environment Loading
```bash
# See what environment variables are available
./start-with-vault.sh test
```

## What Environment Variables Are Available?
- `GITHUB_TOKEN` - Your GitHub Personal Access Token
- `GITHUB_USERNAME` - Your GitHub username (TomMcAvoy)
- `GITLAB_TOKEN` - Your GitLab Personal Access Token  
- `GITLAB_USERNAME` - Your GitLab username (TomMcAvoy)
- `GITHUB_PAT` - Legacy alias for GITHUB_TOKEN

## For Different Applications

### Maven Projects
```bash
./start-with-vault.sh mvn clean install
# Maven can now access ${GITHUB_TOKEN} in pom.xml
```

### Docker Compose
```bash  
./start-with-vault.sh docker-compose up -d
# docker-compose.yml can use ${GITHUB_TOKEN} variables
```

### Node.js Applications
```bash
./start-with-vault.sh node server.js
# process.env.GITHUB_TOKEN available in Node.js
```

### Spring Boot Applications
```bash
./start-with-vault.sh java -jar app.jar
# application.yml can reference ${GITHUB_TOKEN}
```

## Security Benefits
🔐 **Secrets never on disk** - Always encrypted in Vault  
🔄 **Dynamic loading** - Only loaded when needed  
📊 **Audit trail** - Vault logs all secret access  
🔁 **Easy rotation** - Update tokens in Vault, not files
