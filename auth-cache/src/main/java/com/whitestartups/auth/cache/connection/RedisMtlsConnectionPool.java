package com.whitestartups.auth.cache.connection;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import redis.clients.jedis.*;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocketFactory;
import java.net.URI;

/**
 * Redis mTLS Connection Pool Manager
 * Provides secure mTLS connections to Redis with connection pooling
 */
@ApplicationScoped
public class RedisMtlsConnectionPool extends MtlsConnectionPoolManager {
    
    private static final Logger logger = LoggerFactory.getLogger(RedisMtlsConnectionPool.class);
    
    private JedisPool jedisPool;
    private String redisHost;
    private int redisPort;
    private String redisPassword;
    private boolean useTls;
    
    // Connection pool settings
    private static final int MAX_TOTAL_CONNECTIONS = 50;
    private static final int MAX_IDLE_CONNECTIONS = 20;
    private static final int MIN_IDLE_CONNECTIONS = 5;
    private static final int MAX_WAIT_MILLIS = 3000;
    private static final int CONNECTION_TIMEOUT_MS = 5000;
    private static final int SOCKET_TIMEOUT_MS = 10000;
    
    public RedisMtlsConnectionPool() {
        super("REDIS");
    }
    
    @PostConstruct
    @Override
    public void initialize() throws Exception {
        logger.info("Initializing Redis mTLS Connection Pool...");
        
        // Initialize mTLS configuration
        initializeMtlsConfig();
        
        // Parse Redis connection details
        parseRedisConfiguration();
        
        // Validate certificates exist (for mTLS)
        boolean mtlsAvailable = validateCertificates();
        if (!mtlsAvailable) {
            logger.warn("mTLS certificates not found, falling back to basic TLS");
        }
        
        try {
            // Configure Jedis pool with mTLS
            JedisPoolConfig poolConfig = createPoolConfig();
            
            if (useTls && mtlsAvailable) {
                // Create mTLS SSL context
                SSLContext sslContext = createMtlsSslContext();
                SSLSocketFactory sslSocketFactory = sslContext.getSocketFactory();
                
                // Create Jedis pool with mTLS
                jedisPool = new JedisPool(
                    poolConfig,
                    redisHost,
                    redisPort,
                    CONNECTION_TIMEOUT_MS,
                    redisPassword,
                    true,  // SSL
                    sslSocketFactory,
                    null,  // SSL parameters
                    null   // hostname verifier
                );
                
                logger.info("Redis mTLS Connection Pool created with mutual TLS");
                
            } else if (useTls) {
                // Basic TLS without client certificates
                jedisPool = new JedisPool(
                    poolConfig,
                    redisHost,
                    redisPort,
                    CONNECTION_TIMEOUT_MS,
                    redisPassword,
                    true  // SSL
                );
                
                logger.info("Redis Connection Pool created with basic TLS");
                
            } else {
                // No TLS
                jedisPool = new JedisPool(
                    poolConfig,
                    redisHost,
                    redisPort,
                    CONNECTION_TIMEOUT_MS,
                    redisPassword
                );
                
                logger.warn("Redis Connection Pool created WITHOUT TLS - not recommended for production");
            }
            
            // Test connection
            if (performHealthCheck()) {
                isHealthy.set(true);
                logger.info("Redis mTLS Connection Pool initialized successfully");
                logger.info("Pool: max={}, maxIdle={}, minIdle={}, host={}:{}, TLS={}",
                          MAX_TOTAL_CONNECTIONS, MAX_IDLE_CONNECTIONS, MIN_IDLE_CONNECTIONS,
                          redisHost, redisPort, useTls);
            } else {
                throw new Exception("Redis health check failed");
            }
            
        } catch (Exception e) {
            connectionFailures.incrementAndGet();
            logger.error("Failed to initialize Redis mTLS connection pool", e);
            throw e;
        }
    }
    
    private void parseRedisConfiguration() {
        String redisUrl = System.getProperty("redis.url", System.getenv("REDIS_URL"));
        
        if (redisUrl == null) {
            // Default production configuration with TLS
            redisHost = "localhost";
            redisPort = 6380; // TLS port
            useTls = true;
            redisPassword = System.getProperty("redis.password", "RedisPass2024!");
        } else {
            try {
                URI uri = URI.create(redisUrl);
                redisHost = uri.getHost();
                redisPort = uri.getPort();
                useTls = "rediss".equals(uri.getScheme());
                
                // Extract password from URI if present
                String userInfo = uri.getUserInfo();
                if (userInfo != null && userInfo.contains(":")) {
                    redisPassword = userInfo.split(":")[1];
                } else {
                    redisPassword = System.getProperty("redis.password");
                }
                
            } catch (Exception e) {
                logger.error("Invalid Redis URL: {}, using defaults", redisUrl);
                redisHost = "localhost";
                redisPort = useTls ? 6380 : 6379;
                redisPassword = System.getProperty("redis.password");
            }
        }
        
        logger.info("Redis configuration - host: {}, port: {}, TLS: {}", 
                   redisHost, redisPort, useTls);
    }
    
    private JedisPoolConfig createPoolConfig() {
        JedisPoolConfig poolConfig = new JedisPoolConfig();
        
        // Connection pool sizing
        poolConfig.setMaxTotal(MAX_TOTAL_CONNECTIONS);
        poolConfig.setMaxIdle(MAX_IDLE_CONNECTIONS);
        poolConfig.setMinIdle(MIN_IDLE_CONNECTIONS);
        poolConfig.setMaxWaitMillis(MAX_WAIT_MILLIS);
        
        // Connection validation
        poolConfig.setTestOnBorrow(true);
        poolConfig.setTestOnReturn(true);
        poolConfig.setTestWhileIdle(true);
        poolConfig.setMinEvictableIdleTimeMillis(60000); // 1 minute
        poolConfig.setTimeBetweenEvictionRunsMillis(30000); // 30 seconds
        poolConfig.setNumTestsPerEvictionRun(3);
        
        // Blocking behavior
        poolConfig.setBlockWhenExhausted(true);
        
        return poolConfig;
    }
    
    @Override
    public boolean performHealthCheck() {
        if (jedisPool == null) {
            return false;
        }
        
        try (Jedis jedis = jedisPool.getResource()) {
            String response = jedis.ping();
            lastHealthCheck.set(System.currentTimeMillis());
            
            boolean healthy = "PONG".equals(response);
            if (healthy) {
                logger.debug("Redis health check passed");
            } else {
                logger.warn("Redis health check failed - unexpected response: {}", response);
            }
            
            return healthy;
            
        } catch (Exception e) {
            logger.warn("Redis health check failed: {}", e.getMessage());
            isHealthy.set(false);
            return false;
        }
    }
    
    /**
     * Get Redis connection from pool
     */
    public Jedis getResource() {
        if (!isHealthy.get()) {
            logger.warn("Redis connection pool is unhealthy, attempting to reconnect...");
            try {
                initialize();
            } catch (Exception e) {
                logger.error("Failed to reconnect to Redis", e);
            }
        }
        
        if (jedisPool != null) {
            return jedisPool.getResource();
        } else {
            throw new RuntimeException("Redis connection pool is not available");
        }
    }
    
    /**
     * Execute Redis command with automatic resource management
     */
    public <T> T executeWithResource(JedisFunction<T> function) throws Exception {
        try (Jedis jedis = getResource()) {
            return function.apply(jedis);
        }
    }
    
    /**
     * Execute Redis command without return value
     */
    public void executeWithResource(JedisConsumer consumer) throws Exception {
        try (Jedis jedis = getResource()) {
            consumer.accept(jedis);
        }
    }
    
    @PreDestroy
    @Override
    public void cleanup() {
        logger.info("Cleaning up Redis mTLS Connection Pool...");
        
        if (jedisPool != null) {
            try {
                jedisPool.close();
                logger.info("Redis connection pool closed successfully");
            } catch (Exception e) {
                logger.error("Error closing Redis connection pool", e);
            } finally {
                jedisPool = null;
                isHealthy.set(false);
            }
        }
    }
    
    /**
     * Get detailed Redis pool metrics
     */
    public RedisPoolMetrics getDetailedMetrics() {
        JedisPool pool = jedisPool;
        if (pool == null) {
            return new RedisPoolMetrics(serviceName, false, 0, 0, 0, 0, 0, 0, redisHost, redisPort, useTls);
        }
        
        return new RedisPoolMetrics(
            serviceName,
            isHealthy.get(),
            connectionAttempts.get(),
            connectionFailures.get(),
            pool.getNumActive(),
            pool.getNumIdle(),
            pool.getNumWaiters(),
            MAX_TOTAL_CONNECTIONS,
            redisHost,
            redisPort,
            useTls
        );
    }
    
    /**
     * Functional interface for Redis operations
     */
    @FunctionalInterface
    public interface JedisFunction<T> {
        T apply(Jedis jedis) throws Exception;
    }
    
    /**
     * Functional interface for Redis operations without return value
     */
    @FunctionalInterface
    public interface JedisConsumer {
        void accept(Jedis jedis) throws Exception;
    }
    
    /**
     * Redis-specific pool metrics
     */
    public static class RedisPoolMetrics {
        private final String serviceName;
        private final boolean healthy;
        private final long connectionAttempts;
        private final long connectionFailures;
        private final int activeConnections;
        private final int idleConnections;
        private final int waitingThreads;
        private final int maxConnections;
        private final String host;
        private final int port;
        private final boolean tlsEnabled;
        
        public RedisPoolMetrics(String serviceName, boolean healthy, long connectionAttempts,
                              long connectionFailures, int activeConnections, int idleConnections,
                              int waitingThreads, int maxConnections, String host, int port,
                              boolean tlsEnabled) {
            this.serviceName = serviceName;
            this.healthy = healthy;
            this.connectionAttempts = connectionAttempts;
            this.connectionFailures = connectionFailures;
            this.activeConnections = activeConnections;
            this.idleConnections = idleConnections;
            this.waitingThreads = waitingThreads;
            this.maxConnections = maxConnections;
            this.host = host;
            this.port = port;
            this.tlsEnabled = tlsEnabled;
        }
        
        // Getters
        public String getServiceName() { return serviceName; }
        public boolean isHealthy() { return healthy; }
        public long getConnectionAttempts() { return connectionAttempts; }
        public long getConnectionFailures() { return connectionFailures; }
        public int getActiveConnections() { return activeConnections; }
        public int getIdleConnections() { return idleConnections; }
        public int getWaitingThreads() { return waitingThreads; }
        public int getMaxConnections() { return maxConnections; }
        public String getHost() { return host; }
        public int getPort() { return port; }
        public boolean isTlsEnabled() { return tlsEnabled; }
        
        public double getPoolUtilization() {
            return maxConnections > 0 ? (double) activeConnections / maxConnections : 0.0;
        }
        
        @Override
        public String toString() {
            return String.format("RedisPool{%s:%d, healthy:%s, active:%d/%d (%.1f%%), idle:%d, waiting:%d, TLS:%s}",
                               host, port, healthy, activeConnections, maxConnections,
                               getPoolUtilization() * 100, idleConnections, waitingThreads, tlsEnabled);
        }
    }
}