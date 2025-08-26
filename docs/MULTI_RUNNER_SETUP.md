# Multi-Runner CI/CD Setup Guide

## Overview

Yes, you can run both **GitHub runners** and **GitLab runners** in the same project! They are independent CI/CD systems that can coexist and serve different purposes.

## Architecture

```
📁 Your Project
├── .github/workflows/          # GitHub Actions workflows
├── .gitlab-ci.yml             # GitLab CI/CD pipeline
├── runners/
│   ├── github-runner/         # GitHub self-hosted runner setup
│   ├── gitlab-runner/         # GitLab runner setup
│   └── shared-runner/         # Hybrid runner configuration
└── scripts/ci/               # Shared CI scripts
```

## Why Use Both?

### **GitHub Actions Strengths:**
- 🔄 Excellent for automated testing and deployment
- 🌐 Great marketplace of actions
- 📊 Built-in security scanning
- 🚀 Fast startup times

### **GitLab CI/CD Strengths:**
- 📋 Superior pipeline visualization
- 🐳 Excellent Docker integration
- 📈 Advanced deployment strategies
- 🔐 Built-in security features

## Setup Instructions

### 1. Install Both Runner Types

#### GitHub Self-Hosted Runner
```bash
# Download and configure GitHub runner
mkdir -p runners/github-runner
cd runners/github-runner

# Download latest runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure runner (get token from GitHub repo settings)
./config.sh --url https://github.com/YOUR-ORG/oracle-fusion-projects --token YOUR-REGISTRATION-TOKEN

# Start runner as service
sudo ./svc.sh install
sudo ./svc.sh start
```

#### GitLab Runner
```bash
# Install GitLab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
sudo yum install gitlab-runner

# Register GitLab runner (get token from GitLab project settings)
sudo gitlab-runner register \
  --url "https://gitlab.com/" \
  --registration-token "YOUR-GITLAB-TOKEN" \
  --description "oracle-fusion-auth-runner" \
  --tag-list "vault,security,java" \
  --executor "docker" \
  --docker-image "openjdk:17"

# Start GitLab runner
sudo gitlab-runner start
```

### 2. Configuration Files

#### GitHub Actions Workflow (`.github/workflows/security-scan.yml`)
```yaml
name: Security & Vault Integration Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  vault-integration-test:
    runs-on: self-hosted
    services:
      vault:
        image: vault:latest
        env:
          VAULT_DEV_ROOT_TOKEN_ID: root
        options: --cap-add=IPC_LOCK
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Java 17
      uses: actions/setup-java@v4
      with:
        java-version: '17'
        distribution: 'temurin'
    
    - name: Start Vault & Generate Certificates
      run: |
        cd sec-devops-tools/docker/vault
        docker-compose up -d
        sleep 10
        ../../scripts/vault/vault-credentials-manager.sh setup-all
        ../../scripts/vault/vault-cert-manager.sh generate-all
    
    - name: Run Security Tests
      run: |
        mvn clean test -Dtest="**/*SecurityTest,**/*VaultTest"
    
    - name: Vault Certificate Verification
      run: |
        ./scripts/vault/vault-cert-manager.sh list
        ./testing/typescript/secure-cache-warmup.js --verify-only
```

#### GitLab CI/CD Pipeline (`.gitlab-ci.yml`)
```yaml
stages:
  - validate
  - build
  - security
  - deploy

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository"
  VAULT_ADDR: "http://vault:8200"
  VAULT_TOKEN: "root"

cache:
  paths:
    - .m2/repository/

# Vault & Certificate Management
vault-setup:
  stage: validate
  image: vault:latest
  services:
    - name: vault:latest
      alias: vault
      command: ["vault", "server", "-dev", "-dev-root-token-id=root"]
  script:
    - sleep 5
    - export VAULT_ADDR=http://vault:8200
    - export VAULT_TOKEN=root
    - ./scripts/vault/vault-credentials-manager.sh setup-all
    - ./scripts/vault/vault-cert-manager.sh generate-all
  artifacts:
    reports:
      dotenv: vault-config.env
    expire_in: 1 hour
  tags:
    - docker
    - vault

# Java Build with Vault Integration
build:
  stage: build
  image: openjdk:17
  dependencies:
    - vault-setup
  script:
    - ./scripts/vault/vault-credentials-manager.sh generate-env .env.vault
    - source .env.vault
    - mvn clean compile -DskipTests
  artifacts:
    paths:
      - target/
    expire_in: 1 hour
  tags:
    - docker
    - java

# Security Testing with Real Vault
security-scan:
  stage: security
  image: openjdk:17
  services:
    - name: vault:latest
      alias: vault
    - name: mongo:7.0
      alias: mongodb
    - name: redis:7.2-alpine
      alias: redis
  dependencies:
    - vault-setup
    - build
  script:
    - source vault-config.env
    - ./scripts/shell/start-secure-mongodb-vault.sh
    - mvn test -Dtest="**/*SecurityTest"
    - ./testing/typescript/vault-test-credentials.js --full-test
  artifacts:
    reports:
      junit: target/surefire-reports/*.xml
    when: always
  tags:
    - docker
    - security

# Deployment with Certificate Refresh
deploy:
  stage: deploy
  image: docker:latest
  dependencies:
    - security-scan
  services:
    - docker:dind
  before_script:
    - docker info
  script:
    - cd sec-devops-tools/docker
    - docker-compose -f docker-compose-vault-certs.yml up -d
    - ./../../scripts/vault/setup-docker-secrets.sh
    - echo "✅ Deployment with Vault-managed certificates complete"
  environment:
    name: staging
    url: https://staging.whitestartups.com
  only:
    - main
  tags:
    - docker
    - deployment
```

### 3. Shared Runner Infrastructure

#### Docker Compose for Multi-Runner Setup
```yaml
# runners/docker-compose-multi-runner.yml
version: '3.8'

services:
  # GitHub Actions Runner
  github-runner:
    build: ./github-runner/
    container_name: github-actions-runner
    environment:
      - RUNNER_NAME=github-vault-runner
      - RUNNER_TOKEN=${GITHUB_RUNNER_TOKEN}
      - RUNNER_REPOSITORY_URL=https://github.com/YOUR-ORG/oracle-fusion-projects
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ../scripts:/workspace/scripts
      - vault_shared:/workspace/vault
    restart: unless-stopped
    networks:
      - runner-network

  # GitLab Runner  
  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - gitlab_runner_config:/etc/gitlab-runner
      - ../scripts:/workspace/scripts
      - vault_shared:/workspace/vault
    restart: unless-stopped
    networks:
      - runner-network

  # Shared Vault for both runners
  shared-vault:
    image: vault:latest
    container_name: shared-vault
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: root
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    ports:
      - "8200:8200"
    cap_add:
      - IPC_LOCK
    volumes:
      - vault_shared:/vault/data
    networks:
      - runner-network
    restart: unless-stopped

volumes:
  gitlab_runner_config:
  vault_shared:

networks:
  runner-network:
    driver: bridge
```

### 4. Coordination Strategies

#### Option A: Platform-Specific Workflows
- **GitHub**: Security scanning, code quality, automated testing
- **GitLab**: Build, deployment, infrastructure provisioning

#### Option B: Environment-Specific
- **GitHub**: Development and testing workflows  
- **GitLab**: Staging and production deployments

#### Option C: Trigger-Based
- **GitHub**: On pull requests and code changes
- **GitLab**: On releases and manual deployments

### 5. Shared Vault Integration

Both runners can access the same Vault instance for certificates and secrets:

```bash
# Shared script for both platforms
# scripts/ci/vault-integration.sh

#!/bin/bash
export VAULT_ADDR="${VAULT_ADDR:-http://shared-vault:8200}"
export VAULT_TOKEN="${VAULT_TOKEN:-root}"

# Wait for Vault to be ready
while ! curl -s $VAULT_ADDR/v1/sys/health > /dev/null; do
  echo "Waiting for Vault..."
  sleep 2
done

# Setup credentials and certificates
./scripts/vault/vault-credentials-manager.sh setup-all
./scripts/vault/vault-cert-manager.sh generate-all

echo "✅ Vault integration ready for both GitHub and GitLab runners"
```

## Monitoring & Management

### Runner Status Dashboard
```bash
#!/bin/bash
# scripts/ci/runner-status.sh

echo "🔍 MULTI-RUNNER STATUS DASHBOARD"
echo "================================="

# GitHub runner status
echo "📊 GitHub Actions Runner:"
if docker ps | grep -q github-actions-runner; then
    echo "  ✅ GitHub runner: RUNNING"
else
    echo "  ❌ GitHub runner: STOPPED"
fi

# GitLab runner status  
echo "📊 GitLab Runner:"
if docker ps | grep -q gitlab-runner; then
    echo "  ✅ GitLab runner: RUNNING"
else
    echo "  ❌ GitLab runner: STOPPED"
fi

# Shared Vault status
echo "📊 Shared Vault:"
if curl -s http://localhost:8200/v1/sys/health | grep -q '"initialized":true'; then
    echo "  ✅ Vault: HEALTHY"
else
    echo "  ❌ Vault: UNHEALTHY"
fi

echo ""
echo "🔄 Recent Activity:"
echo "GitHub: $(docker logs github-actions-runner --tail 1 2>/dev/null || echo 'No logs')"
echo "GitLab: $(docker logs gitlab-runner --tail 1 2>/dev/null || echo 'No logs')"
```

## Best Practices

### 1. **Resource Management**
```bash
# Set resource limits for runners
docker update --memory="2g" --cpus="1.5" github-actions-runner
docker update --memory="2g" --cpus="1.5" gitlab-runner
```

### 2. **Security Isolation**
- Use separate network segments for each runner
- Implement least-privilege access to Vault
- Rotate runner tokens regularly

### 3. **Monitoring**
```yaml
# Add to both workflows
- name: Report Status
  if: always()
  run: |
    echo "Runner: GitHub Actions" >> /tmp/runner-activity.log
    echo "Pipeline: ${{ github.workflow }}" >> /tmp/runner-activity.log
    echo "Status: ${{ job.status }}" >> /tmp/runner-activity.log
```

## Conclusion

Running both GitHub and GitLab runners provides:
- **🔄 Redundancy**: If one platform is down, the other continues
- **🎯 Specialization**: Use each platform's strengths
- **🌐 Flexibility**: Different teams can use their preferred platform
- **📊 Comprehensive Coverage**: Full CI/CD pipeline coverage

Both runners can share the same Vault instance for centralized certificate and credential management, providing a unified security model across platforms.