#!/usr/bin/env node
/**
 * Oracle Fusion Auth - Comprehensive Test Runner
 * 
 * This script orchestrates all frontend and API testing:
 * - Health checks
 * - Browser testing with Playwright
 * - API load testing with k6
 * - Performance analysis
 * - Test reporting
 */

const { spawn, exec } = require('child_process');
const axios = require('axios');
const fs = require('fs');
const path = require('path');

// Add colors for better output (install with: npm install colors)
let colors;
try {
  colors = require('colors');
} catch (e) {
  // Fallback if colors not installed
  colors = {
    green: (str) => str,
    red: (str) => str,
    blue: (str) => str,
    yellow: (str) => str,
    cyan: (str) => str,
    magenta: (str) => str,
    gray: (str) => str
  };
}

class OracleFusionTestRunner {
  constructor() {
    this.baseUrl = 'http://localhost:8080/auth-web';
    this.apiUrl = `${this.baseUrl}/api`;
    this.results = {
      startTime: Date.now(),
      tests: [],
      summary: {
        total: 0,
        passed: 0,
        failed: 0,
        skipped: 0
      }
    };
  }

  async runAllTests() {
    console.log(colors.cyan('🚀 Oracle Fusion Authentication - Master Test Suite'));
    console.log(colors.gray('=' * 60));
    
    try {
      // Phase 1: Environment checks
      await this.checkEnvironment();
      
      // Phase 2: Health checks
      await this.healthChecks();
      
      // Phase 3: Browser testing
      await this.runBrowserTests();
      
      // Phase 4: API load testing
      await this.runApiTests();
      
      // Phase 5: Generate reports
      await this.generateReports();
      
    } catch (error) {
      console.error(colors.red('💥 Test suite failed:'), error.message);
      process.exit(1);
    }
  }

  async checkEnvironment() {
    console.log(colors.blue('\n🔍 Phase 1: Environment Checks'));
    
    // Check Node.js version
    const nodeVersion = process.version;
    console.log(`📦 Node.js version: ${nodeVersion}`);
    
    // Check if server is running
    try {
      const response = await axios.get(`${this.apiUrl}/auth/health`, { timeout: 5000 });
      console.log(colors.green('✅ Server is running'));
      this.recordTest('Server Health', true);
    } catch (error) {
      console.log(colors.red('❌ Server is not running or not accessible'));
      console.log(colors.yellow('💡 Make sure to start the application server first:'));
      console.log(colors.yellow('   mvn clean package && [deploy to application server]'));
      this.recordTest('Server Health', false);
      throw new Error('Server not accessible');
    }
    
    // Check k6 installation
    const k6Available = await this.checkCommand('k6', '--version');
    if (k6Available) {
      console.log(colors.green('✅ k6 load testing tool available'));
      this.recordTest('k6 Available', true);
    } else {
      console.log(colors.yellow('⚠️  k6 not available - API load tests will be skipped'));
      console.log(colors.yellow('💡 Install k6: https://k6.io/docs/get-started/installation/'));
      this.recordTest('k6 Available', false);
    }
    
    // Check Playwright installation
    const playwrightAvailable = fs.existsSync(path.join(__dirname, 'node_modules', 'playwright'));
    if (playwrightAvailable) {
      console.log(colors.green('✅ Playwright browser testing available'));
      this.recordTest('Playwright Available', true);
    } else {
      console.log(colors.yellow('⚠️  Playwright not available - browser tests will be skipped'));
      console.log(colors.yellow('💡 Install: npm install && npx playwright install'));
      this.recordTest('Playwright Available', false);
    }
  }

  async healthChecks() {
    console.log(colors.blue('\n🏥 Phase 2: Health Checks'));
    
    const endpoints = [
      '/auth/health',
      '/auth/stats',
      '/auth/test-users/10'
    ];
    
    for (const endpoint of endpoints) {
      try {
        const response = await axios.get(`${this.apiUrl}${endpoint}`, { timeout: 3000 });
        console.log(colors.green(`✅ ${endpoint}: ${response.status}`));
        this.recordTest(`Endpoint ${endpoint}`, true, response.data);
      } catch (error) {
        console.log(colors.red(`❌ ${endpoint}: ${error.response?.status || 'FAILED'}`));
        this.recordTest(`Endpoint ${endpoint}`, false, error.message);
      }
    }
    
    // Test a sample authentication
    try {
      const response = await axios.post(`${this.apiUrl}/auth/login`, {
        username: 'testuser123',
        password: 'TestPass3!'
      }, { timeout: 5000 });
      
      if (response.data.success) {
        console.log(colors.green(`✅ Sample authentication: ${response.data.responseTimeMs}ms`));
        this.recordTest('Sample Authentication', true, response.data);
      } else {
        console.log(colors.red('❌ Sample authentication failed'));
        this.recordTest('Sample Authentication', false);
      }
    } catch (error) {
      console.log(colors.red('❌ Sample authentication error'));
      this.recordTest('Sample Authentication', false, error.message);
    }
  }

  async runBrowserTests() {
    console.log(colors.blue('\n🎭 Phase 3: Browser Testing with Playwright'));
    
    if (!fs.existsSync(path.join(__dirname, 'node_modules', 'playwright'))) {
      console.log(colors.yellow('⚠️  Skipping browser tests - Playwright not installed'));
      this.recordTest('Browser Tests', false, 'Playwright not available');
      return;
    }
    
    try {
      const BrowserTester = require('./playwright-browser-test.js');
      const tester = new BrowserTester();
      
      // Run browser tests
      await tester.runAllTests();
      
      console.log(colors.green('✅ Browser tests completed'));
      this.recordTest('Browser Tests', true, tester.results);
      
    } catch (error) {
      console.log(colors.red('❌ Browser tests failed:'), error.message);
      this.recordTest('Browser Tests', false, error.message);
    }
  }

  async runApiTests() {
    console.log(colors.blue('\n⚡ Phase 4: API Load Testing with k6'));
    
    const k6Available = await this.checkCommand('k6', '--version');
    if (!k6Available) {
      console.log(colors.yellow('⚠️  Skipping API load tests - k6 not installed'));
      this.recordTest('API Load Tests', false, 'k6 not available');
      return;
    }
    
    // Run different load test scenarios
    const scenarios = [
      { name: 'Quick Test', args: ['--vus', '10', '--duration', '15s'] },
      { name: 'Medium Load', args: ['--vus', '50', '--duration', '30s'] },
    ];
    
    for (const scenario of scenarios) {
      console.log(colors.cyan(`🔥 Running ${scenario.name}...`));
      
      try {
        const result = await this.runK6Test(scenario.args);
        console.log(colors.green(`✅ ${scenario.name} completed`));
        this.recordTest(`API Load Test - ${scenario.name}`, true, result);
      } catch (error) {
        console.log(colors.red(`❌ ${scenario.name} failed`));
        this.recordTest(`API Load Test - ${scenario.name}`, false, error.message);
      }
    }
  }

  async generateReports() {
    console.log(colors.blue('\n📊 Phase 5: Test Reports'));
    
    const totalTime = Date.now() - this.results.startTime;
    
    console.log(colors.magenta('\n🎯 FINAL TEST REPORT'));
    console.log(colors.gray('=' * 50));
    console.log(`📈 Total Tests: ${this.results.summary.total}`);
    console.log(colors.green(`✅ Passed: ${this.results.summary.passed}`));
    console.log(colors.red(`❌ Failed: ${this.results.summary.failed}`));
    console.log(colors.yellow(`⏭️  Skipped: ${this.results.summary.skipped}`));
    console.log(`⏱️  Total Time: ${(totalTime / 1000).toFixed(1)}s`);
    
    const successRate = ((this.results.summary.passed / this.results.summary.total) * 100).toFixed(1);
    console.log(`📊 Success Rate: ${successRate}%`);
    
    // Save detailed report to file
    const reportFile = `test-report-${new Date().toISOString().slice(0, 19).replace(/:/g, '-')}.json`;
    fs.writeFileSync(reportFile, JSON.stringify(this.results, null, 2));
    console.log(`💾 Detailed report saved: ${reportFile}`);
    
    // Print next steps
    console.log(colors.cyan('\n🚀 Next Steps:'));
    console.log('1. View login page: http://localhost:8080/auth-web/login.html');
    console.log('2. Test API directly: curl -X POST http://localhost:8080/auth-web/api/auth/login \\');
    console.log('   -H "Content-Type: application/json" \\');
    console.log('   -d \'{"username":"testuser123","password":"TestPass3!"}\'');
    console.log('3. Run stress test: npm run test:api:stress');
    console.log('4. Monitor cache stats: curl http://localhost:8080/auth-web/api/auth/stats');
    
    if (this.results.summary.failed > 0) {
      console.log(colors.red('\n⚠️  Some tests failed. Check the details above.'));
      process.exit(1);
    } else {
      console.log(colors.green('\n🎉 All tests passed! System is ready for production.'));
    }
  }

  async runK6Test(args) {
    return new Promise((resolve, reject) => {
      const k6Process = spawn('k6', ['run', ...args, 'k6-api-load-test.js'], {
        cwd: __dirname,
        stdio: ['pipe', 'pipe', 'pipe']
      });
      
      let output = '';
      let errorOutput = '';
      
      k6Process.stdout.on('data', (data) => {
        output += data.toString();
        process.stdout.write(colors.gray(data.toString()));
      });
      
      k6Process.stderr.on('data', (data) => {
        errorOutput += data.toString();
        process.stderr.write(colors.red(data.toString()));
      });
      
      k6Process.on('close', (code) => {
        if (code === 0) {
          resolve({ output, code });
        } else {
          reject(new Error(`k6 process exited with code ${code}: ${errorOutput}`));
        }
      });
      
      // Timeout after 5 minutes
      setTimeout(() => {
        k6Process.kill();
        reject(new Error('k6 test timeout after 5 minutes'));
      }, 300000);
    });
  }

  async checkCommand(command, arg = '--help') {
    return new Promise((resolve) => {
      exec(`${command} ${arg}`, (error, stdout, stderr) => {
        resolve(error === null);
      });
    });
  }

  recordTest(name, passed, data = null) {
    this.results.tests.push({
      name,
      passed,
      data,
      timestamp: Date.now()
    });
    
    this.results.summary.total++;
    if (passed) {
      this.results.summary.passed++;
    } else {
      this.results.summary.failed++;
    }
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--help') || args.includes('-h')) {
    console.log('Oracle Fusion Auth Test Runner');
    console.log('');
    console.log('Usage:');
    console.log('  node test-runner.js              Run all tests');
    console.log('  npm test                         Run all tests');
    console.log('  npm run test:api                 Run k6 API tests only');
    console.log('  npm run test:browser             Run Playwright browser tests only');
    console.log('  npm run test:api:stress          Run stress test');
    console.log('');
    console.log('Prerequisites:');
    console.log('  1. Application server running on http://localhost:8080');
    console.log('  2. k6 installed (for API testing)');
    console.log('  3. Node.js and npm packages installed');
    console.log('');
    return;
  }
  
  const runner = new OracleFusionTestRunner();
  await runner.runAllTests();
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}

module.exports = OracleFusionTestRunner;