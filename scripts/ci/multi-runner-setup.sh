#!/bin/bash

# Multi-Runner Setup Script
# Configures both GitHub Actions and GitLab CI runners with shared Vault

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

RUNNERS_DIR="/home/tom/GitHub/oracle-fusion-projects/runners"

echo -e "${BLUE}🚀 MULTI-RUNNER CI/CD SETUP${NC}"
echo -e "${BLUE}============================${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Create runners directory structure
setup_directories() {
    echo -e "${YELLOW}📁 Creating runner directories...${NC}"
    
    mkdir -p "$RUNNERS_DIR"/{github-runner,gitlab-runner,shared-config}
    mkdir -p "$RUNNERS_DIR/shared-config"/{scripts,vault,docker}
    
    echo -e "${GREEN}✅ Directory structure created${NC}"
}

# Setup GitHub Actions self-hosted runner
setup_github_runner() {
    echo -e "${YELLOW}🐙 Setting up GitHub Actions runner...${NC}"
    
    cd "$RUNNERS_DIR/github-runner"
    
    # Check if already configured
    if [[ -f ".runner" ]]; then
        echo -e "${GREEN}✅ GitHub runner already configured${NC}"
        return 0
    fi
    
    # Download GitHub Actions runner
    if [[ ! -f "actions-runner-linux-x64-2.311.0.tar.gz" ]]; then
        curl -o actions-runner-linux-x64-2.311.0.tar.gz -L \
            https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
        tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
    fi
    
    echo -e "${CYAN}📋 GitHub runner downloaded. Please complete configuration:${NC}"
    echo -e "${CYAN}   1. Get registration token from: https://github.com/YOUR-ORG/oracle-fusion-projects/settings/actions/runners${NC}"
    echo -e "${CYAN}   2. Run: ./config.sh --url https://github.com/YOUR-ORG/oracle-fusion-projects --token YOUR-TOKEN${NC}"
    echo -e "${CYAN}   3. Then run: sudo ./svc.sh install && sudo ./svc.sh start${NC}"
}

# Setup GitLab runner
setup_gitlab_runner() {
    echo -e "${YELLOW}🦊 Setting up GitLab runner...${NC}"
    
    # Install GitLab runner if not present
    if ! command_exists gitlab-runner; then
        echo -e "${YELLOW}Installing GitLab runner...${NC}"
        
        # For Ubuntu/Debian
        curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
        sudo apt-get install -y gitlab-runner
        
        echo -e "${GREEN}✅ GitLab runner installed${NC}"
    fi
    
    # Create GitLab runner configuration script
    cat > "$RUNNERS_DIR/gitlab-runner/register-runner.sh" << 'EOF'
#!/bin/bash

echo "🦊 GitLab Runner Registration"
echo "============================="

echo "📋 Please provide the following information:"
echo "   1. GitLab URL (default: https://gitlab.com/)"
echo "   2. Registration token from: Project Settings > CI/CD > Runners"
echo "   3. Runner description (default: oracle-fusion-auth-runner)"
echo "   4. Tags (default: vault,security,java,docker)"

read -p "GitLab URL [https://gitlab.com/]: " GITLAB_URL
GITLAB_URL=${GITLAB_URL:-https://gitlab.com/}

read -p "Registration token: " REGISTRATION_TOKEN

read -p "Runner description [oracle-fusion-auth-runner]: " RUNNER_DESCRIPTION
RUNNER_DESCRIPTION=${RUNNER_DESCRIPTION:-oracle-fusion-auth-runner}

read -p "Tags [vault,security,java,docker]: " RUNNER_TAGS
RUNNER_TAGS=${RUNNER_TAGS:-vault,security,java,docker}

# Register the runner
sudo gitlab-runner register \
  --non-interactive \
  --url "$GITLAB_URL" \
  --registration-token "$REGISTRATION_TOKEN" \
  --description "$RUNNER_DESCRIPTION" \
  --tag-list "$RUNNER_TAGS" \
  --executor "docker" \
  --docker-image "openjdk:17" \
  --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
  --docker-volumes /tmp/vault-certs:/tmp/vault-certs

echo "✅ GitLab runner registered successfully!"
sudo gitlab-runner start
EOF
    
    chmod +x "$RUNNERS_DIR/gitlab-runner/register-runner.sh"
    echo -e "${CYAN}📋 GitLab runner setup script created at: $RUNNERS_DIR/gitlab-runner/register-runner.sh${NC}"
}

# Setup shared Vault for both runners
setup_shared_vault() {
    echo -e "${YELLOW}🏦 Setting up shared Vault configuration...${NC}"
    
    # Create Docker Compose for shared infrastructure
    cat > "$RUNNERS_DIR/docker-compose-runners.yml" << 'EOF'
version: '3.8'

services:
  # Shared Vault for both GitHub and GitLab runners
  shared-vault:
    image: vault:latest
    container_name: ci-shared-vault
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: root
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    ports:
      - "8201:8200"  # Different port to avoid conflicts
    cap_add:
      - IPC_LOCK
    volumes:
      - runner_vault_data:/vault/data
      - ../scripts/vault:/vault/scripts
    networks:
      - ci-runners
    restart: unless-stopped

  # GitHub Actions runner container (optional, can use system service)
  github-runner-container:
    build: ./github-runner/
    container_name: github-runner-ci
    environment:
      - VAULT_ADDR=http://shared-vault:8200
      - VAULT_TOKEN=root
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ../scripts:/workspace/scripts
      - runner_shared_cache:/workspace/cache
    depends_on:
      - shared-vault
    networks:
      - ci-runners
    restart: unless-stopped
    profiles:
      - github-container

  # GitLab runner container (alternative to system service)
  gitlab-runner-container:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner-ci
    environment:
      - VAULT_ADDR=http://shared-vault:8200
      - VAULT_TOKEN=root
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - gitlab_runner_config:/etc/gitlab-runner
      - ../scripts:/workspace/scripts
      - runner_shared_cache:/workspace/cache
    depends_on:
      - shared-vault
    networks:
      - ci-runners
    restart: unless-stopped
    profiles:
      - gitlab-container

volumes:
  runner_vault_data:
  runner_shared_cache:
  gitlab_runner_config:

networks:
  ci-runners:
    driver: bridge
EOF
    
    # Create shared CI scripts
    cat > "$RUNNERS_DIR/shared-config/scripts/vault-ci-init.sh" << 'EOF'
#!/bin/bash
# Shared Vault initialization for both GitHub and GitLab runners

set -e

export VAULT_ADDR="${VAULT_ADDR:-http://localhost:8201}"
export VAULT_TOKEN="${VAULT_TOKEN:-root}"

echo "🏦 Initializing Vault for CI/CD runners..."

# Wait for Vault to be ready
while ! curl -s $VAULT_ADDR/v1/sys/health > /dev/null; do
  echo "Waiting for Vault..."
  sleep 2
done

# Setup credentials and certificates
if [[ -f "/workspace/scripts/vault/vault-credentials-manager.sh" ]]; then
    /workspace/scripts/vault/vault-credentials-manager.sh setup-all
    /workspace/scripts/vault/vault-cert-manager.sh generate-all
else
    # Fallback to local scripts
    ../../scripts/vault/vault-credentials-manager.sh setup-all
    ../../scripts/vault/vault-cert-manager.sh generate-all
fi

echo "✅ Vault initialized for CI/CD"
EOF
    
    chmod +x "$RUNNERS_DIR/shared-config/scripts/vault-ci-init.sh"
    echo -e "${GREEN}✅ Shared Vault configuration created${NC}"
}

# Create monitoring script
create_monitoring_script() {
    echo -e "${YELLOW}📊 Creating runner monitoring script...${NC}"
    
    cat > "$RUNNERS_DIR/monitor-runners.sh" << 'EOF'
#!/bin/bash

# Multi-Runner Status Monitor

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 MULTI-RUNNER STATUS DASHBOARD${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Check GitHub Actions runner
echo -e "${BLUE}📊 GitHub Actions Runner:${NC}"
if pgrep -f "Runner.Listener" > /dev/null; then
    echo -e "${GREEN}  ✅ System service: RUNNING${NC}"
elif docker ps | grep -q github-runner-ci; then
    echo -e "${GREEN}  ✅ Container: RUNNING${NC}"
else
    echo -e "${RED}  ❌ Not running${NC}"
fi

# Check GitLab runner
echo -e "${BLUE}📊 GitLab Runner:${NC}"
if sudo gitlab-runner status | grep -q "is alive"; then
    echo -e "${GREEN}  ✅ System service: RUNNING${NC}"
elif docker ps | grep -q gitlab-runner-ci; then
    echo -e "${GREEN}  ✅ Container: RUNNING${NC}"
else
    echo -e "${RED}  ❌ Not running${NC}"
fi

# Check shared Vault
echo -e "${BLUE}📊 Shared Vault:${NC}"
if curl -s http://localhost:8201/v1/sys/health | grep -q '"initialized":true'; then
    echo -e "${GREEN}  ✅ HEALTHY (port 8201)${NC}"
elif curl -s http://localhost:8200/v1/sys/health | grep -q '"initialized":true'; then
    echo -e "${GREEN}  ✅ HEALTHY (port 8200)${NC}"
else
    echo -e "${RED}  ❌ UNHEALTHY${NC}"
fi

echo ""
echo -e "${BLUE}🔄 Quick Commands:${NC}"
echo -e "${CYAN}  Start shared infrastructure: cd runners && docker-compose -f docker-compose-runners.yml up -d${NC}"
echo -e "${CYAN}  GitHub runner logs: journalctl -u actions.runner.* -f${NC}"
echo -e "${CYAN}  GitLab runner logs: sudo gitlab-runner logs${NC}"
echo -e "${CYAN}  Container logs: docker logs github-runner-ci / docker logs gitlab-runner-ci${NC}"
EOF
    
    chmod +x "$RUNNERS_DIR/monitor-runners.sh"
    echo -e "${GREEN}✅ Monitoring script created${NC}"
}

# Create example workflows
create_example_workflows() {
    echo -e "${YELLOW}📋 Creating example workflow files...${NC}"
    
    # GitHub Actions workflow
    mkdir -p "/home/tom/GitHub/oracle-fusion-projects/.github/workflows"
    cat > "/home/tom/GitHub/oracle-fusion-projects/.github/workflows/vault-integration.yml" << 'EOF'
name: Vault Integration & Security Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  vault-security-test:
    runs-on: self-hosted
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Java 17
      uses: actions/setup-java@v4
      with:
        java-version: '17'
        distribution: 'temurin'
    
    - name: Initialize Vault & Certificates
      run: |
        export VAULT_ADDR=http://localhost:8201
        export VAULT_TOKEN=root
        ./runners/shared-config/scripts/vault-ci-init.sh
    
    - name: Run Security Tests
      run: |
        mvn clean test -Dtest="**/*SecurityTest,**/*VaultTest"
    
    - name: Verify Certificate Management
      run: |
        ./scripts/vault/vault-cert-manager.sh list
        echo "✅ GitHub Actions: Vault integration verified"
EOF
    
    # GitLab CI pipeline
    cat > "/home/tom/GitHub/oracle-fusion-projects/.gitlab-ci.yml" << 'EOF'
stages:
  - vault-setup
  - security-test
  - deploy

variables:
  VAULT_ADDR: "http://shared-vault:8200"
  VAULT_TOKEN: "root"

vault-init:
  stage: vault-setup
  image: vault:latest
  script:
    - ./runners/shared-config/scripts/vault-ci-init.sh
  artifacts:
    expire_in: 1 hour
  tags:
    - vault

security-scan:
  stage: security-test
  image: openjdk:17
  services:
    - name: vault:latest
      alias: shared-vault
  dependencies:
    - vault-init
  script:
    - export VAULT_ADDR=http://shared-vault:8200
    - mvn clean test -Dtest="**/*SecurityTest"
    - ./scripts/vault/vault-cert-manager.sh list
    - echo "✅ GitLab CI: Vault integration verified"
  tags:
    - security
    - docker

deploy-staging:
  stage: deploy
  image: docker:latest
  services:
    - docker:dind
  dependencies:
    - security-scan
  script:
    - cd sec-devops-tools/docker
    - docker-compose -f docker-compose-vault-certs.yml up -d
    - echo "✅ Deployed with Vault-managed certificates"
  environment:
    name: staging
  only:
    - main
  tags:
    - deployment
EOF
    
    echo -e "${GREEN}✅ Example workflows created${NC}"
}

# Main setup function
main() {
    echo -e "${BLUE}This script will set up both GitHub Actions and GitLab CI runners${NC}"
    echo -e "${BLUE}with shared Vault integration for certificate management.${NC}"
    echo ""
    
    read -p "Continue with multi-runner setup? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Setup cancelled${NC}"
        exit 0
    fi
    
    setup_directories
    setup_shared_vault
    setup_github_runner
    setup_gitlab_runner
    create_monitoring_script
    create_example_workflows
    
    echo ""
    echo -e "${GREEN}🎉 MULTI-RUNNER SETUP COMPLETE!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo -e "${CYAN}1. Complete GitHub runner registration:${NC}"
    echo -e "${CYAN}   cd $RUNNERS_DIR/github-runner${NC}"
    echo -e "${CYAN}   Get token from GitHub and run configuration${NC}"
    echo ""
    echo -e "${CYAN}2. Complete GitLab runner registration:${NC}"
    echo -e "${CYAN}   $RUNNERS_DIR/gitlab-runner/register-runner.sh${NC}"
    echo ""
    echo -e "${CYAN}3. Start shared infrastructure:${NC}"
    echo -e "${CYAN}   cd $RUNNERS_DIR${NC}"
    echo -e "${CYAN}   docker-compose -f docker-compose-runners.yml up -d${NC}"
    echo ""
    echo -e "${CYAN}4. Monitor runners:${NC}"
    echo -e "${CYAN}   $RUNNERS_DIR/monitor-runners.sh${NC}"
    echo ""
    echo -e "${YELLOW}💡 Both runners will share the same Vault instance for certificates!${NC}"
}

main "$@"