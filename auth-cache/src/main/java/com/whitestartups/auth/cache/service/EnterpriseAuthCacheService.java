package com.whitestartups.auth.cache.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import com.mongodb.ConnectionString;
import com.mongodb.MongoClientSettings;
import com.whitestartups.auth.cache.connection.MongoMtlsConnectionPool;
import com.whitestartups.auth.cache.connection.RedisMtlsConnectionPool;
import com.whitestartups.auth.cache.model.EnterpriseUserRecord;
import com.whitestartups.auth.cache.security.SecureMemoryCache;
import com.whitestartups.auth.core.service.UserEncryptionService;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import jakarta.ejb.Stateless;
import jakarta.ejb.TransactionAttribute;
import jakarta.ejb.TransactionAttributeType;
import jakarta.inject.Inject;
import org.bson.Document;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;
import redis.clients.jedis.exceptions.JedisConnectionException;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.TimeUnit;

/**
 * Enterprise Authentication Cache Service
 * 
 * Multi-tier caching strategy:
 * 1. L1: Secure encrypted in-memory LRU cache (ultra-fast < 1ms)
 * 2. L2: Redis distributed cache (fast < 5ms) 
 * 3. L3: MongoDB fallback cache (medium < 20ms)
 * 4. L4: LDAP/Database (slow < 100ms)
 * 
 * Based on enterprise patterns from SiteMinder, OAM, PingAccess
 */
@Stateless
@TransactionAttribute(TransactionAttributeType.SUPPORTS)
public class EnterpriseAuthCacheService {
    
    private static final Logger logger = LoggerFactory.getLogger(EnterpriseAuthCacheService.class);
    
    @Inject
    private SecureMemoryCache secureMemoryCache;
    
    @Inject 
    private UserEncryptionService encryptionService;
    
    @Inject
    private RedisMtlsConnectionPool redisMtlsPool;
    
    @Inject
    private MongoMtlsConnectionPool mongoMtlsPool;
    
    // Legacy connection tracking (for backwards compatibility)
    private volatile boolean redisAvailable = false;
    private volatile boolean mongoAvailable = false;
    
    // JSON serialization
    private ObjectMapper jsonMapper;
    
    // LRU Management
    private final LinkedHashMap<String, CacheEntry> lruIndex = new LinkedHashMap<String, CacheEntry>(1000, 0.75f, true) {
        @Override
        protected boolean removeEldestEntry(Map.Entry<String, CacheEntry> eldest) {
            boolean shouldRemove = size() > getMaxCacheSize();
            if (shouldRemove) {
                // Securely remove from encrypted cache
                String key = eldest.getKey();
                secureMemoryCache.$$secureRemove(key);
                eldest.getValue().userRecord.clearSensitiveData();
                evictionCounter.incrementAndGet();
                logger.debug("LRU evicted user: {}", key);
            }
            return shouldRemove;
        }
    };
    
    // Cache statistics
    private final AtomicLong l1Hits = new AtomicLong(0);
    private final AtomicLong l2Hits = new AtomicLong(0); // Redis
    private final AtomicLong l3Hits = new AtomicLong(0); // MongoDB  
    private final AtomicLong cacheMisses = new AtomicLong(0);
    private final AtomicLong evictionCounter = new AtomicLong(0);
    private final AtomicLong securityViolations = new AtomicLong(0);
    
    // Configuration
    private static final int MAX_L1_CACHE_SIZE = 10000;  // 10K most frequent users in memory
    private static final int L1_TTL_SECONDS = 300;       // 5 minutes L1 cache
    private static final int L2_TTL_SECONDS = 1800;      // 30 minutes Redis cache  
    private static final int L3_TTL_SECONDS = 7200;      // 2 hours MongoDB cache
    private static final String REDIS_KEY_PREFIX = "auth:user:";
    private static final String MONGO_COLLECTION = "users";
    
    @PostConstruct
    public void initialize() {
        try {
            // Initialize JSON mapper
            jsonMapper = new ObjectMapper();
            jsonMapper.registerModule(new JavaTimeModule());
            
            // Initialize mTLS connection pools
            initializeMtlsConnections();
            
            logger.info("Enterprise Auth Cache initialized - L1:{}, Redis:{}, MongoDB:{}", 
                       true, redisAvailable, mongoAvailable);
                       
        } catch (Exception e) {
            logger.error("Failed to initialize enterprise auth cache", e);
        }
    }
    
    /**
     * High-performance user authentication with multi-tier caching
     * Target: < 1ms for L1 hits, < 5ms for L2 hits, < 20ms for L3 hits
     */
    public AuthenticationResult authenticateUser(String username, String password) {
        long startTime = System.nanoTime();
        
        try {
            // L1 Cache: Secure encrypted memory (fastest)
            EnterpriseUserRecord userRecord = getFromL1Cache(username);
            if (userRecord != null) {
                l1Hits.incrementAndGet();
                
                if (validateCredentials(userRecord, password)) {
                    updateAccessStats(userRecord);
                    long responseTimeMs = (System.nanoTime() - startTime) / 1_000_000;
                    
                    logger.debug("L1 cache hit authentication: {} in {}ms", username, responseTimeMs);
                    return new AuthenticationResult(true, userRecord, responseTimeMs, "L1_CACHE");
                } else {
                    return new AuthenticationResult(false, null, 
                                                  (System.nanoTime() - startTime) / 1_000_000, "INVALID_CREDENTIALS");
                }
            }
            
            // L2 Cache: Redis distributed cache
            userRecord = getFromL2Cache(username);  
            if (userRecord != null) {
                l2Hits.incrementAndGet();
                
                if (validateCredentials(userRecord, password)) {
                    // Promote to L1 cache
                    storeInL1Cache(username, userRecord);
                    updateAccessStats(userRecord);
                    long responseTimeMs = (System.nanoTime() - startTime) / 1_000_000;
                    
                    logger.debug("L2 cache hit authentication: {} in {}ms", username, responseTimeMs);
                    return new AuthenticationResult(true, userRecord, responseTimeMs, "L2_REDIS");
                } else {
                    return new AuthenticationResult(false, null,
                                                  (System.nanoTime() - startTime) / 1_000_000, "INVALID_CREDENTIALS");
                }
            }
            
            // L3 Cache: MongoDB fallback
            userRecord = getFromL3Cache(username);
            if (userRecord != null) {
                l3Hits.incrementAndGet();
                
                if (validateCredentials(userRecord, password)) {
                    // Promote to L2 and L1 caches
                    storeInL2Cache(username, userRecord);
                    storeInL1Cache(username, userRecord);
                    updateAccessStats(userRecord);
                    long responseTimeMs = (System.nanoTime() - startTime) / 1_000_000;
                    
                    logger.debug("L3 cache hit authentication: {} in {}ms", username, responseTimeMs);
                    return new AuthenticationResult(true, userRecord, responseTimeMs, "L3_MONGODB");
                } else {
                    return new AuthenticationResult(false, null,
                                                  (System.nanoTime() - startTime) / 1_000_000, "INVALID_CREDENTIALS");
                }
            }
            
            // Cache miss - would need to load from LDAP/Database
            cacheMisses.incrementAndGet();
            long responseTimeMs = (System.nanoTime() - startTime) / 1_000_000;
            
            logger.debug("Cache miss for user: {} in {}ms", username, responseTimeMs);
            return new AuthenticationResult(false, null, responseTimeMs, "CACHE_MISS");
            
        } catch (Exception e) {
            securityViolations.incrementAndGet();
            long responseTimeMs = (System.nanoTime() - startTime) / 1_000_000;
            logger.error("Authentication error for user: {} in {}ms", username, responseTimeMs, e);
            return new AuthenticationResult(false, null, responseTimeMs, "ERROR: " + e.getMessage());
        }
    }
    
    /**
     * Store user in all cache tiers after successful LDAP load
     */
    public boolean storeUserInCache(String username, EnterpriseUserRecord userRecord) {
        try {
            // Set cache metadata
            userRecord.setCacheTimestamp(LocalDateTime.now());
            userRecord.setCacheTtlSeconds((long) L1_TTL_SECONDS);
            
            // Store in all available tiers
            boolean l1Success = storeInL1Cache(username, userRecord);
            boolean l2Success = storeInL2Cache(username, userRecord); 
            boolean l3Success = storeInL3Cache(username, userRecord);
            
            logger.debug("Stored user in cache tiers - L1:{}, L2:{}, L3:{}", 
                        l1Success, l2Success, l3Success);
            
            return l1Success || l2Success || l3Success;
            
        } catch (Exception e) {
            logger.error("Failed to store user in cache: {}", username, e);
            return false;
        }
    }
    
    /**
     * Warm up cache with frequently accessed users
     */
    @TransactionAttribute(TransactionAttributeType.REQUIRED)
    public int warmupCacheWithUsers(List<EnterpriseUserRecord> users) {
        int stored = 0;
        
        for (EnterpriseUserRecord user : users) {
            try {
                if (storeUserInCache(user.getUsername(), user)) {
                    stored++;
                }
            } catch (Exception e) {
                logger.debug("Failed to warm cache for user: {}", user.getUsername(), e);
            }
        }
        
        logger.info("Cache warmed with {} users", stored);
        return stored;
    }
    
    // =============== L1 CACHE (SECURE MEMORY) ===============
    
    private EnterpriseUserRecord getFromL1Cache(String username) {
        try {
            synchronized (lruIndex) {
                CacheEntry entry = lruIndex.get(username);
                if (entry != null && !entry.isExpired()) {
                    // Decrypt from secure memory
                    EnterpriseUserRecord userRecord = secureMemoryCache.$$secureRetrieve(username, EnterpriseUserRecord.class);
                    if (userRecord != null) {
                        userRecord.updateAccessFrequency();
                        // Update LRU order
                        lruIndex.put(username, entry); 
                        return userRecord;
                    }
                } else if (entry != null) {
                    // Remove expired entry
                    lruIndex.remove(username);
                    secureMemoryCache.$$secureRemove(username);
                }
            }
        } catch (Exception e) {
            logger.debug("L1 cache retrieval failed for: {}", username, e);
            securityViolations.incrementAndGet();
        }
        return null;
    }
    
    private boolean storeInL1Cache(String username, EnterpriseUserRecord userRecord) {
        try {
            synchronized (lruIndex) {
                // Store encrypted in secure memory
                boolean stored = secureMemoryCache.$$secureStore(username, userRecord);
                if (stored) {
                    CacheEntry entry = new CacheEntry(userRecord, L1_TTL_SECONDS);
                    lruIndex.put(username, entry);
                    return true;
                }
            }
        } catch (Exception e) {
            logger.debug("L1 cache store failed for: {}", username, e);
            securityViolations.incrementAndGet();
        }
        return false;
    }
    
    // =============== L2 CACHE (REDIS) ===============
    
    private EnterpriseUserRecord getFromL2Cache(String username) {
        if (!redisAvailable) {
            return null;
        }
        
        try {
            return redisMtlsPool.executeWithResource(jedis -> {
                String key = REDIS_KEY_PREFIX + username;
                String json = jedis.get(key);
                
                if (json != null) {
                    // Decrypt and deserialize
                    String decryptedJson = encryptionService.decrypt(json);
                    return jsonMapper.readValue(decryptedJson, EnterpriseUserRecord.class);
                }
                return null;
            });
            
        } catch (JedisConnectionException e) {
            redisAvailable = false;
            logger.warn("Redis mTLS connection lost, falling back to L3", e);
        } catch (Exception e) {
            logger.debug("L2 mTLS cache retrieval failed for: {}", username, e);
        }
        
        return null;
    }
    
    private boolean storeInL2Cache(String username, EnterpriseUserRecord userRecord) {
        if (!redisAvailable) {
            return false;
        }
        
        try {
            Boolean result = redisMtlsPool.executeWithResource(jedis -> {
                String key = REDIS_KEY_PREFIX + username;
                
                // Serialize and encrypt
                String json = jsonMapper.writeValueAsString(userRecord);
                String encryptedJson = encryptionService.encrypt(json);
                
                // Store with TTL
                String redisResult = jedis.setex(key, L2_TTL_SECONDS, encryptedJson);
                return "OK".equals(redisResult);
            });
            
            return result != null && result;
            
        } catch (JedisConnectionException e) {
            redisAvailable = false;
            logger.warn("Redis mTLS connection lost during store operation", e);
        } catch (Exception e) {
            logger.debug("L2 mTLS cache store failed for: {}", username, e);
        }
        
        return false;
    }
    
    // =============== L3 CACHE (MONGODB) ===============
    
    private EnterpriseUserRecord getFromL3Cache(String username) {
        if (!mongoAvailable) {
            return null;
        }
        
        try {
            MongoCollection<Document> userCollection = mongoMtlsPool.getCollection(MONGO_COLLECTION);
            if (userCollection == null) {
                return null;
            }
            
            Document query = new Document("username", username)
                .append("cacheExpiry", new Document("$gt", System.currentTimeMillis()));
            
            Document doc = userCollection.find(query).first();
            
            if (doc != null) {
                // Decrypt and deserialize
                String encryptedJson = doc.getString("userData");
                String decryptedJson = encryptionService.decrypt(encryptedJson);
                return jsonMapper.readValue(decryptedJson, EnterpriseUserRecord.class);
            }
            
        } catch (Exception e) {
            logger.debug("L3 mTLS cache retrieval failed for: {}", username, e);
            mongoAvailable = false;
        }
        
        return null;
    }
    
    private boolean storeInL3Cache(String username, EnterpriseUserRecord userRecord) {
        if (!mongoAvailable) {
            return false;
        }
        
        try {
            MongoCollection<Document> userCollection = mongoMtlsPool.getCollection(MONGO_COLLECTION);
            if (userCollection == null) {
                return false;
            }
            
            // Serialize and encrypt
            String json = jsonMapper.writeValueAsString(userRecord);
            String encryptedJson = encryptionService.encrypt(json);
            
            Document doc = new Document("username", username)
                .append("userData", encryptedJson)
                .append("cacheTime", System.currentTimeMillis())
                .append("cacheExpiry", System.currentTimeMillis() + (L3_TTL_SECONDS * 1000L))
                .append("region", userRecord.getRegion())
                .append("accessCount", userRecord.getAccessFrequency());
            
            // Upsert (update or insert)
            Document filter = new Document("username", username);
            userCollection.replaceOne(filter, doc, 
                new com.mongodb.client.model.ReplaceOptions().upsert(true));
            
            return true;
            
        } catch (Exception e) {
            logger.debug("L3 mTLS cache store failed for: {}", username, e);
            mongoAvailable = false;
        }
        
        return false;
    }
    
    // =============== HELPER METHODS ===============
    
    private boolean validateCredentials(EnterpriseUserRecord userRecord, String password) {
        try {
            // Check account status
            if (!userRecord.isAccountActive()) {
                logger.debug("Account not active: {}", userRecord.getUsername());
                return false;
            }
            
            // Check password expiry
            if (userRecord.isPasswordExpired()) {
                logger.debug("Password expired for: {}", userRecord.getUsername());
                return false;
            }
            
            // Verify password hash
            return encryptionService.verifyPassword(password, userRecord.getPasswordHash());
            
        } catch (Exception e) {
            logger.error("Credential validation failed", e);
            return false;
        }
    }
    
    private void updateAccessStats(EnterpriseUserRecord userRecord) {
        userRecord.updateAccessFrequency();
        userRecord.setLastSuccessfulLogin(LocalDateTime.now());
        
        // Reset failed attempts on successful login
        if (userRecord.getFailedLoginAttempts() != null && userRecord.getFailedLoginAttempts() > 0) {
            userRecord.setFailedLoginAttempts(0);
        }
    }
    
    private int getMaxCacheSize() {
        return MAX_L1_CACHE_SIZE;
    }
    
    /**
     * Initialize mTLS connection pools for Redis and MongoDB
     */
    private void initializeMtlsConnections() {
        // Initialize Redis mTLS connection pool
        try {
            redisMtlsPool.initialize();
            redisAvailable = redisMtlsPool.performHealthCheck();
            
            if (redisAvailable) {
                logger.info("Redis mTLS connection pool initialized: {}", 
                           redisMtlsPool.getStats());
            } else {
                logger.warn("Redis mTLS connection pool unhealthy, L2 cache disabled");
            }
            
        } catch (Exception e) {
            logger.warn("Redis mTLS initialization failed, will use L1+L3 caching only", e);
            redisAvailable = false;
        }
        
        // Initialize MongoDB mTLS connection pool
        try {
            mongoMtlsPool.initialize();
            mongoAvailable = mongoMtlsPool.performHealthCheck();
            
            if (mongoAvailable) {
                logger.info("MongoDB mTLS connection pool initialized: {}", 
                           mongoMtlsPool.getStats());
            } else {
                logger.warn("MongoDB mTLS connection pool unhealthy, L3 cache disabled");
            }
            
        } catch (Exception e) {
            logger.warn("MongoDB mTLS initialization failed, will use L1+L2 caching only", e);
            mongoAvailable = false;
        }
    }
    

    
    /**
     * Get comprehensive cache statistics
     */
    public EnterpriseAuthCacheStatistics getCacheStatistics() {
        return new EnterpriseAuthCacheStatistics(
            secureMemoryCache.$$size(),
            l1Hits.get(),
            l2Hits.get(), 
            l3Hits.get(),
            cacheMisses.get(),
            evictionCounter.get(),
            securityViolations.get(),
            redisAvailable,
            mongoAvailable,
            calculateHitRatio(),
            secureMemoryCache.$$getSecurityStats()
        );
    }
    
    private double calculateHitRatio() {
        long totalHits = l1Hits.get() + l2Hits.get() + l3Hits.get();
        long totalRequests = totalHits + cacheMisses.get();
        return totalRequests > 0 ? (double) totalHits / totalRequests : 0.0;
    }
    
    @PreDestroy
    public void cleanup() {
        try {
            // Cleanup mTLS connection pools
            if (redisMtlsPool != null) {
                redisMtlsPool.cleanup();
            }
            
            if (mongoMtlsPool != null) {
                mongoMtlsPool.cleanup();
            }
            
            // Clear LRU index securely
            synchronized (lruIndex) {
                lruIndex.values().forEach(entry -> entry.userRecord.clearSensitiveData());
                lruIndex.clear();
            }
            
            logger.info("Enterprise auth cache cleanup completed");
            
        } catch (Exception e) {
            logger.error("Cleanup failed", e);
        }
    }
    
    // =============== INNER CLASSES ===============
    
    /**
     * L1 Cache entry with expiration
     */
    private static class CacheEntry {
        final EnterpriseUserRecord userRecord;
        final long expiryTime;
        
        CacheEntry(EnterpriseUserRecord userRecord, int ttlSeconds) {
            this.userRecord = userRecord;
            this.expiryTime = System.currentTimeMillis() + (ttlSeconds * 1000L);
        }
        
        boolean isExpired() {
            return System.currentTimeMillis() > expiryTime;
        }
    }
    
    /**
     * Authentication result with detailed metrics
     */
    public static class AuthenticationResult {
        private final boolean success;
        private final EnterpriseUserRecord userRecord;
        private final long responseTimeMs;
        private final String cacheSource;
        
        public AuthenticationResult(boolean success, EnterpriseUserRecord userRecord, 
                                  long responseTimeMs, String cacheSource) {
            this.success = success;
            this.userRecord = userRecord;
            this.responseTimeMs = responseTimeMs;
            this.cacheSource = cacheSource;
        }
        
        public boolean isSuccess() { return success; }
        public EnterpriseUserRecord getUserRecord() { return userRecord; }
        public long getResponseTimeMs() { return responseTimeMs; }
        public String getCacheSource() { return cacheSource; }
    }
    
    /**
     * Comprehensive cache statistics
     */
    public static class EnterpriseAuthCacheStatistics {
        private final int l1CacheSize;
        private final long l1Hits;
        private final long l2Hits;
        private final long l3Hits;
        private final long cacheMisses;
        private final long evictions;
        private final long securityViolations;
        private final boolean redisAvailable;
        private final boolean mongoAvailable;
        private final double overallHitRatio;
        private final SecureMemoryCache.SecurityStatistics securityStats;
        
        public EnterpriseAuthCacheStatistics(int l1CacheSize, long l1Hits, long l2Hits, 
                                           long l3Hits, long cacheMisses, long evictions,
                                           long securityViolations, boolean redisAvailable,
                                           boolean mongoAvailable, double overallHitRatio,
                                           SecureMemoryCache.SecurityStatistics securityStats) {
            this.l1CacheSize = l1CacheSize;
            this.l1Hits = l1Hits;
            this.l2Hits = l2Hits;
            this.l3Hits = l3Hits;
            this.cacheMisses = cacheMisses;
            this.evictions = evictions;
            this.securityViolations = securityViolations;
            this.redisAvailable = redisAvailable;
            this.mongoAvailable = mongoAvailable;
            this.overallHitRatio = overallHitRatio;
            this.securityStats = securityStats;
        }
        
        // Getters
        public int getL1CacheSize() { return l1CacheSize; }
        public long getL1Hits() { return l1Hits; }
        public long getL2Hits() { return l2Hits; }
        public long getL3Hits() { return l3Hits; }
        public long getCacheMisses() { return cacheMisses; }
        public long getEvictions() { return evictions; }
        public long getSecurityViolations() { return securityViolations; }
        public boolean isRedisAvailable() { return redisAvailable; }
        public boolean isMongoAvailable() { return mongoAvailable; }
        public double getOverallHitRatio() { return overallHitRatio; }
        public SecureMemoryCache.SecurityStatistics getSecurityStats() { return securityStats; }
        
        @Override
        public String toString() {
            return String.format(
                "EnterpriseCache{L1:%d, L1Hits:%d, L2Hits:%d, L3Hits:%d, Misses:%d, " +
                "HitRatio:%.2f%%, Redis:%s, Mongo:%s, SecurityOK:%s}",
                l1CacheSize, l1Hits, l2Hits, l3Hits, cacheMisses, 
                overallHitRatio * 100, redisAvailable, mongoAvailable,
                !securityStats.isSecurityCompromised()
            );
        }
    }
}