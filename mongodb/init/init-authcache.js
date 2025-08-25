// MongoDB Initialization Script for Authentication Cache
// Create database, collections, and indexes for enterprise auth cache

print('🔧 Initializing MongoDB Authentication Cache...');

// Switch to authcache database
use('authcache');

// Create collections
db.createCollection('users', {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["username", "userData", "cacheTime", "cacheExpiry"],
      properties: {
        username: {
          bsonType: "string",
          description: "Username - must be unique"
        },
        userData: {
          bsonType: "string", 
          description: "Encrypted user data (JSON)"
        },
        cacheTime: {
          bsonType: ["long", "int"],
          description: "Cache timestamp in milliseconds"
        },
        cacheExpiry: {
          bsonType: ["long", "int"],
          description: "Cache expiry timestamp in milliseconds"
        },
        region: {
          bsonType: "string",
          description: "User region for geographical optimization"
        },
        accessCount: {
          bsonType: ["long", "int"],
          minimum: 0,
          description: "Number of times user was accessed"
        }
      }
    }
  }
});

// Create indexes for optimal performance
print('📊 Creating performance indexes...');

// Primary index on username (unique)
db.users.createIndex(
  { "username": 1 },
  { 
    name: "idx_username_unique",
    unique: true,
    background: true
  }
);

// TTL index for automatic expiration
db.users.createIndex(
  { "cacheExpiry": 1 },
  { 
    name: "idx_cache_expiry_ttl",
    expireAfterSeconds: 0,
    background: true
  }
);

// Performance indexes
db.users.createIndex(
  { "region": 1 },
  { 
    name: "idx_region",
    background: true
  }
);

db.users.createIndex(
  { "accessCount": -1 },
  { 
    name: "idx_access_count_desc",
    background: true
  }
);

db.users.createIndex(
  { "cacheTime": -1 },
  { 
    name: "idx_cache_time_desc",
    background: true
  }
);

// Compound index for regional queries
db.users.createIndex(
  { "region": 1, "accessCount": -1 },
  { 
    name: "idx_region_access",
    background: true
  }
);

// Create cache statistics collection
db.createCollection('cache_stats', {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["timestamp", "statType"],
      properties: {
        timestamp: {
          bsonType: "date",
          description: "Statistics timestamp"
        },
        statType: {
          bsonType: "string",
          enum: ["performance", "security", "usage"],
          description: "Type of statistics"
        }
      }
    }
  }
});

// Index for statistics
db.cache_stats.createIndex(
  { "timestamp": -1, "statType": 1 },
  { 
    name: "idx_stats_timestamp_type",
    background: true
  }
);

// TTL for statistics (keep for 30 days)
db.cache_stats.createIndex(
  { "timestamp": 1 },
  { 
    name: "idx_stats_ttl",
    expireAfterSeconds: 2592000, // 30 days
    background: true
  }
);

// Create security logs collection
db.createCollection('security_logs', {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["timestamp", "event", "severity"],
      properties: {
        timestamp: {
          bsonType: "date",
          description: "Event timestamp"
        },
        event: {
          bsonType: "string",
          description: "Security event description"
        },
        severity: {
          bsonType: "string",
          enum: ["INFO", "WARN", "ERROR", "CRITICAL"],
          description: "Event severity level"
        }
      }
    }
  }
});

// Security logs indexes
db.security_logs.createIndex(
  { "timestamp": -1 },
  { 
    name: "idx_security_timestamp_desc",
    background: true
  }
);

db.security_logs.createIndex(
  { "severity": 1, "timestamp": -1 },
  { 
    name: "idx_security_severity_time",
    background: true
  }
);

// TTL for security logs (keep for 90 days for compliance)
db.security_logs.createIndex(
  { "timestamp": 1 },
  { 
    name: "idx_security_ttl",
    expireAfterSeconds: 7776000, // 90 days
    background: true
  }
);

// Create regions collection for geographical optimization
db.createCollection('regions');

// Insert region data
db.regions.insertMany([
  {
    code: "US-EAST",
    name: "US East Coast",
    description: "Eastern United States",
    timezone: "America/New_York",
    active: true,
    priority: 1
  },
  {
    code: "US-WEST", 
    name: "US West Coast",
    description: "Western United States",
    timezone: "America/Los_Angeles",
    active: true,
    priority: 2
  },
  {
    code: "EU-WEST",
    name: "Western Europe",
    description: "Western European Union",
    timezone: "Europe/London",
    active: true,
    priority: 3
  },
  {
    code: "ASIA-PAC",
    name: "Asia Pacific",
    description: "Asia Pacific Region",
    timezone: "Asia/Tokyo",
    active: true,
    priority: 4
  },
  {
    code: "CANADA",
    name: "Canada",
    description: "Canadian Region",
    timezone: "America/Toronto",
    active: true,
    priority: 5
  }
]);

db.regions.createIndex({ "code": 1 }, { name: "idx_region_code_unique", unique: true });

// Insert initial cache statistics
print('📈 Inserting initial cache statistics...');

db.cache_stats.insertOne({
  timestamp: new Date(),
  statType: "performance",
  l1CacheSize: 0,
  l1Hits: 0,
  l2Hits: 0,
  l3Hits: 0,
  cacheMisses: 0,
  evictions: 0,
  securityViolations: 0,
  overallHitRatio: 0.0,
  responseTimeP50: 0,
  responseTimeP95: 0,
  responseTimeP99: 0
});

db.cache_stats.insertOne({
  timestamp: new Date(),
  statType: "security",
  encryptionOperations: 0,
  keyRotations: 0,
  debuggingAttempts: 0,
  securityLockdowns: 0,
  antiTamperingEvents: 0
});

// Log initialization completion
db.security_logs.insertOne({
  timestamp: new Date(),
  event: "MongoDB authentication cache initialized",
  severity: "INFO",
  details: {
    collections: ["users", "cache_stats", "security_logs", "regions"],
    indexes: 12,
    regions: 5
  }
});

print('✅ MongoDB Authentication Cache initialized successfully!');
print('📊 Collections created: users, cache_stats, security_logs, regions');
print('🔍 Indexes created: 12 performance and TTL indexes');
print('🌍 Regions configured: US-EAST, US-WEST, EU-WEST, ASIA-PAC, CANADA');
print('🔒 Security logging enabled with 90-day retention');
print('⏱️  Cache statistics enabled with 30-day retention');
print('🚀 Ready for enterprise authentication cache operations!');

// Show collection info
print('\n📋 Collection Summary:');
print('======================');

var collections = ['users', 'cache_stats', 'security_logs', 'regions'];
collections.forEach(function(collName) {
  var stats = db.getCollection(collName).stats();
  print(collName + ': ' + stats.count + ' documents, ' + stats.indexSizes + ' indexes');
});

print('\n🎯 Cache ready for 1000 LDAP test users!');