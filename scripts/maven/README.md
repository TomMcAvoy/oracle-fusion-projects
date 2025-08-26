# Maven WildFly Async Integration

## 🚀 **Overview**

This directory contains Maven integration scripts for the **Unified Async WildFly System v3.0.0**. These scripts provide seamless Maven-based control over the async producer/consumer architecture with circuit breaker protection.

## 📋 **Available Maven Commands**

### **Start Async System**
```bash
# Basic start
mvn exec:exec@wildfly-start-async

# Start with parameters
mvn exec:exec@wildfly-start-async -Djob.type=full_build_deploy -Dtarget.environment=development

# Available job types:
# - full_build_deploy (default)
# - build_only
# - test_only 
# - deploy_only
# - health_check
# - cache_warmup
```

### **Stop Async System**
```bash
# Stop running workflows
mvn exec:exec@wildfly-stop-async
```

### **Deploy via Async System**
```bash
# Basic deploy
mvn exec:exec@wildfly-deploy-async

# Deploy with parameters
mvn exec:exec@wildfly-deploy-async -Dtarget.environment=production -Dskip.tests=false

# Deploy pre-built artifacts only
mvn exec:exec@wildfly-deploy-async -Dskip.build=true
```

### **Check System Status**
```bash
# View comprehensive system status
mvn exec:exec@wildfly-status-async
```

## 🔧 **Configuration Properties**

Set these in your `pom.xml` or via command line:

```xml
<properties>
    <!-- Job Configuration -->
    <job.type>full_build_deploy</job.type>
    <target.environment>development</target.environment>
    <priority>normal</priority>
    <skip.tests>false</skip.tests>
    <skip.build>false</skip.build>
</properties>
```

### **Command Line Override**
```bash
mvn exec:exec@wildfly-start-async \
  -Djob.type=deploy_only \
  -Dtarget.environment=staging \
  -Dpriority=urgent \
  -Dskip.tests=true
```

## 📋 **Script Descriptions**

### **`wildfly-async-start.sh`**
- **Purpose**: Start the unified async WildFly system
- **Features**: 
  - GitHub CLI trigger (primary)
  - API fallback trigger
  - Auto-trigger via git push (backup)
  - Real-time progress monitoring

### **`wildfly-async-stop.sh`**
- **Purpose**: Stop/cancel running WildFly workflows
- **Features**:
  - Find and cancel running workflows
  - Confirmation prompts for safety
  - Bulk cancellation support

### **`wildfly-async-deploy.sh`**
- **Purpose**: Deploy via the async system
- **Features**:
  - Environment-specific deployment
  - Production deployment protection
  - Pre-built artifact deployment
  - Priority escalation for production

### **`wildfly-async-status.sh`**
- **Purpose**: Comprehensive system status
- **Features**:
  - Workflow execution status
  - Circuit breaker health
  - System component verification
  - Recent run statistics

## 🛡️ **Circuit Breaker Protection**

The scripts automatically work with the circuit breaker:

- **Max 5 WildFly jobs** in 10-minute window
- **Max 2 concurrent** processing jobs
- **High failure rate** detection
- **Urgent priority** bypass capability

## 🎯 **Integration Examples**

### **Maven Profile for Development**
```xml
<profile>
    <id>dev-async</id>
    <properties>
        <job.type>build_only</job.type>
        <target.environment>development</target.environment>
        <skip.tests>true</skip.tests>
    </properties>
</profile>
```

### **Maven Profile for Production**
```xml
<profile>
    <id>prod-async</id>
    <properties>
        <job.type>full_build_deploy</job.type>
        <target.environment>production</target.environment>
        <priority>urgent</priority>
        <skip.tests>false</skip.tests>
    </properties>
</profile>
```

### **Usage with Profiles**
```bash
# Development deployment
mvn exec:exec@wildfly-deploy-async -Pdev-async

# Production deployment
mvn exec:exec@wildfly-deploy-async -Pprod-async
```

## 📊 **Monitoring & Troubleshooting**

### **Check System Health**
```bash
mvn exec:exec@wildfly-status-async
```

### **Monitor Workflow Progress**
- Scripts provide GitHub Actions URLs
- Real-time status updates
- Circuit breaker statistics

### **Common Issues**

1. **GitHub CLI not authenticated**
   ```bash
   gh auth login
   ```

2. **Workflow files missing**
   - Ensure `.github/workflows/wildfly-async-*.yml` exist
   - Commit and push if needed

3. **API rate limits**
   - Scripts automatically fall back to alternative methods
   - Circuit breaker provides protection

## 🚀 **Advanced Usage**

### **Batch Operations**
```bash
# Build and deploy multiple environments
mvn exec:exec@wildfly-deploy-async -Dtarget.environment=development
mvn exec:exec@wildfly-deploy-async -Dtarget.environment=staging
```

### **Conditional Deployment**
```bash
# Only deploy if tests pass
mvn test && mvn exec:exec@wildfly-deploy-async
```

### **Emergency Stop**
```bash
# Quick stop all async operations
mvn exec:exec@wildfly-stop-async
```

## 🎉 **Benefits**

- **Seamless Integration**: Works with existing Maven workflows
- **Circuit Breaker Protection**: Prevents runaway builds
- **Multi-Environment Support**: Development, staging, production
- **Flexible Job Types**: From build-only to full deployment
- **Real-time Monitoring**: Progress tracking and status updates
- **Fallback Methods**: Multiple trigger mechanisms for reliability

## 📱 **Quick Reference**

```bash
# Start async system
mvn exec:exec@wildfly-start-async

# Deploy to staging
mvn exec:exec@wildfly-deploy-async -Dtarget.environment=staging

# Check status
mvn exec:exec@wildfly-status-async

# Stop running workflows
mvn exec:exec@wildfly-stop-async
```

---

**🎯 Your WildFly authentication system now has complete Maven integration with the unified async architecture and circuit breaker protection!**