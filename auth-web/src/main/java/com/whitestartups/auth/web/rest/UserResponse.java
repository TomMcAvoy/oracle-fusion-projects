package com.whitestartups.auth.web.rest;

import com.whitestartups.auth.core.model.User;

/**
 * Response object for user information (without sensitive data)
 */
public class UserResponse {
    private String username;
    private String email;
    private String displayName;
    private String region;
    private boolean isActive;
    private String lastLogin;
    
    public UserResponse() {}
    
    public UserResponse(User user) {
        this.username = user.getUsername();
        this.email = user.getEmail();
        this.displayName = user.getDisplayName();
        this.region = user.getRegion();
        this.isActive = user.getIsActive();
        this.lastLogin = user.getLastLogin() != null ? user.getLastLogin().toString() : null;
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
    
    public boolean isActive() {
        return isActive;
    }
    
    public void setActive(boolean active) {
        isActive = active;
    }
    
    public String getLastLogin() {
        return lastLogin;
    }
    
    public void setLastLogin(String lastLogin) {
        this.lastLogin = lastLogin;
    }
}