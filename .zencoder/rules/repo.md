---
description: Repository Information Overview
alwaysApply: true
---

# Distributed Authentication System Information

## Summary
A high-performance J2EE distributed authentication system with LDAP integration, designed to handle 100+ million user records with millisecond authentication response times. The system provides a distributed EJB farm for high-speed authentication caching with intelligent warm-up and regional distribution.

## Structure
- **auth-core**: Singleton EJB for LDAP user loading and management
- **auth-cache**: Distributed EJB farm for high-speed authentication caching
- **auth-client**: Client library for applications to authenticate users
- **auth-web**: REST API endpoints for web-based authentication
- **testing**: Performance and load testing tools
- **ldap**: LDAP configuration and test data
- **mongodb**: MongoDB configuration for caching
- **dev-tools**: Development environment setup scripts

## Language & Runtime
**Language**: Java
**Version**: Java 17
**Framework**: Jakarta EE 10, MicroProfile 6.0
**Build System**: Maven 3.8+
**Package Manager**: Maven
**Application Server**: WildFly/JBoss EAP 37.0.0.Finam

## Dependencies
**Main Dependencies**:
- Jakarta EE API 10.0.0
- MicroProfile 6.0
- SLF4J 2.0.7 / Logback 1.4.8
- Jedis (Redis Client) 5.0.2
- MongoDB Driver 4.11.1
- Jackson 2.15.3

**Development Dependencies**:
- JUnit Jupiter 5.9.3
- Mockito 5.3.1

## Build & Installation
```bash
# Build all modules
mvn clean install

# Build specific module
mvn clean install -pl auth-core

# Skip tests
mvn clean install -DskipTests
```

## Docker
**Configuration**: Docker Compose setup with multiple services
**Services**:
- OpenLDAP (osixia/openldap:1.5.0)
- phpLDAPadmin (osixia/phpldapadmin:latest)
- Redis Cache (redis:7.2-alpine)
- MongoDB (mongo:7.0)

**Docker Compose Command**:
```bash
docker-compose up -d
```

## Testing
**Frameworks**:
- JUnit Jupiter for unit testing
- K6 for API load testing
- Playwright for browser testing
- Artillery for load testing

**Test Location**: 
- Java tests in src/test directories of each module
- Performance tests in testing directory

**Run Commands**:
```bash
# Run all Java tests
mvn test

# Run integration tests
mvn verify

# Run performance tests
npm run test:api --prefix testing

# Run browser tests
npm run test:browser --prefix testing
```

## Project Components

### auth-core
**Type**: EJB Module
**Packaging**: EJB 4.0
**Purpose**: Core LDAP loading and user management singleton EJB
**Main Features**: LDAP integration, user management, authentication logic

### auth-cache
**Type**: EJB Module
**Packaging**: EJB
**Purpose**: Distributed caching EJBs for high-speed authentication
**Main Features**: Redis and MongoDB integration, distributed caching

### auth-client
**Type**: Java Library
**Packaging**: JAR
**Purpose**: Client library for applications to authenticate users
**Main Features**: Synchronous and asynchronous authentication, batch operations

### auth-web
**Type**: Web Application
**Packaging**: WAR
**Purpose**: REST API endpoints for web-based authentication
**Main Features**: JAX-RS REST services, health monitoring, statistics

### Infrastructure
**LDAP**: OpenLDAP for user directory
**Caching**: Two-level caching with Redis (L2) and MongoDB (L3)
**Deployment**: WildFly/JBoss EAP application server
**Monitoring**: JMX metrics, REST endpoints for health and statistics