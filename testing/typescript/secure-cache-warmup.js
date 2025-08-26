const VaultTestCredentials = require('./vault-test-credentials');

/**
 * Secure Cache Warm-up Tool
 * Uses Vault-managed credentials instead of hardcoded values
 */
class SecureCacheWarmup {
  constructor() {
    this.baseUrl = process.env.AUTH_API_URL || 'http://localhost:8080/auth-web/api';
    this.credentials = new VaultTestCredentials();
  }

  // Get test users from Vault pattern (no hardcoded credentials!)
  getTestUsers() {
    // Dynamically generate based on secure pattern from Vault
    return VaultTestCredentials.getTestUsers().slice(0, 16); // Use first 16 for warmup
  }

  async authenticateUser(username, password) {
    const startTime = Date.now();
    
    try {
      const response = await fetch(`${this.baseUrl}/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ username, password })
      });

      const result = await response.json();
      const responseTime = Date.now() - startTime;

      return {
        username,
        success: result.success || false,
        responseTime,
        cached: result.cached || false,
        error: result.success ? null : result.message
      };
    } catch (error) {
      return {
        username,
        success: false,
        responseTime: Date.now() - startTime,
        cached: false,
        error: error.message
      };
    }
  }

  async warmupCache() {
    console.log('🔥 SECURE CACHE WARMUP STARTING');
    console.log('===============================');
    console.log('Using Vault-managed test credentials (no hardcoded passwords)');
    console.log('');

    const users = this.getTestUsers();
    console.log(`🎯 Warming up cache for ${users.length} test users...`);

    // Warm up in 3 rounds for better cache seeding
    for (let round = 1; round <= 3; round++) {
      console.log(`\n🔄 Round ${round}/3:`);
      
      // Authenticate each user multiple times in parallel
      const promises = users.flatMap(user => 
        Array.from({length: 2}, () => this.authenticateUser(user.username, user.password))
      );

      const roundResults = await Promise.all(promises);
      const successful = roundResults.filter(r => r.success).length;
      const avgResponseTime = roundResults.reduce((sum, r) => sum + r.responseTime, 0) / roundResults.length;
      
      console.log(`   ✅ ${successful}/${roundResults.length} authentications successful`);
      console.log(`   ⏱️  Average response time: ${avgResponseTime.toFixed(2)}ms`);
    }
  }

  async runPerformanceTest() {
    console.log('\n⚡ PERFORMANCE TEST');
    console.log('==================');

    const testUser = VaultTestCredentials.getRandomTestUser();
    console.log(`Testing with: ${testUser.username}`);

    const iterations = 10;
    const results = [];

    for (let i = 0; i < iterations; i++) {
      const result = await this.authenticateUser(testUser.username, testUser.password);
      results.push(result);
    }

    const successful = results.filter(r => r.success).length;
    const cached = results.filter(r => r.cached).length;
    const avgTime = results.reduce((sum, r) => sum + r.responseTime, 0) / results.length;
    const minTime = Math.min(...results.map(r => r.responseTime));
    const maxTime = Math.max(...results.map(r => r.responseTime));

    console.log(`\n📊 Results:`);
    console.log(`   Success Rate: ${(successful/iterations*100).toFixed(1)}%`);
    console.log(`   Cache Hit Rate: ${(cached/successful*100).toFixed(1)}%`);
    console.log(`   Average Time: ${avgTime.toFixed(2)}ms`);
    console.log(`   Min Time: ${minTime}ms`);
    console.log(`   Max Time: ${maxTime}ms`);
    console.log(`   Performance: ${avgTime < 50 ? '🚀 Excellent' : avgTime < 100 ? '✅ Good' : '⚠️ Needs optimization'}`);
  }
}

// Run if called directly
if (require.main === module) {
  (async () => {
    const warmup = new SecureCacheWarmup();
    
    try {
      await warmup.warmupCache();
      await warmup.runPerformanceTest();
      
      console.log('\n🎉 Cache warmup completed successfully!');
      console.log('💡 All credentials retrieved securely from Vault patterns');
      
    } catch (error) {
      console.error('❌ Cache warmup failed:', error.message);
      process.exit(1);
    }
  })();
}

module.exports = SecureCacheWarmup;