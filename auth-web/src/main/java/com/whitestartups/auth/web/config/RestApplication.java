package com.whitestartups.auth.web.config;

import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * JAX-RS Application configuration
 * Maps REST endpoints to /api/* path
 */
@ApplicationPath("/api")
public class RestApplication extends Application {
    // JAX-RS will automatically discover and register all @Path annotated classes
}