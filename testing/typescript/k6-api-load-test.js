/**
 * k6 Load Testing Script for Oracle Fusion Auth API
 * 
 * This script tests the authentication API with multiple concurrent users
 * simulating real-world authentication patterns.
 * 
 * Usage:
 *   k6 run --vus 50 --duration 30s k6-api-load-test.js
 *   k6 run --vus 100 --duration 60s k6-api-load-test.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const authFailureRate = new Rate('auth_failures');
const authDuration = new Trend('auth_duration');
const cacheHitRate = new Rate('cache_hits');
const authCounter = new Counter('auth_attempts');

// Test configuration
export const options = {
  stages: [
    { duration: '10s', target: 20 },  // Ramp up to 20 users
    { duration: '30s', target: 50 },  // Stay at 50 users
    { duration: '20s', target: 100 }, // Ramp up to 100 users  
    { duration: '60s', target: 100 }, // Stay at 100 users
    { duration: '20s', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],       // 95% of requests under 500ms
    auth_failures: ['rate<0.1'],            // Less than 10% auth failures
    auth_duration: ['p(95)<200'],           // 95% auth under 200ms
    http_req_failed: ['rate<0.01'],         // Less than 1% HTTP failures
  },
};

const BASE_URL = 'http://localhost:8080/auth-web/api';

// Test user credentials (1000 users available)
const USERS = [];
for (let i = 0; i < 1000; i++) {
  USERS.push({
    username: `testuser${String(i).padStart(3, '0')}`,
    password: `TestPass${i % 10}!`
  });
}

// Different user access patterns
const HIGH_FREQUENCY_USERS = [0, 111, 222, 333, 444, 555, 666, 777, 888, 999];
const MEDIUM_FREQUENCY_USERS = [50, 151, 252, 353, 454];
const LOW_FREQUENCY_USERS = [99, 198, 297, 396, 495];

export function setup() {
  console.log('🚀 Starting Oracle Fusion Auth Load Test');
  console.log(`📊 Testing with ${USERS.length} available users`);
  
  // Health check
  const healthResponse = http.get(`${BASE_URL}/auth/health`);
  check(healthResponse, {
    'Health check passes': (r) => r.status === 200,
  });
  
  return { startTime: new Date() };
}

export default function (data) {
  const userId = selectUser();
  const user = USERS[userId];
  
  // Simulate authentication
  const payload = JSON.stringify({
    username: user.username,
    password: user.password
  });
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };
  
  const startTime = new Date();
  const response = http.post(`${BASE_URL}/auth/login`, payload, params);
  const duration = new Date() - startTime;
  
  // Record metrics
  authCounter.add(1);
  authDuration.add(duration);
  
  const success = check(response, {
    'Status is 200 or 401': (r) => r.status === 200 || r.status === 401,
    'Response time < 1s': (r) => r.timings.duration < 1000,
    'Has JSON response': (r) => {
      try {
        JSON.parse(r.body);
        return true;
      } catch {
        return false;
      }
    },
  });
  
  if (response.status === 200) {
    const result = JSON.parse(response.body);
    
    check(result, {
      'Authentication successful': (r) => r.success === true,
      'Has user data': (r) => r.user && r.user.username,
      'Has performance metrics': (r) => typeof r.responseTimeMs === 'number',
    });
    
    // Track cache performance
    if (result.cacheHit) {
      cacheHitRate.add(1);
    } else {
      cacheHitRate.add(0);
    }
    
    // Log successful high-value authentications
    if (HIGH_FREQUENCY_USERS.includes(userId)) {
      console.log(`✅ High-freq user ${user.username} authenticated in ${result.responseTimeMs}ms (cache: ${result.cacheHit ? 'HIT' : 'MISS'})`);
    }
    
  } else if (response.status === 401) {
    // Expected for some invalid attempts
    authFailureRate.add(1);
  } else {
    // Unexpected error
    authFailureRate.add(1);
    console.log(`❌ Unexpected response ${response.status} for ${user.username}`);
  }
  
  // Realistic user behavior - don't hammer immediately
  sleep(Math.random() * 2 + 0.5); // 0.5-2.5 seconds between requests
}

export function teardown(data) {
  console.log('📊 Load test completed!');
  
  // Get final statistics
  const statsResponse = http.get(`${BASE_URL}/auth/stats`);
  if (statsResponse.status === 200) {
    const stats = JSON.parse(statsResponse.body);
    console.log(`📈 Final Cache Stats:`);
    console.log(`   Cache Size: ${stats.cacheSize}`);
    console.log(`   Cache Hits: ${stats.cacheHits}`);
    console.log(`   Cache Misses: ${stats.cacheMisses}`);
    console.log(`   Hit Ratio: ${(stats.hitRatio * 100).toFixed(2)}%`);
  }
  
  const endTime = new Date();
  const testDuration = (endTime - data.startTime) / 1000;
  console.log(`⏱️  Total test duration: ${testDuration.toFixed(1)}s`);
}

/**
 * Select user based on realistic access patterns:
 * - 60% high-frequency users (popular accounts)
 * - 25% medium-frequency users  
 * - 10% low-frequency users
 * - 5% random users
 */
function selectUser() {
  const rand = Math.random();
  
  if (rand < 0.60) {
    // High frequency users (cache hits expected)
    return HIGH_FREQUENCY_USERS[Math.floor(Math.random() * HIGH_FREQUENCY_USERS.length)];
  } else if (rand < 0.85) {
    // Medium frequency users
    return MEDIUM_FREQUENCY_USERS[Math.floor(Math.random() * MEDIUM_FREQUENCY_USERS.length)];
  } else if (rand < 0.95) {
    // Low frequency users
    return LOW_FREQUENCY_USERS[Math.floor(Math.random() * LOW_FREQUENCY_USERS.length)];
  } else {
    // Random users (cache misses expected)
    return Math.floor(Math.random() * 1000);
  }
}

/**
 * Test scenarios - run with different parameters:
 * 
 * 🔥 Stress Test:
 * k6 run --vus 200 --duration 60s k6-api-load-test.js
 * 
 * 💨 Quick Test:
 * k6 run --vus 10 --duration 10s k6-api-load-test.js
 * 
 * 🚀 Peak Load:
 * k6 run --vus 500 --duration 120s k6-api-load-test.js
 * 
 * 📊 Cache Test (focuses on high-frequency users):
 * k6 run --vus 50 --duration 30s -e CACHE_FOCUSED=true k6-api-load-test.js
 */