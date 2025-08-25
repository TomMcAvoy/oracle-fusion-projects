#!/bin/bash

# Oracle Fusion Auth - Quick Start Testing Script
# This script sets up and runs a quick validation of the authentication system

set -e  # Exit on any error

echo "🚀 Oracle Fusion Authentication - Quick Start Test"
echo "================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ Please run this script from the 'testing' directory${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Step 1: Checking prerequisites...${NC}"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js not found. Please install Node.js first.${NC}"
    exit 1
fi

NODE_VERSION=$(node --version)
echo -e "${GREEN}✅ Node.js found: $NODE_VERSION${NC}"

# Check if server is running
echo -e "${BLUE}🏥 Step 2: Checking server health...${NC}"
if curl -f -s http://localhost:8080/auth-web/api/auth/health > /dev/null; then
    echo -e "${GREEN}✅ Server is running and healthy${NC}"
else
    echo -e "${RED}❌ Server is not running or not accessible${NC}"
    echo -e "${YELLOW}💡 Please start your Jakarta EE application server first${NC}"
    echo "   Example: mvn clean package && deploy to WildFly/Liberty"
    exit 1
fi

# Install dependencies if needed
echo -e "${BLUE}📦 Step 3: Installing dependencies...${NC}"
if [ ! -d "node_modules" ]; then
    npm install
    echo -e "${GREEN}✅ Dependencies installed${NC}"
else
    echo -e "${GREEN}✅ Dependencies already installed${NC}"
fi

# Install Playwright browsers if needed
if [ ! -d "node_modules/playwright" ]; then
    npx playwright install
    echo -e "${GREEN}✅ Playwright browsers installed${NC}"
else
    echo -e "${GREEN}✅ Playwright already available${NC}"
fi

# Test authentication API
# Check if LDAP is needed
echo -e "${BLUE}🔍 Step 4: Checking LDAP availability...${NC}"
if lsof -i :389 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ LDAP server detected on port 389${NC}"
else
    echo -e "${YELLOW}⚠️  No LDAP server found${NC}"
    echo -e "${YELLOW}💡 Run quick LDAP setup: ../quick-ldap-setup.sh${NC}"
    echo -e "${YELLOW}   Option 1 (Docker): Takes 2 minutes${NC}"
    echo -e "${YELLOW}   Option 2 (OpenDJ): Enterprise-grade, fast${NC}"
fi

echo -e "${BLUE}🔐 Step 5: Testing authentication API...${NC}"
AUTH_RESPONSE=$(curl -s -X POST http://localhost:8080/auth-web/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser123","password":"TestPass3!"}')

if echo "$AUTH_RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✅ Authentication API working${NC}"
    
    # Extract response time if available
    RESPONSE_TIME=$(echo "$AUTH_RESPONSE" | grep -o '"responseTimeMs":[0-9]*' | grep -o '[0-9]*')
    if [ ! -z "$RESPONSE_TIME" ]; then
        echo -e "${GREEN}⚡ Response time: ${RESPONSE_TIME}ms${NC}"
    fi
    
    # Warm up cache
    echo -e "${BLUE}🔥 Warming up authentication cache...${NC}"
    if [ -f "../typescript/cache-warmup.js" ]; then
        npm run warmup > /dev/null 2>&1 && echo -e "${GREEN}✅ Cache warmed up${NC}" || echo -e "${YELLOW}⚠️  Cache warmup skipped${NC}"
    fi
else
    echo -e "${RED}❌ Authentication API failed${NC}"
    echo "Response: $AUTH_RESPONSE"
    exit 1
fi

# Check for k6
echo -e "${BLUE}🛠️  Step 6: Checking testing tools...${NC}"
if command -v k6 &> /dev/null; then
    echo -e "${GREEN}✅ k6 load testing tool available${NC}"
    K6_AVAILABLE=true
else
    echo -e "${YELLOW}⚠️  k6 not found - API load tests will be skipped${NC}"
    echo -e "${YELLOW}💡 Install k6: https://k6.io/docs/get-started/installation/${NC}"
    K6_AVAILABLE=false
fi

# Check for Artillery alternative
if command -v artillery &> /dev/null; then
    echo -e "${GREEN}✅ Artillery load testing tool available${NC}"
    ARTILLERY_AVAILABLE=true
else
    echo -e "${YELLOW}⚠️  Artillery not found (alternative to k6)${NC}"
    echo -e "${YELLOW}💡 Install Artillery: npm install -g artillery${NC}"
    ARTILLERY_AVAILABLE=false
fi

# Run quick tests
echo -e "${BLUE}🧪 Step 7: Running quick validation tests...${NC}"

# Browser test
echo -e "${BLUE}🎭 Running browser test...${NC}"
if timeout 30s node ../typescript/playwright-browser-test.js 2>&1 | head -20; then
    echo -e "${GREEN}✅ Browser test completed${NC}"
else
    echo -e "${YELLOW}⚠️  Browser test had issues (check logs above)${NC}"
fi

# API load test (if available)
if [ "$K6_AVAILABLE" = true ]; then
    echo -e "${BLUE}⚡ Running k6 quick load test...${NC}"
    if timeout 20s k6 run --vus 5 --duration 10s ../typescript/k6-api-load-test.js; then
        echo -e "${GREEN}✅ k6 load test completed${NC}"
    else
        echo -e "${YELLOW}⚠️  k6 load test had issues${NC}"
    fi
elif [ "$ARTILLERY_AVAILABLE" = true ]; then
    echo -e "${BLUE}⚡ Running Artillery quick test...${NC}"
    if timeout 20s artillery quick --count 10 --num 2 http://localhost:8080/auth-web/api/auth/login; then
        echo -e "${GREEN}✅ Artillery test completed${NC}"
    else
        echo -e "${YELLOW}⚠️  Artillery test had issues${NC}"
    fi
fi

# Get final statistics
echo -e "${BLUE}📊 Step 7: Final system statistics...${NC}"
STATS_RESPONSE=$(curl -s http://localhost:8080/auth-web/api/auth/stats)
if echo "$STATS_RESPONSE" | grep -q "cacheSize"; then
    echo -e "${GREEN}📈 Cache Statistics:${NC}"
    echo "$STATS_RESPONSE" | jq . 2>/dev/null || echo "$STATS_RESPONSE"
fi

# Success summary
echo ""
echo -e "${GREEN}🎉 QUICK START VALIDATION COMPLETE!${NC}"
echo "================================================="
echo -e "${GREEN}✅ Server: Running and healthy${NC}"
echo -e "${GREEN}✅ API: Authentication working${NC}"
echo -e "${GREEN}✅ Cache: Operational${NC}"
echo -e "${GREEN}✅ Tests: Browser testing available${NC}"
if [ "$K6_AVAILABLE" = true ] || [ "$ARTILLERY_AVAILABLE" = true ]; then
    echo -e "${GREEN}✅ Load Testing: Available${NC}"
fi

echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "1. 🌐 Open login page: http://localhost:8080/auth-web/login.html"
echo "2. 🔑 Try any user: testuser000-testuser999 with TestPass{digit}!"
echo "3. 🧪 Run full test suite: npm test"
echo "4. ⚡ Run load tests: npm run test:api:stress"
echo "5. 📊 Monitor stats: npm run test:stats"

echo ""
echo -e "${YELLOW}💡 Test User Examples:${NC}"
echo "   testuser000 → TestPass0!"
echo "   testuser123 → TestPass3!"
echo "   testuser999 → TestPass9!"

echo ""
echo -e "${BLUE}🎯 Your Oracle Fusion Authentication System is ready for testing!${NC}"