package com.whitestartups.auth.core.connection;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.naming.Context;
import javax.naming.NamingException;
import javax.naming.directory.DirContext;
import javax.naming.directory.InitialDirContext;
import javax.naming.ldap.InitialLdapContext;
import javax.naming.ldap.LdapContext;
import javax.net.ssl.SSLContext;
import java.util.Hashtable;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * LDAP mTLS Connection Pool Manager
 * Provides secure mTLS connections to LDAP with connection pooling
 */
@ApplicationScoped
public class LdapMtlsConnectionPool extends MtlsConnectionPoolManager {
    
    private static final Logger logger = LoggerFactory.getLogger(LdapMtlsConnectionPool.class);
    
    private BlockingQueue<LdapConnection> connectionPool;
    private String ldapUrl;
    private String bindDn;
    private String bindPassword;
    private String baseDn;
    private boolean useTls;
    
    // Connection pool settings
    private static final int MIN_POOL_SIZE = 5;
    private static final int MAX_POOL_SIZE = 20;
    private static final int CONNECTION_TIMEOUT_MS = 5000;
    private static final int READ_TIMEOUT_MS = 10000;
    private static final long CONNECTION_BORROW_TIMEOUT_MS = 3000;
    
    // Active connections tracking
    private final AtomicInteger activeConnections = new AtomicInteger(0);
    private final AtomicInteger borrowedConnections = new AtomicInteger(0);
    
    public LdapMtlsConnectionPool() {
        super("LDAP");
    }
    
    @PostConstruct
    @Override
    public void initialize() throws Exception {
        logger.info("Initializing LDAP mTLS Connection Pool...");
        
        // Initialize mTLS configuration
        initializeMtlsConfig();
        
        // Parse LDAP configuration
        parseLdapConfiguration();
        
        // Validate certificates exist (for mTLS)
        boolean mtlsAvailable = validateCertificates();
        if (!mtlsAvailable) {
            logger.warn("mTLS certificates not found, falling back to basic TLS or StartTLS");
        }
        
        // Initialize connection pool
        connectionPool = new LinkedBlockingQueue<>(MAX_POOL_SIZE);
        
        try {
            // Configure SSL context for mTLS
            if (useTls && mtlsAvailable) {
                SSLContext sslContext = createMtlsSslContext();
                System.setProperty("java.naming.ldap.factory.socket", 
                    "com.whitestartups.auth.core.connection.LdapMtlsSocketFactory");
                LdapMtlsSocketFactory.setSslContext(sslContext);
            }
            
            // Create initial connections
            for (int i = 0; i < MIN_POOL_SIZE; i++) {
                LdapConnection connection = createNewConnection();
                if (connection != null) {
                    connectionPool.offer(connection);
                    activeConnections.incrementAndGet();
                }
            }
            
            // Test connection
            if (performHealthCheck()) {
                isHealthy.set(true);
                logger.info("LDAP mTLS Connection Pool initialized successfully");
                logger.info("Pool: min={}, max={}, active={}, URL={}, TLS={}",
                          MIN_POOL_SIZE, MAX_POOL_SIZE, activeConnections.get(), 
                          sanitizeLdapUrl(ldapUrl), useTls);
            } else {
                throw new Exception("LDAP health check failed");
            }
            
        } catch (Exception e) {
            connectionFailures.incrementAndGet();
            logger.error("Failed to initialize LDAP mTLS connection pool", e);
            throw e;
        }
    }
    
    private void parseLdapConfiguration() {
        ldapUrl = System.getProperty("ldap.url", System.getenv("LDAP_URL"));
        if (ldapUrl == null) {
            // Default production configuration with TLS
            ldapUrl = "ldaps://localhost:636";
            useTls = true;
        } else {
            useTls = ldapUrl.startsWith("ldaps://");
        }
        
        bindDn = System.getProperty("ldap.bind.dn", 
            System.getenv("LDAP_BIND_DN"));
        if (bindDn == null) {
            bindDn = "cn=admin,dc=whitestartups,dc=com";
        }
        
        bindPassword = System.getProperty("ldap.bind.password",
            System.getenv("LDAP_BIND_PASSWORD"));
        if (bindPassword == null) {
            bindPassword = "LdapAdmin2024!";
        }
        
        baseDn = System.getProperty("ldap.base.dn",
            System.getenv("LDAP_BASE_DN"));
        if (baseDn == null) {
            baseDn = "ou=users,dc=whitestartups,dc=com";
        }
        
        logger.info("LDAP configuration - URL: {}, baseDN: {}, TLS: {}", 
                   sanitizeLdapUrl(ldapUrl), baseDn, useTls);
    }
    
    private String sanitizeLdapUrl(String url) {
        // Remove password from URL for logging
        return url != null ? url.replaceAll("://[^:]*:[^@]*@", "://***:***@") : "null";
    }
    
    private LdapConnection createNewConnection() {
        try {
            Hashtable<String, String> env = new Hashtable<>();
            env.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
            env.put(Context.PROVIDER_URL, ldapUrl);
            env.put(Context.SECURITY_AUTHENTICATION, "simple");
            env.put(Context.SECURITY_PRINCIPAL, bindDn);
            env.put(Context.SECURITY_CREDENTIALS, bindPassword);
            
            // Connection timeouts
            env.put("com.sun.jndi.ldap.connect.timeout", String.valueOf(CONNECTION_TIMEOUT_MS));
            env.put("com.sun.jndi.ldap.read.timeout", String.valueOf(READ_TIMEOUT_MS));
            
            // SSL/TLS settings
            if (useTls) {
                env.put(Context.SECURITY_PROTOCOL, "ssl");
                env.put("java.naming.ldap.factory.socket", 
                    "com.whitestartups.auth.core.connection.LdapMtlsSocketFactory");
            }
            
            // Connection pooling
            env.put("com.sun.jndi.ldap.connect.pool", "true");
            env.put("com.sun.jndi.ldap.connect.pool.timeout", "300000"); // 5 minutes
            
            LdapContext context = new InitialLdapContext(env, null);
            return new LdapConnection(context);
            
        } catch (Exception e) {
            logger.error("Failed to create LDAP connection", e);
            connectionFailures.incrementAndGet();
            return null;
        }
    }
    
    @Override
    public boolean performHealthCheck() {
        LdapConnection connection = null;
        try {
            connection = borrowConnection();
            if (connection != null && connection.isValid()) {
                // Perform simple search to test connection
                connection.getContext().search(baseDn, "(objectClass=*)", 
                    new javax.naming.directory.SearchControls() {{
                        setCountLimit(1);
                        setTimeLimit(5000);
                    }});
                
                lastHealthCheck.set(System.currentTimeMillis());
                logger.debug("LDAP health check passed");
                return true;
            }
            
        } catch (Exception e) {
            logger.warn("LDAP health check failed: {}", e.getMessage());
            isHealthy.set(false);
            return false;
        } finally {
            if (connection != null) {
                returnConnection(connection);
            }
        }
        
        return false;
    }
    
    /**
     * Borrow connection from pool
     */
    public LdapConnection borrowConnection() throws InterruptedException {
        if (!isHealthy.get()) {
            logger.warn("LDAP connection pool is unhealthy, attempting to reconnect...");
            try {
                initialize();
            } catch (Exception e) {
                logger.error("Failed to reconnect to LDAP", e);
            }
        }
        
        LdapConnection connection = connectionPool.poll(CONNECTION_BORROW_TIMEOUT_MS, TimeUnit.MILLISECONDS);
        
        if (connection == null) {
            // Try to create new connection if pool not at max capacity
            if (activeConnections.get() < MAX_POOL_SIZE) {
                connection = createNewConnection();
                if (connection != null) {
                    activeConnections.incrementAndGet();
                }
            }
        }
        
        if (connection != null) {
            borrowedConnections.incrementAndGet();
            
            // Validate connection before returning
            if (!connection.isValid()) {
                logger.debug("Replacing invalid LDAP connection");
                connection.close();
                activeConnections.decrementAndGet();
                borrowedConnections.decrementAndGet();
                
                // Create replacement
                connection = createNewConnection();
                if (connection != null) {
                    activeConnections.incrementAndGet();
                    borrowedConnections.incrementAndGet();
                }
            }
        }
        
        return connection;
    }
    
    /**
     * Return connection to pool
     */
    public void returnConnection(LdapConnection connection) {
        if (connection != null) {
            borrowedConnections.decrementAndGet();
            
            if (connection.isValid() && connectionPool.size() < MAX_POOL_SIZE) {
                // Return to pool
                connectionPool.offer(connection);
            } else {
                // Close excess or invalid connections
                connection.close();
                activeConnections.decrementAndGet();
            }
        }
    }
    
    /**
     * Execute LDAP operation with automatic connection management
     */
    public <T> T executeWithConnection(LdapFunction<T> function) throws Exception {
        LdapConnection connection = null;
        try {
            connection = borrowConnection();
            if (connection == null) {
                throw new RuntimeException("Unable to obtain LDAP connection");
            }
            return function.apply(connection);
        } finally {
            if (connection != null) {
                returnConnection(connection);
            }
        }
    }
    
    /**
     * Execute LDAP operation without return value
     */
    public void executeWithConnection(LdapConsumer consumer) throws Exception {
        LdapConnection connection = null;
        try {
            connection = borrowConnection();
            if (connection == null) {
                throw new RuntimeException("Unable to obtain LDAP connection");
            }
            consumer.accept(connection);
        } finally {
            if (connection != null) {
                returnConnection(connection);
            }
        }
    }
    
    @PreDestroy
    @Override
    public void cleanup() {
        logger.info("Cleaning up LDAP mTLS Connection Pool...");
        
        if (connectionPool != null) {
            try {
                // Close all connections in pool
                LdapConnection connection;
                while ((connection = connectionPool.poll()) != null) {
                    connection.close();
                }
                
                logger.info("LDAP connection pool closed successfully");
            } catch (Exception e) {
                logger.error("Error closing LDAP connection pool", e);
            } finally {
                connectionPool = null;
                activeConnections.set(0);
                borrowedConnections.set(0);
                isHealthy.set(false);
            }
        }
    }
    
    /**
     * Get detailed LDAP pool metrics
     */
    public LdapPoolMetrics getDetailedMetrics() {
        return new LdapPoolMetrics(
            serviceName,
            isHealthy.get(),
            connectionAttempts.get(),
            connectionFailures.get(),
            activeConnections.get(),
            borrowedConnections.get(),
            connectionPool != null ? connectionPool.size() : 0,
            MAX_POOL_SIZE,
            sanitizeLdapUrl(ldapUrl),
            baseDn,
            useTls
        );
    }
    
    // Getter methods
    public String getBaseDn() { return baseDn; }
    public String getLdapUrl() { return sanitizeLdapUrl(ldapUrl); }
    public boolean isUseTls() { return useTls; }
    
    /**
     * LDAP Connection wrapper
     */
    public static class LdapConnection {
        private final LdapContext context;
        private volatile boolean valid = true;
        
        public LdapConnection(LdapContext context) {
            this.context = context;
        }
        
        public LdapContext getContext() {
            return context;
        }
        
        public boolean isValid() {
            if (!valid || context == null) {
                return false;
            }
            
            try {
                // Test connection with a simple operation
                context.getEnvironment();
                return true;
            } catch (NamingException e) {
                valid = false;
                return false;
            }
        }
        
        public void close() {
            valid = false;
            if (context != null) {
                try {
                    context.close();
                } catch (NamingException e) {
                    // Ignore close exceptions
                }
            }
        }
    }
    
    /**
     * Functional interface for LDAP operations
     */
    @FunctionalInterface
    public interface LdapFunction<T> {
        T apply(LdapConnection connection) throws Exception;
    }
    
    /**
     * Functional interface for LDAP operations without return value
     */
    @FunctionalInterface
    public interface LdapConsumer {
        void accept(LdapConnection connection) throws Exception;
    }
    
    /**
     * LDAP-specific pool metrics
     */
    public static class LdapPoolMetrics {
        private final String serviceName;
        private final boolean healthy;
        private final long connectionAttempts;
        private final long connectionFailures;
        private final int activeConnections;
        private final int borrowedConnections;
        private final int availableConnections;
        private final int maxConnections;
        private final String ldapUrl;
        private final String baseDn;
        private final boolean tlsEnabled;
        
        public LdapPoolMetrics(String serviceName, boolean healthy, long connectionAttempts,
                             long connectionFailures, int activeConnections, int borrowedConnections,
                             int availableConnections, int maxConnections, String ldapUrl,
                             String baseDn, boolean tlsEnabled) {
            this.serviceName = serviceName;
            this.healthy = healthy;
            this.connectionAttempts = connectionAttempts;
            this.connectionFailures = connectionFailures;
            this.activeConnections = activeConnections;
            this.borrowedConnections = borrowedConnections;
            this.availableConnections = availableConnections;
            this.maxConnections = maxConnections;
            this.ldapUrl = ldapUrl;
            this.baseDn = baseDn;
            this.tlsEnabled = tlsEnabled;
        }
        
        // Getters
        public String getServiceName() { return serviceName; }
        public boolean isHealthy() { return healthy; }
        public long getConnectionAttempts() { return connectionAttempts; }
        public long getConnectionFailures() { return connectionFailures; }
        public int getActiveConnections() { return activeConnections; }
        public int getBorrowedConnections() { return borrowedConnections; }
        public int getAvailableConnections() { return availableConnections; }
        public int getMaxConnections() { return maxConnections; }
        public String getLdapUrl() { return ldapUrl; }
        public String getBaseDn() { return baseDn; }
        public boolean isTlsEnabled() { return tlsEnabled; }
        
        public double getPoolUtilization() {
            return maxConnections > 0 ? (double) borrowedConnections / maxConnections : 0.0;
        }
        
        @Override
        public String toString() {
            return String.format("LdapPool{%s, healthy:%s, active:%d, borrowed:%d/%d (%.1f%%), available:%d, TLS:%s}",
                               ldapUrl, healthy, activeConnections, borrowedConnections, maxConnections,
                               getPoolUtilization() * 100, availableConnections, tlsEnabled);
        }
    }
}