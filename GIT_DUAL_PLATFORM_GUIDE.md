# 🔄 Git Dual Platform Guide

## 🎯 **How to Commit to Both GitHub and GitLab**

You have several options to maintain your code on both platforms simultaneously:

---

## 🚀 **Method 1: Multiple Remotes (Recommended)**

### **Setup Multiple Remotes**

```bash
# Check current remotes
git remote -v

# Add GitLab as a second remote
git remote add gitlab https://gitlab.com/YOUR-USERNAME/oracle-fusion-projects.git

# Add GitHub as origin (if not already set)
git remote add origin https://github.com/YOUR-USERNAME/oracle-fusion-projects.git

# Verify both remotes
git remote -v
# Output should show:
# origin    https://github.com/YOUR-USERNAME/oracle-fusion-projects.git (fetch)
# origin    https://github.com/YOUR-USERNAME/oracle-fusion-projects.git (push)
# gitlab    https://gitlab.com/YOUR-USERNAME/oracle-fusion-projects.git (fetch)
# gitlab    https://gitlab.com/YOUR-USERNAME/oracle-fusion-projects.git (push)
```

### **Push to Both Platforms**

```bash
# Push to GitHub
git push origin main

# Push to GitLab
git push gitlab main

# Push to both at once
git push origin main && git push gitlab main
```

---

## 🔥 **Method 2: Single Push to Both (Super Convenient)**

### **Configure One Remote to Push to Both**

```bash
# Set up origin to push to both GitHub and GitLab
git remote set-url origin --add https://github.com/YOUR-USERNAME/oracle-fusion-projects.git
git remote set-url origin --add https://gitlab.com/YOUR-USERNAME/oracle-fusion-projects.git

# Now a single push goes to both!
git push origin main
# ↑ This pushes to BOTH GitHub AND GitLab
```

### **Verify the Setup**
```bash
git remote -v
# Should show:
# origin    https://github.com/YOUR-USERNAME/oracle-fusion-projects.git (fetch)
# origin    https://github.com/YOUR-USERNAME/oracle-fusion-projects.git (push)
# origin    https://gitlab.com/YOUR-USERNAME/oracle-fusion-projects.git (push)
```

---

## 🛠️ **Method 3: Automated Script**

### **Create Automated Dual Commit Script**

```bash
# Make the script executable
chmod +x ./scripts/git/dual-commit.sh

# Use it like this:
./scripts/git/dual-commit.sh "Add new feature"

# Or just run it and enter message interactively:
./scripts/git/dual-commit.sh
```

---

## ⚙️ **Method 4: Easy Setup Script**

Use our setup script to configure everything automatically:

```bash
# Make setup script executable
chmod +x ./scripts/git/setup-dual-remotes.sh

# Run the setup
./scripts/git/setup-dual-remotes.sh
```

This script will:
- ✅ Configure both GitHub and GitLab remotes
- ✅ Let you choose single or dual remote strategy
- ✅ Test connectivity to both platforms
- ✅ Provide usage instructions

---

## 🔄 **Daily Workflow Examples**

### **Using Multiple Remotes**
```bash
# Make changes
echo "console.log('Hello World');" > test.js

# Commit and push to both
git add .
git commit -m "Add test file"
git push origin main     # → GitHub
git push gitlab main     # → GitLab

# Or use the automated script
./scripts/git/dual-commit.sh "Add test file"
```

### **Using Single Remote (Both Platforms)**
```bash
# Make changes
echo "console.log('Hello World');" > test.js

# Single command pushes to both!
git add .
git commit -m "Add test file"
git push origin main     # → Both GitHub AND GitLab
```

---

## 🎯 **Which Method to Choose?**

### **Multiple Remotes (Method 1)**
✅ **Best for:** Different deployment strategies  
✅ **Pros:** Selective pushing, clear separation  
❌ **Cons:** Must remember to push to both  

### **Single Remote Dual Push (Method 2)**  
✅ **Best for:** True synchronization  
✅ **Pros:** One command = both platforms  
❌ **Cons:** All-or-nothing, harder to troubleshoot  

### **Automated Script (Method 3)**
✅ **Best for:** Consistent workflow  
✅ **Pros:** Error handling, status reporting  
❌ **Cons:** Extra script to maintain  

---

## 🔐 **Authentication Setup**

### **For HTTPS (Recommended)**

```bash
# GitHub - Use Personal Access Token
git remote set-url origin https://USERNAME:TOKEN@github.com/USER/REPO.git

# GitLab - Use Deploy Token or Personal Access Token  
git remote set-url gitlab https://USERNAME:TOKEN@gitlab.com/USER/REPO.git
```

### **For SSH**
```bash
# Generate SSH keys if not already done
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add public key to both platforms:
# GitHub: Settings → SSH and GPG keys
# GitLab: User Settings → SSH Keys

# Use SSH URLs
git remote add origin git@github.com:USERNAME/oracle-fusion-projects.git
git remote add gitlab git@gitlab.com:USERNAME/oracle-fusion-projects.git
```

---

## 🚀 **Advanced: Automated Sync**

### **GitHub Actions to Mirror to GitLab**
```yaml
# .github/workflows/mirror-to-gitlab.yml
name: Mirror to GitLab

on: [push]

jobs:
  mirror:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0
    - name: Mirror to GitLab
      uses: pixta-dev/repository-mirroring-action@v1
      with:
        target_repo_url: ${{ secrets.GITLAB_REPO_URL }}
        ssh_private_key: ${{ secrets.GITLAB_SSH_KEY }}
```

### **GitLab CI to Mirror to GitHub**
```yaml
# .gitlab-ci.yml
mirror_to_github:
  stage: deploy
  script:
    - git push --mirror $GITHUB_REPO_URL
  only:
    - main
  variables:
    GITHUB_REPO_URL: "https://token:$GITHUB_TOKEN@github.com/USER/REPO.git"
```

---

## 🛠️ **Troubleshooting**

### **Common Issues**

```bash
# Check current remotes
git remote -v

# Test connectivity
git ls-remote origin
git ls-remote gitlab

# Fix authentication issues
git config --global credential.helper store

# Reset remotes if needed
git remote remove origin
git remote remove gitlab
# Then re-add them
```

### **Conflict Resolution**
```bash
# If repositories diverge
git fetch origin
git fetch gitlab
git merge origin/main
git push gitlab main
```

---

## ✅ **Quick Setup Summary**

1. **Easy Setup**: Run `./scripts/git/setup-dual-remotes.sh`
2. **Choose Method**: Single remote or multiple remotes
3. **Set Authentication**: HTTPS tokens or SSH keys
4. **Start Committing**: Use `./scripts/git/dual-commit.sh` or standard git commands

---

## 📊 **Our Project Integration**

This setup perfectly complements our multi-runner CI/CD:

```
┌─────────────┐    ┌─────────────┐
│   GITHUB    │    │   GITLAB    │  
│             │    │             │
│ • Same Code │    │ • Same Code │
│ • Actions   │    │ • CI/CD     │
│ • Runner    │    │ • Runner    │
└─────┬───────┘    └─────┬───────┘
      │                  │
      └──────┬───────────┘
             │
      ┌──────▼───────┐
      │ LOCAL REPO   │
      │              │
      │ • Push to    │
      │   both       │
      │ • Shared     │
      │   Vault      │
      └──────────────┘
```

**Now you can commit once and have both runners execute on their respective platforms!** 🚀