# 🔑 LDAP Test Credentials Reference

## Quick Access Summary
**1000 test users with predictable credentials based on username ending digit**

## 🏢 LDAP Server Details
- **Server**: `ldap://localhost:389`
- **Base DN**: `dc=whitestartups,dc=com`
- **Admin DN**: `cn=admin,dc=whitestartups,dc=com`
- **Admin Password**: `WhiteStartups2024!`
- **User Base**: `ou=people,dc=whitestartups,dc=com`

## 🧪 Test User Pattern
**Username**: `testuser000` to `testuser999` (1000 users total)
**Password Pattern**: `TestPass{lastDigit}!`

## 🔐 Password Mapping by Last Digit

| Last Digit | Password | Example Users | Total Users |
|------------|----------|---------------|-------------|
| **0** | `TestPass0!` | testuser000, testuser010, testuser020... | 100 |
| **1** | `TestPass1!` | testuser001, testuser011, testuser021... | 100 |
| **2** | `TestPass2!` | testuser002, testuser012, testuser022... | 100 |
| **3** | `TestPass3!` | testuser003, testuser013, testuser023... | 100 |
| **4** | `TestPass4!` | testuser004, testuser014, testuser024... | 100 |
| **5** | `TestPass5!` | testuser005, testuser015, testuser025... | 100 |
| **6** | `TestPass6!` | testuser006, testuser016, testuser026... | 100 |
| **7** | `TestPass7!` | testuser007, testuser017, testuser027... | 100 |
| **8** | `TestPass8!` | testuser008, testuser018, testuser028... | 100 |
| **9** | `TestPass9!` | testuser009, testuser019, testuser029... | 100 |

## 📝 Sample Credentials

### Easy Test Cases
```bash
# Last digit 0 users
testuser000 → TestPass0!
testuser010 → TestPass0!  
testuser100 → TestPass0!
testuser500 → TestPass0!

# Last digit 1 users  
testuser001 → TestPass1!
testuser011 → TestPass1!
testuser101 → TestPass1!
testuser501 → TestPass1!

# Last digit 5 users
testuser005 → TestPass5!
testuser015 → TestPass5!
testuser105 → TestPass5!
testuser555 → TestPass5!

# Last digit 9 users
testuser009 → TestPass9!
testuser019 → TestPass9!
testuser109 → TestPass9!
testuser999 → TestPass9!
```

## 🧮 Quick Calculation
**To determine password for any user:**
1. Look at the last digit of the username
2. Password = `TestPass{lastDigit}!`

**Examples:**
- `testuser042` → last digit is `2` → password is `TestPass2!`
- `testuser337` → last digit is `7` → password is `TestPass7!`
- `testuser890` → last digit is `0` → password is `TestPass0!`

## 👥 User Profile Details
Each test user has complete enterprise profile:
- **Full Name**: Test### User{lastDigit}
- **Email**: testuser###@whitestartups.com
- **Employee ID**: 6-digit number starting from 010000
- **Phone**: +1-555-#### format
- **Department**: Rotates through 10 departments
- **Region**: Rotates through 5 regions
- **Title**: Rotates through 10 job titles

## 🌍 Regional Distribution
Users are distributed across regions:
- **US-EAST**: Users 0, 5, 10, 15, 20...
- **US-WEST**: Users 1, 6, 11, 16, 21...  
- **EU-WEST**: Users 2, 7, 12, 17, 22...
- **ASIA-PAC**: Users 3, 8, 13, 18, 23...
- **CANADA**: Users 4, 9, 14, 19, 24...

## 🏢 Department Distribution  
Users rotate through departments:
- **engineering** (0, 10, 20...)
- **sales** (1, 11, 21...)
- **marketing** (2, 12, 22...)
- **hr** (3, 13, 23...)
- **finance** (4, 14, 24...)
- **operations** (5, 15, 25...)
- **support** (6, 16, 26...)
- **legal** (7, 17, 27...)
- **security** (8, 18, 28...)
- **research** (9, 19, 29...)

## 🔧 Docker Services
```yaml
# Start all services
docker-compose up -d

# Services running:
# - OpenLDAP: localhost:389 (LDAP) / localhost:636 (LDAPS)
# - phpLDAPadmin: localhost:8080 (Web UI)  
# - Redis: localhost:6379 (L2 Cache)
# - MongoDB: localhost:27017 (L3 Cache)
```

## 🌐 Web Management
**LDAP Admin Interface**: http://localhost:8080
- Login server: `openldap`
- Username: `cn=admin,dc=whitestartups,dc=com`
- Password: `WhiteStartups2024!`

## 🧪 Testing Commands

### Test LDAP Connection
```bash
# Install ldap utils (macOS)
brew install openldap

# Search for users
ldapsearch -x -H ldap://localhost:389 -D "cn=admin,dc=whitestartups,dc=com" -w "WhiteStartups2024!" -b "ou=people,dc=whitestartups,dc=com" "(uid=testuser*)" | head -20

# Test specific user
ldapsearch -x -H ldap://localhost:389 -D "cn=admin,dc=whitestartups,dc=com" -w "WhiteStartups2024!" -b "ou=people,dc=whitestartups,dc=com" "(uid=testuser123)"
```

### Test Authentication
```bash
# Use Python test script
python3 scripts/python/test_ldap_credentials.py

# Manual test with ldapwhoami
ldapwhoami -x -H ldap://localhost:389 -D "uid=testuser123,ou=people,dc=whitestartups,dc=com" -w "TestPass3!"
```

## 🎯 Cache Testing Strategy

### High-Frequency Users (Will hit L1 cache)
```bash
# Test these users repeatedly - should get < 1ms response
testuser000, testuser111, testuser222, testuser333, testuser444
testuser555, testuser666, testuser777, testuser888, testuser999
```

### Medium-Frequency Users (Will hit L2 Redis)
```bash
# Test these occasionally - should get < 5ms response  
testuser050, testuser151, testuser252, testuser353, testuser454
```

### Low-Frequency Users (Will hit L3 MongoDB)
```bash
# Test these rarely - should get < 20ms response
testuser099, testuser198, testuser297, testuser396, testuser495
```

## ⚡ Performance Targets
- **L1 Cache Hit** (Memory): < 1ms
- **L2 Cache Hit** (Redis): < 5ms  
- **L3 Cache Hit** (MongoDB): < 20ms
- **Cache Miss** (LDAP): < 100ms

## 🔒 Security Features
- All passwords use SSHA encryption in LDAP
- Cache data encrypted with AES-256-GCM
- Anti-debugging protection active
- 5-minute key rotation for forward secrecy
- Security violation monitoring

---

**🚀 Ready to test enterprise-grade authentication with 1000 users and millisecond response times!**