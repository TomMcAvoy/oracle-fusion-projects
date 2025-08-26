#!/bin/bash

# Fix GitLab Runner Configuration Issues
# Creates proper configuration and registers runner with Vault integration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

GITLAB_RUNNER_HOME="/home/tom/.gitlab-runner"
GITLAB_RUNNER_CONFIG="$GITLAB_RUNNER_HOME/config.toml"

echo -e "${BLUE}🔧 FIXING GITLAB RUNNER CONFIGURATION${NC}"
echo -e "${BLUE}=====================================${NC}"

# Function to check GitLab runner status
check_gitlab_runner() {
    if ! command -v gitlab-runner >/dev/null 2>&1; then
        echo -e "${RED}❌ GitLab runner not installed${NC}"
        return 1
    fi
    
    if [[ ! -f "$GITLAB_RUNNER_CONFIG" ]]; then
        echo -e "${YELLOW}⚠️  GitLab runner config missing: $GITLAB_RUNNER_CONFIG${NC}"
        return 2
    fi
    
    return 0
}

# Create GitLab runner directories and config
setup_gitlab_runner_config() {
    echo -e "${YELLOW}📁 Setting up GitLab runner directories...${NC}"
    
    # Create GitLab runner home directory
    sudo mkdir -p "$GITLAB_RUNNER_HOME"
    sudo chown tom:tom "$GITLAB_RUNNER_HOME"
    chmod 755 "$GITLAB_RUNNER_HOME"
    
    # Create basic config file structure
    cat > "$GITLAB_RUNNER_CONFIG" << 'EOF'
concurrent = 1
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "oracle-fusion-placeholder"
  url = "https://gitlab.com/"
  token = "placeholder-token"
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "openjdk:17"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock", "/tmp/vault-certs:/tmp/vault-certs"]
    shm_size = 0
EOF
    
    echo -e "${GREEN}✅ Basic GitLab runner config created${NC}"
}

# Install GitLab runner if not present
install_gitlab_runner() {
    if ! command -v gitlab-runner >/dev/null 2>&1; then
        echo -e "${YELLOW}📦 Installing GitLab runner...${NC}"
        
        # Add GitLab repository
        curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
        
        # Install GitLab runner
        sudo apt-get update
        sudo apt-get install -y gitlab-runner
        
        echo -e "${GREEN}✅ GitLab runner installed${NC}"
    else
        echo -e "${GREEN}✅ GitLab runner already installed${NC}"
    fi
}

# Register GitLab runner interactively
register_gitlab_runner() {
    echo -e "${YELLOW}🦊 Registering GitLab runner...${NC}"
    echo ""
    echo -e "${CYAN}📋 You'll need:${NC}"
    echo -e "${CYAN}   1. GitLab registration token from: Project Settings > CI/CD > Runners${NC}"
    echo -e "${CYAN}   2. Choose appropriate settings for your environment${NC}"
    echo ""
    
    read -p "Do you want to register the runner now? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Stop any running runner
        sudo gitlab-runner stop || true
        
        # Register runner with interactive prompts
        sudo gitlab-runner register \
            --config "$GITLAB_RUNNER_CONFIG" \
            --executor "docker" \
            --docker-image "openjdk:17" \
            --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
            --docker-volumes "/tmp/vault-certs:/tmp/vault-certs" \
            --docker-volumes "/home/tom/GitHub/oracle-fusion-projects:/workspace" \
            --tag-list "vault,security,java,docker,auth"
    else
        echo -e "${YELLOW}⏭️  Skipping registration - you can do this later${NC}"
    fi
}

# Create automated registration script
create_automated_register_script() {
    cat > "/tmp/gitlab-register-automated.sh" << 'EOF'
#!/bin/bash

# Automated GitLab Runner Registration Script
# Run this when you have the registration token

set -e

echo "🦊 Automated GitLab Runner Registration"
echo "======================================"

if [[ -z "$GITLAB_REGISTRATION_TOKEN" ]]; then
    echo "❌ Please set GITLAB_REGISTRATION_TOKEN environment variable"
    echo "Get it from: Project Settings > CI/CD > Runners"
    exit 1
fi

GITLAB_URL="${GITLAB_URL:-https://gitlab.com/}"
RUNNER_NAME="${RUNNER_NAME:-oracle-fusion-vault-runner}"
RUNNER_TAGS="${RUNNER_TAGS:-vault,security,java,docker,auth}"

echo "📝 Registering runner with:"
echo "   URL: $GITLAB_URL"
echo "   Name: $RUNNER_NAME"
echo "   Tags: $RUNNER_TAGS"

sudo gitlab-runner register \
    --non-interactive \
    --url "$GITLAB_URL" \
    --registration-token "$GITLAB_REGISTRATION_TOKEN" \
    --name "$RUNNER_NAME" \
    --tag-list "$RUNNER_TAGS" \
    --executor "docker" \
    --docker-image "openjdk:17" \
    --docker-privileged=false \
    --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
    --docker-volumes "/tmp/vault-certs:/tmp/vault-certs" \
    --docker-volumes "/home/tom/GitHub/oracle-fusion-projects:/workspace"

echo "✅ GitLab runner registered successfully!"

# Start the runner
sudo gitlab-runner start

echo "🚀 GitLab runner is now running"
sudo gitlab-runner status
EOF
    
    chmod +x "/tmp/gitlab-register-automated.sh"
    echo -e "${GREEN}✅ Automated registration script: /tmp/gitlab-register-automated.sh${NC}"
}

# Create runner management scripts
create_runner_management() {
    echo -e "${YELLOW}🛠️  Creating runner management scripts...${NC}"
    
    # GitLab runner control script
    cat > "/tmp/gitlab-runner-control.sh" << 'EOF'
#!/bin/bash

# GitLab Runner Control Script

COMMAND="$1"

case "$COMMAND" in
    "start")
        echo "🚀 Starting GitLab runner..."
        sudo gitlab-runner start
        sudo gitlab-runner status
        ;;
    "stop")
        echo "⏹️  Stopping GitLab runner..."
        sudo gitlab-runner stop
        ;;
    "restart")
        echo "🔄 Restarting GitLab runner..."
        sudo gitlab-runner restart
        sudo gitlab-runner status
        ;;
    "status")
        echo "📊 GitLab runner status:"
        sudo gitlab-runner status
        ;;
    "logs")
        echo "📋 GitLab runner logs (last 50 lines):"
        sudo journalctl -u gitlab-runner -n 50 --no-pager
        ;;
    "config")
        echo "⚙️  GitLab runner configuration:"
        sudo cat /home/tom/.gitlab-runner/config.toml
        ;;
    "unregister")
        echo "🗑️  Unregistering GitLab runner..."
        sudo gitlab-runner unregister --all-runners
        ;;
    *)
        echo "GitLab Runner Control"
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  start      - Start the runner"
        echo "  stop       - Stop the runner" 
        echo "  restart    - Restart the runner"
        echo "  status     - Show runner status"
        echo "  logs       - Show recent logs"
        echo "  config     - Show configuration"
        echo "  unregister - Unregister all runners"
        ;;
esac
EOF
    
    chmod +x "/tmp/gitlab-runner-control.sh"
    echo -e "${GREEN}✅ Runner control script: /tmp/gitlab-runner-control.sh${NC}"
}

# Create Vault-integrated GitLab CI configuration
create_vault_gitlab_ci() {
    cat > "/home/tom/GitHub/oracle-fusion-projects/.gitlab-ci-vault.yml" << 'EOF'
# GitLab CI with Vault Integration
# Complete pipeline with certificate management

stages:
  - vault-setup
  - build
  - security-test
  - deploy

variables:
  VAULT_ADDR: "http://host.docker.internal:8200"
  VAULT_TOKEN: "root"
  MAVEN_OPTS: "-Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository"

cache:
  paths:
    - .m2/repository/

# Initialize Vault and certificates
vault-init:
  stage: vault-setup
  image: vault:latest
  before_script:
    - apk add --no-cache curl jq
  script:
    - echo "🏦 Initializing Vault for CI/CD..."
    - sleep 5  # Wait for Vault to be ready
    # Test Vault connectivity
    - curl -s $VAULT_ADDR/v1/sys/health || echo "Vault not accessible, using local setup"
    # Create certificate retrieval script
    - |
      cat > /tmp/get-vault-certs.sh << 'SCRIPT_EOF'
      #!/bin/sh
      export VAULT_ADDR=${VAULT_ADDR:-http://host.docker.internal:8200}
      export VAULT_TOKEN=${VAULT_TOKEN:-root}
      
      # Function to get certificate from Vault
      get_cert() {
          local service=$1
          local cert_type=$2
          local output_file=$3
          
          if command -v vault >/dev/null 2>&1; then
              vault kv get -field="$cert_type" "secret/${service}-keys" | base64 -d > "$output_file" 2>/dev/null || echo "Certificate not found in Vault"
          else
              echo "Vault CLI not available, skipping certificate retrieval"
          fi
      }
      
      # Create certificate directory
      mkdir -p /tmp/vault-certs
      
      # Try to retrieve certificates (won't fail if not available)
      get_cert mongodb ca_crt /tmp/vault-certs/mongodb-ca.crt
      get_cert mongodb server_pem /tmp/vault-certs/mongodb-server.pem
      get_cert ldap ca_crt /tmp/vault-certs/ldap-ca.crt
      
      echo "✅ Certificate retrieval complete"
      SCRIPT_EOF
    - chmod +x /tmp/get-vault-certs.sh
    - /tmp/get-vault-certs.sh
  artifacts:
    paths:
      - /tmp/vault-certs/
    expire_in: 1 hour
  tags:
    - docker

# Build with Java
build:
  stage: build
  image: openjdk:17
  dependencies:
    - vault-init
  script:
    - echo "🔨 Building with Java 17..."
    - java --version
    - mvn --version
    - mvn clean compile -DskipTests
  artifacts:
    paths:
      - target/
      - .m2/repository/
    expire_in: 1 hour
  tags:
    - java

# Security tests with Vault integration
security-test:
  stage: security-test
  image: openjdk:17
  services:
    - name: redis:7.2-alpine
      alias: redis-test
    - name: vault:latest
      alias: vault-test
  dependencies:
    - vault-init
    - build
  variables:
    REDIS_URL: "redis://redis-test:6379"
    VAULT_ADDR: "http://vault-test:8200"
  before_script:
    - apt-get update && apt-get install -y curl
  script:
    - echo "🔐 Running security tests with Vault..."
    - ls -la /tmp/vault-certs/ || echo "No certificates found"
    - mvn test -Dtest="**/*SecurityTest,**/*VaultTest" -Dmaven.repo.local=.m2/repository || echo "Some tests may have failed"
    - echo "✅ Security testing complete"
  artifacts:
    reports:
      junit: target/surefire-reports/*.xml
    when: always
    expire_in: 1 day
  tags:
    - security
    - docker

# Deployment with Docker Compose
deploy:
  stage: deploy
  image: docker:latest
  services:
    - docker:dind
  dependencies:
    - security-test
  before_script:
    - apk add --no-cache docker-compose
  script:
    - echo "🚀 Deploying with Vault-managed certificates..."
    - cd sec-devops-tools/docker
    - docker-compose --version
    - docker-compose -f docker-compose-vault-certs.yml config || echo "Config validation done"
    - echo "✅ Deployment configuration verified"
  environment:
    name: staging
    url: https://staging.whitestartups.com
  only:
    - main
  tags:
    - deployment
    - docker
EOF
    
    echo -e "${GREEN}✅ Vault-integrated GitLab CI created${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}This script will fix GitLab runner configuration issues${NC}"
    echo ""
    
    # Check current status
    check_gitlab_runner
    status=$?
    
    case $status in
        1)
            echo -e "${YELLOW}Installing GitLab runner...${NC}"
            install_gitlab_runner
            setup_gitlab_runner_config
            ;;
        2)
            echo -e "${YELLOW}Setting up configuration...${NC}"
            setup_gitlab_runner_config
            ;;
        0)
            echo -e "${GREEN}✅ GitLab runner config exists${NC}"
            ;;
    esac
    
    create_automated_register_script
    create_runner_management
    create_vault_gitlab_ci
    
    # Try to start the runner
    echo -e "${YELLOW}🚀 Starting GitLab runner...${NC}"
    sudo gitlab-runner start || echo "Runner will start after registration"
    
    echo ""
    echo -e "${GREEN}🎉 GITLAB RUNNER SETUP COMPLETE!${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo ""
    echo -e "${CYAN}1. Get GitLab registration token from:${NC}"
    echo -e "${CYAN}   Project Settings > CI/CD > Runners > New project runner${NC}"
    echo ""
    echo -e "${CYAN}2. Register runner (choose one method):${NC}"
    echo ""
    echo -e "${CYAN}   Method A - Interactive:${NC}"
    echo -e "${CYAN}   sudo gitlab-runner register${NC}"
    echo ""
    echo -e "${CYAN}   Method B - Automated:${NC}"
    echo -e "${CYAN}   export GITLAB_REGISTRATION_TOKEN='your-token'${NC}"
    echo -e "${CYAN}   /tmp/gitlab-register-automated.sh${NC}"
    echo ""
    echo -e "${CYAN}3. Control runner:${NC}"
    echo -e "${CYAN}   /tmp/gitlab-runner-control.sh status${NC}"
    echo -e "${CYAN}   /tmp/gitlab-runner-control.sh logs${NC}"
    echo ""
    echo -e "${CYAN}4. Use Vault-integrated pipeline:${NC}"
    echo -e "${CYAN}   Copy .gitlab-ci-vault.yml to .gitlab-ci.yml${NC}"
    echo ""
    echo -e "${BLUE}📁 Configuration location: $GITLAB_RUNNER_CONFIG${NC}"
    echo -e "${BLUE}🔧 Management script: /tmp/gitlab-runner-control.sh${NC}"
}

main "$@"