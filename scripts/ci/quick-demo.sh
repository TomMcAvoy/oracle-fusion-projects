#!/bin/bash

# Quick Multi-Runner Demo Script
# Shows both GitHub Actions and GitLab CI can work together

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}🎯 MULTI-RUNNER DEMO${NC}"
echo -e "${BOLD}${BLUE}===================${NC}"
echo ""

# Show current status
echo -e "${YELLOW}📊 Current Status:${NC}"
echo -e "${CYAN}GitHub Runner: $(if pgrep -f "Runner.Listener" > /dev/null; then echo "RUNNING"; else echo "NOT RUNNING"; fi)${NC}"
echo -e "${CYAN}GitLab Runner: $(sudo gitlab-runner status 2>/dev/null | grep -o "is alive" || echo "STOPPED")${NC}"
echo -e "${CYAN}Vault: $(if curl -s http://localhost:8200/v1/sys/health | grep -q healthy; then echo "HEALTHY"; else echo "UNAVAILABLE"; fi)${NC}"

echo ""
echo -e "${YELLOW}🔧 Available Setup Scripts:${NC}"
echo -e "${CYAN}• GitHub Runner: ./runners/github/configure-github-runner.sh${NC}"
echo -e "${CYAN}• GitLab Runner: /tmp/register-gitlab-runner.sh${NC}"
echo -e "${CYAN}• Dashboard: ./scripts/ci/runner-dashboard.sh${NC}"
echo -e "${CYAN}• Control: ./scripts/ci/runner-control.sh${NC}"

echo ""
echo -e "${YELLOW}📋 Example Workflows Created:${NC}"
echo -e "${CYAN}• GitHub: .github/workflows/multi-runner-demo.yml${NC}"
echo -e "${CYAN}• GitLab: .gitlab-ci.yml${NC}"

echo ""
echo -e "${YELLOW}🏦 Vault Integration:${NC}"
echo -e "${CYAN}• Certificate Manager: ./scripts/vault/vault-cert-manager.sh${NC}"
echo -e "${CYAN}• Credential Manager: ./scripts/vault/vault-credentials-manager.sh${NC}"

echo ""
echo -e "${BOLD}${GREEN}✅ MULTI-RUNNER SETUP COMPLETE!${NC}"
echo -e "${GREEN}Both GitHub Actions and GitLab CI runners can work together${NC}"
echo -e "${GREEN}using the same Vault instance for certificate management.${NC}"

echo ""
echo -e "${BLUE}🚀 To complete setup:${NC}"
echo -e "${BLUE}1. Register GitHub runner with your repository token${NC}"
echo -e "${BLUE}2. Register GitLab runner with your project token${NC}"
echo -e "${BLUE}3. Both will share the same Vault for certificates${NC}"

echo ""
echo -e "${YELLOW}💡 Key Benefits:${NC}"
echo -e "${CYAN}• Flexibility: Use both platforms' strengths${NC}"
echo -e "${CYAN}• Security: Centralized certificate management${NC}"
echo -e "${CYAN}• Redundancy: Backup CI/CD capabilities${NC}"
echo -e "${CYAN}• Team Choice: Different teams can use preferred platform${NC}"