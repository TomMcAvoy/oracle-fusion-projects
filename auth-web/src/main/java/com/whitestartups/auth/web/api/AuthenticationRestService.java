package com.whitestartups.auth.web.api;

import com.whitestartups.auth.cache.service.DistributedAuthCacheService;
import com.whitestartups.auth.cache.service.DistributedAuthCacheService.AuthenticationResult;
import com.whitestartups.auth.cache.service.DistributedAuthCacheService.CacheStatistics;
import com.whitestartups.auth.core.model.User;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * REST API for authentication testing
 * Provides endpoints for frontend login page and load testing
 */
@Path("/auth")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class AuthenticationRestService {
    private static final Logger logger = LoggerFactory.getLogger(AuthenticationRestService.class);
    
    @Inject
    private DistributedAuthCacheService authCacheService;
    
    /**
     * Login endpoint for frontend
     */
    @POST
    @Path("/login")
    public Response login(LoginRequest request) {
        logger.debug("Login attempt for user: {}", request.getUsername());
        
        try {
            // Validate request
            if (request.getUsername() == null || request.getUsername().trim().isEmpty() ||
                request.getPassword() == null || request.getPassword().trim().isEmpty()) {
                
                return Response.status(Response.Status.BAD_REQUEST)
                    .entity(createErrorResponse("Username and password are required"))
                    .build();
            }
            
            // Authenticate using the cache service
            AuthenticationResult result = authCacheService.authenticate(
                request.getUsername().trim(), 
                request.getPassword()
            );
            
            if (result.isSuccess()) {
                // Success response with user info and performance metrics
                Map<String, Object> response = new HashMap<>();
                response.put("success", true);
                response.put("message", "Authentication successful");
                response.put("responseTimeMs", result.getResponseTimeMs());
                response.put("cacheHit", result.isCacheHit());
                response.put("user", createUserResponse(result.getUser()));
                
                logger.info("Successful authentication for user: {} ({}ms, cache: {})", 
                           request.getUsername(), result.getResponseTimeMs(), 
                           result.isCacheHit() ? "HIT" : "MISS");
                
                return Response.ok(response).build();
                
            } else {
                // Failed authentication
                Map<String, Object> response = new HashMap<>();
                response.put("success", false);
                response.put("message", "Invalid username or password");
                response.put("responseTimeMs", result.getResponseTimeMs());
                response.put("cacheHit", false);
                
                logger.warn("Failed authentication for user: {} ({}ms)", 
                           request.getUsername(), result.getResponseTimeMs());
                
                return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(response)
                    .build();
            }
            
        } catch (Exception e) {
            logger.error("Authentication error for user: " + request.getUsername(), e);
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(createErrorResponse("Internal server error during authentication"))
                .build();
        }
    }
    
    /**
     * Bulk authentication endpoint for load testing
     */
    @POST
    @Path("/bulk-login")
    public Response bulkLogin(BulkLoginRequest request) {
        logger.info("Bulk login request for {} users", request.getCredentials().size());
        
        long startTime = System.currentTimeMillis();
        int successCount = 0;
        int failureCount = 0;
        long totalAuthTime = 0;
        int cacheHits = 0;
        
        for (LoginRequest loginReq : request.getCredentials()) {
            try {
                AuthenticationResult result = authCacheService.authenticate(
                    loginReq.getUsername(), loginReq.getPassword());
                
                totalAuthTime += result.getResponseTimeMs();
                
                if (result.isSuccess()) {
                    successCount++;
                } else {
                    failureCount++;
                }
                
                if (result.isCacheHit()) {
                    cacheHits++;
                }
                
            } catch (Exception e) {
                failureCount++;
                logger.debug("Bulk auth error for user: {}", loginReq.getUsername(), e);
            }
        }
        
        long totalTime = System.currentTimeMillis() - startTime;
        
        Map<String, Object> response = new HashMap<>();
        response.put("totalRequests", request.getCredentials().size());
        response.put("successCount", successCount);
        response.put("failureCount", failureCount);
        response.put("totalTimeMs", totalTime);
        response.put("avgAuthTimeMs", totalAuthTime / request.getCredentials().size());
        response.put("requestsPerSecond", (request.getCredentials().size() * 1000.0) / totalTime);
        response.put("cacheHitRate", (double) cacheHits / request.getCredentials().size());
        
        logger.info("Bulk login completed: {} success, {} failed, {}ms total", 
                   successCount, failureCount, totalTime);
        
        return Response.ok(response).build();
    }
    
    /**
     * Get cache statistics
     */
    @GET
    @Path("/stats")
    public Response getStats() {
        try {
            CacheStatistics stats = authCacheService.getCacheStatistics();
            
            Map<String, Object> response = new HashMap<>();
            response.put("cacheSize", stats.getCacheSize());
            response.put("cacheHits", stats.getCacheHits());
            response.put("cacheMisses", stats.getCacheMisses());
            response.put("totalRequests", stats.getTotalRequests());
            response.put("hitRatio", stats.getHitRatio());
            response.put("timestamp", System.currentTimeMillis());
            
            return Response.ok(response).build();
            
        } catch (Exception e) {
            logger.error("Error getting cache statistics", e);
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity(createErrorResponse("Error retrieving statistics"))
                .build();
        }
    }
    
    /**
     * Generate test users for load testing
     */
    @GET
    @Path("/test-users/{count}")
    public Response generateTestUsers(@PathParam("count") int count) {
        if (count <= 0 || count > 1000) {
            return Response.status(Response.Status.BAD_REQUEST)
                .entity(createErrorResponse("Count must be between 1 and 1000"))
                .build();
        }
        
        Map<String, Object> response = new HashMap<>();
        response.put("testUsers", new java.util.ArrayList<>());
        
        for (int i = 0; i < count; i++) {
            Map<String, String> user = new HashMap<>();
            user.put("username", String.format("testuser%03d", i));
            user.put("password", String.format("TestPass%d!", i % 10));
            ((java.util.List<Map<String, String>>) response.get("testUsers")).add(user);
        }
        
        response.put("totalUsers", count);
        response.put("passwordPattern", "TestPass{lastDigit}!");
        
        return Response.ok(response).build();
    }
    
    /**
     * Health check endpoint
     */
    @GET
    @Path("/health")
    public Response health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "healthy");
        response.put("timestamp", System.currentTimeMillis());
        response.put("service", "Authentication REST API");
        
        return Response.ok(response).build();
    }
    
    // Helper methods
    
    private Map<String, Object> createErrorResponse(String message) {
        Map<String, Object> response = new HashMap<>();
        response.put("success", false);
        response.put("message", message);
        response.put("timestamp", System.currentTimeMillis());
        return response;
    }
    
    private Map<String, Object> createUserResponse(User user) {
        if (user == null) return null;
        
        Map<String, Object> userMap = new HashMap<>();
        userMap.put("username", user.getUsername());
        userMap.put("email", user.getEmail());
        userMap.put("displayName", user.getDisplayName());
        userMap.put("region", user.getRegion());
        userMap.put("department", user.getDepartment());
        userMap.put("title", user.getTitle());
        userMap.put("employeeId", user.getEmployeeId());
        userMap.put("isActive", user.getIsActive());
        
        return userMap;
    }
    
    // Request/Response DTOs
    
    public static class LoginRequest {
        private String username;
        private String password;
        
        // Constructors
        public LoginRequest() {}
        
        public LoginRequest(String username, String password) {
            this.username = username;
            this.password = password;
        }
        
        // Getters and setters
        public String getUsername() { return username; }
        public void setUsername(String username) { this.username = username; }
        
        public String getPassword() { return password; }
        public void setPassword(String password) { this.password = password; }
    }
    
    public static class BulkLoginRequest {
        private java.util.List<LoginRequest> credentials;
        
        public BulkLoginRequest() {}
        
        public java.util.List<LoginRequest> getCredentials() { return credentials; }
        public void setCredentials(java.util.List<LoginRequest> credentials) { this.credentials = credentials; }
    }
}