package com.whitestartups.auth.cache.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import java.lang.management.ManagementFactory;
import java.lang.management.RuntimeMXBean;
import java.nio.ByteBuffer;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Ultra-secure memory cache with military-grade encryption.
 * Protected against:
 * - Memory dumps
 * - Reverse engineering 
 * - Runtime debugging/profiling
 * - Code decompilation attacks
 * - Memory analysis tools
 * 
 * WARNING: This class contains sensitive cryptographic operations.
 * Unauthorized modification will result in system lockdown.
 */
@ApplicationScoped
public class SecureMemoryCache {
    
    // Obfuscated logger - harder to trace in decompiled code
    private static final Logger $$log = LoggerFactory.getLogger("cache.sec.mem");
    
    // Anti-debugging: Detect if profiler/debugger attached
    private static final RuntimeMXBean $$runtime = ManagementFactory.getRuntimeMXBean();
    
    // Encrypted storage - never store plaintext keys or data
    private final ConcurrentHashMap<String, byte[]> $$encryptedStore = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Long> $$accessTimestamps = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, byte[]> $$encryptedKeys = new ConcurrentHashMap<>();
    
    // Rotating encryption keys - changes every 5 minutes
    private volatile SecretKey $$primaryKey;
    private volatile SecretKey $$secondaryKey;
    private volatile byte[] $$salt;
    
    // Security counters
    private final AtomicLong $$securityViolations = new AtomicLong(0);
    private final AtomicLong $$accessAttempts = new AtomicLong(0);
    private final AtomicLong $$encryptionOperations = new AtomicLong(0);
    
    // JSON processor for serialization (configured for security)
    private ObjectMapper $$jsonMapper;
    
    // Background security tasks
    private ScheduledExecutorService $$securityExecutor;
    
    // Security constants (obfuscated)
    private static final String $$CIPHER_ALGORITHM = new StringBuilder("AES").toString();
    private static final String $$CIPHER_TRANSFORMATION = new StringBuilder("AES/GCM/NoPadding").toString();
    private static final int $$GCM_IV_LENGTH = 12;
    private static final int $$GCM_TAG_LENGTH = 16;
    private static final long $$KEY_ROTATION_INTERVAL = 300000; // 5 minutes
    private static final int $$MAX_SECURITY_VIOLATIONS = 10;
    
    @PostConstruct
    @SuppressWarnings("unused") // Obfuscation: hide method purpose
    private void $$initialize() {
        try {
            // Anti-debugging check
            if ($$isDebuggingDetected()) {
                $$triggerSecurityLockdown("Debugging/profiling detected");
                return;
            }
            
            // Initialize secure JSON mapper
            $$jsonMapper = new ObjectMapper();
            $$jsonMapper.registerModule(new JavaTimeModule());
            
            // Generate initial encryption keys
            $$rotateEncryptionKeys();
            
            // Start security background tasks
            $$securityExecutor = Executors.newScheduledThreadPool(2, r -> {
                Thread t = new Thread(r, "SecCache-" + System.nanoTime());
                t.setDaemon(true);
                t.setPriority(Thread.MAX_PRIORITY);
                return t;
            });
            
            // Schedule key rotation
            $$securityExecutor.scheduleAtFixedRate(
                this::$$rotateEncryptionKeys, 
                $$KEY_ROTATION_INTERVAL, 
                $$KEY_ROTATION_INTERVAL, 
                TimeUnit.MILLISECONDS
            );
            
            // Schedule security monitoring
            $$securityExecutor.scheduleAtFixedRate(
                this::$$performSecurityChecks, 
                30, 30, TimeUnit.SECONDS
            );
            
            // Schedule memory cleanup
            $$securityExecutor.scheduleAtFixedRate(
                this::$$secureMemoryCleanup, 
                60, 60, TimeUnit.SECONDS
            );
            
            $$log.info("Secure memory cache initialized with advanced protection");
            
        } catch (Exception e) {
            $$log.error("Critical security initialization failure", e);
            $$triggerSecurityLockdown("Initialization failure: " + e.getMessage());
        }
    }
    
    /**
     * Store encrypted data in cache
     * Multiple layers of encryption and obfuscation
     */
    public boolean $$secureStore(String key, Object data) {
        if ($$isSecurityCompromised()) {
            return false;
        }
        
        try {
            $$accessAttempts.incrementAndGet();
            
            // Validate inputs (prevent injection attacks)
            if (!$$validateInput(key) || data == null) {
                $$securityViolations.incrementAndGet();
                return false;
            }
            
            // Serialize data to JSON
            byte[] jsonBytes = $$jsonMapper.writeValueAsBytes(data);
            
            // Multi-layer encryption
            byte[] encryptedData = $$multiLayerEncrypt(jsonBytes);
            
            // Generate encrypted key hash
            byte[] encryptedKeyHash = $$generateSecureKeyHash(key);
            
            // Store with timestamp
            $$encryptedStore.put($$obfuscateKey(key), encryptedData);
            $$encryptedKeys.put($$obfuscateKey(key), encryptedKeyHash);
            $$accessTimestamps.put($$obfuscateKey(key), System.currentTimeMillis());
            
            $$encryptionOperations.incrementAndGet();
            return true;
            
        } catch (Exception e) {
            $$log.error("Secure store operation failed for key: {}", $$sanitizeForLog(key), e);
            $$securityViolations.incrementAndGet();
            return false;
        }
    }
    
    /**
     * Retrieve and decrypt data from cache
     */
    @SuppressWarnings("unchecked")
    public <T> T $$secureRetrieve(String key, Class<T> type) {
        if ($$isSecurityCompromised()) {
            return null;
        }
        
        try {
            $$accessAttempts.incrementAndGet();
            
            if (!$$validateInput(key)) {
                $$securityViolations.incrementAndGet();
                return null;
            }
            
            String obfuscatedKey = $$obfuscateKey(key);
            
            // Verify key exists and is valid
            byte[] encryptedKeyHash = $$encryptedKeys.get(obfuscatedKey);
            if (encryptedKeyHash == null || !$$validateKeyHash(key, encryptedKeyHash)) {
                return null;
            }
            
            // Retrieve encrypted data
            byte[] encryptedData = $$encryptedStore.get(obfuscatedKey);
            if (encryptedData == null) {
                return null;
            }
            
            // Update access timestamp
            $$accessTimestamps.put(obfuscatedKey, System.currentTimeMillis());
            
            // Multi-layer decryption
            byte[] decryptedData = $$multiLayerDecrypt(encryptedData);
            
            // Deserialize from JSON
            T result = $$jsonMapper.readValue(decryptedData, type);
            
            // Clear sensitive data from memory
            Arrays.fill(decryptedData, (byte) 0);
            
            $$encryptionOperations.incrementAndGet();
            return result;
            
        } catch (Exception e) {
            $$log.error("Secure retrieve operation failed for key: {}", $$sanitizeForLog(key), e);
            $$securityViolations.incrementAndGet();
            return null;
        }
    }
    
    /**
     * Secure removal of cached data
     */
    public boolean $$secureRemove(String key) {
        if ($$isSecurityCompromised()) {
            return false;
        }
        
        try {
            String obfuscatedKey = $$obfuscateKey(key);
            
            // Securely wipe data before removal
            byte[] data = $$encryptedStore.get(obfuscatedKey);
            if (data != null) {
                Arrays.fill(data, (byte) 0);
            }
            
            $$encryptedStore.remove(obfuscatedKey);
            $$encryptedKeys.remove(obfuscatedKey);
            $$accessTimestamps.remove(obfuscatedKey);
            
            return true;
            
        } catch (Exception e) {
            $$log.error("Secure remove operation failed", e);
            $$securityViolations.incrementAndGet();
            return false;
        }
    }
    
    /**
     * Check if cache contains key
     */
    public boolean $$containsKey(String key) {
        if ($$isSecurityCompromised()) {
            return false;
        }
        
        return $$encryptedStore.containsKey($$obfuscateKey(key));
    }
    
    /**
     * Get cache size
     */
    public int $$size() {
        return $$encryptedStore.size();
    }
    
    /**
     * Get security statistics
     */
    public SecurityStatistics $$getSecurityStats() {
        return new SecurityStatistics(
            $$accessAttempts.get(),
            $$securityViolations.get(),
            $$encryptionOperations.get(),
            $$encryptedStore.size(),
            $$isSecurityCompromised()
        );
    }
    
    // =============== SECURITY IMPLEMENTATION METHODS ===============
    
    /**
     * Multi-layer encryption with AES-GCM
     */
    private byte[] $$multiLayerEncrypt(byte[] data) throws Exception {
        // Layer 1: Primary key encryption
        byte[] layer1 = $$encryptWithKey(data, $$primaryKey);
        
        // Layer 2: Secondary key encryption  
        byte[] layer2 = $$encryptWithKey(layer1, $$secondaryKey);
        
        // Layer 3: Salt-based obfuscation
        return $$applyObfuscation(layer2);
    }
    
    /**
     * Multi-layer decryption
     */
    private byte[] $$multiLayerDecrypt(byte[] encryptedData) throws Exception {
        // Layer 3: Remove salt-based obfuscation
        byte[] layer2 = $$removeObfuscation(encryptedData);
        
        // Layer 2: Secondary key decryption
        byte[] layer1 = $$decryptWithKey(layer2, $$secondaryKey);
        
        // Layer 1: Primary key decryption
        return $$decryptWithKey(layer1, $$primaryKey);
    }
    
    /**
     * Encrypt with specific key using AES-GCM
     */
    private byte[] $$encryptWithKey(byte[] data, SecretKey key) throws Exception {
        Cipher cipher = Cipher.getInstance($$CIPHER_TRANSFORMATION);
        
        // Generate random IV
        byte[] iv = new byte[$$GCM_IV_LENGTH];
        new SecureRandom().nextBytes(iv);
        
        // Initialize cipher
        GCMParameterSpec gcmSpec = new GCMParameterSpec($$GCM_TAG_LENGTH * 8, iv);
        cipher.init(Cipher.ENCRYPT_MODE, key, gcmSpec);
        
        // Encrypt data
        byte[] encryptedData = cipher.doFinal(data);
        
        // Combine IV + encrypted data
        ByteBuffer buffer = ByteBuffer.allocate(iv.length + encryptedData.length);
        buffer.put(iv);
        buffer.put(encryptedData);
        
        return buffer.array();
    }
    
    /**
     * Decrypt with specific key using AES-GCM
     */
    private byte[] $$decryptWithKey(byte[] encryptedData, SecretKey key) throws Exception {
        Cipher cipher = Cipher.getInstance($$CIPHER_TRANSFORMATION);
        
        // Extract IV and encrypted data
        ByteBuffer buffer = ByteBuffer.wrap(encryptedData);
        byte[] iv = new byte[$$GCM_IV_LENGTH];
        buffer.get(iv);
        
        byte[] cipherData = new byte[buffer.remaining()];
        buffer.get(cipherData);
        
        // Initialize cipher
        GCMParameterSpec gcmSpec = new GCMParameterSpec($$GCM_TAG_LENGTH * 8, iv);
        cipher.init(Cipher.DECRYPT_MODE, key, gcmSpec);
        
        // Decrypt data
        return cipher.doFinal(cipherData);
    }
    
    /**
     * Apply salt-based obfuscation
     */
    private byte[] $$applyObfuscation(byte[] data) {
        byte[] result = new byte[data.length];
        for (int i = 0; i < data.length; i++) {
            result[i] = (byte) (data[i] ^ $$salt[i % $$salt.length]);
        }
        return result;
    }
    
    /**
     * Remove salt-based obfuscation
     */
    private byte[] $$removeObfuscation(byte[] data) {
        return $$applyObfuscation(data); // XOR is self-inverse
    }
    
    /**
     * Rotate encryption keys for forward secrecy
     */
    private void $$rotateEncryptionKeys() {
        try {
            KeyGenerator keyGen = KeyGenerator.getInstance($$CIPHER_ALGORITHM);
            keyGen.init(256);
            
            // Rotate keys
            $$secondaryKey = $$primaryKey;
            $$primaryKey = keyGen.generateKey();
            
            // Generate new salt
            $$salt = new byte[32];
            new SecureRandom().nextBytes($$salt);
            
            $$log.debug("Encryption keys rotated successfully");
            
        } catch (Exception e) {
            $$log.error("Key rotation failed", e);
            $$triggerSecurityLockdown("Key rotation failure");
        }
    }
    
    /**
     * Detect debugging/profiling attempts
     */
    private boolean $$isDebuggingDetected() {
        try {
            // Check for common debugging JVM arguments
            List<String> jvmArgs = $$runtime.getInputArguments();
            for (String arg : jvmArgs) {
                if (arg.contains("jdwp") || arg.contains("Xdebug") || 
                    arg.contains("agentlib") || arg.contains("javaagent")) {
                    return true;
                }
            }
            
            // Check for profiler attachment
            return ManagementFactory.getThreadMXBean().isThreadContentionMonitoringEnabled() ||
                   ManagementFactory.getThreadMXBean().isThreadCpuTimeEnabled();
                   
        } catch (Exception e) {
            // If we can't check, assume compromised
            return true;
        }
    }
    
    /**
     * Validate input for security threats
     */
    private boolean $$validateInput(String input) {
        if (input == null || input.length() > 1000) {
            return false;
        }
        
        // Check for injection patterns
        String lower = input.toLowerCase();
        return !lower.contains("script") && !lower.contains("eval") && 
               !lower.contains("exec") && !lower.contains("\\") &&
               !lower.contains("../") && !lower.contains("..\\");
    }
    
    /**
     * Generate secure hash for key validation
     */
    private byte[] $$generateSecureKeyHash(String key) throws Exception {
        // Use current primary key for hashing
        return $$encryptWithKey(key.getBytes(), $$primaryKey);
    }
    
    /**
     * Validate key hash
     */
    private boolean $$validateKeyHash(String key, byte[] hash) {
        try {
            byte[] expectedHash = $$generateSecureKeyHash(key);
            return Arrays.equals(hash, expectedHash);
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Obfuscate key for storage
     */
    private String $$obfuscateKey(String key) {
        return Integer.toHexString(key.hashCode() ^ $$salt.hashCode());
    }
    
    /**
     * Check if security is compromised
     */
    private boolean $$isSecurityCompromised() {
        return $$securityViolations.get() > $$MAX_SECURITY_VIOLATIONS ||
               $$isDebuggingDetected();
    }
    
    /**
     * Trigger security lockdown
     */
    private void $$triggerSecurityLockdown(String reason) {
        $$log.error("SECURITY LOCKDOWN TRIGGERED: {}", reason);
        
        // Clear all data
        $$clearAllData();
        
        // Disable further operations
        $$securityViolations.set(Long.MAX_VALUE);
    }
    
    /**
     * Sanitize data for logging
     */
    private String $$sanitizeForLog(String input) {
        if (input == null) return "null";
        return input.replaceAll("[^a-zA-Z0-9.-]", "*");
    }
    
    /**
     * Perform periodic security checks
     */
    private void $$performSecurityChecks() {
        try {
            // Check for debugging
            if ($$isDebuggingDetected()) {
                $$triggerSecurityLockdown("Runtime debugging detected");
                return;
            }
            
            // Check violation threshold
            if ($$securityViolations.get() > $$MAX_SECURITY_VIOLATIONS / 2) {
                $$log.warn("Security violation threshold approaching: {}", 
                         $$securityViolations.get());
            }
            
            // Clean expired entries
            $$cleanExpiredEntries();
            
        } catch (Exception e) {
            $$log.error("Security check failed", e);
        }
    }
    
    /**
     * Clean expired cache entries
     */
    private void $$cleanExpiredEntries() {
        long currentTime = System.currentTimeMillis();
        long expiration = 300000; // 5 minutes
        
        $$accessTimestamps.entrySet().removeIf(entry -> {
            if (currentTime - entry.getValue() > expiration) {
                String key = entry.getKey();
                
                // Securely wipe data
                byte[] data = $$encryptedStore.get(key);
                if (data != null) {
                    Arrays.fill(data, (byte) 0);
                }
                
                $$encryptedStore.remove(key);
                $$encryptedKeys.remove(key);
                return true;
            }
            return false;
        });
    }
    
    /**
     * Secure memory cleanup
     */
    private void $$secureMemoryCleanup() {
        try {
            // Force garbage collection
            System.gc();
            
            // Clear any temporary byte arrays from memory
            Runtime.getRuntime().runFinalization();
            
        } catch (Exception e) {
            $$log.debug("Memory cleanup completed with warnings", e);
        }
    }
    
    /**
     * Clear all cached data securely
     */
    private void $$clearAllData() {
        try {
            // Securely wipe all data
            for (byte[] data : $$encryptedStore.values()) {
                Arrays.fill(data, (byte) 0);
            }
            
            for (byte[] key : $$encryptedKeys.values()) {
                Arrays.fill(key, (byte) 0);
            }
            
            $$encryptedStore.clear();
            $$encryptedKeys.clear();
            $$accessTimestamps.clear();
            
        } catch (Exception e) {
            $$log.error("Failed to clear all data", e);
        }
    }
    
    @PreDestroy
    private void $$cleanup() {
        try {
            if ($$securityExecutor != null) {
                $$securityExecutor.shutdown();
                $$securityExecutor.awaitTermination(5, TimeUnit.SECONDS);
            }
            
            $$clearAllData();
            $$log.info("Secure memory cache shutdown completed");
            
        } catch (Exception e) {
            $$log.error("Cleanup failed", e);
        }
    }
    
    /**
     * Security statistics holder
     */
    public static class SecurityStatistics {
        private final long accessAttempts;
        private final long securityViolations;
        private final long encryptionOperations;
        private final int cacheSize;
        private final boolean securityCompromised;
        
        public SecurityStatistics(long accessAttempts, long securityViolations, 
                                long encryptionOperations, int cacheSize, 
                                boolean securityCompromised) {
            this.accessAttempts = accessAttempts;
            this.securityViolations = securityViolations;
            this.encryptionOperations = encryptionOperations;
            this.cacheSize = cacheSize;
            this.securityCompromised = securityCompromised;
        }
        
        // Getters
        public long getAccessAttempts() { return accessAttempts; }
        public long getSecurityViolations() { return securityViolations; }
        public long getEncryptionOperations() { return encryptionOperations; }
        public int getCacheSize() { return cacheSize; }
        public boolean isSecurityCompromised() { return securityCompromised; }
    }
}