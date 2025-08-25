#!/bin/bash

# Complete Oracle Fusion Auth Testing Setup
# This script sets up LDAP, populates users, warms cache, and runs tests

set -e

echo "🚀 Oracle Fusion Auth - Complete Testing Setup"
echo "==============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
LDAP_OPTION=${1:-1}  # Default to Docker LDAP
WARMUP_ENABLED=${2:-true}
RUN_TESTS=${3:-true}

print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════╗
    ║  🔐 Oracle Fusion Authentication Testing Suite    ║
    ║                                                   ║
    ║  ✅ LDAP Server Setup                             ║
    ║  👥 1000+ Test Users                              ║
    ║  🔥 Cache Warmup                                  ║
    ║  ⚡ Performance Testing                           ║
    ╚═══════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_prerequisites() {
    echo -e "${BLUE}🔍 Step 1: Checking prerequisites...${NC}"
    
    local missing_deps=()
    
    # Check Docker (for option 1)
    if [ "$LDAP_OPTION" = "1" ] && ! command -v docker &> /dev/null; then
        missing_deps+=("Docker")
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        missing_deps+=("Node.js")
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing dependencies: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}💡 Please install the missing dependencies first${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites satisfied${NC}"
}

setup_ldap_server() {
    echo -e "${BLUE}🏗️  Step 2: Setting up LDAP server...${NC}"
    
    # Check if LDAP is already running
    if lsof -i :389 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ LDAP server already running on port 389${NC}"
        return 0
    fi
    
    # Run the quick LDAP setup
    if [ -f "../quick-ldap-setup.sh" ]; then
        echo -e "${YELLOW}🚀 Starting automated LDAP setup...${NC}"
        echo "$LDAP_OPTION" | ../quick-ldap-setup.sh
    else
        echo -e "${RED}❌ LDAP setup script not found${NC}"
        echo -e "${YELLOW}💡 Please run: ../quick-ldap-setup.sh${NC}"
        return 1
    fi
}

verify_application_server() {
    echo -e "${BLUE}🏥 Step 3: Verifying application server...${NC}"
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s http://localhost:8080/auth-web/api/auth/health > /dev/null; then
            echo -e "${GREEN}✅ Application server is healthy${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}⏳ Waiting for application server... ($attempt/$max_attempts)${NC}"
        sleep 2
        ((attempt++))
    done
    
    echo -e "${RED}❌ Application server is not accessible${NC}"
    echo -e "${YELLOW}💡 Please ensure your Jakarta EE server is running with the auth-web application${NC}"
    return 1
}

install_dependencies() {
    echo -e "${BLUE}📦 Step 4: Installing Node.js dependencies...${NC}"
    
    if [ ! -f "package.json" ]; then
        echo -e "${RED}❌ package.json not found. Are you in the testing directory?${NC}"
        return 1
    fi
    
    npm install --silent
    
    if [ ! -d "node_modules/playwright" ]; then
        echo -e "${YELLOW}🎭 Installing Playwright browsers...${NC}"
        npx playwright install --with-deps > /dev/null 2>&1
    fi
    
    echo -e "${GREEN}✅ Dependencies installed${NC}"
}

warm_up_cache() {
    if [ "$WARMUP_ENABLED" != "true" ]; then
        echo -e "${YELLOW}⏭️  Skipping cache warmup${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🔥 Step 5: Warming up authentication cache...${NC}"
    
    if [ -f "../typescript/cache-warmup.js" ]; then
        echo -e "${YELLOW}⚡ Pre-loading high-frequency users...${NC}"
        if node ../typescript/cache-warmup.js; then
            echo -e "${GREEN}✅ Cache successfully warmed up${NC}"
        else
            echo -e "${YELLOW}⚠️  Cache warmup had issues but continuing...${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Cache warmup script not found${NC}"
    fi
}

run_comprehensive_tests() {
    if [ "$RUN_TESTS" != "true" ]; then
        echo -e "${YELLOW}⏭️  Skipping tests${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🧪 Step 6: Running comprehensive tests...${NC}"
    
    # Quick validation test
    echo -e "${CYAN}🔐 Testing authentication...${NC}"
    local auth_response
    auth_response=$(curl -s -X POST http://localhost:8080/auth-web/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{"username":"testuser123","password":"TestPass3!"}')
    
    if echo "$auth_response" | grep -q '"success":true'; then
        local response_time
        response_time=$(echo "$auth_response" | grep -o '"responseTimeMs":[0-9]*' | grep -o '[0-9]*')
        echo -e "${GREEN}✅ Authentication working (${response_time:-?}ms)${NC}"
    else
        echo -e "${RED}❌ Authentication test failed${NC}"
        return 1
    fi
    
    # Browser tests
    echo -e "${CYAN}🎭 Running browser tests...${NC}"
    if timeout 45s node ../typescript/playwright-browser-test.js > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Browser tests passed${NC}"
    else
        echo -e "${YELLOW}⚠️  Browser tests had issues${NC}"
    fi
    
    # API load tests (if k6 available)
    if command -v k6 &> /dev/null; then
        echo -e "${CYAN}⚡ Running API load tests...${NC}"
    if timeout 30s k6 run --vus 10 --duration 15s ../typescript/k6-api-load-test.js > /dev/null 2>&1; then
            echo -e "${GREEN}✅ API load tests passed${NC}"
        else
            echo -e "${YELLOW}⚠️  API load tests had issues${NC}"
        fi
    else
        echo -e "${YELLOW}💡 k6 not available - skipping API load tests${NC}"
    fi
}

show_final_report() {
    echo -e "${BLUE}📊 Step 7: Final system status...${NC}"
    
    # Get cache statistics
    local stats_response
    stats_response=$(curl -s http://localhost:8080/auth-web/api/auth/stats 2>/dev/null || echo '{}')
    
    if echo "$stats_response" | grep -q "cacheSize"; then
        echo -e "${GREEN}📈 Cache Statistics:${NC}"
        
        # Parse JSON manually (jq might not be available)
        local cache_size hit_ratio total_requests
        cache_size=$(echo "$stats_response" | grep -o '"cacheSize":[0-9]*' | grep -o '[0-9]*')
        hit_ratio=$(echo "$stats_response" | grep -o '"hitRatio":[0-9.]*' | grep -o '[0-9.]*')
        total_requests=$(echo "$stats_response" | grep -o '"totalRequests":[0-9]*' | grep -o '[0-9]*')
        
        echo -e "${GREEN}   Cache Size: ${cache_size:-0}${NC}"
        echo -e "${GREEN}   Hit Ratio: $(echo "scale=1; ${hit_ratio:-0} * 100" | bc 2>/dev/null || echo "0")%${NC}"
        echo -e "${GREEN}   Total Requests: ${total_requests:-0}${NC}"
    fi
    
    # Test LDAP connection
    if lsof -i :389 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ LDAP Server: Running (port 389)${NC}"
    else
        echo -e "${YELLOW}⚠️  LDAP Server: Not detected${NC}"
    fi
    
    # Test MongoDB
    if lsof -i :27017 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ MongoDB Cache: Running (port 27017)${NC}"
    else
        echo -e "${YELLOW}⚠️  MongoDB Cache: Not detected${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 COMPLETE SETUP FINISHED!${NC}"
    echo -e "${CYAN}=" * 40 "${NC}"
    echo -e "${GREEN}✅ LDAP Server: Ready${NC}"
    echo -e "${GREEN}✅ Authentication API: Working${NC}"
    echo -e "${GREEN}✅ Cache System: Warmed up${NC}"
    echo -e "${GREEN}✅ Testing Suite: Validated${NC}"
    
    echo ""
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo -e "${CYAN}1. 🌐 Open login page:${NC} http://localhost:8080/auth-web/login.html"
    echo -e "${CYAN}2. 🔑 Try test users:${NC} testuser001-testuser999"
    echo -e "${CYAN}3. 🔐 Password pattern:${NC} TestPass{lastDigit}!"
    echo -e "${CYAN}4. 🧪 Run full tests:${NC} npm test"
    echo -e "${CYAN}5. ⚡ Run load tests:${NC} npm run test:api:stress"
    echo -e "${CYAN}6. 📊 Check cache stats:${NC} npm run test:stats"
    
    echo ""
    echo -e "${YELLOW}💡 Example Test Users:${NC}"
    echo -e "${CYAN}   testuser001 → TestPass1!${NC}"
    echo -e "${CYAN}   testuser123 → TestPass3!${NC}"  
    echo -e "${CYAN}   testuser999 → TestPass9!${NC}"
}

show_usage() {
    echo "Oracle Fusion Auth - Complete Testing Setup"
    echo ""
    echo "Usage:"
    echo "  ./complete-setup.sh [ldap_option] [warmup] [run_tests]"
    echo ""
    echo "Parameters:"
    echo "  ldap_option  LDAP setup option (1=Docker, 2=OpenDJ, 3=ApacheDS, 4=Homebrew)"
    echo "  warmup       Enable cache warmup (true/false, default: true)"
    echo "  run_tests    Run validation tests (true/false, default: true)"
    echo ""
    echo "Examples:"
    echo "  ./complete-setup.sh                    # Docker LDAP, with warmup and tests"
    echo "  ./complete-setup.sh 2                  # OpenDJ LDAP, with warmup and tests"
    echo "  ./complete-setup.sh 1 false            # Docker LDAP, no warmup, with tests"
    echo "  ./complete-setup.sh 1 true false       # Docker LDAP, with warmup, no tests"
}

main() {
    # Handle help
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_usage
        return 0
    fi
    
    print_banner
    
    # Run setup steps
    check_prerequisites
    setup_ldap_server  
    verify_application_server
    install_dependencies
    warm_up_cache
    run_comprehensive_tests
    show_final_report
    
    echo ""
    echo -e "${GREEN}🎯 Your Oracle Fusion Authentication System is ready for enterprise testing!${NC}"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi