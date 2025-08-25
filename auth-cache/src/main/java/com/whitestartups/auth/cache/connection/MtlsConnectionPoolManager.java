package com.whitestartups.auth.cache.connection;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManagerFactory;
import java.io.FileInputStream;
import java.security.KeyStore;
import java.security.SecureRandom;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Base class for mTLS connection pool managers
 * Provides common mTLS certificate handling and SSL context creation
 */
public abstract class MtlsConnectionPoolManager {
    
    private static final Logger logger = LoggerFactory.getLogger(MtlsConnectionPoolManager.class);
    
    // Connection health tracking
    protected final AtomicBoolean isHealthy = new AtomicBoolean(false);
    protected final AtomicLong connectionAttempts = new AtomicLong(0);
    protected final AtomicLong connectionFailures = new AtomicLong(0);
    protected final AtomicLong lastHealthCheck = new AtomicLong(0);
    
    // mTLS Configuration
    protected String keystorePath;
    protected String keystorePassword;
    protected String truststorePath; 
    protected String truststorePassword;
    protected String serviceName;
    
    protected MtlsConnectionPoolManager(String serviceName) {
        this.serviceName = serviceName;
    }
    
    /**
     * Initialize mTLS configuration from system properties
     */
    protected void initializeMtlsConfig() {
        String servicePrefix = serviceName.toLowerCase();
        
        this.keystorePath = System.getProperty(servicePrefix + ".keystore.path",
            "/Users/thomasmcavoy/GitHub/oracle-fusion-projects/certs/" + servicePrefix + "-client-keystore.p12");
            
        this.keystorePassword = System.getProperty(servicePrefix + ".keystore.password", 
            "ClientKey2024!");
            
        this.truststorePath = System.getProperty(servicePrefix + ".truststore.path",
            "/Users/thomasmcavoy/GitHub/oracle-fusion-projects/certs/" + servicePrefix + "-truststore.p12");
            
        this.truststorePassword = System.getProperty(servicePrefix + ".truststore.password",
            "TrustStore2024!");
            
        logger.info("mTLS configured for {} - keystore: {}, truststore: {}", 
                   serviceName, keystorePath, truststorePath);
    }
    
    /**
     * Create SSL context with mTLS certificates
     */
    protected SSLContext createMtlsSslContext() throws Exception {
        connectionAttempts.incrementAndGet();
        
        try {
            // Load client keystore (client certificate)
            KeyStore keyStore = KeyStore.getInstance("PKCS12");
            try (FileInputStream keystoreInput = new FileInputStream(keystorePath)) {
                keyStore.load(keystoreInput, keystorePassword.toCharArray());
            }
            
            KeyManagerFactory keyManagerFactory = KeyManagerFactory.getInstance(
                KeyManagerFactory.getDefaultAlgorithm());
            keyManagerFactory.init(keyStore, keystorePassword.toCharArray());
            
            // Load truststore (server certificate validation)
            KeyStore trustStore = KeyStore.getInstance("PKCS12");
            try (FileInputStream truststoreInput = new FileInputStream(truststorePath)) {
                trustStore.load(truststoreInput, truststorePassword.toCharArray());
            }
            
            TrustManagerFactory trustManagerFactory = TrustManagerFactory.getInstance(
                TrustManagerFactory.getDefaultAlgorithm());
            trustManagerFactory.init(trustStore);
            
            // Create SSL context with mutual TLS
            SSLContext sslContext = SSLContext.getInstance("TLSv1.3");
            sslContext.init(
                keyManagerFactory.getKeyManagers(),
                trustManagerFactory.getTrustManagers(),
                new SecureRandom()
            );
            
            logger.info("mTLS SSL context created successfully for {}", serviceName);
            return sslContext;
            
        } catch (Exception e) {
            connectionFailures.incrementAndGet();
            logger.error("Failed to create mTLS SSL context for {}: {}", serviceName, e.getMessage());
            throw e;
        }
    }
    
    /**
     * Validate certificate files exist
     */
    protected boolean validateCertificates() {
        java.io.File keystoreFile = new java.io.File(keystorePath);
        java.io.File truststoreFile = new java.io.File(truststorePath);
        
        if (!keystoreFile.exists()) {
            logger.error("Keystore not found: {}", keystorePath);
            return false;
        }
        
        if (!truststoreFile.exists()) {
            logger.error("Truststore not found: {}", truststorePath);
            return false;
        }
        
        logger.info("mTLS certificates validated for {} - keystore: {} ({}), truststore: {} ({})",
                   serviceName,
                   keystoreFile.getName(), keystoreFile.length() + " bytes",
                   truststoreFile.getName(), truststoreFile.length() + " bytes");
        
        return true;
    }
    
    /**
     * Perform health check on connection pool
     */
    public abstract boolean performHealthCheck();
    
    /**
     * Initialize the connection pool
     */
    public abstract void initialize() throws Exception;
    
    /**
     * Cleanup resources
     */
    public abstract void cleanup();
    
    /**
     * Get connection pool statistics
     */
    public ConnectionPoolStats getStats() {
        return new ConnectionPoolStats(
            serviceName,
            isHealthy.get(),
            connectionAttempts.get(),
            connectionFailures.get(),
            lastHealthCheck.get()
        );
    }
    
    /**
     * Connection pool statistics
     */
    public static class ConnectionPoolStats {
        private final String serviceName;
        private final boolean healthy;
        private final long connectionAttempts;
        private final long connectionFailures;
        private final long lastHealthCheck;
        
        public ConnectionPoolStats(String serviceName, boolean healthy, 
                                 long connectionAttempts, long connectionFailures,
                                 long lastHealthCheck) {
            this.serviceName = serviceName;
            this.healthy = healthy;
            this.connectionAttempts = connectionAttempts;
            this.connectionFailures = connectionFailures;
            this.lastHealthCheck = lastHealthCheck;
        }
        
        public String getServiceName() { return serviceName; }
        public boolean isHealthy() { return healthy; }
        public long getConnectionAttempts() { return connectionAttempts; }
        public long getConnectionFailures() { return connectionFailures; }
        public long getLastHealthCheck() { return lastHealthCheck; }
        public double getSuccessRate() {
            return connectionAttempts > 0 ? 
                (double)(connectionAttempts - connectionFailures) / connectionAttempts : 0.0;
        }
        
        @Override
        public String toString() {
            return String.format("%s{healthy:%s, attempts:%d, failures:%d, success:%.1f%%}",
                               serviceName, healthy, connectionAttempts, connectionFailures,
                               getSuccessRate() * 100);
        }
    }
}