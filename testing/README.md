# 🧪 Oracle Fusion Auth - Frontend Testing Suite

Comprehensive testing framework for the Oracle Fusion Authentication System with **1000 test users** and multiple testing approaches.

## 🎯 **What's Included**

### **1. Login Page** (`login.html`)
- Beautiful responsive HTML login interface  
- Real-time authentication with performance metrics
- **1000 test users** with predictable passwords
- Keyboard shortcuts (Alt + 0-9) for quick testing

### **2. REST API** (`AuthenticationRestService.java`)
- `/api/auth/login` - Single authentication
- `/api/auth/bulk-login` - Bulk authentication for load testing
- `/api/auth/stats` - Cache statistics
- `/api/auth/test-users/{count}` - Generate test user list

### **3. Load Testing Tools**
- **k6** - High-performance API load testing
- **Artillery** - Alternative load testing (easier setup)
- **Playwright** - Real browser testing with multiple browsers

### **4. Test Orchestration**
- `test-runner.js` - Master test suite runner
- Automated health checks
- Performance benchmarking
- Comprehensive reporting

---

## 🚀 **Quick Start**

### **Step 1: Start the Application**
```bash
# Build and deploy the application
cd /Users/thomasmcavoy/GitHub/oracle-fusion-projects
mvn clean package

# Deploy to your Jakarta EE server (WildFly, Liberty, etc.)
# Application should be accessible at: http://localhost:8080/auth-web
```

### **Step 2: Install Testing Tools**
```bash
# Navigate to testing directory
cd testing

# Install Node.js dependencies
npm install

# Install Playwright browsers
npx playwright install

# Install k6 (choose your platform):
# Mac: brew install k6
# Windows: choco install k6
# Linux: sudo apt install k6
# Or download from: https://k6.io/docs/get-started/installation/

# Alternative: Install Artillery (easier but less features)
npm install -g artillery
```

### **Step 3: Run Tests**
```bash
# Run complete test suite
npm test

# Or run individual test types:
npm run test:browser    # Playwright browser tests
npm run test:api        # k6 API load tests
npm run test:api:quick  # Quick k6 test (10 users, 10s)
npm run test:api:stress # Stress test (200 users, 60s)
```

---

## 📊 **Test User Credentials**

### **1000 Test Users Available:**
- **Usernames:** `testuser000` to `testuser999`  
- **Password Pattern:** `TestPass{lastDigit}!`

### **Examples:**
```
testuser000 → TestPass0!
testuser123 → TestPass3!
testuser456 → TestPass6!
testuser789 → TestPass9!
testuser999 → TestPass9!
```

### **Quick Manual Testing:**
1. Open: http://localhost:8080/auth-web/login.html
2. Use any testuser### with TestPass{lastDigit}!
3. Press **Alt + 0-9** for quick user selection

---

## 🛠️ **Testing Tools Comparison**

| Tool | Best For | Pros | Cons | Installation |
|------|----------|------|------|--------------|
| **k6** | API Load Testing | Fastest, best metrics, JavaScript | Separate install | `brew install k6` |
| **Artillery** | API Load Testing | Easy setup, YAML config | Fewer features | `npm install -g artillery` |
| **Playwright** | Browser Testing | Multi-browser, realistic | Slower than API tests | `npx playwright install` |

---

## ⚡ **Load Testing Scenarios**

### **k6 API Tests:**
```bash
# Quick validation (10 users, 10 seconds)
k6 run --vus 10 --duration 10s k6-api-load-test.js

# Medium load (50 users, 30 seconds)  
k6 run --vus 50 --duration 30s k6-api-load-test.js

# Stress test (200 users, 60 seconds)
k6 run --vus 200 --duration 60s k6-api-load-test.js

# Peak load (500 users, 2 minutes)
k6 run --vus 500 --duration 120s k6-api-load-test.js
```

### **Artillery Tests:**
```bash
# Run standard load test
artillery run artillery-load-test.yml

# Quick test
artillery quick --count 50 --num 5 http://localhost:8080/auth-web/api/auth/login

# Custom target
artillery run --target http://your-server:8080 artillery-load-test.yml
```

### **Playwright Browser Tests:**
```bash
# Full browser test suite
node typescript/playwright-browser-test.js

# Individual components available:
# - Single browser functionality
# - Multi-browser compatibility (Chrome, Firefox, Safari)
# - Concurrent user sessions
# - Performance stress testing
# - User experience scenarios
```

---

## 📈 **Performance Expectations**

### **Expected Response Times:**
- **Cache Hit:** < 50ms ⚡
- **Cache Miss (DB):** < 200ms 🔍  
- **Cache Miss (LDAP):** < 500ms 🌐

### **Cache Hit Ratios:**
- **High-frequency users:** 85-95% 🎯
- **Medium-frequency users:** 50-70% 📊
- **Random users:** 10-20% 🎲

### **Throughput Targets:**
- **Single server:** 500+ req/sec 🚀
- **With caching:** 1000+ req/sec ⚡

---

## 🏗️ **Test Architecture**

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Browser       │    │   k6/Artillery   │    │   Test Runner   │
│   (Playwright)  │    │   (API Tests)    │    │   (Orchestrator)│
└─────────┬───────┘    └────────┬─────────┘    └─────────┬───────┘
          │                     │                        │
          └─────────────────────┼────────────────────────┘
                                │
                    ┌───────────▼────────────┐
                    │     REST API           │
                    │ /api/auth/login        │
                    │ /api/auth/stats        │
                    │ /api/auth/bulk-login   │
                    └───────────┬────────────┘
                                │
                    ┌───────────▼────────────┐
                    │  DistributedAuthCache  │
                    │  (3-Tier Cache)        │
                    └───────────┬────────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
    ┌───────────▼────┐ ┌────────▼────┐ ┌────────▼────────┐
    │  L1: Memory    │ │ L2: Database│ │ L3: Mock LDAP   │
    │  (Fastest)     │ │  (Fast)     │ │  (Fallback)     │
    └────────────────┘ └─────────────┘ └─────────────────┘
```

---

## 🎛️ **Test Configuration**

### **Environment Variables:**
```bash
export AUTH_BASE_URL="http://localhost:8080/auth-web"
export TEST_USERS_COUNT="1000"
export CACHE_FOCUSED="true"  # Focus on high-frequency users
```

### **Custom Test Scenarios:**
Edit the test files to customize:

**`k6-api-load-test.js`:**
- Modify `options.stages` for different load patterns
- Adjust `HIGH_FREQUENCY_USERS` array
- Change `thresholds` for performance criteria

**`artillery-load-test.yml`:**
- Update `phases` for different load curves
- Modify `ensure` thresholds
- Customize `scenarios` weights

**`playwright-browser-test.js`:**
- Add custom user journey tests
- Modify browser types and versions
- Customize assertion criteria

---

## 📊 **Reports and Metrics**

### **Test Runner Output:**
- ✅ Real-time test status
- 📈 Performance metrics
- 🎯 Success/failure rates  
- 💾 Detailed JSON reports

### **k6 Metrics:**
- `http_req_duration` - Response times
- `auth_failures` - Authentication failure rate
- `cache_hits` - Cache hit rate
- `auth_duration` - Custom auth timing

### **Cache Statistics:**
```bash
# Get real-time cache stats
curl http://localhost:8080/auth-web/api/auth/stats

# Expected response:
{
  "cacheSize": 247,
  "cacheHits": 1456,
  "cacheMisses": 234,
  "totalRequests": 1690,
  "hitRatio": 0.8615,
  "timestamp": 1699123456789
}
```

---

## 🔧 **Troubleshooting**

### **Common Issues:**

**❌ "Server not accessible"**
```bash
# Check if application is running
curl http://localhost:8080/auth-web/api/auth/health

# Expected: {"status":"healthy","timestamp":...}
```

**❌ "k6 command not found"**
```bash
# Install k6:
# Mac: brew install k6
# Windows: choco install k6  
# Linux: sudo apt install k6
# Manual: https://k6.io/docs/get-started/installation/
```

**❌ "Playwright not found"**
```bash
cd testing
npm install
npx playwright install
```

**❌ "Authentication always fails"**
```bash
# Verify test user pattern:
# testuser000 → TestPass0!
# testuser123 → TestPass3!
# Password = TestPass + (last digit) + !
```

### **Performance Issues:**

**Slow Response Times:**
- Check database connection pool settings
- Monitor cache hit ratios
- Verify PBKDF2 iteration count (50,000 = ~10ms)

**Low Cache Hit Rates:**
- Verify cache configuration
- Check user access patterns in test scripts
- Monitor memory usage

---

## 🚀 **Advanced Usage**

### **Custom Test Scenarios:**
```javascript
// Add to k6-api-load-test.js
export function customScenario() {
  // Your custom test logic
  const response = http.post(`${BASE_URL}/auth/login`, {
    username: 'your-test-user',
    password: 'your-test-password'
  });
  
  check(response, {
    'Custom test passes': (r) => r.status === 200,
  });
}
```

### **CI/CD Integration:**
```bash
# Add to your CI pipeline
npm install
npm run setup
npm run test:api:quick  # Quick validation
# Exit code 0 = success, 1 = failure
```

### **Production Load Testing:**
```bash
# Point to production environment
export AUTH_BASE_URL="https://your-prod-server.com/auth-web"
k6 run --vus 100 --duration 60s k6-api-load-test.js
```

---

## 🎉 **Success Criteria**

Your authentication system is **production-ready** when:

- ✅ **All health checks pass**
- ✅ **95% of requests < 500ms**  
- ✅ **Authentication success rate > 99%**
- ✅ **Cache hit ratio > 80%** (for frequent users)
- ✅ **System handles 500+ concurrent users**
- ✅ **Browser tests pass in Chrome, Firefox, Safari**
- ✅ **Zero security vulnerabilities detected**

---

## 📚 **Additional Resources**

- **k6 Documentation:** https://k6.io/docs/
- **Artillery Guide:** https://www.artillery.io/docs
- **Playwright Docs:** https://playwright.dev/
- **Jakarta EE Security:** https://jakarta.ee/specifications/security/
- **PBKDF2 Best Practices:** https://owasp.org/www-community/hashes
- **Load Testing Best Practices:** https://k6.io/docs/testing-guides/

---

**🎯 Happy Testing!** Your Oracle Fusion Authentication System is now equipped with enterprise-grade testing capabilities. 🚀