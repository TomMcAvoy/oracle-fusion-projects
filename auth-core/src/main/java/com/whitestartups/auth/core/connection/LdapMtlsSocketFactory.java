package com.whitestartups.auth.core.connection;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.net.SocketFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;
import java.io.IOException;
import java.net.InetAddress;
import java.net.Socket;
import java.net.UnknownHostException;

/**
 * Custom SSL Socket Factory for LDAP mTLS connections
 * Used by JNDI LDAP context to create secure sockets with client certificates
 */
public class LdapMtlsSocketFactory extends SocketFactory {
    
    private static final Logger logger = LoggerFactory.getLogger(LdapMtlsSocketFactory.class);
    
    private static volatile SSLContext sslContext;
    private static volatile SSLSocketFactory sslSocketFactory;
    
    /**
     * Set SSL context for mTLS connections
     */
    public static void setSslContext(SSLContext context) {
        sslContext = context;
        sslSocketFactory = context.getSocketFactory();
        logger.info("LDAP mTLS socket factory SSL context configured");
    }
    
    /**
     * Get default socket factory instance (required by JNDI)
     */
    public static SocketFactory getDefault() {
        return new LdapMtlsSocketFactory();
    }
    
    @Override
    public Socket createSocket() throws IOException {
        if (sslSocketFactory == null) {
            throw new IOException("SSL context not configured for LDAP mTLS socket factory");
        }
        
        SSLSocket socket = (SSLSocket) sslSocketFactory.createSocket();
        configureSslSocket(socket);
        return socket;
    }
    
    @Override
    public Socket createSocket(String host, int port) throws IOException, UnknownHostException {
        if (sslSocketFactory == null) {
            throw new IOException("SSL context not configured for LDAP mTLS socket factory");
        }
        
        SSLSocket socket = (SSLSocket) sslSocketFactory.createSocket(host, port);
        configureSslSocket(socket);
        
        logger.debug("Created LDAP mTLS socket to {}:{}", host, port);
        return socket;
    }
    
    @Override
    public Socket createSocket(String host, int port, InetAddress localHost, int localPort) 
            throws IOException, UnknownHostException {
        if (sslSocketFactory == null) {
            throw new IOException("SSL context not configured for LDAP mTLS socket factory");
        }
        
        SSLSocket socket = (SSLSocket) sslSocketFactory.createSocket(host, port, localHost, localPort);
        configureSslSocket(socket);
        
        logger.debug("Created LDAP mTLS socket to {}:{} from {}:{}", host, port, localHost, localPort);
        return socket;
    }
    
    @Override
    public Socket createSocket(InetAddress host, int port) throws IOException {
        if (sslSocketFactory == null) {
            throw new IOException("SSL context not configured for LDAP mTLS socket factory");
        }
        
        SSLSocket socket = (SSLSocket) sslSocketFactory.createSocket(host, port);
        configureSslSocket(socket);
        
        logger.debug("Created LDAP mTLS socket to {}:{}", host.getHostAddress(), port);
        return socket;
    }
    
    @Override
    public Socket createSocket(InetAddress address, int port, InetAddress localAddress, int localPort) 
            throws IOException {
        if (sslSocketFactory == null) {
            throw new IOException("SSL context not configured for LDAP mTLS socket factory");
        }
        
        SSLSocket socket = (SSLSocket) sslSocketFactory.createSocket(address, port, localAddress, localPort);
        configureSslSocket(socket);
        
        logger.debug("Created LDAP mTLS socket to {}:{} from {}:{}", 
                    address.getHostAddress(), port, localAddress.getHostAddress(), localPort);
        return socket;
    }
    
    /**
     * Configure SSL socket for secure LDAP communication
     */
    private void configureSslSocket(SSLSocket socket) throws IOException {
        try {
            // Enable client authentication (mTLS)
            socket.setNeedClientAuth(true);
            
            // Configure supported protocols (prefer TLS 1.3, fallback to 1.2)
            String[] supportedProtocols = socket.getSupportedProtocols();
            String[] enabledProtocols;
            
            if (containsProtocol(supportedProtocols, "TLSv1.3")) {
                enabledProtocols = new String[]{"TLSv1.3", "TLSv1.2"};
            } else {
                enabledProtocols = new String[]{"TLSv1.2"};
            }
            
            socket.setEnabledProtocols(enabledProtocols);
            
            // Configure cipher suites (prefer ECDSA and strong ciphers)
            String[] supportedCipherSuites = socket.getSupportedCipherSuites();
            String[] enabledCipherSuites = selectSecureCipherSuites(supportedCipherSuites);
            socket.setEnabledCipherSuites(enabledCipherSuites);
            
            logger.debug("LDAP SSL socket configured - protocols: {}, cipher suites: {}", 
                        String.join(", ", enabledProtocols), enabledCipherSuites.length);
                        
        } catch (Exception e) {
            logger.error("Failed to configure LDAP SSL socket", e);
            throw new IOException("SSL socket configuration failed", e);
        }
    }
    
    /**
     * Check if protocol array contains specific protocol
     */
    private boolean containsProtocol(String[] protocols, String target) {
        for (String protocol : protocols) {
            if (target.equals(protocol)) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * Select secure cipher suites, prioritizing ECDSA and AES-GCM
     */
    private String[] selectSecureCipherSuites(String[] supportedCipherSuites) {
        // Priority order: TLS 1.3 suites, ECDSA, RSA with GCM, then CBC
        String[] preferredSuites = {
            // TLS 1.3 cipher suites
            "TLS_AES_256_GCM_SHA384",
            "TLS_CHACHA20_POLY1305_SHA256",
            "TLS_AES_128_GCM_SHA256",
            
            // TLS 1.2 ECDSA cipher suites
            "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
            "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
            "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
            "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384",
            "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256",
            
            // TLS 1.2 RSA cipher suites
            "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
            "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256",
            "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
            "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384",
            "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256"
        };
        
        // Find intersection of preferred and supported cipher suites
        java.util.List<String> enabledSuites = new java.util.ArrayList<>();
        java.util.Set<String> supportedSet = new java.util.HashSet<>(java.util.Arrays.asList(supportedCipherSuites));
        
        for (String preferred : preferredSuites) {
            if (supportedSet.contains(preferred)) {
                enabledSuites.add(preferred);
            }
        }
        
        // If no preferred suites found, fall back to defaults (but log warning)
        if (enabledSuites.isEmpty()) {
            logger.warn("No preferred cipher suites found, using system defaults");
            return supportedCipherSuites;
        }
        
        String[] result = enabledSuites.toArray(new String[0]);
        logger.debug("Selected {} secure cipher suites from {} supported", result.length, supportedCipherSuites.length);
        
        return result;
    }
}