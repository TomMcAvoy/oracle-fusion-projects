package com.whitestartups.auth.core.service;

import jakarta.enterprise.context.ApplicationScoped;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.security.spec.InvalidKeySpecException;
import java.util.Base64;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.SecretKeyFactory;

/**
 * Service for encrypting/decrypting user data and passwords
 * Used to secure EJB communications and sensitive user data
 */
@ApplicationScoped
public class UserEncryptionService {
    private static final Logger logger = LoggerFactory.getLogger(UserEncryptionService.class);
    
    private static final String HASH_ALGORITHM = "SHA-256";
    private static final String LDAP_HASH_ALGORITHM = "SHA-1";  // For OpenLDAP SSHA
    private static final String PBKDF2_ALGORITHM = "PBKDF2WithHmacSHA256";  // Recommended balance
    private static final String ENCRYPTION_ALGORITHM = "AES";
    private static final String TRANSFORMATION = "AES/ECB/PKCS5Padding";
    
    // PBKDF2 configuration for optimal performance/security balance
    private static final int PBKDF2_ITERATIONS = 50000;  // 50K iterations (fast but secure)
    private static final int PBKDF2_KEY_LENGTH = 256;    // 256-bit key
    private static final int PBKDF2_SALT_LENGTH = 32;    // 32-byte salt
    
    // In production, this would come from a secure key management system
    private final SecretKey encryptionKey;
    
    public UserEncryptionService() {
        // Initialize encryption key
        this.encryptionKey = generateSecretKey();
    }
    
    /**
     * Hash a password using SHA-256 with salt
     */
    public String hashPassword(String password) {
        try {
            // Generate random salt
            SecureRandom random = new SecureRandom();
            byte[] salt = new byte[16];
            random.nextBytes(salt);
            
            // Create hash with salt
            MessageDigest digest = MessageDigest.getInstance(HASH_ALGORITHM);
            digest.update(salt);
            byte[] hashedPassword = digest.digest(password.getBytes(StandardCharsets.UTF_8));
            
            // Combine salt and hash for storage
            byte[] combined = new byte[salt.length + hashedPassword.length];
            System.arraycopy(salt, 0, combined, 0, salt.length);
            System.arraycopy(hashedPassword, 0, combined, salt.length, hashedPassword.length);
            
            return Base64.getEncoder().encodeToString(combined);
            
        } catch (Exception e) {
            logger.error("Error hashing password", e);
            throw new RuntimeException("Password hashing failed", e);
        }
    }
    
    /**
     * Verify a password against its hash
     */
    public boolean verifyPassword(String password, String hashedPassword) {
        try {
            byte[] combined = Base64.getDecoder().decode(hashedPassword);
            
            // Extract salt (first 16 bytes)
            byte[] salt = new byte[16];
            System.arraycopy(combined, 0, salt, 0, 16);
            
            // Extract original hash
            byte[] originalHash = new byte[combined.length - 16];
            System.arraycopy(combined, 16, originalHash, 0, originalHash.length);
            
            // Hash the provided password with the same salt
            MessageDigest digest = MessageDigest.getInstance(HASH_ALGORITHM);
            digest.update(salt);
            byte[] testHash = digest.digest(password.getBytes(StandardCharsets.UTF_8));
            
            // Compare hashes
            return MessageDigest.isEqual(originalHash, testHash);
            
        } catch (Exception e) {
            logger.error("Error verifying password", e);
            return false;
        }
    }
    
    /**
     * Encrypt sensitive user data for EJB transmission
     */
    public String encryptUserData(String data) {
        try {
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.ENCRYPT_MODE, encryptionKey);
            
            byte[] encryptedData = cipher.doFinal(data.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(encryptedData);
            
        } catch (Exception e) {
            logger.error("Error encrypting user data", e);
            throw new RuntimeException("Encryption failed", e);
        }
    }
    
    /**
     * Decrypt sensitive user data received from EJB
     */
    public String decryptUserData(String encryptedData) {
        try {
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.DECRYPT_MODE, encryptionKey);
            
            byte[] decodedData = Base64.getDecoder().decode(encryptedData);
            byte[] decryptedData = cipher.doFinal(decodedData);
            
            return new String(decryptedData, StandardCharsets.UTF_8);
            
        } catch (Exception e) {
            logger.error("Error decrypting user data", e);
            throw new RuntimeException("Decryption failed", e);
        }
    }
    
    /**
     * Encrypt generic data (alias for encryptUserData)
     */
    public String encrypt(String data) {
        return encryptUserData(data);
    }
    
    /**
     * Decrypt generic data (alias for decryptUserData)
     */
    public String decrypt(String encryptedData) {
        return decryptUserData(encryptedData);
    }
    
    /**
     * Generate a secure token for session management
     */
    public String generateSecureToken() {
        try {
            SecureRandom random = new SecureRandom();
            byte[] token = new byte[32];
            random.nextBytes(token);
            
            return Base64.getUrlEncoder().withoutPadding().encodeToString(token);
            
        } catch (Exception e) {
            logger.error("Error generating secure token", e);
            throw new RuntimeException("Token generation failed", e);
        }
    }
    
    /**
     * Generate secret key for encryption
     */
    private SecretKey generateSecretKey() {
        try {
            // In production, this would be loaded from secure storage
            String keyString = "MySecureKey12345"; // 16 bytes for AES-128
            byte[] key = keyString.getBytes(StandardCharsets.UTF_8);
            
            return new SecretKeySpec(key, ENCRYPTION_ALGORITHM);
            
        } catch (Exception e) {
            logger.error("Error generating secret key", e);
            throw new RuntimeException("Key generation failed", e);
        }
    }
    
    /**
     * Hash password using PBKDF2-SHA256 (RECOMMENDED: secure and fast)
     * Format: {PBKDF2}iterations$salt$hash
     * 50,000 iterations = ~10ms per hash (good balance)
     */
    public String hashPasswordPBKDF2(String password) {
        return hashPasswordPBKDF2(password, PBKDF2_ITERATIONS);
    }
    
    /**
     * Hash password using PBKDF2-SHA256 with custom iterations
     */
    public String hashPasswordPBKDF2(String password, int iterations) {
        try {
            // Generate random salt
            SecureRandom random = new SecureRandom();
            byte[] salt = new byte[PBKDF2_SALT_LENGTH];
            random.nextBytes(salt);
            
            // Generate PBKDF2 hash
            PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, iterations, PBKDF2_KEY_LENGTH);
            SecretKeyFactory factory = SecretKeyFactory.getInstance(PBKDF2_ALGORITHM);
            byte[] hash = factory.generateSecret(spec).getEncoded();
            
            // Clear sensitive data
            spec.clearPassword();
            
            // Format: {PBKDF2}iterations$salt$hash (Base64 encoded)
            String saltB64 = Base64.getEncoder().encodeToString(salt);
            String hashB64 = Base64.getEncoder().encodeToString(hash);
            
            return String.format("{PBKDF2}%d$%s$%s", iterations, saltB64, hashB64);
            
        } catch (NoSuchAlgorithmException | InvalidKeySpecException e) {
            logger.error("Error hashing password with PBKDF2", e);
            throw new RuntimeException("PBKDF2 password hashing failed", e);
        }
    }
    
    /**
     * Verify password against PBKDF2 hash
     */
    public boolean verifyPasswordPBKDF2(String password, String pbkdf2Hash) {
        try {
            // Parse format: {PBKDF2}iterations$salt$hash
            if (!pbkdf2Hash.startsWith("{PBKDF2}")) {
                return false;
            }
            
            String[] parts = pbkdf2Hash.substring(8).split("\\$");
            if (parts.length != 3) {
                return false;
            }
            
            int iterations = Integer.parseInt(parts[0]);
            byte[] salt = Base64.getDecoder().decode(parts[1]);
            byte[] storedHash = Base64.getDecoder().decode(parts[2]);
            
            // Generate hash with same parameters
            PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, iterations, PBKDF2_KEY_LENGTH);
            SecretKeyFactory factory = SecretKeyFactory.getInstance(PBKDF2_ALGORITHM);
            byte[] testHash = factory.generateSecret(spec).getEncoded();
            
            // Clear sensitive data
            spec.clearPassword();
            
            // Compare hashes
            return MessageDigest.isEqual(storedHash, testHash);
            
        } catch (Exception e) {
            logger.error("Error verifying PBKDF2 password", e);
            return false;
        }
    }
    
    /**
     * Hash password using OpenLDAP SSHA format (faster but less secure)
     * SSHA = Salted SHA-1 - much faster than SHA-256, still secure with salt
     * Format: {SSHA}base64(sha1(password+salt)+salt)
     */
    public String hashPasswordSSHA(String password) {
        try {
            // Generate 4-byte salt (OpenLDAP standard)
            SecureRandom random = new SecureRandom();
            byte[] salt = new byte[4];
            random.nextBytes(salt);
            
            // Create SHA-1 hash with password + salt
            MessageDigest digest = MessageDigest.getInstance(LDAP_HASH_ALGORITHM);
            digest.update(password.getBytes(StandardCharsets.UTF_8));
            digest.update(salt);
            byte[] hash = digest.digest();
            
            // Combine hash + salt (OpenLDAP SSHA format)
            byte[] combined = new byte[hash.length + salt.length];
            System.arraycopy(hash, 0, combined, 0, hash.length);
            System.arraycopy(salt, 0, combined, hash.length, salt.length);
            
            // Return in OpenLDAP format
            return "{SSHA}" + Base64.getEncoder().encodeToString(combined);
            
        } catch (Exception e) {
            logger.error("Error hashing password with SSHA", e);
            throw new RuntimeException("SSHA password hashing failed", e);
        }
    }
    
    /**
     * Verify password against OpenLDAP SSHA hash
     */
    public boolean verifyPasswordSSHA(String password, String sshaHash) {
        try {
            // Remove {SSHA} prefix if present
            String base64Hash = sshaHash.startsWith("{SSHA}") ? 
                               sshaHash.substring(6) : sshaHash;
            
            byte[] combined = Base64.getDecoder().decode(base64Hash);
            
            // SHA-1 produces 20 bytes, salt is the remainder
            byte[] hash = new byte[20];
            byte[] salt = new byte[combined.length - 20];
            
            System.arraycopy(combined, 0, hash, 0, 20);
            System.arraycopy(combined, 20, salt, 0, salt.length);
            
            // Hash the provided password with extracted salt
            MessageDigest digest = MessageDigest.getInstance(LDAP_HASH_ALGORITHM);
            digest.update(password.getBytes(StandardCharsets.UTF_8));
            digest.update(salt);
            byte[] testHash = digest.digest();
            
            // Compare hashes
            return MessageDigest.isEqual(hash, testHash);
            
        } catch (Exception e) {
            logger.error("Error verifying SSHA password", e);
            return false;
        }
    }
    
    /**
     * Hash password using plain SHA (faster but less secure - no salt)
     * Format: {SHA}base64(sha1(password))
     * Only use for high-performance testing scenarios
     */
    public String hashPasswordSHA(String password) {
        try {
            MessageDigest digest = MessageDigest.getInstance(LDAP_HASH_ALGORITHM);
            byte[] hash = digest.digest(password.getBytes(StandardCharsets.UTF_8));
            return "{SHA}" + Base64.getEncoder().encodeToString(hash);
            
        } catch (Exception e) {
            logger.error("Error hashing password with SHA", e);
            throw new RuntimeException("SHA password hashing failed", e);
        }
    }
    
    /**
     * Verify password against OpenLDAP SHA hash
     */
    public boolean verifyPasswordSHA(String password, String shaHash) {
        try {
            // Remove {SHA} prefix if present
            String base64Hash = shaHash.startsWith("{SHA}") ? 
                               shaHash.substring(5) : shaHash;
            
            byte[] storedHash = Base64.getDecoder().decode(base64Hash);
            
            // Hash the provided password
            MessageDigest digest = MessageDigest.getInstance(LDAP_HASH_ALGORITHM);
            byte[] testHash = digest.digest(password.getBytes(StandardCharsets.UTF_8));
            
            // Compare hashes
            return MessageDigest.isEqual(storedHash, testHash);
            
        } catch (Exception e) {
            logger.error("Error verifying SHA password", e);
            return false;
        }
    }
    
    /**
     * Universal password verification - detects hash type and verifies accordingly
     */
    public boolean verifyPasswordUniversal(String password, String hashedPassword) {
        if (hashedPassword.startsWith("{PBKDF2}")) {
            return verifyPasswordPBKDF2(password, hashedPassword);
        } else if (hashedPassword.startsWith("{SSHA}")) {
            return verifyPasswordSSHA(password, hashedPassword);
        } else if (hashedPassword.startsWith("{SHA}")) {
            return verifyPasswordSHA(password, hashedPassword);
        } else {
            // Fallback to our standard SHA-256 format
            return verifyPassword(password, hashedPassword);
        }
    }
    
    /**
     * Get encryption key information (for debugging)
     */
    public String getEncryptionInfo() {
        return String.format("Algorithm: %s, Key Format: %s", 
                           ENCRYPTION_ALGORITHM, encryptionKey.getFormat());
    }
    
    /**
     * Performance comparison of different hashing algorithms
     */
    public void benchmarkHashingPerformance(String testPassword) {
        int iterations = 1000;  // Reduced because PBKDF2 is slower
        logger.info("🏁 Password Hashing Performance Benchmark ({} iterations)", iterations);
        
        // Benchmark SHA (fastest - NOT RECOMMENDED for production)
        long startTime = System.currentTimeMillis();
        for (int i = 0; i < iterations; i++) {
            hashPasswordSHA(testPassword);
        }
        long shaTime = System.currentTimeMillis() - startTime;
        
        // Benchmark SSHA (fast but SHA-1 is deprecated)
        startTime = System.currentTimeMillis();
        for (int i = 0; i < iterations; i++) {
            hashPasswordSSHA(testPassword);
        }
        long sshaTime = System.currentTimeMillis() - startTime;
        
        // Benchmark PBKDF2-SHA256 (RECOMMENDED)
        startTime = System.currentTimeMillis();
        for (int i = 0; i < iterations; i++) {
            hashPasswordPBKDF2(testPassword);
        }
        long pbkdf2Time = System.currentTimeMillis() - startTime;
        
        // Benchmark SHA-256 (basic)
        startTime = System.currentTimeMillis();
        for (int i = 0; i < iterations; i++) {
            hashPassword(testPassword);
        }
        long sha256Time = System.currentTimeMillis() - startTime;
        
        logger.info("📊 Hashing Performance Results:");
        logger.info("   {SHA}     (no salt):       {}ms ({:.2f}ms each) - FASTEST but INSECURE", 
                   shaTime, (double)shaTime/iterations);
        logger.info("   {SSHA}    (SHA-1+salt):    {}ms ({:.2f}ms each) - FAST but SHA-1 deprecated", 
                   sshaTime, (double)sshaTime/iterations);
        logger.info("   SHA-256   (basic salt):    {}ms ({:.2f}ms each) - GOOD but single iteration", 
                   sha256Time, (double)sha256Time/iterations);
        logger.info("   {PBKDF2}  (50K iterations): {}ms ({:.2f}ms each) - RECOMMENDED ⭐", 
                   pbkdf2Time, (double)pbkdf2Time/iterations);
                   
        logger.info("");
        logger.info("🎯 RECOMMENDATION: Use PBKDF2 for production (~{:.1f}ms per hash)", 
                   (double)pbkdf2Time/iterations);
        logger.info("💡 Why PBKDF2? Secure, configurable, industry standard, OpenLDAP compatible");
        
        // Show requests per second capability
        double pbkdf2RPS = (iterations * 1000.0) / pbkdf2Time;
        logger.info("⚡ PBKDF2 Performance: ~{:.0f} hashes/second (suitable for auth workloads)", pbkdf2RPS);
    }
}