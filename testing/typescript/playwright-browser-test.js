/**
 * Playwright Browser Testing Script for Oracle Fusion Auth
 * 
 * Tests the actual login page with real browser interactions
 * and concurrent user sessions.
 * 
 * Setup:
 *   npm install playwright
 *   npx playwright install
 * 
 * Usage:
 *   node playwright-browser-test.js
 */

const { chromium, firefox, webkit } = require('playwright');

class AuthBrowserTester {
  constructor() {
    this.baseUrl = 'http://localhost:8080/auth-web';
    this.results = {
      totalTests: 0,
      passed: 0,
      failed: 0,
      errors: [],
      responseTimes: [],
      startTime: Date.now()
    };
  }

  async runAllTests() {
    console.log('🎭 Starting Playwright Browser Tests for Oracle Fusion Auth');
    console.log('=' * 60);

    try {
      // Test 1: Single browser basic functionality
      await this.testSingleBrowser();
      
      // Test 2: Multi-browser compatibility
      await this.testMultiBrowser();
      
      // Test 3: Concurrent sessions
      await this.testConcurrentSessions();
      
      // Test 4: Performance stress test
      await this.testPerformanceStress();
      
      // Test 5: User experience scenarios
      await this.testUserExperience();
      
    } catch (error) {
      console.error('💥 Test suite failed:', error);
    }
    
    this.printFinalReport();
  }

  async testSingleBrowser() {
    console.log('🔍 Test 1: Single Browser Basic Functionality');
    
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    
    try {
      // Navigate to login page
      await page.goto(`${this.baseUrl}/login.html`);
      await this.recordResult('Page Load', true);
      
      // Test valid login
      await this.testLogin(page, 'testuser123', 'TestPass3!', true, 'Valid Login');
      
      // Test invalid login
      await this.testLogin(page, 'testuser999', 'WrongPassword', false, 'Invalid Login');
      
      // Test empty fields
      await this.testLogin(page, '', '', false, 'Empty Fields');
      
      // Test SQL injection attempt
      await this.testLogin(page, "admin'; DROP TABLE users; --", 'password', false, 'SQL Injection Prevention');
      
    } finally {
      await browser.close();
    }
    
    console.log('✅ Single browser tests completed');
  }

  async testMultiBrowser() {
    console.log('🌐 Test 2: Multi-Browser Compatibility');
    
    const browsers = [
      { name: 'Chromium', launcher: chromium },
      { name: 'Firefox', launcher: firefox },
      { name: 'WebKit', launcher: webkit }
    ];
    
    const promises = browsers.map(async ({ name, launcher }) => {
      const browser = await launcher.launch({ headless: true });
      const page = await browser.newPage();
      
      try {
        await page.goto(`${this.baseUrl}/login.html`);
        await this.testLogin(page, 'testuser456', 'TestPass6!', true, `${name} Login`);
        return { browser: name, success: true };
      } catch (error) {
        console.error(`❌ ${name} failed:`, error.message);
        return { browser: name, success: false, error: error.message };
      } finally {
        await browser.close();
      }
    });
    
    const results = await Promise.all(promises);
    
    results.forEach(result => {
      if (result.success) {
        console.log(`✅ ${result.browser} compatibility: PASSED`);
      } else {
        console.log(`❌ ${result.browser} compatibility: FAILED`);
      }
    });
  }

  async testConcurrentSessions() {
    console.log('⚡ Test 3: Concurrent Sessions (10 browsers)');
    
    const concurrentUsers = 10;
    const promises = [];
    
    for (let i = 0; i < concurrentUsers; i++) {
      const userNum = i * 100; // Spread users out
      const username = `testuser${String(userNum).padStart(3, '0')}`;
      const password = `TestPass${userNum % 10}!`;
      
      promises.push(this.simulateConcurrentUser(username, password, i));
    }
    
    const startTime = Date.now();
    const results = await Promise.all(promises);
    const totalTime = Date.now() - startTime;
    
    const successful = results.filter(r => r.success).length;
    const failed = results.filter(r => !r.success).length;
    
    console.log(`📊 Concurrent Sessions Results:`);
    console.log(`   Total Users: ${concurrentUsers}`);
    console.log(`   Successful: ${successful}`);
    console.log(`   Failed: ${failed}`);
    console.log(`   Total Time: ${totalTime}ms`);
    console.log(`   Avg Time per User: ${(totalTime / concurrentUsers).toFixed(1)}ms`);
    
    this.recordResult('Concurrent Sessions', successful >= 8); // 80% success rate
  }

  async testPerformanceStress() {
    console.log('🔥 Test 4: Performance Stress Test');
    
    const browser = await chromium.launch({ headless: true });
    const stressTests = [];
    
    // Test different user patterns rapidly
    const testUsers = [
      'testuser000', 'testuser111', 'testuser222', 'testuser333', 'testuser444'
    ];
    
    for (const username of testUsers) {
      const password = `TestPass${username.slice(-1)}!`;
      
      // Test each user 5 times rapidly (cache performance test)
      for (let i = 0; i < 5; i++) {
        stressTests.push(this.performStressLogin(browser, username, password, i));
        
        // Small delay to avoid overwhelming
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }
    
    const startTime = Date.now();
    const results = await Promise.all(stressTests);
    const totalTime = Date.now() - startTime;
    
    const successful = results.filter(r => r.success).length;
    const avgResponseTime = results.reduce((sum, r) => sum + (r.responseTime || 0), 0) / results.length;
    
    console.log(`⚡ Stress Test Results:`);
    console.log(`   Total Requests: ${stressTests.length}`);
    console.log(`   Successful: ${successful}`);
    console.log(`   Success Rate: ${(successful/stressTests.length*100).toFixed(1)}%`);
    console.log(`   Avg Response Time: ${avgResponseTime.toFixed(1)}ms`);
    console.log(`   Requests/sec: ${(stressTests.length * 1000 / totalTime).toFixed(1)}`);
    
    await browser.close();
  }

  async testUserExperience() {
    console.log('👤 Test 5: User Experience Scenarios');
    
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    
    try {
      await page.goto(`${this.baseUrl}/login.html`);
      
      // Test keyboard shortcuts (Alt + number keys)
      console.log('Testing keyboard shortcuts...');
      await page.keyboard.press('Alt+1');
      
      // Check if quick-fill worked
      const username = await page.inputValue('#username');
      const password = await page.inputValue('#password');
      
      const quickFillWorked = username === 'testuser001' && password === 'TestPass1!';
      this.recordResult('Keyboard Quick-Fill', quickFillWorked);
      
      // Test form validation
      await page.fill('#username', '');
      await page.fill('#password', '');
      await page.click('.login-btn');
      
      // Should see validation message
      await page.waitForSelector('.message', { timeout: 2000 });
      this.recordResult('Form Validation', true);
      
      // Test successful login flow
      await page.fill('#username', 'testuser789');
      await page.fill('#password', 'TestPass9!');
      await page.click('.login-btn');
      
      // Wait for success message and stats
      await page.waitForSelector('.message.success', { timeout: 5000 });
      await page.waitForSelector('#stats', { timeout: 2000 });
      
      const successMessage = await page.textContent('.message.success');
      const statsVisible = await page.isVisible('#stats');
      
      this.recordResult('Success Flow', successMessage.includes('Authentication successful') && statsVisible);
      
    } finally {
      await browser.close();
    }
    
    console.log('✅ User experience tests completed');
  }

  async testLogin(page, username, password, shouldSucceed, testName) {
    const startTime = Date.now();
    
    try {
      // Fill in credentials
      await page.fill('#username', username);
      await page.fill('#password', password);
      
      // Submit form
      await page.click('.login-btn');
      
      // Wait for result
      await page.waitForSelector('.message', { timeout: 5000 });
      
      const message = await page.textContent('.message');
      const isSuccess = message.includes('Authentication successful');
      const responseTime = Date.now() - startTime;
      
      this.responseTimes.push(responseTime);
      
      if (shouldSucceed === isSuccess) {
        this.recordResult(testName, true, responseTime);
        console.log(`✅ ${testName}: ${responseTime}ms`);
      } else {
        this.recordResult(testName, false);
        console.log(`❌ ${testName}: Expected ${shouldSucceed ? 'success' : 'failure'} but got ${isSuccess ? 'success' : 'failure'}`);
      }
      
    } catch (error) {
      this.recordResult(testName, false);
      console.log(`❌ ${testName}: ${error.message}`);
    }
  }

  async simulateConcurrentUser(username, password, userIndex) {
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    
    try {
      const startTime = Date.now();
      
      await page.goto(`${this.baseUrl}/login.html`);
      await page.fill('#username', username);
      await page.fill('#password', password);
      await page.click('.login-btn');
      
      await page.waitForSelector('.message', { timeout: 10000 });
      
      const message = await page.textContent('.message');
      const success = message.includes('Authentication successful');
      const responseTime = Date.now() - startTime;
      
      return { userIndex, username, success, responseTime };
      
    } catch (error) {
      return { userIndex, username, success: false, error: error.message };
    } finally {
      await browser.close();
    }
  }

  async performStressLogin(browser, username, password, iteration) {
    const page = await browser.newPage();
    
    try {
      const startTime = Date.now();
      
      await page.goto(`${this.baseUrl}/login.html`);
      await page.fill('#username', username);
      await page.fill('#password', password);
      await page.click('.login-btn');
      
      await page.waitForSelector('.message', { timeout: 5000 });
      
      const message = await page.textContent('.message');
      const success = message.includes('Authentication successful');
      const responseTime = Date.now() - startTime;
      
      return { username, iteration, success, responseTime };
      
    } catch (error) {
      return { username, iteration, success: false, responseTime: Date.now() - startTime };
    } finally {
      await page.close();
    }
  }

  recordResult(testName, success, responseTime = null) {
    this.results.totalTests++;
    
    if (success) {
      this.results.passed++;
    } else {
      this.results.failed++;
      this.results.errors.push(testName);
    }
    
    if (responseTime) {
      this.results.responseTimes.push(responseTime);
    }
  }

  printFinalReport() {
    const totalTime = Date.now() - this.results.startTime;
    
    console.log('');
    console.log('🎭 PLAYWRIGHT BROWSER TEST REPORT');
    console.log('=' * 50);
    console.log(`📊 Test Summary:`);
    console.log(`   Total Tests: ${this.results.totalTests}`);
    console.log(`   Passed: ${this.results.passed}`);
    console.log(`   Failed: ${this.results.failed}`);
    console.log(`   Success Rate: ${(this.results.passed / this.results.totalTests * 100).toFixed(1)}%`);
    console.log(`   Total Duration: ${(totalTime / 1000).toFixed(1)}s`);
    
    if (this.results.responseTimes.length > 0) {
      this.results.responseTimes.sort((a, b) => a - b);
      const p50 = this.results.responseTimes[Math.floor(this.results.responseTimes.length * 0.5)];
      const p95 = this.results.responseTimes[Math.floor(this.results.responseTimes.length * 0.95)];
      
      console.log(`⚡ Performance Metrics:`);
      console.log(`   Avg Response Time: ${(this.results.responseTimes.reduce((a, b) => a + b, 0) / this.results.responseTimes.length).toFixed(1)}ms`);
      console.log(`   P50 Response Time: ${p50}ms`);
      console.log(`   P95 Response Time: ${p95}ms`);
      console.log(`   Min Response Time: ${this.results.responseTimes[0]}ms`);
      console.log(`   Max Response Time: ${this.results.responseTimes[this.results.responseTimes.length - 1]}ms`);
    }
    
    if (this.results.failed > 0) {
      console.log(`❌ Failed Tests: ${this.results.errors.join(', ')}`);
    }
    
    console.log('');
    console.log('🎯 Browser Testing Complete!');
    console.log('💡 Test the login page manually at: http://localhost:8080/auth-web/login.html');
  }
}

// Run the tests
async function runTests() {
  const tester = new AuthBrowserTester();
  await tester.runAllTests();
}

// Execute if run directly
if (require.main === module) {
  runTests().catch(console.error);
}

module.exports = AuthBrowserTester;