package com.whitestartups.auth.cache.connection;

import com.mongodb.ConnectionString;
import com.mongodb.MongoClientSettings;
import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoDatabase;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.net.ssl.SSLContext;
import java.util.concurrent.TimeUnit;

/**
 * MongoDB mTLS Connection Pool Manager
 * Provides secure mTLS connections to MongoDB with connection pooling
 */
@ApplicationScoped
public class MongoMtlsConnectionPool extends MtlsConnectionPoolManager {
    
    private static final Logger logger = LoggerFactory.getLogger(MongoMtlsConnectionPool.class);
    
    private MongoClient mongoClient;
    private MongoDatabase database;
    private String connectionString;
    private String databaseName;
    
    // Connection pool settings
    private static final int MIN_POOL_SIZE = 5;
    private static final int MAX_POOL_SIZE = 50;
    private static final int MAX_CONNECTION_IDLE_TIME_SEC = 30;
    private static final int MAX_CONNECTION_LIFETIME_SEC = 600;
    private static final int CONNECTION_TIMEOUT_MS = 5000;
    private static final int SOCKET_TIMEOUT_MS = 10000;
    
    public MongoMtlsConnectionPool() {
        super("MONGODB");
    }
    
    @PostConstruct
    @Override
    public void initialize() throws Exception {
        logger.info("Initializing MongoDB mTLS Connection Pool...");
        
        // Initialize mTLS configuration
        initializeMtlsConfig();
        
        // Get MongoDB connection details
        connectionString = System.getProperty("mongodb.url",
            System.getenv("MONGODB_URL"));
            
        if (connectionString == null) {
            // Production mTLS connection string
            connectionString = "mongodb://authcache:password@localhost:27017/authcache?ssl=true&authSource=admin";
        }
        
        databaseName = System.getProperty("mongodb.database", "authcache");
        
        // Validate certificates exist
        if (!validateCertificates()) {
            logger.warn("mTLS certificates not found, falling back to basic TLS");
        }
        
        try {
            // Create mTLS SSL context
            SSLContext sslContext = createMtlsSslContext();
            
            // Configure MongoDB client with mTLS
            MongoClientSettings.Builder settingsBuilder = MongoClientSettings.builder()
                .applyConnectionString(new ConnectionString(connectionString))
                .applyToSslSettings(builder -> {
                    builder.enabled(true);
                    builder.invalidHostNameAllowed(false);
                    builder.context(sslContext);
                })
                .applyToConnectionPoolSettings(builder -> {
                    builder.minSize(MIN_POOL_SIZE);
                    builder.maxSize(MAX_POOL_SIZE);
                    builder.maxConnectionIdleTime(MAX_CONNECTION_IDLE_TIME_SEC, TimeUnit.SECONDS);
                    builder.maxConnectionLifeTime(MAX_CONNECTION_LIFETIME_SEC, TimeUnit.SECONDS);
                })
                .applyToSocketSettings(builder -> {
                    builder.connectTimeout(CONNECTION_TIMEOUT_MS, TimeUnit.MILLISECONDS);
                    builder.readTimeout(SOCKET_TIMEOUT_MS, TimeUnit.MILLISECONDS);
                });
            
            mongoClient = MongoClients.create(settingsBuilder.build());
            database = mongoClient.getDatabase(databaseName);
            
            // Test connection
            if (performHealthCheck()) {
                isHealthy.set(true);
                logger.info("MongoDB mTLS Connection Pool initialized successfully");
                logger.info("Pool: min={}, max={}, database={}", MIN_POOL_SIZE, MAX_POOL_SIZE, databaseName);
            } else {
                throw new Exception("MongoDB health check failed");
            }
            
        } catch (Exception e) {
            connectionFailures.incrementAndGet();
            logger.error("Failed to initialize MongoDB mTLS connection pool", e);
            throw e;
        }
    }
    
    @Override
    public boolean performHealthCheck() {
        if (mongoClient == null || database == null) {
            return false;
        }
        
        try {
            // Perform ping operation
            database.runCommand(new org.bson.Document("ping", 1));
            lastHealthCheck.set(System.currentTimeMillis());
            
            logger.debug("MongoDB health check passed");
            return true;
            
        } catch (Exception e) {
            logger.warn("MongoDB health check failed: {}", e.getMessage());
            isHealthy.set(false);
            return false;
        }
    }
    
    /**
     * Get MongoDB client with mTLS connection
     */
    public MongoClient getClient() {
        if (!isHealthy.get()) {
            logger.warn("MongoDB connection pool is unhealthy, attempting to reconnect...");
            try {
                initialize();
            } catch (Exception e) {
                logger.error("Failed to reconnect to MongoDB", e);
            }
        }
        return mongoClient;
    }
    
    /**
     * Get MongoDB database with mTLS connection
     */
    public MongoDatabase getDatabase() {
        if (!isHealthy.get()) {
            logger.warn("MongoDB connection pool is unhealthy, attempting to reconnect...");
            try {
                initialize();
            } catch (Exception e) {
                logger.error("Failed to reconnect to MongoDB", e);
            }
        }
        return database;
    }
    
    /**
     * Get collection with mTLS connection
     */
    public com.mongodb.client.MongoCollection<org.bson.Document> getCollection(String collectionName) {
        MongoDatabase db = getDatabase();
        return db != null ? db.getCollection(collectionName) : null;
    }
    
    @PreDestroy
    @Override
    public void cleanup() {
        logger.info("Cleaning up MongoDB mTLS Connection Pool...");
        
        if (mongoClient != null) {
            try {
                mongoClient.close();
                logger.info("MongoDB client closed successfully");
            } catch (Exception e) {
                logger.error("Error closing MongoDB client", e);
            } finally {
                mongoClient = null;
                database = null;
                isHealthy.set(false);
            }
        }
    }
    
    /**
     * Get detailed connection pool metrics
     */
    public MongoPoolMetrics getDetailedMetrics() {
        // Note: MongoDB Java driver doesn't expose detailed pool metrics by default
        // This would require custom monitoring or JMX integration
        return new MongoPoolMetrics(
            serviceName,
            isHealthy.get(),
            connectionAttempts.get(),
            connectionFailures.get(),
            MIN_POOL_SIZE,
            MAX_POOL_SIZE,
            databaseName,
            connectionString.replaceAll("password=[^&]*", "password=***")
        );
    }
    
    /**
     * MongoDB-specific pool metrics
     */
    public static class MongoPoolMetrics {
        private final String serviceName;
        private final boolean healthy;
        private final long connectionAttempts;
        private final long connectionFailures;
        private final int minPoolSize;
        private final int maxPoolSize;
        private final String databaseName;
        private final String sanitizedConnectionString;
        
        public MongoPoolMetrics(String serviceName, boolean healthy, long connectionAttempts,
                              long connectionFailures, int minPoolSize, int maxPoolSize,
                              String databaseName, String sanitizedConnectionString) {
            this.serviceName = serviceName;
            this.healthy = healthy;
            this.connectionAttempts = connectionAttempts;
            this.connectionFailures = connectionFailures;
            this.minPoolSize = minPoolSize;
            this.maxPoolSize = maxPoolSize;
            this.databaseName = databaseName;
            this.sanitizedConnectionString = sanitizedConnectionString;
        }
        
        // Getters
        public String getServiceName() { return serviceName; }
        public boolean isHealthy() { return healthy; }
        public long getConnectionAttempts() { return connectionAttempts; }
        public long getConnectionFailures() { return connectionFailures; }
        public int getMinPoolSize() { return minPoolSize; }
        public int getMaxPoolSize() { return maxPoolSize; }
        public String getDatabaseName() { return databaseName; }
        public String getSanitizedConnectionString() { return sanitizedConnectionString; }
        
        @Override
        public String toString() {
            return String.format("MongoPool{db:%s, healthy:%s, pool:%d-%d, attempts:%d, failures:%d}",
                               databaseName, healthy, minPoolSize, maxPoolSize, 
                               connectionAttempts, connectionFailures);
        }
    }
}