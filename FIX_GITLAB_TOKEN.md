# 🔧 Fix GitLab Token Permissions

## 🚨 **Issue Identified**
Your GitLab token has **read access** but not **write access**.

## ✅ **Solution: Create New Token with Correct Permissions**

### **Step 1: Create New GitLab Token**
1. **Go to:** https://gitlab.com/-/profile/personal_access_tokens
2. **Token name:** `oracle-fusion-projects-full-access`  
3. **Expiration:** Set to 1 year or no expiration
4. **Scopes - CHECK ALL OF THESE:**
   - ✅ `api` (full API access)
   - ✅ `read_user` (read user info)  
   - ✅ `read_repository` (pull repositories)
   - ✅ `write_repository` (push to repositories)
   - ✅ `read_registry` (optional, for Docker)
   - ✅ `write_registry` (optional, for Docker)

5. **Click:** "Create personal access token"
6. **COPY THE NEW TOKEN** (you won't see it again!)

### **Step 2: Update Token File**
```bash
# Replace the token in your secure file:
echo "NEW_TOKEN_HERE" > .secrets/.gitlab_token

# Example:
echo "glpat-abcdefghijklmnop123456" > .secrets/.gitlab_token
```

### **Step 3: Test the Fix**
```bash
# Reconfigure GitLab remote with new token:
./scripts/git/setup-gitlab-token.sh

# Test dual commit:
./scripts/git/dual-commit.sh "Test with corrected GitLab token permissions"
```

## 🎯 **Expected Result After Fix:**
```
✅ Committed: Test with corrected GitLab token permissions  
✅ GitHub: Pushed successfully
✅ GitLab: Pushed successfully  ← This will work now!
```

## 🔍 **Why This Happened:**
GitLab tokens are very specific about scopes. Your current token probably only has:
- ✅ `read_repository` (which is why `ls-remote` worked)  
- ❌ Missing `write_repository` (which is why push failed)
- ❌ Missing `api` (which is why API calls failed)

## 💡 **Security Note:**
The token is safely stored in `.secrets/.gitlab_token` and not exposed in your repository!