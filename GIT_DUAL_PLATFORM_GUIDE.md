# 🔄 Git Operations with Dual Platform Setup

## 📋 **Basic Git Operations (Work Exactly The Same)**

### **🔍 Checking Status & Differences**
```bash
# Check what files are changed
git status

# See differences in working directory
git diff

# See differences for staged files  
git diff --cached

# See differences between commits
git diff HEAD~1 HEAD

# See differences in a specific file
git diff filename.java
```

### **📝 Regular Commit Workflow**
```bash
# Stage specific files
git add file1.java file2.md

# Stage all changes
git add .

# Commit normally (stays local)
git commit -m "Your commit message"

# View commit history
git log
git log --oneline
```

### **🌿 Branch Operations**
```bash
# Create new branch
git branch feature-branch
git checkout -b feature-branch  # create and switch

# Switch branches
git checkout master
git switch feature-branch

# List branches
git branch          # local branches
git branch -r       # remote branches  
git branch -a       # all branches

# Merge branches
git checkout master
git merge feature-branch
```

---

## 🚀 **Push Operations (This Is Where Dual Platform Kicks In)**

### **Option 1: Use Dual Commit Script (Recommended)**
```bash
# Commits locally AND pushes to BOTH platforms
./scripts/git/dual-commit.sh "Your commit message"
```

### **Option 2: Manual Control**
```bash
# Commit locally first
git add .
git commit -m "Your message"

# Push to specific platform
git push origin master     # GitHub only
git push gitlab master     # GitLab only

# Or push to both manually
git push origin master && git push gitlab master
```

---

## 🔄 **Pull Operations (Fetching Updates)**

### **Pulling from Primary Platform (GitHub)**
```bash
# Pull from GitHub (default)
git pull
git pull origin master

# Check for remote updates without pulling
git fetch
git fetch origin
```

### **Pulling from GitLab**
```bash
# Pull from GitLab specifically  
git pull gitlab master

# Fetch from GitLab
git fetch gitlab
```

### **Sync All Remotes**
```bash
# Fetch from all remotes
git fetch --all

# See what's different
git log --oneline origin/master
git log --oneline gitlab/master
```

---

## 📊 **Checking Remote Status**

### **View Remote Configuration**
```bash
# See all remotes
git remote -v

# Check remote branches
git ls-remote origin    # GitHub branches
git ls-remote gitlab    # GitLab branches
```

### **Compare Remote Branches**
```bash
# See commits ahead/behind
git status              # shows vs origin/master
git log origin/master..HEAD     # commits ahead of GitHub
git log gitlab/master..HEAD     # commits ahead of GitLab
```

---

## 🛠️ **Daily Workflow Examples**

### **Typical Development Session**
```bash
# 1. Start your day - check status
git status
git pull                # get latest from GitHub

# 2. Work on your code
# ... make changes ...

# 3. Check what you changed
git diff
git status

# 4. Commit and push to both platforms
git add .
./scripts/git/dual-commit.sh "Add new authentication feature"

# That's it! Both platforms are updated
```

### **Working with Branches**
```bash
# Create feature branch
git checkout -b feature/user-auth

# Work and commit normally
git add .
git commit -m "Add user validation"

# Push branch to both platforms  
git push origin feature/user-auth
git push gitlab feature/user-auth

# Or use dual commit for branch
./scripts/git/dual-commit.sh "Complete user authentication feature"
```

### **Reviewing Changes Before Push**
```bash
# See what you're about to commit
git diff --cached

# See commit history
git log --oneline -5

# Check remote status
git fetch
git status

# Then push to both
./scripts/git/dual-commit.sh "Your message"
```

---

## 🔍 **Useful Git Commands for Dual Setup**

### **Investigation Commands**
```bash
# Check which remote is ahead/behind
git fetch --all
git log --oneline --graph --all -10

# See remote URLs
git remote get-url origin
git remote get-url gitlab

# Check last commits on each remote
git log origin/master -1
git log gitlab/master -1
```

### **Branch Comparison**
```bash
# Compare your branch with both remotes
git diff origin/master
git diff gitlab/master

# See commits unique to each platform
git log origin/master..gitlab/master
git log gitlab/master..origin/master
```

---

## ⚡ **Quick Commands Summary**

| Operation | Command |
|-----------|---------|
| **See changes** | `git diff` |
| **Check status** | `git status` |
| **Commit locally** | `git commit -m "message"` |
| **Dual platform push** | `./scripts/git/dual-commit.sh "message"` |
| **Pull from GitHub** | `git pull` |
| **Pull from GitLab** | `git pull gitlab master` |
| **View remotes** | `git remote -v` |
| **Check history** | `git log --oneline` |
| **Create branch** | `git checkout -b branch-name` |

---

## 💡 **Key Points:**

✅ **All normal Git operations work exactly the same**  
✅ **Only push operations are affected by dual remotes**  
✅ **Use the dual-commit script for easiest workflow**  
✅ **You can still push to individual platforms if needed**  
✅ **Pulling defaults to GitHub (origin) unless specified**

---

## 🎯 **Bottom Line:**

**Work exactly as you did before!** The dual platform setup is invisible for daily operations. Just use the dual-commit script when you want to push to both platforms at once. 🚀# Git Operations Guide
Updated: Tue Aug 26 04:54:36 PM ADT 2025
