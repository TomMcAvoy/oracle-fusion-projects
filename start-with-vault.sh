#!/bin/bash
# 🚀 Simple Vault Environment Loader

echo "🔐 Loading secrets from Vault into environment..."

# Load environment from Vault
source <(./scripts/vault/vault-env.sh)

echo "✅ Environment loaded. Available variables:"
echo "   GITHUB_USERNAME: $GITHUB_USERNAME"  
echo "   GITHUB_TOKEN: ${GITHUB_TOKEN:0:15}..."
echo "   GITLAB_USERNAME: $GITLAB_USERNAME"
echo "   GITLAB_TOKEN: ${GITLAB_TOKEN:0:15}..."

# Now you can run any command with these environment variables
if [ "$1" == "test" ]; then
    echo ""
    echo "🧪 Testing environment access..."
    env | grep -E "^(GITHUB_|GITLAB_)" | sed 's/=.*/=***HIDDEN***/'
elif [ $# -gt 0 ]; then
    echo ""  
    echo "🚀 Executing: $*"
    exec "$@"
else
    echo ""
    echo "Usage: $0 [command] or $0 test"
    echo "Example: $0 mvn clean install"
    echo "Example: $0 docker-compose up -d"
fi
