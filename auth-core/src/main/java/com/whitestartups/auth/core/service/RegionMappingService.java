package com.whitestartups.auth.core.service;

import jakarta.enterprise.context.ApplicationScoped;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Service for mapping users to geographical regions
 * Implements intelligent region assignment for optimal cache distribution
 */
@ApplicationScoped
public class RegionMappingService {
    private static final Logger logger = LoggerFactory.getLogger(RegionMappingService.class);
    
    // Region definitions with capacity and load factors
    private final Map<String, RegionInfo> regions = new ConcurrentHashMap<>();
    private final Map<String, String> userRegionCache = new ConcurrentHashMap<>();
    
    public RegionMappingService() {
        initializeRegions();
    }
    
    /**
     * Initialize available regions with their characteristics
     */
    private void initializeRegions() {
        regions.put("US-EAST", new RegionInfo("US-EAST", "us-east-1", 1000000, 0.7));
        regions.put("US-WEST", new RegionInfo("US-WEST", "us-west-2", 800000, 0.6));
        regions.put("EU-WEST", new RegionInfo("EU-WEST", "eu-west-1", 600000, 0.5));
        regions.put("ASIA-PAC", new RegionInfo("ASIA-PAC", "ap-southeast-1", 400000, 0.4));
        regions.put("CANADA", new RegionInfo("CANADA", "ca-central-1", 200000, 0.3));
        regions.put("AUSTRALIA", new RegionInfo("AUSTRALIA", "ap-southeast-2", 150000, 0.2));
        
        logger.info("Initialized {} regions for user mapping", regions.size());
    }
    
    /**
     * Determine optimal region for a user based on various factors
     */
    public String determineOptimalRegion(String username, String email, String ldapDn) {
        // Check cache first
        String cachedRegion = userRegionCache.get(username);
        if (cachedRegion != null) {
            return cachedRegion;
        }
        
        String assignedRegion = calculateRegionFromHeuristics(username, email, ldapDn);
        
        // Cache the result
        userRegionCache.put(username, assignedRegion);
        
        logger.debug("Assigned user {} to region {}", username, assignedRegion);
        return assignedRegion;
    }
    
    /**
     * Calculate region using multiple heuristics
     */
    private String calculateRegionFromHeuristics(String username, String email, String ldapDn) {
        // Heuristic 1: Email domain geography
        String domainRegion = getRegionFromEmailDomain(email);
        if (domainRegion != null) {
            return domainRegion;
        }
        
        // Heuristic 2: LDAP DN organizational unit
        String ldapRegion = getRegionFromLdapDn(ldapDn);
        if (ldapRegion != null) {
            return ldapRegion;
        }
        
        // Heuristic 3: Username patterns
        String usernameRegion = getRegionFromUsername(username);
        if (usernameRegion != null) {
            return usernameRegion;
        }
        
        // Heuristic 4: Load balancing - assign to least loaded region
        return getLeastLoadedRegion();
    }
    
    /**
     * Extract region from email domain
     */
    private String getRegionFromEmailDomain(String email) {
        if (email == null) return null;
        
        String domain = email.substring(email.lastIndexOf('@') + 1).toLowerCase();
        
        // Common patterns for regional email domains
        if (domain.contains(".us") || domain.contains("america") || domain.endsWith(".com")) {
            return "US-EAST"; // Default US region
        } else if (domain.contains(".ca") || domain.contains("canada")) {
            return "CANADA";
        } else if (domain.contains(".eu") || domain.contains(".de") || domain.contains(".fr") || 
                   domain.contains(".uk") || domain.contains(".nl")) {
            return "EU-WEST";
        } else if (domain.contains(".au")) {
            return "AUSTRALIA";
        } else if (domain.contains(".jp") || domain.contains(".sg") || domain.contains(".kr")) {
            return "ASIA-PAC";
        }
        
        return null;
    }
    
    /**
     * Extract region from LDAP DN organizational structure
     */
    private String getRegionFromLdapDn(String ldapDn) {
        if (ldapDn == null) return null;
        
        String dn = ldapDn.toLowerCase();
        
        // Look for organizational unit patterns
        if (dn.contains("ou=americas") || dn.contains("ou=usa")) {
            return "US-EAST";
        } else if (dn.contains("ou=europe") || dn.contains("ou=emea")) {
            return "EU-WEST";
        } else if (dn.contains("ou=asia") || dn.contains("ou=apac")) {
            return "ASIA-PAC";
        } else if (dn.contains("ou=canada")) {
            return "CANADA";
        } else if (dn.contains("ou=australia") || dn.contains("ou=oceania")) {
            return "AUSTRALIA";
        }
        
        // Look for city/country codes in DN
        if (dn.contains("c=us") || dn.contains("l=newyork") || dn.contains("l=chicago")) {
            return "US-EAST";
        } else if (dn.contains("l=seattle") || dn.contains("l=portland") || dn.contains("l=losangeles")) {
            return "US-WEST";
        }
        
        return null;
    }
    
    /**
     * Extract region hints from username patterns
     */
    private String getRegionFromUsername(String username) {
        if (username == null) return null;
        
        String lower = username.toLowerCase();
        
        // Common regional prefixes/suffixes in corporate usernames
        if (lower.startsWith("us") || lower.endsWith("us")) {
            return "US-EAST";
        } else if (lower.startsWith("eu") || lower.endsWith("eu")) {
            return "EU-WEST";
        } else if (lower.startsWith("asia") || lower.endsWith("asia")) {
            return "ASIA-PAC";
        } else if (lower.startsWith("ca") || lower.endsWith("ca")) {
            return "CANADA";
        } else if (lower.startsWith("au") || lower.endsWith("au")) {
            return "AUSTRALIA";
        }
        
        return null;
    }
    
    /**
     * Get the region with the lowest current load
     */
    private String getLeastLoadedRegion() {
        return regions.entrySet().stream()
                .min((e1, e2) -> Double.compare(e1.getValue().currentLoad, e2.getValue().currentLoad))
                .map(Map.Entry::getKey)
                .orElse("US-EAST"); // Default fallback
    }
    
    /**
     * Update load statistics for a region
     */
    public void updateRegionLoad(String regionCode, int userCount) {
        RegionInfo region = regions.get(regionCode);
        if (region != null) {
            region.currentLoad = (double) userCount / region.capacity;
            logger.debug("Updated region {} load to {}", regionCode, region.currentLoad);
        }
    }
    
    /**
     * Get all available regions
     */
    public Map<String, RegionInfo> getAllRegions() {
        return new HashMap<>(regions);
    }
    
    /**
     * Get region information
     */
    public RegionInfo getRegionInfo(String regionCode) {
        return regions.get(regionCode);
    }
    
    /**
     * Clear user region cache (useful for testing)
     */
    public void clearCache() {
        userRegionCache.clear();
        logger.info("Cleared user region cache");
    }
    
    /**
     * Get cache statistics
     */
    public String getCacheStats() {
        return String.format("Cached regions for %d users", userRegionCache.size());
    }
    
    /**
     * Region information class
     */
    public static class RegionInfo {
        public final String code;
        public final String awsRegion;
        public final int capacity;
        public double currentLoad;
        
        public RegionInfo(String code, String awsRegion, int capacity, double initialLoad) {
            this.code = code;
            this.awsRegion = awsRegion;
            this.capacity = capacity;
            this.currentLoad = initialLoad;
        }
        
        @Override
        public String toString() {
            return String.format("Region{code='%s', aws='%s', capacity=%d, load=%.2f}", 
                               code, awsRegion, capacity, currentLoad);
        }
    }
}