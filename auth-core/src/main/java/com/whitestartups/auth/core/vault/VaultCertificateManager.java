package com.whitestartups.auth.core.vault;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import javax.json.Json;
import javax.json.JsonObject;
import javax.json.JsonReader;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Base64;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Real-time certificate management with Vault integration
 * Retrieves and caches certificates from Vault with automatic refresh
 */
public class VaultCertificateManager {
    
    private static final Logger logger = LoggerFactory.getLogger(VaultCertificateManager.class);
    
    private static final String DEFAULT_VAULT_URL = "http://localhost:8200";
    private static final String DEFAULT_VAULT_TOKEN = "root";
    private static final long REFRESH_INTERVAL_MINUTES = 60;
    
    private final String vaultUrl;
    private final String vaultToken;
    private final ConcurrentHashMap<String, CertificateData> certificateCache;
    private final ScheduledExecutorService scheduler;
    
    private static VaultCertificateManager instance;
    
    public static synchronized VaultCertificateManager getInstance() {
        if (instance == null) {
            String vaultUrl = System.getProperty("vault.url", 
                System.getenv().getOrDefault("VAULT_ADDR", DEFAULT_VAULT_URL));
            String vaultToken = System.getProperty("vault.token",
                System.getenv().getOrDefault("VAULT_TOKEN", DEFAULT_VAULT_TOKEN));
            instance = new VaultCertificateManager(vaultUrl, vaultToken);
        }
        return instance;
    }
    
    private VaultCertificateManager(String vaultUrl, String vaultToken) {
        this.vaultUrl = vaultUrl;
        this.vaultToken = vaultToken;
        this.certificateCache = new ConcurrentHashMap<>();
        this.scheduler = Executors.newScheduledThreadPool(2);
        
        // Start automatic certificate refresh
        scheduler.scheduleAtFixedRate(this::refreshAllCertificates, 
            0, REFRESH_INTERVAL_MINUTES, TimeUnit.MINUTES);
        
        logger.info("VaultCertificateManager initialized with Vault URL: {}", vaultUrl);
    }
    
    /**
     * Get certificate content from Vault with caching
     */
    public String getCertificateContent(String service, String certType) {
        String key = service + ":" + certType;
        CertificateData cached = certificateCache.get(key);
        
        if (cached != null && !cached.isExpired()) {
            logger.debug("Returning cached certificate: {}", key);
            return cached.content;
        }
        
        try {
            String content = retrieveCertificateFromVault(service, certType);
            if (content != null) {
                certificateCache.put(key, new CertificateData(content));
                logger.info("Certificate retrieved from Vault: {}", key);
                return content;
            }
        } catch (Exception e) {
            logger.error("Failed to retrieve certificate {} from Vault", key, e);
        }
        
        // Return cached content if available, even if expired, as fallback
        if (cached != null) {
            logger.warn("Using expired cached certificate: {}", key);
            return cached.content;
        }
        
        throw new RuntimeException("Certificate not available: " + key);
    }
    
    /**
     * Write certificate to temporary file for application use
     */
    public Path writeCertificateToTempFile(String service, String certType, String suffix) {
        try {
            String content = getCertificateContent(service, certType);
            Path tempFile = Files.createTempFile("vault-cert-" + service + "-" + certType, suffix);
            
            // Handle binary data (base64 encoded keystores)
            if (certType.contains("jks") || certType.contains("p12")) {
                byte[] decoded = Base64.getDecoder().decode(content);
                Files.write(tempFile, decoded);
            } else {
                Files.write(tempFile, content.getBytes(StandardCharsets.UTF_8));
            }
            
            // Set restrictive permissions
            tempFile.toFile().setReadable(true, true);
            tempFile.toFile().setWritable(true, true);
            tempFile.toFile().setExecutable(false);
            
            logger.info("Certificate written to temporary file: {} -> {}", service + ":" + certType, tempFile);
            return tempFile;
        } catch (IOException e) {
            throw new RuntimeException("Failed to write certificate to temporary file", e);
        }
    }
    
    /**
     * Get X.509 Certificate object from Vault
     */
    public X509Certificate getX509Certificate(String service, String certType) {
        try {
            String pemContent = getCertificateContent(service, certType);
            CertificateFactory cf = CertificateFactory.getInstance("X.509");
            return (X509Certificate) cf.generateCertificate(
                new ByteArrayInputStream(pemContent.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new RuntimeException("Failed to create X.509 certificate", e);
        }
    }
    
    /**
     * Get private key from Vault
     */
    public PrivateKey getPrivateKey(String service, String keyType) {
        try {
            String pemContent = getCertificateContent(service, keyType);
            
            // Remove PEM headers and decode
            String privateKeyContent = pemContent
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replace("-----BEGIN RSA PRIVATE KEY-----", "")
                .replace("-----END RSA PRIVATE KEY-----", "")
                .replaceAll("\\s", "");
            
            byte[] decoded = Base64.getDecoder().decode(privateKeyContent);
            PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(decoded);
            KeyFactory keyFactory = KeyFactory.getInstance("RSA");
            return keyFactory.generatePrivate(keySpec);
        } catch (Exception e) {
            throw new RuntimeException("Failed to create private key", e);
        }
    }
    
    /**
     * Get MongoDB TLS configuration with real-time certificate retrieval
     */
    public MongoTLSConfig getMongoTLSConfig() {
        Path serverPem = writeCertificateToTempFile("mongodb", "server_pem", ".pem");
        Path caCert = writeCertificateToTempFile("mongodb", "ca_crt", ".crt");
        Path truststore = writeCertificateToTempFile("mongodb", "truststore_jks", ".jks");
        Path keystore = writeCertificateToTempFile("mongodb", "keystore_jks", ".jks");
        
        return new MongoTLSConfig(serverPem, caCert, truststore, keystore);
    }
    
    /**
     * Refresh all cached certificates
     */
    private void refreshAllCertificates() {
        logger.info("Refreshing all cached certificates from Vault...");
        certificateCache.keySet().forEach(key -> {
            try {
                String[] parts = key.split(":");
                if (parts.length == 2) {
                    String content = retrieveCertificateFromVault(parts[0], parts[1]);
                    if (content != null) {
                        certificateCache.put(key, new CertificateData(content));
                    }
                }
            } catch (Exception e) {
                logger.warn("Failed to refresh certificate: {}", key, e);
            }
        });
    }
    
    /**
     * Retrieve certificate from Vault API
     */
    private String retrieveCertificateFromVault(String service, String certType) throws IOException {
        String path = "/v1/secret/data/" + service + "-keys";
        URL url = new URL(vaultUrl + path);
        
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setRequestMethod("GET");
        connection.setRequestProperty("X-Vault-Token", vaultToken);
        connection.setConnectTimeout(5000);
        connection.setReadTimeout(10000);
        
        int responseCode = connection.getResponseCode();
        if (responseCode != 200) {
            logger.error("Vault API error: {} for {}", responseCode, path);
            return null;
        }
        
        try (InputStream is = connection.getInputStream();
             JsonReader reader = Json.createReader(is)) {
            JsonObject response = reader.readObject();
            JsonObject data = response.getJsonObject("data").getJsonObject("data");
            
            String encodedContent = data.getString(certType, null);
            if (encodedContent != null) {
                return new String(Base64.getDecoder().decode(encodedContent), StandardCharsets.UTF_8);
            }
        }
        
        return null;
    }
    
    /**
     * Shutdown certificate manager
     */
    public void shutdown() {
        scheduler.shutdown();
        try {
            if (!scheduler.awaitTermination(10, TimeUnit.SECONDS)) {
                scheduler.shutdownNow();
            }
        } catch (InterruptedException e) {
            scheduler.shutdownNow();
        }
        
        // Clean up temporary files
        certificateCache.clear();
        logger.info("VaultCertificateManager shutdown complete");
    }
    
    /**
     * Certificate data with expiration tracking
     */
    private static class CertificateData {
        final String content;
        final long timestamp;
        
        CertificateData(String content) {
            this.content = content;
            this.timestamp = System.currentTimeMillis();
        }
        
        boolean isExpired() {
            return (System.currentTimeMillis() - timestamp) > (REFRESH_INTERVAL_MINUTES * 60 * 1000);
        }
    }
    
    /**
     * MongoDB TLS configuration holder
     */
    public static class MongoTLSConfig {
        public final Path serverPem;
        public final Path caCert;
        public final Path truststore;
        public final Path keystore;
        
        MongoTLSConfig(Path serverPem, Path caCert, Path truststore, Path keystore) {
            this.serverPem = serverPem;
            this.caCert = caCert;
            this.truststore = truststore;
            this.keystore = keystore;
        }
    }
}package com.whitestartups.auth.core.vault;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import javax.json.Json;
import javax.json.JsonObject;
import javax.json.JsonReader;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Base64;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Real-time certificate management with Vault integration
 * Retrieves and caches certificates from Vault with automatic refresh
 */
public class VaultCertificateManager {
    
    private static final Logger logger = LoggerFactory.getLogger(VaultCertificateManager.class);
    
    private static final String DEFAULT_VAULT_URL = "http://localhost:8200";
    private static final String DEFAULT_VAULT_TOKEN = "root";
    private static final long REFRESH_INTERVAL_MINUTES = 60;
    
    private final String vaultUrl;
    private final String vaultToken;
    private final ConcurrentHashMap<String, CertificateData> certificateCache;
    private final ScheduledExecutorService scheduler;
    
    private static VaultCertificateManager instance;
    
    public static synchronized VaultCertificateManager getInstance() {
        if (instance == null) {
            String vaultUrl = System.getProperty("vault.url", 
                System.getenv().getOrDefault("VAULT_ADDR", DEFAULT_VAULT_URL));
            String vaultToken = System.getProperty("vault.token",
                System.getenv().getOrDefault("VAULT_TOKEN", DEFAULT_VAULT_TOKEN));
            instance = new VaultCertificateManager(vaultUrl, vaultToken);
        }
        return instance;
    }
    
    private VaultCertificateManager(String vaultUrl, String vaultToken) {
        this.vaultUrl = vaultUrl;
        this.vaultToken = vaultToken;
        this.certificateCache = new ConcurrentHashMap<>();
        this.scheduler = Executors.newScheduledThreadPool(2);
        
        // Start automatic certificate refresh
        scheduler.scheduleAtFixedRate(this::refreshAllCertificates, 
            0, REFRESH_INTERVAL_MINUTES, TimeUnit.MINUTES);
        
        logger.info("VaultCertificateManager initialized with Vault URL: {}", vaultUrl);
    }
    
    /**
     * Get certificate content from Vault with caching
     */
    public String getCertificateContent(String service, String certType) {
        String key = service + ":" + certType;
        CertificateData cached = certificateCache.get(key);
        
        if (cached != null && !cached.isExpired()) {
            logger.debug("Returning cached certificate: {}", key);
            return cached.content;
        }
        
        try {
            String content = retrieveCertificateFromVault(service, certType);
            if (content != null) {
                certificateCache.put(key, new CertificateData(content));
                logger.info("Certificate retrieved from Vault: {}", key);
                return content;
            }
        } catch (Exception e) {
            logger.error("Failed to retrieve certificate {} from Vault", key, e);
        }
        
        // Return cached content if available, even if expired, as fallback
        if (cached != null) {
            logger.warn("Using expired cached certificate: {}", key);
            return cached.content;
        }
        
        throw new RuntimeException("Certificate not available: " + key);
    }
    
    /**
     * Write certificate to temporary file for application use
     */
    public Path writeCertificateToTempFile(String service, String certType, String suffix) {
        try {
            String content = getCertificateContent(service, certType);
            Path tempFile = Files.createTempFile("vault-cert-" + service + "-" + certType, suffix);
            
            // Handle binary data (base64 encoded keystores)
            if (certType.contains("jks") || certType.contains("p12")) {
                byte[] decoded = Base64.getDecoder().decode(content);
                Files.write(tempFile, decoded);
            } else {
                Files.write(tempFile, content.getBytes(StandardCharsets.UTF_8));
            }
            
            // Set restrictive permissions
            tempFile.toFile().setReadable(true, true);
            tempFile.toFile().setWritable(true, true);
            tempFile.toFile().setExecutable(false);
            
            logger.info("Certificate written to temporary file: {} -> {}", service + ":" + certType, tempFile);
            return tempFile;
        } catch (IOException e) {
            throw new RuntimeException("Failed to write certificate to temporary file", e);
        }
    }
    
    /**
     * Get X.509 Certificate object from Vault
     */
    public X509Certificate getX509Certificate(String service, String certType) {
        try {
            String pemContent = getCertificateContent(service, certType);
            CertificateFactory cf = CertificateFactory.getInstance("X.509");
            return (X509Certificate) cf.generateCertificate(
                new ByteArrayInputStream(pemContent.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new RuntimeException("Failed to create X.509 certificate", e);
        }
    }
    
    /**
     * Get private key from Vault
     */
    public PrivateKey getPrivateKey(String service, String keyType) {
        try {
            String pemContent = getCertificateContent(service, keyType);
            
            // Remove PEM headers and decode
            String privateKeyContent = pemContent
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replace("-----BEGIN RSA PRIVATE KEY-----", "")
                .replace("-----END RSA PRIVATE KEY-----", "")
                .replaceAll("\\s", "");
            
            byte[] decoded = Base64.getDecoder().decode(privateKeyContent);
            PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(decoded);
            KeyFactory keyFactory = KeyFactory.getInstance("RSA");
            return keyFactory.generatePrivate(keySpec);
        } catch (Exception e) {
            throw new RuntimeException("Failed to create private key", e);
        }
    }
    
    /**
     * Get MongoDB TLS configuration with real-time certificate retrieval
     */
    public MongoTLSConfig getMongoTLSConfig() {
        Path serverPem = writeCertificateToTempFile("mongodb", "server_pem", ".pem");
        Path caCert = writeCertificateToTempFile("mongodb", "ca_crt", ".crt");
        Path truststore = writeCertificateToTempFile("mongodb", "truststore_jks", ".jks");
        Path keystore = writeCertificateToTempFile("mongodb", "keystore_jks", ".jks");
        
        return new MongoTLSConfig(serverPem, caCert, truststore, keystore);
    }
    
    /**
     * Refresh all cached certificates
     */
    private void refreshAllCertificates() {
        logger.info("Refreshing all cached certificates from Vault...");
        certificateCache.keySet().forEach(key -> {
            try {
                String[] parts = key.split(":");
                if (parts.length == 2) {
                    String content = retrieveCertificateFromVault(parts[0], parts[1]);
                    if (content != null) {
                        certificateCache.put(key, new CertificateData(content));
                    }
                }
            } catch (Exception e) {
                logger.warn("Failed to refresh certificate: {}", key, e);
            }
        });
    }
    
    /**
     * Retrieve certificate from Vault API
     */
    private String retrieveCertificateFromVault(String service, String certType) throws IOException {
        String path = "/v1/secret/data/" + service + "-keys";
        URL url = new URL(vaultUrl + path);
        
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setRequestMethod("GET");
        connection.setRequestProperty("X-Vault-Token", vaultToken);
        connection.setConnectTimeout(5000);
        connection.setReadTimeout(10000);
        
        int responseCode = connection.getResponseCode();
        if (responseCode != 200) {
            logger.error("Vault API error: {} for {}", responseCode, path);
            return null;
        }
        
        try (InputStream is = connection.getInputStream();
             JsonReader reader = Json.createReader(is)) {
            JsonObject response = reader.readObject();
            JsonObject data = response.getJsonObject("data").getJsonObject("data");
            
            String encodedContent = data.getString(certType, null);
            if (encodedContent != null) {
                return new String(Base64.getDecoder().decode(encodedContent), StandardCharsets.UTF_8);
            }
        }
        
        return null;
    }
    
    /**
     * Shutdown certificate manager
     */
    public void shutdown() {
        scheduler.shutdown();
        try {
            if (!scheduler.awaitTermination(10, TimeUnit.SECONDS)) {
                scheduler.shutdownNow();
            }
        } catch (InterruptedException e) {
            scheduler.shutdownNow();
        }
        
        // Clean up temporary files
        certificateCache.clear();
        logger.info("VaultCertificateManager shutdown complete");
    }
    
    /**
     * Certificate data with expiration tracking
     */
    private static class CertificateData {
        final String content;
        final long timestamp;
        
        CertificateData(String content) {
            this.content = content;
            this.timestamp = System.currentTimeMillis();
        }
        
        boolean isExpired() {
            return (System.currentTimeMillis() - timestamp) > (REFRESH_INTERVAL_MINUTES * 60 * 1000);
        }
    }
    
    /**
     * MongoDB TLS configuration holder
     */
    public static class MongoTLSConfig {
        public final Path serverPem;
        public final Path caCert;
        public final Path truststore;
        public final Path keystore;
        
        MongoTLSConfig(Path serverPem, Path caCert, Path truststore, Path keystore) {
            this.serverPem = serverPem;
            this.caCert = caCert;
            this.truststore = truststore;
            this.keystore = keystore;
        }
    }
}