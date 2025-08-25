package com.whitestartups.auth.client;

import java.util.ArrayList;
import java.util.List;

/**
 * Request object for batch authentication operations
 */
public class BatchAuthenticationRequest {
    private List<Credential> credentials = new ArrayList<>();
    private int maxConcurrency = 10;
    private long timeoutMs = 5000;
    
    public BatchAuthenticationRequest() {}
    
    public BatchAuthenticationRequest(List<Credential> credentials) {
        this.credentials = credentials;
    }
    
    /**
     * Add a credential to the batch
     */
    public BatchAuthenticationRequest addCredential(String username, String password) {
        credentials.add(new Credential(username, password));
        return this;
    }
    
    public List<Credential> getCredentials() {
        return credentials;
    }
    
    public void setCredentials(List<Credential> credentials) {
        this.credentials = credentials;
    }
    
    public int getMaxConcurrency() {
        return maxConcurrency;
    }
    
    public void setMaxConcurrency(int maxConcurrency) {
        this.maxConcurrency = maxConcurrency;
    }
    
    public long getTimeoutMs() {
        return timeoutMs;
    }
    
    public void setTimeoutMs(long timeoutMs) {
        this.timeoutMs = timeoutMs;
    }
    
    /**
     * Credential pair for username/password
     */
    public static class Credential {
        private String username;
        private String password;
        
        public Credential() {}
        
        public Credential(String username, String password) {
            this.username = username;
            this.password = password;
        }
        
        public String getUsername() {
            return username;
        }
        
        public void setUsername(String username) {
            this.username = username;
        }
        
        public String getPassword() {
            return password;
        }
        
        public void setPassword(String password) {
            this.password = password;
        }
    }
}