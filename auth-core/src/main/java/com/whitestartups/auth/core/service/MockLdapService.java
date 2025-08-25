package com.whitestartups.auth.core.service;

import com.whitestartups.auth.core.model.User;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.LocalDateTime;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Mock LDAP Service for testing with 1000 predictable test users
 * Simulates LDAP queries without requiring actual LDAP server
 * 
 * USER PATTERN:
 * - Usernames: testuser000 to testuser999 (1000 users)
 * - Passwords: TestPass{lastDigit}! (10 different passwords)
 * 
 * EXAMPLES:
 * - testuser000, testuser010, testuser020... → TestPass0!
 * - testuser001, testuser011, testuser021... → TestPass1!
 * - testuser123 → TestPass3!
 * - testuser999 → TestPass9!
 */
@ApplicationScoped
public class MockLdapService {
    private static final Logger logger = LoggerFactory.getLogger(MockLdapService.class);
    
    @Inject
    private UserEncryptionService encryptionService;
    
    // Cache for generated users (simulates LDAP directory)
    private static final ConcurrentHashMap<String, User> ldapDirectory = new ConcurrentHashMap<>();
    
    // Password mapping by last digit
    private static final String[] PASSWORDS = {
        "TestPass0!", "TestPass1!", "TestPass2!", "TestPass3!", "TestPass4!",
        "TestPass5!", "TestPass6!", "TestPass7!", "TestPass8!", "TestPass9!"
    };
    
    // Department rotation
    private static final String[] DEPARTMENTS = {
        "engineering", "sales", "marketing", "hr", "finance",
        "operations", "support", "legal", "security", "research"
    };
    
    // Region rotation
    private static final String[] REGIONS = {
        "US-EAST", "US-WEST", "EU-WEST", "ASIA-PAC", "CANADA"
    };
    
    // Title rotation
    private static final String[] TITLES = {
        "Software Engineer", "Sales Manager", "Marketing Specialist",
        "HR Coordinator", "Financial Analyst", "Operations Manager",
        "Support Technician", "Legal Counsel", "Security Analyst",
        "Research Scientist"
    };
    
    /**
     * Initialize 1000 test users in mock LDAP directory
     */
    public void initializeTestUsers() {
        if (!ldapDirectory.isEmpty()) {
            logger.debug("Mock LDAP directory already initialized with {} users", ldapDirectory.size());
            return;
        }
        
        logger.info("🔧 Initializing Mock LDAP with 1000 test users...");
        
        for (int i = 0; i < 1000; i++) {
            String username = String.format("testuser%03d", i);
            User user = createTestUser(i, username);
            ldapDirectory.put(username, user);
        }
        
        logger.info("✅ Mock LDAP initialized with {} test users", ldapDirectory.size());
        logger.info("🔑 Password Pattern: TestPass{lastDigit}!");
        logger.info("📝 Examples: testuser000→TestPass0!, testuser123→TestPass3!, testuser999→TestPass9!");
        
        // Run password hashing benchmark
        logger.info("🏁 Running password hashing performance test...");
        encryptionService.benchmarkHashingPerformance("TestPass0!");
    }
    
    /**
     * Create a test user with predictable attributes
     */
    private User createTestUser(int userIndex, String username) {
        // Calculate attributes based on user index
        int lastDigit = userIndex % 10;
        String password = PASSWORDS[lastDigit];
        
        String firstName = String.format("Test%03d", userIndex);
        String lastName = String.format("User%d", lastDigit);
        String email = username + "@whitestartups.com";
        String region = REGIONS[userIndex % REGIONS.length];
        String department = DEPARTMENTS[userIndex % DEPARTMENTS.length];
        String title = TITLES[userIndex % TITLES.length];
        
        // Create user with PBKDF2 password hash (secure and fast - RECOMMENDED)
        User user = new User(username, email, firstName + " " + lastName, region);
        user.setPasswordHash(encryptionService.hashPasswordPBKDF2(password));
        user.setEmployeeId(String.format("%06d", userIndex + 10000));
        user.setDepartment(department);
        user.setTitle(title);
        user.setPhoneNumber(String.format("+1-555-%04d", userIndex + 2000));
        user.setIsActive(true);
        user.setCreatedDate(LocalDateTime.now().minusDays(userIndex % 365)); // Spread creation dates
        user.setLastLogin(null); // Will be set on first login
        
        return user;
    }
    
    /**
     * Authenticate user against mock LDAP directory
     * Simulates LDAP bind operation
     */
    public boolean authenticateUser(String username, String password) {
        // Add delay to simulate LDAP network latency (50-100ms)
        simulateLdapLatency();
        
        User user = ldapDirectory.get(username);
        if (user == null) {
            logger.debug("Mock LDAP: User not found: {}", username);
            return false;
        }
        
        boolean isValid = encryptionService.verifyPasswordUniversal(password, user.getPasswordHash());
        
        if (isValid) {
            logger.debug("Mock LDAP: Authentication successful for user: {}", username);
        } else {
            logger.debug("Mock LDAP: Authentication failed for user: {}", username);
        }
        
        return isValid;
    }
    
    /**
     * Load user from mock LDAP directory
     * Simulates LDAP search operation
     */
    public User loadUserFromLdap(String username) {
        // Add delay to simulate LDAP network latency
        simulateLdapLatency();
        
        User user = ldapDirectory.get(username);
        
        if (user != null) {
            logger.debug("Mock LDAP: User loaded: {} ({})", username, user.getDisplayName());
            return cloneUser(user); // Return a copy to avoid reference issues
        } else {
            logger.debug("Mock LDAP: User not found: {}", username);
            return null;
        }
    }
    
    /**
     * Simulate LDAP network latency (50-100ms realistic delay)
     */
    private void simulateLdapLatency() {
        try {
            // Random delay between 50-100ms (typical LDAP response time)
            Thread.sleep(50 + (int)(Math.random() * 50));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
    
    /**
     * Clone user object to avoid reference issues
     */
    private User cloneUser(User original) {
        User clone = new User(original.getUsername(), original.getEmail(), 
                            original.getDisplayName(), original.getRegion());
        clone.setPasswordHash(original.getPasswordHash());
        clone.setEmployeeId(original.getEmployeeId());
        clone.setDepartment(original.getDepartment());
        clone.setTitle(original.getTitle());
        clone.setPhoneNumber(original.getPhoneNumber());
        clone.setIsActive(original.getIsActive());
        clone.setCreatedDate(original.getCreatedDate());
        clone.setLastLogin(original.getLastLogin());
        return clone;
    }
    
    /**
     * Get password for any test user (for testing purposes)
     */
    public String getPasswordForUser(String username) {
        if (!username.startsWith("testuser") || username.length() != 11) {
            return null;
        }
        
        try {
            // Extract last digit from username
            int lastDigit = Character.getNumericValue(username.charAt(10));
            return PASSWORDS[lastDigit];
        } catch (Exception e) {
            return null;
        }
    }
    
    /**
     * Get directory statistics
     */
    public MockLdapStatistics getStatistics() {
        return new MockLdapStatistics(
            ldapDirectory.size(),
            calculatePasswordDistribution(),
            calculateRegionalDistribution(),
            calculateDepartmentDistribution()
        );
    }
    
    private int[] calculatePasswordDistribution() {
        int[] distribution = new int[10];
        for (User user : ldapDirectory.values()) {
            String username = user.getUsername();
            if (username.startsWith("testuser") && username.length() == 11) {
                int lastDigit = Character.getNumericValue(username.charAt(10));
                distribution[lastDigit]++;
            }
        }
        return distribution;
    }
    
    private int[] calculateRegionalDistribution() {
        int[] distribution = new int[REGIONS.length];
        for (User user : ldapDirectory.values()) {
            for (int i = 0; i < REGIONS.length; i++) {
                if (REGIONS[i].equals(user.getRegion())) {
                    distribution[i]++;
                    break;
                }
            }
        }
        return distribution;
    }
    
    private int[] calculateDepartmentDistribution() {
        int[] distribution = new int[DEPARTMENTS.length];
        for (User user : ldapDirectory.values()) {
            for (int i = 0; i < DEPARTMENTS.length; i++) {
                if (DEPARTMENTS[i].equals(user.getDepartment())) {
                    distribution[i]++;
                    break;
                }
            }
        }
        return distribution;
    }
    
    /**
     * Mock LDAP Statistics
     */
    public static class MockLdapStatistics {
        private final int totalUsers;
        private final int[] passwordDistribution;
        private final int[] regionalDistribution;
        private final int[] departmentDistribution;
        
        public MockLdapStatistics(int totalUsers, int[] passwordDistribution,
                                int[] regionalDistribution, int[] departmentDistribution) {
            this.totalUsers = totalUsers;
            this.passwordDistribution = passwordDistribution;
            this.regionalDistribution = regionalDistribution;
            this.departmentDistribution = departmentDistribution;
        }
        
        public int getTotalUsers() { return totalUsers; }
        public int[] getPasswordDistribution() { return passwordDistribution; }
        public int[] getRegionalDistribution() { return regionalDistribution; }
        public int[] getDepartmentDistribution() { return departmentDistribution; }
        
        @Override
        public String toString() {
            StringBuilder sb = new StringBuilder("Mock LDAP Statistics:\n");
            sb.append("Total Users: ").append(totalUsers).append("\n");
            
            sb.append("Password Distribution (by last digit):\n");
            for (int i = 0; i < passwordDistribution.length; i++) {
                sb.append(String.format("  TestPass%d!: %d users\n", i, passwordDistribution[i]));
            }
            
            return sb.toString();
        }
    }
}