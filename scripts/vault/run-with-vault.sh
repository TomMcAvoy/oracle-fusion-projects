#!/bin/bash
# 🚀 Application Launcher with Vault-backed Environment

echo "🔐 Starting application with Vault environment..."

# Load Vault environment
source <(./scripts/vault/vault-env.sh)

# Start your application with all environment variables available
echo "Environment loaded. Starting application..."
echo ""

# Examples of how to use:
case "${1:-help}" in
    "test-env")
        echo "📋 Available environment variables:"
        env | grep -E "(GITHUB_|GITLAB_)" | sed 's/=.*$/=***/'
        ;;
    "mvn")
        shift
        echo "🏗️ Running Maven with Vault environment..."
        mvn "$@"
        ;;
    "docker")
        shift  
        echo "🐳 Running Docker with Vault environment..."
        docker "$@"
        ;;
    "node")
        shift
        echo "📦 Running Node.js with Vault environment..."
        node "$@"
        ;;
    *)
        echo "Usage: $0 {test-env|mvn|docker|node} [args...]"
        echo ""
        echo "Examples:"
        echo "  $0 test-env              # Show loaded environment"
        echo "  $0 mvn clean install     # Run Maven with Vault env"
        echo "  $0 docker-compose up -d  # Run Docker Compose with Vault env"
        echo "  $0 node server.js        # Run Node.js with Vault env"
        ;;
esac
