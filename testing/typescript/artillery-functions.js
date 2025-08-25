/**
 * Artillery Custom Functions for Oracle Fusion Auth Load Testing
 */

// High-frequency users (these should hit cache more often)
const HIGH_FREQUENCY_USERS = [0, 111, 222, 333, 444, 555, 666, 777, 888, 999];

// Medium-frequency users
const MEDIUM_FREQUENCY_USERS = [50, 151, 252, 353, 454];

// All available test users (0-999)
const ALL_USERS = Array.from({length: 1000}, (_, i) => i);

/**
 * Select a random user following realistic usage patterns:
 * - 60% high-frequency users (cache hits expected)
 * - 25% medium-frequency users  
 * - 15% completely random users (cache misses expected)
 */
function selectRandomUser(context, events, done) {
  const rand = Math.random();
  let userNum;
  
  if (rand < 0.60) {
    // High frequency users
    userNum = HIGH_FREQUENCY_USERS[Math.floor(Math.random() * HIGH_FREQUENCY_USERS.length)];
  } else if (rand < 0.85) {
    // Medium frequency users
    userNum = MEDIUM_FREQUENCY_USERS[Math.floor(Math.random() * MEDIUM_FREQUENCY_USERS.length)];
  } else {
    // Random users
    userNum = Math.floor(Math.random() * 1000);
  }
  
  context.vars.username = `testuser${String(userNum).padStart(3, '0')}`;
  context.vars.password = `TestPass${userNum % 10}!`;
  
  return done();
}

/**
 * Select high-frequency user (for cache hit testing)
 */
function selectHighFrequencyUser(context, events, done) {
  const userNum = HIGH_FREQUENCY_USERS[Math.floor(Math.random() * HIGH_FREQUENCY_USERS.length)];
  
  context.vars.username = `testuser${String(userNum).padStart(3, '0')}`;
  context.vars.password = `TestPass${userNum % 10}!`;
  
  return done();
}

/**
 * Select invalid credentials (for negative testing)
 */
function selectInvalidCredentials(context, events, done) {
  const userNum = Math.floor(Math.random() * 1000);
  
  context.vars.username = `testuser${String(userNum).padStart(3, '0')}`;
  context.vars.password = 'InvalidPassword123!'; // Wrong password
  
  return done();
}

/**
 * Log authentication metrics
 */
function logAuthResult(context, events, done) {
  if (context.vars.authSuccess) {
    console.log(`✅ ${context.vars.username}: ${context.vars.responseTime}ms (cache: ${context.vars.cacheHit ? 'HIT' : 'MISS'})`);
  } else {
    console.log(`❌ ${context.vars.username}: Auth failed`);
  }
  
  return done();
}

/**
 * Validate response and track custom metrics
 */
function validateResponse(requestParams, response, context, ee, next) {
  if (response.statusCode === 200) {
    const body = JSON.parse(response.body);
    
    // Track custom metrics
    if (body.success) {
      ee.emit('customStat', 'auth_success', 1);
      
      if (body.cacheHit) {
        ee.emit('customStat', 'cache_hit', 1);
      } else {
        ee.emit('customStat', 'cache_miss', 1);
      }
      
      // Track response times by cache status
      if (body.cacheHit) {
        ee.emit('customStat', 'cache_hit_response_time', body.responseTimeMs);
      } else {
        ee.emit('customStat', 'cache_miss_response_time', body.responseTimeMs);
      }
      
    } else {
      ee.emit('customStat', 'auth_failure', 1);
    }
  }
  
  return next();
}

/**
 * Setup phase - run before test starts
 */
function setupTest(context, events, done) {
  console.log('🚀 Starting Artillery Load Test for Oracle Fusion Auth');
  console.log('📊 Test Users: testuser000 to testuser999');
  console.log('🔑 Password Pattern: TestPass{lastDigit}!');
  console.log('⚡ Expected high cache hit rate for frequent users');
  
  return done();
}

/**
 * Cleanup phase - run after test completes
 */
function cleanupTest(context, events, done) {
  console.log('🏁 Artillery load test completed');
  console.log('💡 Check application logs for detailed authentication metrics');
  
  return done();
}

module.exports = {
  selectRandomUser,
  selectHighFrequencyUser,
  selectInvalidCredentials,
  logAuthResult,
  validateResponse,
  setupTest,
  cleanupTest
};