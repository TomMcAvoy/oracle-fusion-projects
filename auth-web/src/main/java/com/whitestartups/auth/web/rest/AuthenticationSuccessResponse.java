package com.whitestartups.auth.web.rest;

import com.whitestartups.auth.core.model.User;

/**
 * Response object for successful authentication
 */
public class AuthenticationSuccessResponse {
    private String username;
    private String email;
    private String displayName;
    private String region;
    private long responseTimeMs;
    private long timestamp;
    
    public AuthenticationSuccessResponse() {
        this.timestamp = System.currentTimeMillis();
    }
    
    public AuthenticationSuccessResponse(User user, long responseTimeMs) {
        this.username = user.getUsername();
        this.email = user.getEmail();
        this.displayName = user.getDisplayName();
        this.region = user.getRegion();
        this.responseTimeMs = responseTimeMs;
        this.timestamp = System.currentTimeMillis();
    }
    
    public String getUsername() {
        return username;
    }
    
    public void setUsername(String username) {
        this.username = username;
    }
    
    public String getEmail() {
        return email;
    }
    
    public void setEmail(String email) {
        this.email = email;
    }
    
    public String getDisplayName() {
        return displayName;
    }
    
    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }
    
    public String getRegion() {
        return region;
    }
    
    public void setRegion(String region) {
        this.region = region;
    }
    
    public long getResponseTimeMs() {
        return responseTimeMs;
    }
    
    public void setResponseTimeMs(long responseTimeMs) {
        this.responseTimeMs = responseTimeMs;
    }
    
    public long getTimestamp() {
        return timestamp;
    }
    
    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }
}