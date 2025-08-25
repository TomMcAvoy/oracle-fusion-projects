package com.whitestartups.auth.web.rest;

/**
 * Response object for session validation
 */
public class SessionValidationResponse {
    private boolean valid;
    private String message;
    private long timestamp;
    
    public SessionValidationResponse() {
        this.timestamp = System.currentTimeMillis();
    }
    
    public SessionValidationResponse(boolean valid, String message) {
        this.valid = valid;
        this.message = message;
        this.timestamp = System.currentTimeMillis();
    }
    
    public boolean isValid() {
        return valid;
    }
    
    public void setValid(boolean valid) {
        this.valid = valid;
    }
    
    public String getMessage() {
        return message;
    }
    
    public void setMessage(String message) {
        this.message = message;
    }
    
    public long getTimestamp() {
        return timestamp;
    }
    
    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }
}