# 🦊 GitLab Authentication Setup Guide

## 🔍 **Find Your GitLab Username**

Since you logged in with Google OAuth (thomas.mcavoy@whitestartups.com), your GitLab username might be different.

### **Method 1: Check GitLab Profile**
1. Go to: https://gitlab.com/-/profile
2. Look for **"Username"** field (not the email)
3. It might be something like: `thomas.mcavoy`, `thomas-mcavoy`, `tmcavoy`, etc.

### **Method 2: Check GitLab URL**
When you're logged into GitLab, check the URL when you visit your profile:
- URL will be: `https://gitlab.com/YOUR_ACTUAL_USERNAME`
- That's your GitLab username!

---

## 🔐 **Authentication Options**

### **Option A: Personal Access Token (Recommended)**

1. **Create the Token:**
   - Go to: https://gitlab.com/-/profile/personal_access_tokens
   - **Token name**: `oracle-fusion-projects`
   - **Scopes**: Check these boxes:
     - ✅ `read_repository`
     - ✅ `write_repository` 
     - ✅ `read_user` (optional, for profile info)
   - **Expiration**: Set to 1 year or no expiration
   - Click **"Create personal access token"**
   - **COPY THE TOKEN** (you won't see it again!)

2. **Update Git Remote:**
```bash
# Replace YOUR_GITLAB_USERNAME with your actual username from step 1
git remote set-url gitlab https://YOUR_GITLAB_USERNAME:YOUR_TOKEN@gitlab.com/whitestartups.com/e-commerce/oracle-fusion-projects.git

# Example if your username is "thomas-mcavoy":
# git remote set-url gitlab https://thomas-mcavoy:glpat-xxxxxxxxxxxx@gitlab.com/whitestartups.com/e-commerce/oracle-fusion-projects.git
```

### **Option B: Use Email as Username**
Sometimes GitLab accepts the email address:
```bash
git remote set-url gitlab https://thomas.mcavoy@whitestartups.com:YOUR_TOKEN@gitlab.com/whitestartups.com/e-commerce/oracle-fusion-projects.git
```

### **Option C: SSH Key (Most Secure)**
```bash
# 1. Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "thomas.mcavoy@whitestartups.com"

# 2. Copy public key
cat ~/.ssh/id_ed25519.pub

# 3. Add to GitLab:
#    - Go to: https://gitlab.com/-/profile/keys
#    - Paste the public key
#    - Give it a title like "Oracle Fusion Projects"

# 4. Update remote to use SSH
git remote set-url gitlab git@gitlab.com:whitestartups.com/e-commerce/oracle-fusion-projects.git
```

---

## 🧪 **Test Authentication**

Once you've set up authentication, test it:

```bash
# Test GitLab connection
git ls-remote gitlab

# If successful, you'll see branch references
# If failed, you'll see authentication errors
```

---

## 🔍 **Troubleshooting Common Issues**

### **Issue 1: Username Not Found**
```bash
# Error: "Username not found"
# Solution: Use your actual GitLab username, not email
```

### **Issue 2: Token Invalid** 
```bash
# Error: "Authentication failed"
# Solutions:
# - Check token hasn't expired
# - Ensure you copied the full token
# - Verify token has correct permissions
```

### **Issue 3: Repository Not Found**
```bash
# Error: "Repository not found"
# Solution: Make sure the GitLab repository exists first:
# 1. Go to: https://gitlab.com/whitestartups.com/e-commerce
# 2. Create "oracle-fusion-projects" repository if it doesn't exist
```

---

## 🚀 **Complete the Setup**

Once authentication works, test the full dual commit:

```bash
./scripts/git/dual-commit.sh "Test GitLab authentication setup"
```

Expected success output:
```
✅ GitHub: Pushed successfully
✅ GitLab: Pushed successfully
```