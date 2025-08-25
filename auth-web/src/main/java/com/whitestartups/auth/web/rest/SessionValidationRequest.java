package com.whitestartups.auth.web.rest;

/**
 * Request object for session validation
 */
public class SessionValidationRequest {
    private String username;
    private String sessionToken;
    
    public SessionValidationRequest() {}
    
    public SessionValidationRequest(String username, String sessionToken) {
        this.username = username;
        this.sessionToken = sessionToken;
    }
    
    public String getUsername() {
        return username;
    }
    
    public void setUsername(String username) {
        this.username = username;
    }
    
    public String getSessionToken() {
        return sessionToken;
    }
    
    public void setSessionToken(String sessionToken) {
        this.sessionToken = sessionToken;
    }
}