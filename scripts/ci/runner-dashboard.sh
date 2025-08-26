#!/bin/bash

# Comprehensive Multi-Runner Dashboard
# Monitors GitHub Actions, GitLab CI, and Vault status

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"

# Function to check service status
check_service() {
    local service_name="$1"
    local check_command="$2"
    
    if eval "$check_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $service_name: RUNNING${NC}"
        return 0
    else
        echo -e "${RED}❌ $service_name: STOPPED${NC}"
        return 1
    fi
}

# Function to get service info
get_service_info() {
    local service_name="$1"
    local info_command="$2"
    
    local info=$(eval "$info_command" 2>/dev/null || echo "Not available")
    echo -e "${CYAN}   Info: $info${NC}"
}

# Check GitHub Actions runner
check_github_runner() {
    echo -e "${BOLD}${BLUE}📊 GITHUB ACTIONS RUNNER${NC}"
    echo -e "${BLUE}=========================${NC}"
    
    # Check if runner process is running
    if pgrep -f "Runner.Listener" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Process: RUNNING${NC}"
        
        # Get runner info
        local runner_pid=$(pgrep -f "Runner.Listener")
        echo -e "${CYAN}   PID: $runner_pid${NC}"
        
        # Check if runner service is active
        if systemctl is-active actions.runner.* >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Service: ACTIVE${NC}"
            local service_name=$(systemctl --type=service | grep actions.runner | awk '{print $1}')
            echo -e "${CYAN}   Service: $service_name${NC}"
        else
            echo -e "${YELLOW}⚠️  Service: Not configured as systemd service${NC}"
        fi
        
        # Check runner logs for recent activity
        local last_activity=$(journalctl -u actions.runner.* --since "1 hour ago" -q --no-pager | tail -1 2>/dev/null || echo "No recent activity")
        echo -e "${CYAN}   Last activity: ${last_activity:0:60}...${NC}"
        
    elif docker ps | grep -q github-runner; then
        echo -e "${GREEN}✅ Container: RUNNING${NC}"
        echo -e "${CYAN}   Container: $(docker ps --format 'table {{.Names}}' | grep github-runner)${NC}"
    else
        echo -e "${RED}❌ GitHub runner: NOT RUNNING${NC}"
    fi
}

# Check GitLab runner
check_gitlab_runner() {
    echo ""
    echo -e "${BOLD}${BLUE}📊 GITLAB RUNNER${NC}"
    echo -e "${BLUE}================${NC}"
    
    if command -v gitlab-runner >/dev/null 2>&1; then
        # Check GitLab runner status
        local runner_status=$(sudo gitlab-runner status 2>/dev/null || echo "Error getting status")
        
        if echo "$runner_status" | grep -q "is alive"; then
            echo -e "${GREEN}✅ GitLab runner: RUNNING${NC}"
            
            # Get registered runners
            if [[ -f "/home/tom/.gitlab-runner/config.toml" ]]; then
                local runner_count=$(grep -c "\\[\\[runners\\]\\]" "/home/tom/.gitlab-runner/config.toml" 2>/dev/null || echo "0")
                echo -e "${CYAN}   Registered runners: $runner_count${NC}"
                
                # Get runner names
                local runner_names=$(grep "name =" "/home/tom/.gitlab-runner/config.toml" | cut -d'"' -f2 | tr '\n' ', ' | sed 's/,$//')
                echo -e "${CYAN}   Names: $runner_names${NC}"
            fi
            
            # Check recent logs
            local last_log=$(sudo journalctl -u gitlab-runner --since "1 hour ago" -q --no-pager | tail -1 2>/dev/null || echo "No recent logs")
            echo -e "${CYAN}   Last log: ${last_log:0:60}...${NC}"
            
        else
            echo -e "${RED}❌ GitLab runner: STOPPED${NC}"
            echo -e "${YELLOW}   Status: $runner_status${NC}"
        fi
    else
        echo -e "${RED}❌ GitLab runner: NOT INSTALLED${NC}"
    fi
}

# Check Vault status
check_vault_status() {
    echo ""
    echo -e "${BOLD}${BLUE}📊 VAULT STATUS${NC}"
    echo -e "${BLUE}===============${NC}"
    
    # Check Vault container
    if docker ps | grep -q "vault"; then
        echo -e "${GREEN}✅ Vault container: RUNNING${NC}"
        local vault_container=$(docker ps --format '{{.Names}}' | grep vault)
        echo -e "${CYAN}   Container: $vault_container${NC}"
    fi
    
    # Check Vault API
    local vault_health=$(curl -s "$VAULT_ADDR/v1/sys/health" 2>/dev/null || echo "")
    if echo "$vault_health" | grep -q '"initialized":true'; then
        echo -e "${GREEN}✅ Vault API: HEALTHY${NC}"
        
        # Check if sealed
        if echo "$vault_health" | grep -q '"sealed":false'; then
            echo -e "${GREEN}✅ Vault: UNSEALED${NC}"
        else
            echo -e "${YELLOW}⚠️  Vault: SEALED${NC}"
        fi
        
        # Check certificate availability
        check_vault_certificates
        
    else
        echo -e "${RED}❌ Vault API: UNREACHABLE${NC}"
        echo -e "${CYAN}   URL: $VAULT_ADDR${NC}"
    fi
}

# Check Vault certificates
check_vault_certificates() {
    echo -e "${CYAN}   🔐 Certificate Status:${NC}"
    
    for service in mongodb ldap wildfly; do
        local cert_check=$(docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" \
            $(docker ps --format '{{.Names}}' | grep vault | head -1) \
            vault kv get "secret/${service}-keys" 2>/dev/null || echo "")
        
        if [[ -n "$cert_check" ]]; then
            echo -e "${GREEN}     ✅ $service certificates: AVAILABLE${NC}"
        else
            echo -e "${YELLOW}     ⚠️  $service certificates: MISSING${NC}"
        fi
    done
}

# Check Docker services
check_docker_services() {
    echo ""
    echo -e "${BOLD}${BLUE}📊 DOCKER SERVICES${NC}"
    echo -e "${BLUE}==================${NC}"
    
    # List running containers relevant to CI/CD
    echo -e "${CYAN}   🐳 Running Containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep -E "(vault|gitlab|github|mongo|redis|ldap)" | \
        while read line; do
            echo -e "${CYAN}     $line${NC}"
        done 2>/dev/null || echo -e "${YELLOW}     No CI/CD containers running${NC}"
}

# Show runner activity summary
show_activity_summary() {
    echo ""
    echo -e "${BOLD}${BLUE}📊 RECENT ACTIVITY SUMMARY${NC}"
    echo -e "${BLUE}============================${NC}"
    
    # GitHub Actions activity
    echo -e "${MAGENTA}🐙 GitHub Actions (last 24h):${NC}"
    local gh_logs=$(journalctl -u actions.runner.* --since "24 hours ago" -q --no-pager 2>/dev/null || echo "")
    if [[ -n "$gh_logs" ]]; then
        echo "$gh_logs" | grep -E "(Job|completed|started)" | tail -3 | \
            while read line; do
                echo -e "${CYAN}   $line${NC}"
            done
    else
        echo -e "${YELLOW}   No recent GitHub Actions activity${NC}"
    fi
    
    # GitLab runner activity
    echo -e "${MAGENTA}🦊 GitLab Runner (last 24h):${NC}"
    local gl_logs=$(sudo journalctl -u gitlab-runner --since "24 hours ago" -q --no-pager 2>/dev/null || echo "")
    if [[ -n "$gl_logs" ]]; then
        echo "$gl_logs" | grep -E "(job|completed|started|received)" | tail -3 | \
            while read line; do
                echo -e "${CYAN}   $line${NC}"
            done
    else
        echo -e "${YELLOW}   No recent GitLab runner activity${NC}"
    fi
    
    # Vault activity
    echo -e "${MAGENTA}🏦 Vault Activity (last 24h):${NC}"
    local vault_logs=$(docker logs $(docker ps --format '{{.Names}}' | grep vault | head -1) --since 24h 2>/dev/null || echo "")
    if [[ -n "$vault_logs" ]]; then
        echo "$vault_logs" | grep -E "(request|auth|secret)" | tail -3 | \
            while read line; do
                echo -e "${CYAN}   ${line:0:80}...${NC}"
            done
    else
        echo -e "${YELLOW}   No recent Vault activity${NC}"
    fi
}

# Show quick commands
show_quick_commands() {
    echo ""
    echo -e "${BOLD}${BLUE}🔧 QUICK COMMANDS${NC}"
    echo -e "${BLUE}=================${NC}"
    
    echo -e "${YELLOW}GitLab Runner:${NC}"
    echo -e "${CYAN}  sudo gitlab-runner status${NC}"
    echo -e "${CYAN}  sudo gitlab-runner restart${NC}"
    echo -e "${CYAN}  sudo gitlab-runner logs${NC}"
    
    echo -e "${YELLOW}GitHub Actions:${NC}"
    echo -e "${CYAN}  journalctl -u actions.runner.* -f${NC}"
    echo -e "${CYAN}  systemctl status actions.runner.*${NC}"
    
    echo -e "${YELLOW}Vault:${NC}"
    echo -e "${CYAN}  docker logs dev-vault${NC}"
    echo -e "${CYAN}  ./scripts/vault/vault-cert-manager.sh list${NC}"
    
    echo -e "${YELLOW}Docker:${NC}"
    echo -e "${CYAN}  docker-compose -f sec-devops-tools/docker/docker-compose-vault-certs.yml up -d${NC}"
    echo -e "${CYAN}  docker ps | grep -E '(vault|runner)'${NC}"
}

# Main dashboard function
main() {
    clear
    echo -e "${BOLD}${MAGENTA}🎛️  MULTI-RUNNER CI/CD DASHBOARD${NC}"
    echo -e "${BOLD}${MAGENTA}================================${NC}"
    echo -e "${CYAN}$(date)${NC}"
    echo ""
    
    check_github_runner
    check_gitlab_runner
    check_vault_status
    check_docker_services
    show_activity_summary
    show_quick_commands
    
    echo ""
    echo -e "${BOLD}${GREEN}🔄 Dashboard refresh: $0${NC}"
    echo -e "${BOLD}${GREEN}🔍 Watch mode: watch -n 30 $0${NC}"
}

# Handle command line arguments
case "${1:-dashboard}" in
    "dashboard"|"")
        main
        ;;
    "github")
        check_github_runner
        ;;
    "gitlab")
        check_gitlab_runner
        ;;
    "vault")
        check_vault_status
        ;;
    "activity")
        show_activity_summary
        ;;
    "quick")
        show_quick_commands
        ;;
    *)
        echo "Multi-Runner Dashboard"
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  dashboard  - Full dashboard (default)"
        echo "  github     - GitHub Actions runner only"
        echo "  gitlab     - GitLab runner only"
        echo "  vault      - Vault status only"
        echo "  activity   - Recent activity summary"
        echo "  quick      - Quick commands reference"
        ;;
esac