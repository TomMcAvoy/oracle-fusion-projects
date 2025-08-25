#!/usr/bin/env node
/**
 * Cache Warmup Script - Pre-load authentication cache for testing
 * 
 * This script authenticates high-frequency users multiple times to:
 * 1. Pre-populate the cache with commonly tested users
 * 2. Ensure cache hit rates are realistic during load testing
 * 3. Validate that caching is working properly
 * 
 * Usage:
 *   node cache-warmup.js
 *   npm run warmup
 */

const axios = require('axios').default;

class CacheWarmer {
  constructor(baseUrl = 'http://localhost:8080/auth-web/api/auth') {
    this.baseUrl = baseUrl;
    this.results = {
      attempts: 0,
      successful: 0,
      failed: 0,
      cacheHits: 0,
      cacheMisses: 0,
      averageResponseTime: 0,
      errors: []
    };
  }

  async warmupCache() {
    console.log('🔥 Authentication Cache Warmup Starting...');
    console.log('='.repeat(50));

    try {
      // First, check if server is running
      await this.checkServerHealth();

      // Get initial cache statistics
      const initialStats = await this.getCacheStats();
      console.log('📊 Initial Cache State:');
      console.log(`   Size: ${initialStats?.cacheSize || 0}`);
      console.log(`   Hit Ratio: ${((initialStats?.hitRatio || 0) * 100).toFixed(1)}%`);

      // Define high-frequency users for warmup
      const highFreqUsers = this.getHighFrequencyUsers();
      
      // Warm up in multiple rounds
      await this.performWarmupRounds(highFreqUsers, 3);

      // Get final statistics
      const finalStats = await this.getCacheStats();
      this.printFinalReport(initialStats, finalStats);

    } catch (error) {
      console.error('❌ Cache warmup failed:', error.message);
      process.exit(1);
    }
  }

  async checkServerHealth() {
    console.log('🏥 Checking server health...');
    try {
      const response = await axios.get(`${this.baseUrl}/health`, { timeout: 5000 });
      if (response.status === 200) {
        console.log('✅ Authentication server is healthy');
      }
    } catch (error) {
      throw new Error(`Server health check failed: ${error.message}`);
    }
  }

  async getCacheStats() {
    try {
      const response = await axios.get(`${this.baseUrl}/stats`, { timeout: 3000 });
      return response.data;
    } catch (error) {
      console.log('⚠️  Could not retrieve cache statistics');
      return null;
    }
  }

  getHighFrequencyUsers() {
    // These users will be accessed frequently during testing
    // Based on the patterns in our k6 and Playwright tests
    return [
      { username: 'testuser000', password: 'TestPass0!' },
      { username: 'testuser001', password: 'TestPass1!' },
      { username: 'testuser002', password: 'TestPass2!' },
      { username: 'testuser003', password: 'TestPass3!' },
      { username: 'testuser111', password: 'TestPass1!' },
      { username: 'testuser123', password: 'TestPass3!' },
      { username: 'testuser222', password: 'TestPass2!' },
      { username: 'testuser333', password: 'TestPass3!' },
      { username: 'testuser444', password: 'TestPass4!' },
      { username: 'testuser456', password: 'TestPass6!' },
      { username: 'testuser555', password: 'TestPass5!' },
      { username: 'testuser666', password: 'TestPass6!' },
      { username: 'testuser777', password: 'TestPass7!' },
      { username: 'testuser789', password: 'TestPass9!' },
      { username: 'testuser888', password: 'TestPass8!' },
      { username: 'testuser999', password: 'TestPass9!' }
    ];
  }

  async performWarmupRounds(users, rounds) {
    console.log(`\n🔄 Starting ${rounds} warmup rounds with ${users.length} high-frequency users...`);

    for (let round = 1; round <= rounds; round++) {
      console.log(`\n⚡ Round ${round}/${rounds}:`);
      
      // Authenticate each user multiple times in parallel
      const promises = users.flatMap(user => 
        Array.from({length: 2}, () => this.authenticateUser(user.username, user.password))
      );

      const roundResults = await Promise.all(promises);
      this.processRoundResults(roundResults, round);

      // Brief pause between rounds to allow cache to settle
      if (round < rounds) {
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
  }

  async authenticateUser(username, password) {
    const startTime = Date.now();
    
    try {
      const response = await axios.post(`${this.baseUrl}/login`, {
        username,
        password
      }, { 
        timeout: 10000,
        headers: {
          'Content-Type': 'application/json'
        }
      });

      const responseTime = Date.now() - startTime;
      this.results.attempts++;

      if (response.status === 200 && response.data.success) {
        this.results.successful++;
        
        if (response.data.cacheHit) {
          this.results.cacheHits++;
        } else {
          this.results.cacheMisses++;
        }

        return {
          username,
          success: true,
          responseTime: response.data.responseTimeMs || responseTime,
          cacheHit: response.data.cacheHit,
          actualResponseTime: responseTime
        };
      } else {
        this.results.failed++;
        this.results.errors.push(`${username}: Authentication failed`);
        
        return {
          username,
          success: false,
          error: 'Authentication failed'
        };
      }

    } catch (error) {
      this.results.failed++;
      this.results.attempts++;
      this.results.errors.push(`${username}: ${error.message}`);
      
      return {
        username,
        success: false,
        error: error.message
      };
    }
  }

  processRoundResults(results, round) {
    const successful = results.filter(r => r.success);
    const cacheHits = successful.filter(r => r.cacheHit);
    const avgResponseTime = successful.length > 0 
      ? successful.reduce((sum, r) => sum + (r.responseTime || 0), 0) / successful.length
      : 0;

    console.log(`   ✅ Successful: ${successful.length}/${results.length}`);
    console.log(`   🎯 Cache Hits: ${cacheHits.length}/${successful.length} (${(cacheHits.length/Math.max(successful.length,1)*100).toFixed(1)}%)`);
    console.log(`   ⚡ Avg Response: ${avgResponseTime.toFixed(1)}ms`);

    // Show sample results
    const samples = successful.slice(0, 3);
    samples.forEach(result => {
      const cacheStatus = result.cacheHit ? '🎯 HIT' : '🔍 MISS';
      console.log(`      ${result.username}: ${result.responseTime}ms ${cacheStatus}`);
    });
  }

  printFinalReport(initialStats, finalStats) {
    console.log('\n🎉 CACHE WARMUP COMPLETE');
    console.log('='.repeat(50));

    // Overall results
    console.log('📊 Warmup Results:');
    console.log(`   Total Attempts: ${this.results.attempts}`);
    console.log(`   Successful: ${this.results.successful}`);
    console.log(`   Failed: ${this.results.failed}`);
    console.log(`   Success Rate: ${(this.results.successful/this.results.attempts*100).toFixed(1)}%`);

    // Cache performance
    const totalCacheAttempts = this.results.cacheHits + this.results.cacheMisses;
    if (totalCacheAttempts > 0) {
      console.log(`\n🎯 Cache Performance:`);
      console.log(`   Cache Hits: ${this.results.cacheHits}`);
      console.log(`   Cache Misses: ${this.results.cacheMisses}`);
      console.log(`   Hit Ratio: ${(this.results.cacheHits/totalCacheAttempts*100).toFixed(1)}%`);
    }

    // Cache growth
    if (initialStats && finalStats) {
      const sizeGrowth = finalStats.cacheSize - initialStats.cacheSize;
      console.log(`\n📈 Cache Growth:`);
      console.log(`   Initial Size: ${initialStats.cacheSize}`);
      console.log(`   Final Size: ${finalStats.cacheSize}`);
      console.log(`   Growth: +${sizeGrowth} entries`);
      console.log(`   Final Hit Ratio: ${(finalStats.hitRatio * 100).toFixed(1)}%`);
    }

    // Errors (if any)
    if (this.results.errors.length > 0) {
      console.log(`\n❌ Errors (${this.results.errors.length}):`);
      this.results.errors.slice(0, 5).forEach(error => {
        console.log(`   ${error}`);
      });
      
      if (this.results.errors.length > 5) {
        console.log(`   ... and ${this.results.errors.length - 5} more`);
      }
    }

    console.log('\n🚀 Cache is now warmed up for load testing!');
    console.log('💡 High-frequency users are now cached and ready for optimal performance');
  }
}

// CLI execution
async function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--help') || args.includes('-h')) {
    console.log('Cache Warmup Script');
    console.log('');
    console.log('Usage:');
    console.log('  node cache-warmup.js [--url <base_url>]');
    console.log('');
    console.log('Options:');
    console.log('  --url <url>    Base URL for auth API (default: http://localhost:8080/auth-web/api/auth)');
    console.log('  --help, -h     Show this help message');
    return;
  }

  const urlIndex = args.indexOf('--url');
  const baseUrl = urlIndex !== -1 && args[urlIndex + 1] 
    ? args[urlIndex + 1] 
    : 'http://localhost:8080/auth-web/api/auth';

  const warmer = new CacheWarmer(baseUrl);
  await warmer.warmupCache();
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}

module.exports = CacheWarmer;