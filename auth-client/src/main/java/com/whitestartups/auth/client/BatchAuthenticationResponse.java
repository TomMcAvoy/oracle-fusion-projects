package com.whitestartups.auth.client;

import java.util.HashMap;
import java.util.Map;

/**
 * Response object for batch authentication operations
 */
public class BatchAuthenticationResponse {
    private Map<String, AuthenticationClient.AuthenticationResponse> results = new HashMap<>();
    private int totalRequests;
    private int successfulAuthentications;
    private int failedAuthentications;
    private long totalProcessingTimeMs;
    
    public BatchAuthenticationResponse() {}
    
    /**
     * Add authentication result for a user
     */
    public void addResult(String username, AuthenticationClient.AuthenticationResponse response) {
        results.put(username, response);
        totalRequests++;
        
        if (response.isSuccess()) {
            successfulAuthentications++;
        } else {
            failedAuthentications++;
        }
        
        totalProcessingTimeMs += response.getResponseTimeMs();
    }
    
    /**
     * Get result for specific username
     */
    public AuthenticationClient.AuthenticationResponse getResult(String username) {
        return results.get(username);
    }
    
    /**
     * Check if specific user authentication was successful
     */
    public boolean isUserAuthenticated(String username) {
        AuthenticationClient.AuthenticationResponse response = results.get(username);
        return response != null && response.isSuccess();
    }
    
    /**
     * Get all results
     */
    public Map<String, AuthenticationClient.AuthenticationResponse> getAllResults() {
        return new HashMap<>(results);
    }
    
    /**
     * Get summary statistics
     */
    public BatchSummary getSummary() {
        return new BatchSummary(
            totalRequests,
            successfulAuthentications,
            failedAuthentications,
            totalProcessingTimeMs,
            totalRequests > 0 ? (double) totalProcessingTimeMs / totalRequests : 0
        );
    }
    
    public int getTotalRequests() {
        return totalRequests;
    }
    
    public int getSuccessfulAuthentications() {
        return successfulAuthentications;
    }
    
    public int getFailedAuthentications() {
        return failedAuthentications;
    }
    
    public long getTotalProcessingTimeMs() {
        return totalProcessingTimeMs;
    }
    
    /**
     * Summary statistics for batch operation
     */
    public static class BatchSummary {
        private final int totalRequests;
        private final int successful;
        private final int failed;
        private final long totalTimeMs;
        private final double averageTimeMs;
        
        public BatchSummary(int totalRequests, int successful, int failed, 
                          long totalTimeMs, double averageTimeMs) {
            this.totalRequests = totalRequests;
            this.successful = successful;
            this.failed = failed;
            this.totalTimeMs = totalTimeMs;
            this.averageTimeMs = averageTimeMs;
        }
        
        public int getTotalRequests() { return totalRequests; }
        public int getSuccessful() { return successful; }
        public int getFailed() { return failed; }
        public long getTotalTimeMs() { return totalTimeMs; }
        public double getAverageTimeMs() { return averageTimeMs; }
        
        public double getSuccessRate() {
            return totalRequests > 0 ? (double) successful / totalRequests : 0;
        }
        
        @Override
        public String toString() {
            return String.format("BatchSummary{total=%d, success=%d, failed=%d, successRate=%.2f%%, avgTime=%.2fms}",
                               totalRequests, successful, failed, getSuccessRate() * 100, averageTimeMs);
        }
    }
}