package com.whitestartups.auth.core.service;

import com.whitestartups.auth.core.model.User;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import jakarta.ejb.Schedule;
import jakarta.ejb.Singleton;
import jakarta.ejb.Startup;
import jakarta.ejb.TransactionAttribute;
import jakarta.ejb.TransactionAttributeType;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Singleton EJB that loads LDAP users into the database cache.
 * This service implements intelligent warm-up strategies to ensure
 * users are pre-loaded in their regional cache for millisecond authentication.
 */
@Singleton
@Startup
public class LdapUserLoaderService {
    private static final Logger logger = LoggerFactory.getLogger(LdapUserLoaderService.class);

    @PersistenceContext
    private EntityManager entityManager;

    @Inject
    private UserEncryptionService encryptionService;

    @Inject
    private RegionMappingService regionMappingService;
    
    @Inject
    private MockLdapService mockLdapService;

    private final AtomicLong totalUsersLoaded = new AtomicLong(0);
    private final AtomicInteger currentBatchSize = new AtomicInteger(1000);
    private volatile boolean isLoading = false;

    @PostConstruct
    public void initialize() {
        logger.info("🔧 LDAP User Loader Service initializing with Mock LDAP...");
        
        // Initialize mock LDAP with 1000 test users
        mockLdapService.initializeTestUsers();
        
        // Display Mock LDAP statistics
        MockLdapService.MockLdapStatistics stats = mockLdapService.getStatistics();
        logger.info("📊 Mock LDAP Stats: {}", stats);
        
        // Perform initial load on startup
        performIntelligentWarmup();
        
        logger.info("✅ LDAP User Loader Service initialized. Database users: {}", 
                   getTotalUserCount());
        logger.info("🔑 Test any user: testuser### with TestPass{lastDigit}!");
    }

    /**
     * Scheduled method that runs daily to refresh user cache
     * Uses intelligent loading based on usage patterns
     */
    @Schedule(hour = "2", minute = "0", second = "0", persistent = false)
    @TransactionAttribute(TransactionAttributeType.NOT_SUPPORTED)
    public void scheduledUserRefresh() {
        logger.info("Starting scheduled user refresh...");
        performIntelligentWarmup();
    }

    /**
     * Intelligent warm-up that prioritizes users based on region and usage patterns
     */
    public void performIntelligentWarmup() {
        if (isLoading) {
            logger.warn("User loading already in progress, skipping...");
            return;
        }

        isLoading = true;
        try {
            logger.info("Starting intelligent LDAP user warm-up...");
            
            // Get current user count for comparison
            long currentCount = getTotalUserCount();
            logger.info("Current user count in cache: {}", currentCount);

            // Load users by region priority
            loadUsersByRegionPriority();
            
            long newCount = getTotalUserCount();
            logger.info("User warm-up completed. Users loaded: {} -> {}", 
                       currentCount, newCount);
            
            totalUsersLoaded.set(newCount);
            
        } catch (Exception e) {
            logger.error("Error during intelligent warm-up", e);
        } finally {
            isLoading = false;
        }
    }

    /**
     * Loads users prioritizing by region to optimize geographical distribution
     */
    private void loadUsersByRegionPriority() {
        logger.info("🌍 Loading 1000 test users from Mock LDAP into database cache...");
        
        // Load all 1000 test users from mock LDAP
        int usersLoaded = 0;
        
        for (int i = 0; i < 1000; i++) {
            try {
                String username = String.format("testuser%03d", i);
                User ldapUser = mockLdapService.loadUserFromLdap(username);
                
                if (ldapUser != null) {
                    // Check if user already exists in database
                    User existingUser = findUserByUsername(username);
                    
                    if (existingUser == null) {
                        // Create new user in database
                        entityManager.persist(ldapUser);
                        usersLoaded++;
                        logger.debug("Loaded new user from Mock LDAP: {}", username);
                    } else {
                        // Update existing user
                        existingUser.setEmail(ldapUser.getEmail());
                        existingUser.setDisplayName(ldapUser.getDisplayName());
                        existingUser.setRegion(ldapUser.getRegion());
                        existingUser.setPasswordHash(ldapUser.getPasswordHash());
                        existingUser.setIsActive(true);
                        entityManager.merge(existingUser);
                        logger.debug("Updated existing user from Mock LDAP: {}", username);
                    }
                    
                    // Batch processing for performance
                    if ((i + 1) % 100 == 0) {
                        entityManager.flush();
                        entityManager.clear();
                        logger.info("Processed {} users from Mock LDAP", i + 1);
                    }
                }
            } catch (Exception e) {
                logger.error("Failed to load user testuser{:03d} from Mock LDAP", i, e);
            }
        }
        
        // Final flush
        entityManager.flush();
        entityManager.clear();
        
        logger.info("✅ Completed loading {} users from Mock LDAP to database", usersLoaded);
    }

    /**
     * Load a single user from Mock LDAP (on-demand)
     */
    public User loadSingleUserFromLdap(String username) {
        logger.debug("Loading single user from Mock LDAP: {}", username);
        
        try {
            User ldapUser = mockLdapService.loadUserFromLdap(username);
            
            if (ldapUser != null) {
                // Check if user already exists in database
                User existingUser = findUserByUsername(username);
                
                if (existingUser == null) {
                    // Create new user in database
                    entityManager.persist(ldapUser);
                    logger.info("Loaded new user from Mock LDAP: {}", username);
                    return ldapUser;
                } else {
                    // Update existing user
                    existingUser.setEmail(ldapUser.getEmail());
                    existingUser.setDisplayName(ldapUser.getDisplayName());
                    existingUser.setRegion(ldapUser.getRegion());
                    existingUser.setPasswordHash(ldapUser.getPasswordHash());
                    existingUser.setIsActive(true);
                    entityManager.merge(existingUser);
                    logger.info("Updated existing user from Mock LDAP: {}", username);
                    return existingUser;
                }
            } else {
                logger.debug("User not found in Mock LDAP: {}", username);
                return null;
            }
            
        } catch (Exception e) {
            logger.error("Error loading user from Mock LDAP: {}", username, e);
            return null;
        }
    }

    /**
     * Authenticate user using Mock LDAP
     */
    public boolean authenticateUser(String username, String password) {
        logger.debug("Authenticating user via Mock LDAP: {}", username);
        return mockLdapService.authenticateUser(username, password);
    }
    
    /**
     * Get password for test user (for testing purposes)
     */
    public String getTestPassword(String username) {
        return mockLdapService.getPasswordForUser(username);
    }

    /**
     * Find user by username using named query
     */
    private User findUserByUsername(String username) {
        try {
            return entityManager.createNamedQuery("User.findByUsername", User.class)
                    .setParameter("username", username)
                    .getSingleResult();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Get total user count in cache
     */
    public long getTotalUserCount() {
        return entityManager.createNamedQuery("User.countAll", Long.class)
                .getSingleResult();
    }

    /**
     * Manual trigger for user loading (useful for testing)
     */
    public void triggerUserLoad() {
        logger.info("Manual user load triggered");
        performIntelligentWarmup();
    }

    /**
     * Get loading statistics
     */
    public String getLoadingStats() {
        return String.format("Total Users: %d, Currently Loading: %s, Batch Size: %d",
                           totalUsersLoaded.get(), isLoading, currentBatchSize.get());
    }

    @PreDestroy
    public void cleanup() {
        logger.info("LDAP User Loader Service shutting down...");
    }
}