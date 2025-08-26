package com.whitestartups.auth.client;

import com.whitestartups.auth.cache.service.DistributedAuthCacheService;
import com.whitestartups.auth.core.model.User;
import jakarta.annotation.PostConstruct;
import jakarta.ejb.EJB;
import jakarta.enterprise.context.ApplicationScoped;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.naming.Context;
import javax.naming.InitialContext;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Client library for applications to authenticate users against the distributed cache.
 * Provides both synchronous and asynchronous authentication methods.
 */
@ApplicationScoped
public class AuthenticationClient {
    private static final Logger logger = LoggerFactory.getLogger(AuthenticationClient.class);
    
    @EJB
    private DistributedAuthCacheService authCacheService;
    
    private ExecutorService asyncExecutor;
    private boolean initialized = false;
    
    @PostConstruct
    public void initialize() {
        asyncExecutor = Executors.newFixedThreadPool(10);
        
        // Initialize EJB lookup if injection fails
        if (authCacheService == null) {
            initializeEJBLookup();
        }
        
        initialized = true;
        logger.info("Authentication Client initialized");
    }
    
    /**
     * Synchronous authentication - blocks until result is available
     */
    public AuthenticationResponse authenticate(String username, String password) {
        if (!initialized) {
            return new AuthenticationResponse(false, "Client not initialized", null, 0, false);
        }
        
        if (username == null || password == null || username.trim().isEmpty()) {
            return new AuthenticationResponse(false, "Invalid credentials", null, 0, false);
        }
        
        try {
            DistributedAuthCacheService.AuthenticationResult result = 
                authCacheService.authenticate(username, password);
            
            return new AuthenticationResponse(
                result.isSuccess(),
                result.getErrorMessage(),
                result.getUser(),
                result.getResponseTimeMs(),
                result.isCacheHit()
            );
            
        } catch (Exception e) {
            logger.error("Authentication failed for user: {}", username, e);
            return new AuthenticationResponse(false, "Authentication service error", null, 0, false);
        }
    }
    
    /**
     * Asynchronous authentication - returns CompletableFuture
     */
    public CompletableFuture<AuthenticationResponse> authenticateAsync(String username, String password) {
        return CompletableFuture.supplyAsync(() -> authenticate(username, password), asyncExecutor);
    }
    
    /**
     * Quick user lookup for session validation
     */
    public User getUserByUsername(String username) {
        if (!initialized || username == null || username.trim().isEmpty()) {
            return null;
        }
        
        try {
            return authCacheService.getUserByUsername(username);
        } catch (Exception e) {
            logger.error("Failed to lookup user: {}", username, e);
            return null;
        }
    }
    
    /**
     * Batch authentication for multiple users (useful for bulk operations)
     */
    public CompletableFuture<BatchAuthenticationResponse> authenticateBatch(
            BatchAuthenticationRequest request) {
        
        return CompletableFuture.supplyAsync(() -> {
            BatchAuthenticationResponse response = new BatchAuthenticationResponse();
            
            for (BatchAuthenticationRequest.Credential credential : request.getCredentials()) {
                AuthenticationResponse authResponse = authenticate(
                    credential.getUsername(), credential.getPassword());
                
                response.addResult(credential.getUsername(), authResponse);
            }
            
            return response;
        }, asyncExecutor);
    }
    
    /**
     * Validate user session (lightweight operation)
     */
    public boolean validateSession(String username, String sessionToken) {
        // In a real implementation, this would validate the session token
        // For now, just check if user exists
        User user = getUserByUsername(username);
        return user != null && user.getIsActive();
    }
    
    /**
     * Get authentication service statistics
     */
    public ServiceStatistics getServiceStatistics() {
        try {
            DistributedAuthCacheService.CacheStatistics cacheStats = 
                authCacheService.getCacheStatistics();
            
            return new ServiceStatistics(
                cacheStats.getCacheSize(),
                cacheStats.getCacheHits(),
                cacheStats.getCacheMisses(),
                cacheStats.getHitRatio(),
                initialized
            );
            
        } catch (Exception e) {
            logger.error("Failed to get service statistics", e);
            return new ServiceStatistics(0, 0, 0, 0.0, false);
        }
    }
    
    /**
     * Initialize EJB lookup manually if injection fails
     */
    private void initializeEJBLookup() {
        try {
            Context context = new InitialContext();
            // Adjust JNDI name based on your application server
            authCacheService = (DistributedAuthCacheService) context.lookup(
                "java:global/distributed-auth-system/auth-cache/DistributedAuthCacheService"
            );
            
            logger.info("EJB lookup successful");
            
        } catch (Exception e) {
            logger.error("Failed to lookup authentication service EJB", e);
        }
    }
    
    /**
     * Cleanup resources
     */
    public void cleanup() {
        if (asyncExecutor != null && !asyncExecutor.isShutdown()) {
            asyncExecutor.shutdown();
        }
        initialized = false;
    }
    
    /**
     * Authentication response wrapper
     */
    public static class AuthenticationResponse {
        private final boolean success;
        private final String message;
        private final User user;
        private final long responseTimeMs;
        private final boolean cacheHit;
        
        public AuthenticationResponse(boolean success, String message, User user, long responseTimeMs) {
            this(success, message, user, responseTimeMs, false);
        }
        
        public AuthenticationResponse(boolean success, String message, User user, long responseTimeMs, boolean cacheHit) {
            this.success = success;
            this.message = message;
            this.user = user;
            this.responseTimeMs = responseTimeMs;
            this.cacheHit = cacheHit;
        }
        
        public boolean isSuccess() { return success; }
        public String getMessage() { return message; }
        public User getUser() { return user; }
        public long getResponseTimeMs() { return responseTimeMs; }
        public boolean isCacheHit() { return cacheHit; }
    }
    
    /**
     * Service statistics
     */
    public static class ServiceStatistics {
        private final int cacheSize;
        private final long cacheHits;
        private final long cacheMisses;
        private final double hitRatio;
        private final boolean serviceAvailable;
        
        public ServiceStatistics(int cacheSize, long cacheHits, long cacheMisses, 
                               double hitRatio, boolean serviceAvailable) {
            this.cacheSize = cacheSize;
            this.cacheHits = cacheHits;
            this.cacheMisses = cacheMisses;
            this.hitRatio = hitRatio;
            this.serviceAvailable = serviceAvailable;
        }
        
        public int getCacheSize() { return cacheSize; }
        public long getCacheHits() { return cacheHits; }
        public long getCacheMisses() { return cacheMisses; }
        public double getHitRatio() { return hitRatio; }
        public boolean isServiceAvailable() { return serviceAvailable; }
    }
}