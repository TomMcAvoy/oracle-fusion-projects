# 🌐 Multi-Runner Networking Guide

## 📡 **Port Usage: GitHub vs GitLab Runners**

### 🔍 **Short Answer**
**No, neither runner "listens" on ports by default.** Both make **outbound connections only**.

### 📊 **Detailed Networking Breakdown**

## 🐙 **GitHub Actions Runner**

### **Connection Pattern: OUTBOUND ONLY**
```bash
GitHub Runner → github.com:443 (HTTPS)
```

**Ports Used:**
- ✅ **No listening ports** - Pure client mode
- 🔄 **Outbound HTTPS (443)** to GitHub servers
- 📡 **Polling mechanism** - Runner asks GitHub for jobs
- 🔒 **Secure WebSocket** connections for real-time updates

**Network Flow:**
```
[GitHub Runner] --HTTPS--> [github.com]
     ↑                           ↓
     └── Job Results ←-----------┘
```

---

## 🦊 **GitLab CI Runner**

### **Connection Pattern: OUTBOUND ONLY**
```bash
GitLab Runner → gitlab.com:443 (HTTPS)
```

**Ports Used:**
- ✅ **No listening ports** - Pure client mode  
- 🔄 **Outbound HTTPS (443)** to GitLab servers
- 📡 **Job polling** - Runner requests work from GitLab
- 🔄 **API calls** for job status, logs, artifacts

**Network Flow:**
```
[GitLab Runner] --HTTPS--> [gitlab.com]
     ↑                          ↓
     └── Job Updates ←----------┘
```

---

## 🚫 **No Port Conflicts Between Runners**

### **Why No Conflicts:**
1. **Both are clients** - They don't listen, only connect outbound
2. **Different target servers** - GitHub vs GitLab
3. **No shared listening services**
4. **Independent processes**

---

## 🎯 **Live Port Analysis Results**

Based on our current setup:

```bash
📡 GitHub Actions Runner: ❌ Not running (ready for registration)
🦊 GitLab Runner: ✅ Process running (PID: 136613)
   ✅ No listening ports (outbound only)
   📡 No active connections (waiting for jobs)

🏦 Vault Service: ✅ Running on port 8200 (containerized)
   📡 Port mapping: 8200:8200

📊 Port Status:
   ✅ Port 3000: Available
   ✅ Port 5432: Available  
   ✅ Port 6379: Available
   ✅ Port 8080: Available
   🔴 Port 8200: OCCUPIED (Vault - expected)
   ✅ Port 9000: Available
```

**Analysis Tool:**
```bash
# Check current port usage:
./scripts/ci/port-analysis.sh
```

---

## ⚠️ **Potential Port Conflicts: Job-Level**

### **When Conflicts CAN Occur:**

#### **🐳 Docker Container Ports**
If both runners spawn containers using the same host ports:

```yaml
# GitHub Actions workflow
services:
  web:
    image: nginx
    ports:
      - "8080:80"  # ← Potential conflict

# GitLab CI pipeline  
services:
  - name: nginx:latest
    alias: web
    ports:
      - "8080:80"  # ← Same port!
```

#### **🛠️ Build Tool Ports**
Development servers, test databases, etc.:

```bash
# Both runners might try to use:
- Port 3000 (Node.js dev server)
- Port 5432 (PostgreSQL)
- Port 6379 (Redis)
- Port 8080 (Java apps)
```

---

## 🔧 **Port Management Strategies**

### **1. Dynamic Port Allocation**
```yaml
# GitHub Actions - Use random ports
services:
  postgres:
    image: postgres:13
    ports:
      - "0:5432"  # Docker assigns random host port

# GitLab CI - Let Docker choose
services:
  - name: postgres:13
    alias: db
    # No host port mapping - use container networking
```

### **2. Port Ranges by Runner**
```yaml
# GitHub Actions - Use 8000-8999 range
ports:
  - "8080:80"
  - "8081:3000"

# GitLab CI - Use 9000-9999 range  
ports:
  - "9080:80"
  - "9081:3000"
```

### **3. Container Networking (Recommended)**
```yaml
# Both runners use internal container networking
# No host port exposure needed
services:
  web:
    image: nginx
    # No ports section - containers communicate internally
```

---

## 🛡️ **Security Considerations**

### **Outbound Connections Only**
```bash
# GitHub Runner connections
GitHub Runner → github.com:443
GitHub Runner → api.github.com:443
GitHub Runner → github-production-release-asset-*.amazonaws.com:443

# GitLab Runner connections  
GitLab Runner → gitlab.com:443
GitLab Runner → registry.gitlab.com:443
GitLab Runner → gitlab-ci-token:xxx@gitlab.com:443
```

### **Firewall Rules**
```bash
# Allow outbound HTTPS (both runners need this)
sudo ufw allow out 443/tcp

# Allow Docker (if using Docker executor)
sudo ufw allow out on docker0

# Vault access (localhost only)
# Port 8200 only accessible locally
```

---

## 📋 **Best Practices for Multi-Runner Setup**

### **1. Container Isolation**
```yaml
# Use Docker networks to isolate jobs
networks:
  github-jobs:
    driver: bridge
  gitlab-jobs:
    driver: bridge
```

### **2. Resource Limits**
```toml
# GitLab Runner config.toml
[[runners]]
  [runners.docker]
    memory = "2g"
    cpus = "1.0"
    
# GitHub Runner - set via environment
ACTIONS_RUNNER_HOOK_JOB_STARTED=/usr/local/bin/limit-resources
```

### **3. Port Management Strategy**
```bash
# Environment-specific port ranges
export GITHUB_RUNNER_PORT_RANGE="8000-8999"
export GITLAB_RUNNER_PORT_RANGE="9000-9999"
export VAULT_PORT="8200"
```

---

## 🔧 **Troubleshooting Port Issues**

### **Check for Port Conflicts**
```bash
# List all listening ports
sudo netstat -tlnp

# Check specific port
sudo lsof -i :8080

# Check Docker port mappings
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Use our analysis tool
./scripts/ci/port-analysis.sh
```

### **Common Solutions**
```yaml
# 1. Use ephemeral ports
ports:
  - "0:8080"  # Docker assigns random host port

# 2. Use container networking
networks:
  - runner-network

# 3. Different port ranges per runner
github_port: 8080
gitlab_port: 9080
```

---

## 📊 **Current Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    HOST SYSTEM                               │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ GitHub       │    │ GitLab       │    │ Vault        │  │
│  │ Runner       │    │ Runner       │    │ Container    │  │
│  │              │    │              │    │              │  │
│  │ No ports     │    │ No ports     │    │ Port 8200    │  │
│  │ (outbound    │    │ (outbound    │    │ (localhost   │  │
│  │  only)       │    │  only)       │    │  only)       │  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘  │
│         │                   │                   │          │
│         │                   │                   │          │
└─────────┼───────────────────┼───────────────────┼──────────┘
          │                   │                   │
          │                   │                   │
          ▼                   ▼                   ▼
    github.com:443      gitlab.com:443      localhost:8200
```

---

## ✅ **Summary**

### **The Answer:**
**NO port conflicts between runners** - They're both clients that make outbound connections only.

### **Key Points:**
1. ✅ **Runners don't listen** on any ports
2. ✅ **Both use HTTPS outbound** to their respective platforms  
3. ✅ **Vault uses port 8200** (containerized, no conflict)
4. ⚠️  **Job-level conflicts possible** if containers use same host ports
5. 🔧 **Easy to manage** with proper container networking

### **Best Practice:**
Use container networking and avoid host port mapping to eliminate any potential conflicts between jobs running on different runners.

### **Monitoring:**
```bash
# Check current port usage
./scripts/ci/port-analysis.sh

# Monitor continuously  
watch -n 30 ./scripts/ci/port-analysis.sh
```

---

## 💡 **Conclusion**

**Both GitHub Actions and GitLab CI runners can run simultaneously without port conflicts** because:

- Neither runner listens on ports (they're pure clients)
- Both make outbound HTTPS connections to their respective platforms
- Only potential conflicts are in job-level containers
- Our Vault setup uses containerized port 8200 safely
- Container networking eliminates most conflict scenarios

The architecture is designed for coexistence! 🚀