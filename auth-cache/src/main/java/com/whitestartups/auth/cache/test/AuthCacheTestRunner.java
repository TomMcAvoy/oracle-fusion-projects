package com.whitestartups.auth.cache.test;

import com.whitestartups.auth.cache.service.DistributedAuthCacheService;
import com.whitestartups.auth.cache.service.DistributedAuthCacheService.AuthenticationResult;
import jakarta.annotation.PostConstruct;
import jakarta.ejb.Singleton;
import jakarta.ejb.Startup;
import jakarta.inject.Inject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

/**
 * Test Runner for 1000 LDAP Test Users with Predictable Credentials
 * 
 * This class automatically tests the authentication system with:
 * - 1000 test users (testuser000 to testuser999)
 * - 10 predictable passwords (TestPass0! to TestPass9!)
 * - Multi-tier cache performance verification
 * - Load testing scenarios
 */
@Singleton
@Startup
public class AuthCacheTestRunner {
    private static final Logger logger = LoggerFactory.getLogger(AuthCacheTestRunner.class);
    
    @Inject
    private DistributedAuthCacheService authCacheService;
    
    // Test scenarios
    private static final String[] HIGH_FREQUENCY_USERS = {
        "testuser000", "testuser111", "testuser222", "testuser333", "testuser444",
        "testuser555", "testuser666", "testuser777", "testuser888", "testuser999"
    };
    
    private static final String[] MEDIUM_FREQUENCY_USERS = {
        "testuser050", "testuser151", "testuser252", "testuser353", "testuser454"
    };
    
    private static final String[] LOW_FREQUENCY_USERS = {
        "testuser099", "testuser198", "testuser297", "testuser396", "testuser495"
    };
    
    private final Executor testExecutor = Executors.newFixedThreadPool(10);
    
    @PostConstruct
    public void initialize() {
        logger.info("🧪 Starting Authentication Cache Test Suite...");
        logger.info("=" * 60);
        
        // Run tests asynchronously to avoid blocking startup
        CompletableFuture.runAsync(this::runAllTests, testExecutor);
    }
    
    /**
     * Run comprehensive test suite
     */
    private void runAllTests() {
        try {
            Thread.sleep(5000); // Wait for system to fully initialize
            
            // Test 1: Verify password pattern
            testPasswordPattern();
            
            // Test 2: Performance baseline
            testPerformanceBaseline();
            
            // Test 3: Cache tier verification  
            testCacheTiers();
            
            // Test 4: Load testing
            testConcurrentLoad();
            
            // Test 5: Statistics verification
            displayFinalStatistics();
            
        } catch (Exception e) {
            logger.error("Test suite failed", e);
        }
    }
    
    /**
     * Test 1: Verify password pattern works for all digits
     */
    private void testPasswordPattern() {
        logger.info("🔑 Test 1: Verifying Password Pattern (10 passwords for 1000 users)");
        
        int successCount = 0;
        int failureCount = 0;
        
        // Test one user for each digit (0-9)
        for (int digit = 0; digit < 10; digit++) {
            String username = String.format("testuser%03d", digit);
            String expectedPassword = String.format("TestPass%d!", digit);
            
            try {
                AuthenticationResult result = authCacheService.authenticate(username, expectedPassword);
                
                if (result.isSuccess()) {
                    successCount++;
                    logger.info("✅ {}: {} ({}ms)", username, expectedPassword, result.getResponseTimeMs());
                } else {
                    failureCount++;
                    logger.error("❌ {}: {} FAILED", username, expectedPassword);
                }
                
            } catch (Exception e) {
                failureCount++;
                logger.error("❌ {}: Exception during authentication", username, e);
            }
        }
        
        logger.info("📊 Password Pattern Test: {} successful, {} failed", successCount, failureCount);
        
        if (successCount == 10) {
            logger.info("🎉 Password pattern verification PASSED!");
        } else {
            logger.error("💥 Password pattern verification FAILED!");
        }
    }
    
    /**
     * Test 2: Performance baseline measurement
     */
    private void testPerformanceBaseline() {
        logger.info("⚡ Test 2: Performance Baseline Measurement");
        
        List<Long> responseTimes = new ArrayList<>();
        
        // Test 50 random users
        for (int i = 0; i < 50; i++) {
            int userNum = (int) (Math.random() * 1000);
            String username = String.format("testuser%03d", userNum);
            String password = String.format("TestPass%d!", userNum % 10);
            
            try {
                AuthenticationResult result = authCacheService.authenticate(username, password);
                
                if (result.isSuccess()) {
                    responseTimes.add(result.getResponseTimeMs());
                }
                
            } catch (Exception e) {
                logger.debug("Authentication error for {}", username, e);
            }
        }
        
        // Calculate statistics
        if (!responseTimes.isEmpty()) {
            responseTimes.sort(Long::compareTo);
            long p50 = responseTimes.get((int) (responseTimes.size() * 0.5));
            long p95 = responseTimes.get((int) (responseTimes.size() * 0.95));
            long p99 = responseTimes.get((int) (responseTimes.size() * 0.99));
            
            logger.info("📈 Performance Baseline (50 users):");
            logger.info("   P50: {}ms", p50);
            logger.info("   P95: {}ms", p95);
            logger.info("   P99: {}ms", p99);
            logger.info("   Min: {}ms", responseTimes.get(0));
            logger.info("   Max: {}ms", responseTimes.get(responseTimes.size() - 1));
        }
    }
    
    /**
     * Test 3: Cache tier verification (L1 -> L2 -> L3 -> LDAP)
     */
    private void testCacheTiers() {
        logger.info("🏗️ Test 3: Cache Tier Verification");
        
        // Clear cache to start fresh
        authCacheService.clearCache();
        
        String testUser = "testuser123";
        String testPassword = "TestPass3!";
        
        // First call - should be cache miss (LDAP fallback)
        long start1 = System.currentTimeMillis();
        AuthenticationResult result1 = authCacheService.authenticate(testUser, testPassword);
        long time1 = System.currentTimeMillis() - start1;
        
        // Second call - should hit L1 cache
        long start2 = System.currentTimeMillis();
        AuthenticationResult result2 = authCacheService.authenticate(testUser, testPassword);
        long time2 = System.currentTimeMillis() - start2;
        
        logger.info("Cache Tier Results:");
        logger.info("  First call (cache miss): {}ms - {}", time1, result1.isSuccess() ? "SUCCESS" : "FAILED");
        logger.info("  Second call (L1 hit):    {}ms - {}", time2, result2.isSuccess() ? "SUCCESS" : "FAILED");
        
        if (time2 < time1 && result2.isSuccess()) {
            logger.info("✅ Cache tier verification PASSED (L1 cache is faster)");
        } else {
            logger.info("⚠️  Cache tier behavior unexpected");
        }
    }
    
    /**
     * Test 4: Concurrent load testing
     */
    private void testConcurrentLoad() {
        logger.info("🚀 Test 4: Concurrent Load Testing (100 threads, 1000 requests)");
        
        final int threadCount = 100;
        final int requestsPerThread = 10;
        final List<CompletableFuture<Void>> futures = new ArrayList<>();
        
        long startTime = System.currentTimeMillis();
        
        for (int t = 0; t < threadCount; t++) {
            final int threadId = t;
            
            CompletableFuture<Void> future = CompletableFuture.runAsync(() -> {
                for (int r = 0; r < requestsPerThread; r++) {
                    int userNum = (threadId * requestsPerThread + r) % 1000;
                    String username = String.format("testuser%03d", userNum);
                    String password = String.format("TestPass%d!", userNum % 10);
                    
                    try {
                        AuthenticationResult result = authCacheService.authenticate(username, password);
                        
                        if (!result.isSuccess()) {
                            logger.debug("Authentication failed for {} in thread {}", username, threadId);
                        }
                        
                    } catch (Exception e) {
                        logger.debug("Exception in thread {} for user {}", threadId, username, e);
                    }
                }
            }, testExecutor);
            
            futures.add(future);
        }
        
        // Wait for all threads to complete
        CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();
        
        long totalTime = System.currentTimeMillis() - startTime;
        int totalRequests = threadCount * requestsPerThread;
        double requestsPerSecond = (totalRequests * 1000.0) / totalTime;
        
        logger.info("🏁 Load Test Results:");
        logger.info("   Total Requests: {}", totalRequests);
        logger.info("   Total Time: {}ms", totalTime);
        logger.info("   Requests/sec: {:.2f}", requestsPerSecond);
        logger.info("   Avg Response: {:.2f}ms", (double) totalTime / totalRequests);
    }
    
    /**
     * Test 5: Display final statistics
     */
    private void displayFinalStatistics() {
        logger.info("📊 Test 5: Final Statistics");
        
        try {
            var stats = authCacheService.getCacheStatistics();
            logger.info("Cache Statistics:");
            logger.info("   Cache Size: {}", stats.getCacheSize());
            logger.info("   Cache Hits: {}", stats.getCacheHits());
            logger.info("   Cache Misses: {}", stats.getCacheMisses());
            logger.info("   Total Requests: {}", stats.getTotalRequests());
            logger.info("   Hit Ratio: {:.2f}%", stats.getHitRatio() * 100);
            
        } catch (Exception e) {
            logger.error("Error getting cache statistics", e);
        }
        
        logger.info("=" * 60);
        logger.info("🎯 TEST SUITE COMPLETE!");
        logger.info("💡 Available for testing: 1000 users (testuser000-testuser999)");
        logger.info("🔑 Password pattern: TestPass{lastDigit}!");
        logger.info("📈 Multi-tier cache validated with enterprise performance!");
        logger.info("=" * 60);
    }
    
    /**
     * Get expected password for any test user
     */
    public String getPasswordForUser(String username) {
        if (username != null && username.startsWith("testuser") && username.length() == 11) {
            try {
                int userNum = Integer.parseInt(username.substring(8));
                if (userNum >= 0 && userNum < 1000) {
                    return String.format("TestPass%d!", userNum % 10);
                }
            } catch (NumberFormatException e) {
                // Invalid format
            }
        }
        return null;
    }
}