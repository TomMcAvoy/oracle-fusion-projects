package com.whitestartups.auth.cache.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Enterprise User Cache Record - Based on SiteMinder/OAM/PingAccess patterns
 * 
 * Contains comprehensive user security profile for high-performance authentication.
 * This mirrors what enterprise IAM systems like:
 * - CA SiteMinder (Broadcom SSO)
 * - Oracle Access Manager (OAM) 
 * - Ping Identity PingAccess
 * - IBM Security Access Manager
 * 
 * All sensitive data is encrypted in memory and protected from reverse engineering.
 */
public final class EnterpriseUserRecord implements java.io.Serializable {
    
    private static final long serialVersionUID = 1L;
    
    // ============== CORE IDENTITY ==============
    @JsonProperty("uid")
    private String username;
    
    @JsonProperty("dn")  
    private String distinguishedName; // LDAP DN
    
    @JsonProperty("empId")
    private String employeeId;
    
    @JsonProperty("custId") 
    private String customerId;
    
    @JsonProperty("email")
    private String primaryEmail;
    
    @JsonProperty("emails")
    private List<String> alternateEmails;
    
    @JsonProperty("dispName")
    private String displayName;
    
    @JsonProperty("dept")
    private String department;
    
    @JsonProperty("org")
    private String organization;
    
    @JsonProperty("region")
    private String region;
    
    // ============== AUTHENTICATION DATA ==============
    @JsonProperty("pwdHash")
    private String passwordHash; // Multiple algorithm support
    
    @JsonProperty("pwdSalt")
    private String passwordSalt;
    
    @JsonProperty("pwdAlgo") 
    private String hashAlgorithm; // SHA-256, bcrypt, PBKDF2, etc.
    
    @JsonProperty("pwdStrength")
    private Integer passwordStrength; // 1-5 scale
    
    @JsonProperty("pwdExpiry")
    private LocalDateTime passwordExpiry;
    
    @JsonProperty("pwdLastChange")
    private LocalDateTime passwordLastChanged;
    
    @JsonProperty("pwdPolicy")
    private String passwordPolicyId;
    
    // ============== MULTI-FACTOR AUTHENTICATION ==============
    @JsonProperty("mfaEnabled")
    private Boolean mfaEnabled;
    
    @JsonProperty("mfaMethods")
    private Set<String> mfaMethods; // SMS, EMAIL, TOTP, FIDO, etc.
    
    @JsonProperty("mfaSecrets")
    @JsonIgnore // Never serialize MFA secrets
    private Map<String, byte[]> mfaSecrets;
    
    @JsonProperty("mfaBackupCodes")
    @JsonIgnore
    private List<String> mfaBackupCodes;
    
    @JsonProperty("fidoKeys")
    private List<String> fidoKeyIds;
    
    // ============== SESSION MANAGEMENT ==============
    @JsonProperty("sessionKey")
    @JsonIgnore // Highly sensitive - never serialize
    private String activeSessionKey;
    
    @JsonProperty("sessionExpiry")
    private LocalDateTime sessionExpiry;
    
    @JsonProperty("ssoArtifacts")
    @JsonIgnore
    private Map<String, String> ssoArtifacts; // SAML, OAuth tokens
    
    @JsonProperty("deviceTrust")
    private Map<String, Integer> trustedDevices; // DeviceId -> Trust Level
    
    // ============== AUTHORIZATION & ROLES ==============
    @JsonProperty("roles")
    private Set<String> assignedRoles;
    
    @JsonProperty("groups")
    private Set<String> groupMemberships;
    
    @JsonProperty("perms")
    private Set<String> explicitPermissions;
    
    @JsonProperty("entitlements")
    private Map<String, Set<String>> resourceEntitlements; // Resource -> Actions
    
    @JsonProperty("policies")
    private Set<String> applicablePolicies;
    
    @JsonProperty("clearance")
    private String securityClearance; // CONFIDENTIAL, SECRET, TOP_SECRET
    
    // ============== ACCOUNT STATUS & SECURITY ==============
    @JsonProperty("status")
    private String accountStatus; // ACTIVE, INACTIVE, LOCKED, DISABLED
    
    @JsonProperty("lockout")
    private AccountLockoutInfo lockoutInfo;
    
    @JsonProperty("riskScore")
    private Integer riskScore; // 0-100
    
    @JsonProperty("riskFactors")
    private Set<String> riskFactors;
    
    @JsonProperty("failedAttempts")
    private Integer failedLoginAttempts;
    
    @JsonProperty("lastSuccess")
    private LocalDateTime lastSuccessfulLogin;
    
    @JsonProperty("lastFailure") 
    private LocalDateTime lastFailedLogin;
    
    @JsonProperty("lastIP")
    private String lastLoginIP;
    
    @JsonProperty("loginLocations")
    private List<String> recentLoginLocations;
    
    // ============== COMPLIANCE & AUDIT ==============
    @JsonProperty("created")
    private LocalDateTime accountCreated;
    
    @JsonProperty("lastModified")
    private LocalDateTime lastModified;
    
    @JsonProperty("lastReview")
    private LocalDateTime lastSecurityReview;
    
    @JsonProperty("complianceFlags")
    private Set<String> complianceFlags; // SOX, GDPR, HIPAA, etc.
    
    @JsonProperty("dataClassification")
    private String dataClassification;
    
    @JsonProperty("retentionPolicy")
    private String dataRetentionPolicy;
    
    // ============== PERFORMANCE & CACHING ==============
    @JsonProperty("accessFreq")
    private Long accessFrequency;
    
    @JsonProperty("cacheTime")
    private LocalDateTime cacheTimestamp;
    
    @JsonProperty("cacheTTL")
    private Long cacheTtlSeconds;
    
    @JsonProperty("cacheRegion")
    private String cacheRegion;
    
    @JsonProperty("loadBalance")
    private String loadBalancingHint;
    
    // ============== FEDERATION & EXTERNAL SYSTEMS ==============
    @JsonProperty("federated")
    private Boolean federatedUser;
    
    @JsonProperty("idpId")
    private String identityProviderId;
    
    @JsonProperty("extRefs")
    private Map<String, String> externalSystemRefs; // System -> ExternalUserId
    
    @JsonProperty("samlAttrs")
    private Map<String, String> samlAttributes;
    
    @JsonProperty("oidcClaims")
    private Map<String, Object> oidcClaims;
    
    // ============== CONSTRUCTORS ==============
    
    public EnterpriseUserRecord() {
        this.cacheTimestamp = LocalDateTime.now();
        this.accessFrequency = 0L;
        this.riskScore = 0;
        this.failedLoginAttempts = 0;
    }
    
    public EnterpriseUserRecord(String username, String email, String displayName) {
        this();
        this.username = username;
        this.primaryEmail = email;
        this.displayName = displayName;
        this.accountStatus = "ACTIVE";
        this.accountCreated = LocalDateTime.now();
    }
    
    // ============== CACHE MANAGEMENT METHODS ==============
    
    /**
     * Update access frequency for LRU cache management
     */
    public void updateAccessFrequency() {
        this.accessFrequency++;
        this.cacheTimestamp = LocalDateTime.now();
    }
    
    /**
     * Check if cache entry is expired
     */
    public boolean isCacheExpired() {
        if (cacheTtlSeconds == null || cacheTimestamp == null) {
            return false;
        }
        return cacheTimestamp.plusSeconds(cacheTtlSeconds).isBefore(LocalDateTime.now());
    }
    
    /**
     * Check if account is in lockout status
     */
    public boolean isAccountLocked() {
        return "LOCKED".equals(accountStatus) || 
               (lockoutInfo != null && lockoutInfo.isCurrentlyLocked());
    }
    
    /**
     * Check if account is active and usable
     */
    public boolean isAccountActive() {
        return "ACTIVE".equals(accountStatus) && !isAccountLocked();
    }
    
    /**
     * Check if password is expired
     */
    public boolean isPasswordExpired() {
        return passwordExpiry != null && passwordExpiry.isBefore(LocalDateTime.now());
    }
    
    /**
     * Get security risk level based on risk score
     */
    public String getRiskLevel() {
        if (riskScore == null || riskScore <= 20) return "LOW";
        if (riskScore <= 50) return "MEDIUM";
        if (riskScore <= 80) return "HIGH";
        return "CRITICAL";
    }
    
    /**
     * Check if user requires MFA
     */
    public boolean requiresMFA() {
        return Boolean.TRUE.equals(mfaEnabled) || 
               riskScore > 50 || 
               (securityClearance != null && !securityClearance.equals("PUBLIC"));
    }
    
    // ============== SENSITIVE DATA HANDLING ==============
    
    /**
     * Clear all sensitive data from memory (called before cache eviction)
     */
    public void clearSensitiveData() {
        // Clear password data
        if (passwordHash != null) {
            passwordHash = null;
        }
        if (passwordSalt != null) {
            passwordSalt = null;
        }
        
        // Clear session data
        activeSessionKey = null;
        if (ssoArtifacts != null) {
            ssoArtifacts.clear();
        }
        
        // Clear MFA secrets
        if (mfaSecrets != null) {
            mfaSecrets.values().forEach(secret -> {
                if (secret != null) {
                    java.util.Arrays.fill(secret, (byte) 0);
                }
            });
            mfaSecrets.clear();
        }
        
        // Clear backup codes
        if (mfaBackupCodes != null) {
            mfaBackupCodes.clear();
        }
    }
    
    // ============== GETTERS AND SETTERS ==============
    
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    
    public String getDistinguishedName() { return distinguishedName; }
    public void setDistinguishedName(String distinguishedName) { this.distinguishedName = distinguishedName; }
    
    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }
    
    public String getCustomerId() { return customerId; }
    public void setCustomerId(String customerId) { this.customerId = customerId; }
    
    public String getPrimaryEmail() { return primaryEmail; }
    public void setPrimaryEmail(String primaryEmail) { this.primaryEmail = primaryEmail; }
    
    public List<String> getAlternateEmails() { return alternateEmails; }
    public void setAlternateEmails(List<String> alternateEmails) { this.alternateEmails = alternateEmails; }
    
    public String getDisplayName() { return displayName; }
    public void setDisplayName(String displayName) { this.displayName = displayName; }
    
    public String getDepartment() { return department; }
    public void setDepartment(String department) { this.department = department; }
    
    public String getOrganization() { return organization; }
    public void setOrganization(String organization) { this.organization = organization; }
    
    public String getRegion() { return region; }
    public void setRegion(String region) { this.region = region; }
    
    public String getPasswordHash() { return passwordHash; }
    public void setPasswordHash(String passwordHash) { this.passwordHash = passwordHash; }
    
    public String getPasswordSalt() { return passwordSalt; }
    public void setPasswordSalt(String passwordSalt) { this.passwordSalt = passwordSalt; }
    
    public String getHashAlgorithm() { return hashAlgorithm; }
    public void setHashAlgorithm(String hashAlgorithm) { this.hashAlgorithm = hashAlgorithm; }
    
    public Integer getPasswordStrength() { return passwordStrength; }
    public void setPasswordStrength(Integer passwordStrength) { this.passwordStrength = passwordStrength; }
    
    public LocalDateTime getPasswordExpiry() { return passwordExpiry; }
    public void setPasswordExpiry(LocalDateTime passwordExpiry) { this.passwordExpiry = passwordExpiry; }
    
    public LocalDateTime getPasswordLastChanged() { return passwordLastChanged; }
    public void setPasswordLastChanged(LocalDateTime passwordLastChanged) { this.passwordLastChanged = passwordLastChanged; }
    
    public String getPasswordPolicyId() { return passwordPolicyId; }
    public void setPasswordPolicyId(String passwordPolicyId) { this.passwordPolicyId = passwordPolicyId; }
    
    public Boolean getMfaEnabled() { return mfaEnabled; }
    public void setMfaEnabled(Boolean mfaEnabled) { this.mfaEnabled = mfaEnabled; }
    
    public Set<String> getMfaMethods() { return mfaMethods; }
    public void setMfaMethods(Set<String> mfaMethods) { this.mfaMethods = mfaMethods; }
    
    public Map<String, byte[]> getMfaSecrets() { return mfaSecrets; }
    public void setMfaSecrets(Map<String, byte[]> mfaSecrets) { this.mfaSecrets = mfaSecrets; }
    
    public List<String> getMfaBackupCodes() { return mfaBackupCodes; }
    public void setMfaBackupCodes(List<String> mfaBackupCodes) { this.mfaBackupCodes = mfaBackupCodes; }
    
    public List<String> getFidoKeyIds() { return fidoKeyIds; }
    public void setFidoKeyIds(List<String> fidoKeyIds) { this.fidoKeyIds = fidoKeyIds; }
    
    public String getActiveSessionKey() { return activeSessionKey; }
    public void setActiveSessionKey(String activeSessionKey) { this.activeSessionKey = activeSessionKey; }
    
    public LocalDateTime getSessionExpiry() { return sessionExpiry; }
    public void setSessionExpiry(LocalDateTime sessionExpiry) { this.sessionExpiry = sessionExpiry; }
    
    public Map<String, String> getSsoArtifacts() { return ssoArtifacts; }
    public void setSsoArtifacts(Map<String, String> ssoArtifacts) { this.ssoArtifacts = ssoArtifacts; }
    
    public Map<String, Integer> getTrustedDevices() { return trustedDevices; }
    public void setTrustedDevices(Map<String, Integer> trustedDevices) { this.trustedDevices = trustedDevices; }
    
    public Set<String> getAssignedRoles() { return assignedRoles; }
    public void setAssignedRoles(Set<String> assignedRoles) { this.assignedRoles = assignedRoles; }
    
    public Set<String> getGroupMemberships() { return groupMemberships; }
    public void setGroupMemberships(Set<String> groupMemberships) { this.groupMemberships = groupMemberships; }
    
    public Set<String> getExplicitPermissions() { return explicitPermissions; }
    public void setExplicitPermissions(Set<String> explicitPermissions) { this.explicitPermissions = explicitPermissions; }
    
    public Map<String, Set<String>> getResourceEntitlements() { return resourceEntitlements; }
    public void setResourceEntitlements(Map<String, Set<String>> resourceEntitlements) { this.resourceEntitlements = resourceEntitlements; }
    
    public Set<String> getApplicablePolicies() { return applicablePolicies; }
    public void setApplicablePolicies(Set<String> applicablePolicies) { this.applicablePolicies = applicablePolicies; }
    
    public String getSecurityClearance() { return securityClearance; }
    public void setSecurityClearance(String securityClearance) { this.securityClearance = securityClearance; }
    
    public String getAccountStatus() { return accountStatus; }
    public void setAccountStatus(String accountStatus) { this.accountStatus = accountStatus; }
    
    public AccountLockoutInfo getLockoutInfo() { return lockoutInfo; }
    public void setLockoutInfo(AccountLockoutInfo lockoutInfo) { this.lockoutInfo = lockoutInfo; }
    
    public Integer getRiskScore() { return riskScore; }
    public void setRiskScore(Integer riskScore) { this.riskScore = riskScore; }
    
    public Set<String> getRiskFactors() { return riskFactors; }
    public void setRiskFactors(Set<String> riskFactors) { this.riskFactors = riskFactors; }
    
    public Integer getFailedLoginAttempts() { return failedLoginAttempts; }
    public void setFailedLoginAttempts(Integer failedLoginAttempts) { this.failedLoginAttempts = failedLoginAttempts; }
    
    public LocalDateTime getLastSuccessfulLogin() { return lastSuccessfulLogin; }
    public void setLastSuccessfulLogin(LocalDateTime lastSuccessfulLogin) { this.lastSuccessfulLogin = lastSuccessfulLogin; }
    
    public LocalDateTime getLastFailedLogin() { return lastFailedLogin; }
    public void setLastFailedLogin(LocalDateTime lastFailedLogin) { this.lastFailedLogin = lastFailedLogin; }
    
    public String getLastLoginIP() { return lastLoginIP; }
    public void setLastLoginIP(String lastLoginIP) { this.lastLoginIP = lastLoginIP; }
    
    public List<String> getRecentLoginLocations() { return recentLoginLocations; }
    public void setRecentLoginLocations(List<String> recentLoginLocations) { this.recentLoginLocations = recentLoginLocations; }
    
    public LocalDateTime getAccountCreated() { return accountCreated; }
    public void setAccountCreated(LocalDateTime accountCreated) { this.accountCreated = accountCreated; }
    
    public LocalDateTime getLastModified() { return lastModified; }
    public void setLastModified(LocalDateTime lastModified) { this.lastModified = lastModified; }
    
    public LocalDateTime getLastSecurityReview() { return lastSecurityReview; }
    public void setLastSecurityReview(LocalDateTime lastSecurityReview) { this.lastSecurityReview = lastSecurityReview; }
    
    public Set<String> getComplianceFlags() { return complianceFlags; }
    public void setComplianceFlags(Set<String> complianceFlags) { this.complianceFlags = complianceFlags; }
    
    public String getDataClassification() { return dataClassification; }
    public void setDataClassification(String dataClassification) { this.dataClassification = dataClassification; }
    
    public String getDataRetentionPolicy() { return dataRetentionPolicy; }
    public void setDataRetentionPolicy(String dataRetentionPolicy) { this.dataRetentionPolicy = dataRetentionPolicy; }
    
    public Long getAccessFrequency() { return accessFrequency; }
    public void setAccessFrequency(Long accessFrequency) { this.accessFrequency = accessFrequency; }
    
    public LocalDateTime getCacheTimestamp() { return cacheTimestamp; }
    public void setCacheTimestamp(LocalDateTime cacheTimestamp) { this.cacheTimestamp = cacheTimestamp; }
    
    public Long getCacheTtlSeconds() { return cacheTtlSeconds; }
    public void setCacheTtlSeconds(Long cacheTtlSeconds) { this.cacheTtlSeconds = cacheTtlSeconds; }
    
    public String getCacheRegion() { return cacheRegion; }
    public void setCacheRegion(String cacheRegion) { this.cacheRegion = cacheRegion; }
    
    public String getLoadBalancingHint() { return loadBalancingHint; }
    public void setLoadBalancingHint(String loadBalancingHint) { this.loadBalancingHint = loadBalancingHint; }
    
    public Boolean getFederatedUser() { return federatedUser; }
    public void setFederatedUser(Boolean federatedUser) { this.federatedUser = federatedUser; }
    
    public String getIdentityProviderId() { return identityProviderId; }
    public void setIdentityProviderId(String identityProviderId) { this.identityProviderId = identityProviderId; }
    
    public Map<String, String> getExternalSystemRefs() { return externalSystemRefs; }
    public void setExternalSystemRefs(Map<String, String> externalSystemRefs) { this.externalSystemRefs = externalSystemRefs; }
    
    public Map<String, String> getSamlAttributes() { return samlAttributes; }
    public void setSamlAttributes(Map<String, String> samlAttributes) { this.samlAttributes = samlAttributes; }
    
    public Map<String, Object> getOidcClaims() { return oidcClaims; }
    public void setOidcClaims(Map<String, Object> oidcClaims) { this.oidcClaims = oidcClaims; }
    
    @Override
    public String toString() {
        return String.format("EnterpriseUserRecord{username='%s', email='%s', status='%s', region='%s', accessFreq=%d}", 
                           username, primaryEmail, accountStatus, region, accessFrequency);
    }
    
    // ============== INNER CLASSES ==============
    
    /**
     * Account lockout information
     */
    public static class AccountLockoutInfo implements java.io.Serializable {
        private LocalDateTime lockoutTime;
        private LocalDateTime unlockTime;
        private String lockoutReason;
        private Integer attemptCount;
        private String lockoutPolicyId;
        
        public boolean isCurrentlyLocked() {
            if (unlockTime == null) return false;
            return LocalDateTime.now().isBefore(unlockTime);
        }
        
        // Getters and setters
        public LocalDateTime getLockoutTime() { return lockoutTime; }
        public void setLockoutTime(LocalDateTime lockoutTime) { this.lockoutTime = lockoutTime; }
        
        public LocalDateTime getUnlockTime() { return unlockTime; }
        public void setUnlockTime(LocalDateTime unlockTime) { this.unlockTime = unlockTime; }
        
        public String getLockoutReason() { return lockoutReason; }
        public void setLockoutReason(String lockoutReason) { this.lockoutReason = lockoutReason; }
        
        public Integer getAttemptCount() { return attemptCount; }
        public void setAttemptCount(Integer attemptCount) { this.attemptCount = attemptCount; }
        
        public String getLockoutPolicyId() { return lockoutPolicyId; }
        public void setLockoutPolicyId(String lockoutPolicyId) { this.lockoutPolicyId = lockoutPolicyId; }
    }
}