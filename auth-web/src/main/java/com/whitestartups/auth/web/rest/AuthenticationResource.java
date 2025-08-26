package com.whitestartups.auth.web.rest;

import com.whitestartups.auth.client.AuthenticationClient;
import com.whitestartups.auth.client.BatchAuthenticationRequest;
import com.whitestartups.auth.client.BatchAuthenticationResponse;
import com.whitestartups.auth.core.model.User;
import jakarta.enterprise.context.RequestScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

/**
 * REST API endpoints for authentication services.
 * Provides HTTP interface to the distributed authentication system.
 */
@Path("/auth")
@RequestScoped
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class AuthenticationResource {
    private static final Logger logger = LoggerFactory.getLogger(AuthenticationResource.class);
    
    @Inject
    private AuthenticationClient authClient;
    
    /**
     * Authenticate a single user
     * POST /auth/authenticate
     */
    @POST
    @Path("/authenticate")
    public Response authenticate(AuthenticationRequest request) {
        logger.debug("Authentication request for user: {}", request.getUsername());
        
        if (request.getUsername() == null || request.getPassword() == null) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse("Username and password are required"))
                    .build();
        }
        
        try {
            AuthenticationClient.AuthenticationResponse authResponse = 
                authClient.authenticate(request.getUsername(), request.getPassword());
            
            if (authResponse.isSuccess()) {
                AuthenticationSuccessResponse response = new AuthenticationSuccessResponse(
                    authResponse.getUser(),
                    authResponse.getResponseTimeMs(),
                    authResponse.isCacheHit()
                );
                
                return Response.ok(response).build();
            } else {
                return Response.status(Response.Status.UNAUTHORIZED)
                        .entity(new ErrorResponse(authResponse.getMessage()))
                        .build();
            }
            
        } catch (Exception e) {
            logger.error("Authentication error", e);
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(new ErrorResponse("Authentication service error"))
                    .build();
        }
    }
    
    /**
     * Asynchronous authentication
     * POST /auth/authenticate/async
     */
    @POST
    @Path("/authenticate/async")
    public Response authenticateAsync(AuthenticationRequest request) {
        logger.debug("Async authentication request for user: {}", request.getUsername());
        
        if (request.getUsername() == null || request.getPassword() == null) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse("Username and password are required"))
                    .build();
        }
        
        try {
            // Start async authentication
            CompletableFuture<AuthenticationClient.AuthenticationResponse> future = 
                authClient.authenticateAsync(request.getUsername(), request.getPassword());
            
            // For REST API, we'll return a tracking ID and the client can poll for results
            String trackingId = java.util.UUID.randomUUID().toString();
            
            // In a real implementation, you'd store the future with the tracking ID
            // For demo purposes, we'll just return the tracking ID
            
            Map<String, Object> response = new HashMap<>();
            response.put("trackingId", trackingId);
            response.put("status", "PROCESSING");
            response.put("message", "Authentication request accepted");
            
            return Response.accepted(response).build();
            
        } catch (Exception e) {
            logger.error("Async authentication error", e);
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(new ErrorResponse("Authentication service error"))
                    .build();
        }
    }
    
    /**
     * Batch authentication for multiple users
     * POST /auth/authenticate/batch
     */
    @POST
    @Path("/authenticate/batch")
    public Response authenticateBatch(BatchAuthenticationRequest request) {
        logger.debug("Batch authentication request for {} users", 
                   request.getCredentials().size());
        
        if (request.getCredentials().isEmpty()) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse("At least one credential is required"))
                    .build();
        }
        
        try {
            CompletableFuture<BatchAuthenticationResponse> future = 
                authClient.authenticateBatch(request);
            
            // For demonstration, we'll wait for the result
            // In production, you might return immediately with a tracking ID
            BatchAuthenticationResponse batchResponse = future.get();
            
            return Response.ok(batchResponse).build();
            
        } catch (Exception e) {
            logger.error("Batch authentication error", e);
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(new ErrorResponse("Batch authentication service error"))
                    .build();
        }
    }
    
    /**
     * Get user by username
     * GET /auth/users/{username}
     */
    @GET
    @Path("/users/{username}")
    public Response getUser(@PathParam("username") String username) {
        logger.debug("User lookup request for: {}", username);
        
        try {
            User user = authClient.getUserByUsername(username);
            
            if (user != null) {
                return Response.ok(new UserResponse(user)).build();
            } else {
                return Response.status(Response.Status.NOT_FOUND)
                        .entity(new ErrorResponse("User not found"))
                        .build();
            }
            
        } catch (Exception e) {
            logger.error("User lookup error", e);
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(new ErrorResponse("User lookup service error"))
                    .build();
        }
    }
    
    /**
     * Validate user session
     * POST /auth/validate
     */
    @POST
    @Path("/validate")
    public Response validateSession(SessionValidationRequest request) {
        logger.debug("Session validation request for user: {}", request.getUsername());
        
        try {
            boolean isValid = authClient.validateSession(
                request.getUsername(), request.getSessionToken());
            
            if (isValid) {
                return Response.ok(new SessionValidationResponse(true, "Valid session")).build();
            } else {
                return Response.status(Response.Status.UNAUTHORIZED)
                        .entity(new SessionValidationResponse(false, "Invalid session"))
                        .build();
            }
            
        } catch (Exception e) {
            logger.error("Session validation error", e);
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(new ErrorResponse("Session validation service error"))
                    .build();
        }
    }
    
    /**
     * Get service health and statistics
     * GET /auth/stats
     */
    @GET
    @Path("/stats")
    public Response getServiceStats() {
        try {
            AuthenticationClient.ServiceStatistics stats = authClient.getServiceStatistics();
            return Response.ok(stats).build();
            
        } catch (Exception e) {
            logger.error("Statistics error", e);
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(new ErrorResponse("Statistics service error"))
                    .build();
        }
    }
    
    /**
     * Health check endpoint
     * GET /auth/health
     */
    @GET
    @Path("/health")
    public Response healthCheck() {
        try {
            AuthenticationClient.ServiceStatistics stats = authClient.getServiceStatistics();
            
            Map<String, Object> health = new HashMap<>();
            health.put("status", stats.isServiceAvailable() ? "UP" : "DOWN");
            health.put("cacheSize", stats.getCacheSize());
            health.put("hitRatio", stats.getHitRatio());
            health.put("timestamp", System.currentTimeMillis());
            
            if (stats.isServiceAvailable()) {
                return Response.ok(health).build();
            } else {
                return Response.status(Response.Status.SERVICE_UNAVAILABLE)
                        .entity(health)
                        .build();
            }
            
        } catch (Exception e) {
            logger.error("Health check error", e);
            Map<String, Object> health = new HashMap<>();
            health.put("status", "DOWN");
            health.put("error", e.getMessage());
            health.put("timestamp", System.currentTimeMillis());
            
            return Response.status(Response.Status.SERVICE_UNAVAILABLE)
                    .entity(health)
                    .build();
        }
    }
}