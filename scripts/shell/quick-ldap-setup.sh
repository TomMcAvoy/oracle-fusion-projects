#!/bin/bash

# Quick LDAP Setup - Multiple Options
# Choose the fastest option for your environment

set -e

echo "🚀 Quick LDAP Setup - Choose Your Option"
echo "======================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_options() {
    echo -e "${BLUE}Available LDAP Options:${NC}"
    echo "1. 🐳 Docker OpenLDAP (Fastest - 2 minutes)"
    echo "2. ☕ OpenDJ (Java-based, very fast, enterprise-grade)"
    echo "3. 🔧 ApacheDS (Java-based, easiest setup)"
    echo "4. 🏠 Native OpenLDAP (macOS Homebrew)"
    echo ""
}

setup_docker_ldap() {
    echo -e "${BLUE}🐳 Setting up Docker OpenLDAP...${NC}"
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
        return 1
    fi
    
    # Create simple docker-compose for just LDAP
    cat > docker-compose-ldap-only.yml << 'EOF'
version: '3.8'

services:
  openldap:
    image: osixia/openldap:1.5.0
    container_name: quick-ldap
    hostname: ldap.local
    ports:
      - "389:389"
      - "636:636"
    environment:
      LDAP_ORGANISATION: "Test Corp"
      LDAP_DOMAIN: "test.local"
      LDAP_BASE_DN: "dc=test,dc=local"
      LDAP_ADMIN_PASSWORD: "admin123"
      LDAP_CONFIG_PASSWORD: "config123"
      LDAP_READONLY_USER: "false"
      LDAP_RFC2307BIS_SCHEMA: "false"
      LDAP_BACKEND: "mdb"
      LDAP_TLS: "false"
      LDAP_REPLICATION: "false"
      LDAP_REMOVE_CONFIG_AFTER_SETUP: "true"
      LDAP_LOG_LEVEL: "256"
    volumes:
      - ./ldap-quick:/container/service/slapd/assets/config/bootstrap/ldif/custom
    restart: unless-stopped
    command: --copy-service
EOF

    # Create quick LDIF with test users
    mkdir -p ldap-quick
    cat > ldap-quick/quick-users.ldif << 'EOF'
# Quick test users for immediate testing
dn: ou=people,dc=test,dc=local
objectClass: organizationalUnit
ou: people

# Test user 1
dn: uid=testuser001,ou=people,dc=test,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: testuser001
sn: User001
givenName: Test
cn: Test User001
uidNumber: 1001
gidNumber: 1001
userPassword: TestPass1!
loginShell: /bin/bash
homeDirectory: /home/testuser001
mail: testuser001@test.local

# Test user 2
dn: uid=testuser002,ou=people,dc=test,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: testuser002
sn: User002
givenName: Test
cn: Test User002
uidNumber: 1002
gidNumber: 1002
userPassword: TestPass2!
loginShell: /bin/bash
homeDirectory: /home/testuser002
mail: testuser002@test.local

# Test user 3
dn: uid=testuser003,ou=people,dc=test,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: testuser003
sn: User003
givenName: Test
cn: Test User003
uidNumber: 1003
gidNumber: 1003
userPassword: TestPass3!
loginShell: /bin/bash
homeDirectory: /home/testuser003
mail: testuser003@test.local
EOF

    echo -e "${YELLOW}🚀 Starting Docker LDAP...${NC}"
    docker-compose -f docker-compose-ldap-only.yml up -d
    
    echo -e "${YELLOW}⏳ Waiting for LDAP to start...${NC}"
    sleep 10
    
    # Test connection
    if docker exec quick-ldap ldapsearch -x -H ldap://localhost -b dc=test,dc=local -D "cn=admin,dc=test,dc=local" -w admin123 "(objectclass=*)" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker LDAP is running!${NC}"
        echo -e "${GREEN}🔗 LDAP Server: localhost:389${NC}"
        echo -e "${GREEN}🔑 Admin DN: cn=admin,dc=test,dc=local${NC}"
        echo -e "${GREEN}🔐 Admin Password: admin123${NC}"
        echo -e "${GREEN}👥 Test Users: testuser001, testuser002, testuser003${NC}"
        echo -e "${GREEN}🔑 Test Passwords: TestPass1!, TestPass2!, TestPass3!${NC}"
        return 0
    else
        echo -e "${RED}❌ LDAP failed to start properly${NC}"
        return 1
    fi
}

setup_opendj() {
    echo -e "${BLUE}☕ Setting up OpenDJ...${NC}"
    
    # Check Java
    if ! command -v java &> /dev/null; then
        echo -e "${RED}❌ Java not found. Installing OpenJDK...${NC}"
        brew install openjdk@11
        export JAVA_HOME=$(/usr/libexec/java_home -v 11)
    fi
    
    # Download OpenDJ
    OPENDJ_DIR="$HOME/opendj"
    if [ ! -d "$OPENDJ_DIR" ]; then
        echo -e "${YELLOW}📥 Downloading OpenDJ...${NC}"
        cd "$HOME"
        curl -L -o opendj.zip "https://github.com/OpenIdentityPlatform/OpenDJ/releases/download/4.4.15/opendj-4.4.15.zip"
        unzip opendj.zip
        mv opendj-* opendj
        rm opendj.zip
    fi
    
    # Setup OpenDJ
    cd "$OPENDJ_DIR"
    
    if [ ! -f config/config.ldif ]; then
        echo -e "${YELLOW}⚙️  Configuring OpenDJ...${NC}"
        ./setup --cli --hostname localhost --ldapPort 389 --rootUserDN "cn=Directory Manager" --rootUserPassword "password123" --baseDN "dc=test,dc=local" --acceptLicense --no-prompt
    fi
    
    # Start OpenDJ
    echo -e "${YELLOW}🚀 Starting OpenDJ...${NC}"
    ./bin/start-ds --quiet
    
    # Add test users
    cat > /tmp/opendj-users.ldif << 'EOF'
dn: ou=people,dc=test,dc=local
objectClass: organizationalUnit
ou: people

dn: uid=testuser001,ou=people,dc=test,dc=local
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
uid: testuser001
sn: User001
cn: Test User001
givenName: Test
mail: testuser001@test.local
userPassword: TestPass1!

dn: uid=testuser002,ou=people,dc=test,dc=local
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
uid: testuser002
sn: User002
cn: Test User002
givenName: Test
mail: testuser002@test.local
userPassword: TestPass2!

dn: uid=testuser003,ou=people,dc=test,dc=local
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
uid: testuser003
sn: User003
cn: Test User003
givenName: Test
mail: testuser003@test.local
userPassword: TestPass3!
EOF

    ./bin/ldapmodify -h localhost -p 389 -D "cn=Directory Manager" -w password123 -a -f /tmp/opendj-users.ldif
    
    echo -e "${GREEN}✅ OpenDJ is running!${NC}"
    echo -e "${GREEN}🔗 LDAP Server: localhost:389${NC}"
    echo -e "${GREEN}🔑 Admin DN: cn=Directory Manager${NC}"
    echo -e "${GREEN}🔐 Admin Password: password123${NC}"
    echo -e "${GREEN}👥 Test Users: testuser001, testuser002, testuser003${NC}"
    echo -e "${GREEN}🔑 Test Passwords: TestPass1!, TestPass2!, TestPass3!${NC}"
}

setup_apacheds() {
    echo -e "${BLUE}🔧 Setting up ApacheDS...${NC}"
    
    # Check Java
    if ! command -v java &> /dev/null; then
        echo -e "${YELLOW}📦 Installing Java...${NC}"
        brew install openjdk@11
    fi
    
    # Download ApacheDS
    APACHEDS_DIR="$HOME/apacheds"
    if [ ! -d "$APACHEDS_DIR" ]; then
        echo -e "${YELLOW}📥 Downloading ApacheDS...${NC}"
        cd "$HOME"
        curl -L -o apacheds.tar.gz "https://downloads.apache.org/directory/apacheds/dist/2.0.0.AM26/apacheds-2.0.0.AM26.tar.gz"
        tar -xzf apacheds.tar.gz
        mv apacheds-* apacheds
        rm apacheds.tar.gz
    fi
    
    # Start ApacheDS
    cd "$APACHEDS_DIR"
    echo -e "${YELLOW}🚀 Starting ApacheDS...${NC}"
    ./bin/apacheds.sh start default
    
    sleep 5
    
    echo -e "${GREEN}✅ ApacheDS is running!${NC}"
    echo -e "${GREEN}🔗 LDAP Server: localhost:10389${NC}"
    echo -e "${GREEN}🔑 Admin DN: uid=admin,ou=system${NC}"
    echo -e "${GREEN}🔐 Admin Password: secret${NC}"
    echo -e "${YELLOW}💡 Use LDAP Studio to add users: http://directory.apache.org/studio/${NC}"
}

setup_homebrew_ldap() {
    echo -e "${BLUE}🏠 Setting up Native OpenLDAP...${NC}"
    
    # Install OpenLDAP
    if ! command -v slapd &> /dev/null; then
        echo -e "${YELLOW}📦 Installing OpenLDAP via Homebrew...${NC}"
        brew install openldap
    fi
    
    # Create configuration
    LDAP_DIR="/usr/local/var/lib/ldap"
    sudo mkdir -p "$LDAP_DIR"
    
    # Create basic config
    cat > /tmp/slapd.conf << 'EOF'
include /usr/local/etc/openldap/schema/core.schema
include /usr/local/etc/openldap/schema/cosine.schema
include /usr/local/etc/openldap/schema/inetorgperson.schema

pidfile /usr/local/var/run/slapd.pid
argsfile /usr/local/var/run/slapd.args

database mdb
suffix "dc=test,dc=local"
rootdn "cn=admin,dc=test,dc=local"
rootpw admin123
directory /usr/local/var/lib/ldap

index objectClass eq
index uid eq
index cn eq
EOF

    # Start slapd
    sudo /usr/local/libexec/slapd -f /tmp/slapd.conf -h "ldap://0.0.0.0:389"
    
    echo -e "${GREEN}✅ Native OpenLDAP is running!${NC}"
    echo -e "${GREEN}🔗 LDAP Server: localhost:389${NC}"
    echo -e "${GREEN}🔑 Admin DN: cn=admin,dc=test,dc=local${NC}"
    echo -e "${GREEN}🔐 Admin Password: admin123${NC}"
}

test_ldap_connection() {
    echo -e "${BLUE}🔍 Testing LDAP Connection...${NC}"
    
    # Test different LDAP setups
    local servers=("localhost:389" "localhost:10389")
    local admin_dns=("cn=admin,dc=test,dc=local" "cn=Directory Manager,dc=test,dc=local" "uid=admin,ou=system")
    local passwords=("admin123" "password123" "secret")
    
    for server in "${servers[@]}"; do
        for i in "${!admin_dns[@]}"; do
            admin_dn="${admin_dns[$i]}"
            password="${passwords[$i]}"
            
            if ldapsearch -x -H "ldap://$server" -D "$admin_dn" -w "$password" -b "dc=test,dc=local" "(objectclass=*)" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Connection successful to $server${NC}"
                echo -e "${GREEN}   Admin DN: $admin_dn${NC}"
                echo -e "${GREEN}   Password: $password${NC}"
                return 0
            fi
        done
    done
    
    echo -e "${RED}❌ No LDAP server connection found${NC}"
    return 1
}

warm_up_cache() {
    echo -e "${BLUE}🔥 Warming up authentication cache...${NC}"
    
    # Create cache warmup script
    cat > cache-warmup.py << 'EOF'
#!/usr/bin/env python3
import requests
import json
import time
import concurrent.futures

BASE_URL = "http://localhost:8080/auth-web/api/auth"

# High-frequency users for cache warming
HIGH_FREQ_USERS = [
    ("testuser001", "TestPass1!"),
    ("testuser002", "TestPass2!"),
    ("testuser003", "TestPass3!"),
    ("testuser123", "TestPass3!"),
    ("testuser456", "TestPass6!"),
    ("testuser789", "TestPass9!"),
]

def warm_user(username, password):
    try:
        response = requests.post(f"{BASE_URL}/login", 
            json={"username": username, "password": password},
            timeout=5
        )
        if response.status_code == 200:
            data = response.json()
            return f"✅ {username}: {data.get('responseTimeMs', '?')}ms (cache: {data.get('cacheHit', False)})"
        else:
            return f"❌ {username}: HTTP {response.status_code}"
    except Exception as e:
        return f"❌ {username}: {str(e)}"

def main():
    print("🔥 Warming up authentication cache...")
    
    # Test server availability first
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        if response.status_code != 200:
            print("❌ Authentication server not available")
            return
    except:
        print("❌ Authentication server not accessible")
        return
    
    # Warm up high-frequency users multiple times
    results = []
    
    for round_num in range(3):
        print(f"\n🔄 Warmup Round {round_num + 1}/3")
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
            futures = []
            for username, password in HIGH_FREQ_USERS:
                futures.append(executor.submit(warm_user, username, password))
            
            for future in concurrent.futures.as_completed(futures):
                result = future.result()
                print(f"   {result}")
                results.append(result)
        
        time.sleep(1)  # Brief pause between rounds
    
    # Check cache stats
    try:
        response = requests.get(f"{BASE_URL}/stats", timeout=5)
        if response.status_code == 200:
            stats = response.json()
            print(f"\n📊 Cache Statistics:")
            print(f"   Cache Size: {stats.get('cacheSize', 0)}")
            print(f"   Hit Ratio: {stats.get('hitRatio', 0.0):.2%}")
            print(f"   Total Requests: {stats.get('totalRequests', 0)}")
    except:
        pass
    
    print("\n🎯 Cache warmup completed!")

if __name__ == "__main__":
    main()
EOF

    chmod +x cache-warmup.py
    
    # Install requests if needed
    pip3 install requests 2>/dev/null || echo "requests already installed"
    
    # Run warmup
    python3 cache-warmup.py
}

main() {
    show_options
    
    echo -n "Choose option (1-4): "
    read choice
    
    case $choice in
        1)
            setup_docker_ldap && test_ldap_connection && warm_up_cache
            ;;
        2)
            setup_opendj && test_ldap_connection && warm_up_cache
            ;;
        3)
            setup_apacheds && test_ldap_connection && warm_up_cache
            ;;
        4)
            setup_homebrew_ldap && test_ldap_connection && warm_up_cache
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}🎉 Quick LDAP Setup Complete!${NC}"
    echo -e "${BLUE}💡 Now you can run your tests with real LDAP authentication${NC}"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi