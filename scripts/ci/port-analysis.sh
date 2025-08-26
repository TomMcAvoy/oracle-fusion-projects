#!/bin/bash

# Multi-Runner Port Analysis Script
# Shows networking details for GitHub Actions and GitLab CI runners

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}🔍 MULTI-RUNNER PORT ANALYSIS${NC}"
echo -e "${BOLD}${BLUE}=============================${NC}"
echo ""

# Check GitHub Actions Runner
check_github_runner_ports() {
    echo -e "${YELLOW}📡 GitHub Actions Runner:${NC}"
    
    if pgrep -f "Runner.Listener" > /dev/null; then
        runner_pid=$(pgrep -f "Runner.Listener")
        echo -e "${GREEN}   ✅ Process running (PID: $runner_pid)${NC}"
        
        # Check listening ports
        local listening_ports=$(sudo netstat -tlnp 2>/dev/null | grep $runner_pid || echo "")
        if [[ -n "$listening_ports" ]]; then
            echo -e "${RED}   🔴 Listening ports found:${NC}"
            echo "$listening_ports" | sed 's/^/      /'
        else
            echo -e "${GREEN}   ✅ No listening ports (outbound only)${NC}"
        fi
        
        # Check outbound connections
        local connections=$(sudo netstat -tnp 2>/dev/null | grep $runner_pid | head -3 || echo "")
        if [[ -n "$connections" ]]; then
            echo -e "${CYAN}   📡 Active connections:${NC}"
            echo "$connections" | sed 's/^/      /'
        else
            echo -e "${CYAN}   📡 No active connections${NC}"
        fi
    else
        echo -e "${RED}   ❌ Not running${NC}"
    fi
    echo ""
}

# Check GitLab Runner
check_gitlab_runner_ports() {
    echo -e "${YELLOW}🦊 GitLab Runner:${NC}"
    
    if pgrep -f gitlab-runner > /dev/null; then
        runner_pid=$(pgrep -f gitlab-runner)
        echo -e "${GREEN}   ✅ Process running (PID: $runner_pid)${NC}"
        
        # Check listening ports
        local listening_ports=$(sudo netstat -tlnp 2>/dev/null | grep $runner_pid || echo "")
        if [[ -n "$listening_ports" ]]; then
            echo -e "${RED}   🔴 Listening ports found:${NC}"
            echo "$listening_ports" | sed 's/^/      /'
        else
            echo -e "${GREEN}   ✅ No listening ports (outbound only)${NC}"
        fi
        
        # Check outbound connections
        local connections=$(sudo netstat -tnp 2>/dev/null | grep $runner_pid | head -3 || echo "")
        if [[ -n "$connections" ]]; then
            echo -e "${CYAN}   📡 Active connections:${NC}"
            echo "$connections" | sed 's/^/      /'
        else
            echo -e "${CYAN}   📡 No active connections${NC}"
        fi
    else
        echo -e "${RED}   ❌ Not running${NC}"
    fi
    echo ""
}

# Check Vault and other services
check_supporting_services() {
    echo -e "${YELLOW}🏦 Supporting Services:${NC}"
    
    # Vault
    if docker ps | grep -q dev-vault; then
        echo -e "${GREEN}   ✅ Vault container running${NC}"
        local vault_ports=$(docker port dev-vault 2>/dev/null || echo "8200/tcp -> 0.0.0.0:8200")
        echo -e "${CYAN}   📡 Port mapping: $vault_ports${NC}"
    else
        echo -e "${RED}   ❌ Vault not running${NC}"
    fi
    echo ""
}

# Check for potential port conflicts
check_common_ports() {
    echo -e "${YELLOW}📊 Common Development Ports:${NC}"
    
    local ports=(3000 5432 6379 8080 8200 9000)
    for port in "${ports[@]}"; do
        if netstat -tln 2>/dev/null | grep -q ":$port "; then
            local process=$(sudo lsof -i :$port 2>/dev/null | tail -n +2 | awk '{print $1}' | head -1 || echo "Unknown")
            echo -e "${RED}   🔴 Port $port: OCCUPIED ($process)${NC}"
        else
            echo -e "${GREEN}   ✅ Port $port: Available${NC}"
        fi
    done
    echo ""
}

# Show network summary
show_network_summary() {
    echo -e "${BOLD}${BLUE}📋 NETWORKING SUMMARY${NC}"
    echo -e "${BLUE}=====================${NC}"
    
    echo -e "${CYAN}Connection Pattern:${NC}"
    echo -e "${CYAN}  GitHub Runner → github.com:443 (HTTPS outbound)${NC}"
    echo -e "${CYAN}  GitLab Runner → gitlab.com:443 (HTTPS outbound)${NC}"
    echo -e "${CYAN}  Vault Service → localhost:8200 (Docker container)${NC}"
    
    echo ""
    echo -e "${GREEN}✅ Port Conflict Analysis:${NC}"
    echo -e "${GREEN}   • Runners use outbound connections only${NC}"
    echo -e "${GREEN}   • No listening ports = No direct conflicts${NC}"
    echo -e "${GREEN}   • Conflicts only possible in job containers${NC}"
    
    echo ""
    echo -e "${YELLOW}⚠️  Potential Conflict Areas:${NC}"
    echo -e "${YELLOW}   • Docker containers started by jobs${NC}"
    echo -e "${YELLOW}   • Development servers in pipelines${NC}"
    echo -e "${YELLOW}   • Database containers in tests${NC}"
    
    echo ""
    echo -e "${BLUE}💡 Best Practice:${NC}"
    echo -e "${BLUE}   Use Docker networking instead of host ports${NC}"
}

# Main execution
main() {
    check_github_runner_ports
    check_gitlab_runner_ports
    check_supporting_services
    check_common_ports
    show_network_summary
}

# Handle command line arguments
case "${1:-all}" in
    "github")
        check_github_runner_ports
        ;;
    "gitlab")
        check_gitlab_runner_ports
        ;;
    "vault")
        check_supporting_services
        ;;
    "ports")
        check_common_ports
        ;;
    "summary")
        show_network_summary
        ;;
    "all"|*)
        main
        ;;
esac