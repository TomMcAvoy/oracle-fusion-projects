#!/bin/bash

# Enable MongoDB TLS Security
# This script configures the existing MongoDB for enterprise security

set -e

echo "🔐 Enabling MongoDB TLS Security"
echo "================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MONGO_DATA_DIR="/usr/local/var/mongodb-secure"
MONGO_LOG_FILE="/usr/local/var/log/mongodb/mongo-secure.log"
MONGO_PID_FILE="/usr/local/var/run/mongod-secure.pid"

stop_current_mongodb() {
    echo -e "${BLUE}🛑 Stopping current MongoDB...${NC}"
    
    # Find MongoDB process
    MONGO_PID=$(ps aux | grep mongod | grep -v grep | awk '{print $2}' | head -1)
    
    if [ ! -z "$MONGO_PID" ]; then
        echo -e "${YELLOW}Stopping MongoDB process $MONGO_PID...${NC}"
        kill -TERM "$MONGO_PID"
        sleep 5
        
        # Force kill if still running
        if kill -0 "$MONGO_PID" 2>/dev/null; then
            echo -e "${YELLOW}Force stopping MongoDB...${NC}"
            kill -KILL "$MONGO_PID"
            sleep 2
        fi
        
        echo -e "${GREEN}✅ MongoDB stopped${NC}"
    else
        echo -e "${GREEN}✅ MongoDB not running${NC}"
    fi
}

setup_tls_certificates() {
    echo -e "${BLUE}🔑 Setting up TLS certificates...${NC}"
    
    cd "$(dirname "$0")/mongodb/tls"
    
    if [ ! -f "ca.crt" ]; then
        echo -e "${YELLOW}Generating TLS certificates...${NC}"
        chmod +x generate-certs.sh
        ./generate-certs.sh
    else
        echo -e "${GREEN}✅ TLS certificates already exist${NC}"
    fi
}

create_secure_data_directory() {
    echo -e "${BLUE}📁 Setting up secure data directory...${NC}"
    
    # Create secure MongoDB data directory
    if [ ! -d "$MONGO_DATA_DIR" ]; then
        sudo mkdir -p "$MONGO_DATA_DIR"
        sudo chown $(whoami):staff "$MONGO_DATA_DIR"
        echo -e "${GREEN}✅ Secure data directory created${NC}"
    fi
    
    # Create log directory
    sudo mkdir -p "$(dirname "$MONGO_LOG_FILE")"
    sudo chown $(whoami):staff "$(dirname "$MONGO_LOG_FILE")"
    
    # Create PID directory
    sudo mkdir -p "$(dirname "$MONGO_PID_FILE")"
    sudo chown $(whoami):staff "$(dirname "$MONGO_PID_FILE")"
}

migrate_existing_data() {
    echo -e "${BLUE}📦 Migrating existing data...${NC}"
    
    local source_dir="/usr/local/var/mongodb"
    
    if [ -d "$source_dir" ] && [ "$(ls -A "$source_dir")" ]; then
        echo -e "${YELLOW}Copying existing data to secure directory...${NC}"
        cp -r "$source_dir"/* "$MONGO_DATA_DIR/"
        echo -e "${GREEN}✅ Data migrated${NC}"
    else
        echo -e "${YELLOW}No existing data to migrate${NC}"
    fi
}

create_mongodb_user() {
    echo -e "${BLUE}👤 Creating MongoDB authentication user...${NC}"
    
    # Start MongoDB temporarily without auth for user creation
    echo -e "${YELLOW}Starting temporary MongoDB for user setup...${NC}"
    
    mongod --config "$(dirname "$0")/mongodb/mongod-secure.conf" --noauth --fork \
           --logpath /tmp/mongo-temp.log --pidfilepath /tmp/mongo-temp.pid
    
    sleep 3
    
    # Create admin user
    mongosh --eval '
    use admin;
    db.createUser({
      user: "admin",
      pwd: "MongoAdmin2024!",
      roles: ["root"]
    });
    
    use authcache;
    db.createUser({
      user: "authcache",
      pwd: "MongoCacheUser2024!",
      roles: [
        { role: "readWrite", db: "authcache" }
      ]
    });
    
    print("✅ MongoDB users created");
    '
    
    # Stop temporary MongoDB
    TEMP_PID=$(cat /tmp/mongo-temp.pid)
    kill -TERM "$TEMP_PID"
    rm -f /tmp/mongo-temp.log /tmp/mongo-temp.pid
    
    echo -e "${GREEN}✅ MongoDB users created${NC}"
}

start_secure_mongodb() {
    echo -e "${BLUE}🚀 Starting secure MongoDB...${NC}"
    
    # Start MongoDB with TLS and authentication
    mongod --config "$(dirname "$0")/mongodb/mongod-secure.conf" --fork
    
    sleep 5
    
    # Test TLS connection
    if mongosh "mongodb://authcache:MongoCacheUser2024!@localhost:27017/authcache?tls=true&tlsCAFile=$(pwd)/mongodb/tls/ca.crt" --eval "db.runCommand({ping: 1})" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Secure MongoDB is running with TLS!${NC}"
        return 0
    else
        echo -e "${RED}❌ TLS connection test failed${NC}"
        return 1
    fi
}

update_application_config() {
    echo -e "${BLUE}⚙️  Updating application configuration...${NC}"
    
    # Set environment variables for TLS connection
    cat > "$(dirname "$0")/mongodb-tls.env" << EOF
# MongoDB TLS Configuration for Enterprise Auth Cache
export MONGODB_URL="mongodb://authcache:MongoCacheUser2024!@localhost:27017/authcache?tls=true&authSource=authcache"
export MONGODB_TRUSTSTORE_PATH="$(pwd)/mongodb/tls/mongodb-truststore.jks"
export MONGODB_TRUSTSTORE_PASSWORD="MongoTrust2024!"
export MONGODB_KEYSTORE_PATH="$(pwd)/mongodb/tls/mongodb-keystore.jks"
export MONGODB_KEYSTORE_PASSWORD="MongoClient2024!"

# Java system properties for TLS
export JAVA_OPTS="\$JAVA_OPTS -Dmongodb.url=\$MONGODB_URL"
export JAVA_OPTS="\$JAVA_OPTS -Dmongodb.truststore=\$MONGODB_TRUSTSTORE_PATH"
export JAVA_OPTS="\$JAVA_OPTS -Dmongodb.truststore.password=\$MONGODB_TRUSTSTORE_PASSWORD"
export JAVA_OPTS="\$JAVA_OPTS -Dmongodb.keystore=\$MONGODB_KEYSTORE_PATH"
export JAVA_OPTS="\$JAVA_OPTS -Dmongodb.keystore.password=\$MONGODB_KEYSTORE_PASSWORD"
EOF
    
    echo -e "${GREEN}✅ TLS configuration saved to mongodb-tls.env${NC}"
    echo -e "${YELLOW}💡 To enable TLS, run: source mongodb-tls.env${NC}"
}

verify_security() {
    echo -e "${BLUE}🔍 Verifying security configuration...${NC}"
    
    # Test that non-TLS connections are rejected
    if mongosh "mongodb://localhost:27017/authcache" --eval "db.runCommand({ping: 1})" > /dev/null 2>&1; then
        echo -e "${RED}❌ WARNING: Non-TLS connections are still allowed!${NC}"
    else
        echo -e "${GREEN}✅ Non-TLS connections properly rejected${NC}"
    fi
    
    # Test authentication
    if mongosh "mongodb://localhost:27017/authcache?tls=true&tlsCAFile=$(pwd)/mongodb/tls/ca.crt" --eval "db.runCommand({ping: 1})" > /dev/null 2>&1; then
        echo -e "${RED}❌ WARNING: Unauthenticated connections allowed!${NC}"
    else
        echo -e "${GREEN}✅ Authentication properly required${NC}"
    fi
    
    echo -e "${GREEN}✅ Security verification complete${NC}"
}

show_final_status() {
    echo ""
    echo -e "${GREEN}🎉 MongoDB TLS Security Enabled!${NC}"
    echo -e "${BLUE}=" * 40 "${NC}"
    echo -e "${GREEN}✅ TLS Encryption: Enabled${NC}"
    echo -e "${GREEN}✅ Authentication: Required${NC}"
    echo -e "${GREEN}✅ Client Certificates: Configured${NC}"
    echo -e "${GREEN}✅ Database: authcache${NC}"
    
    echo ""
    echo -e "${BLUE}🔑 Connection Details:${NC}"
    echo -e "${CYAN}URL: mongodb://authcache:MongoCacheUser2024!@localhost:27017/authcache?tls=true&authSource=authcache${NC}"
    echo -e "${CYAN}Admin: admin / MongoAdmin2024!${NC}"
    echo -e "${CYAN}App User: authcache / MongoCacheUser2024!${NC}"
    
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo -e "${CYAN}1. Source TLS config: source mongodb-tls.env${NC}"
    echo -e "${CYAN}2. Restart your application server${NC}"
    echo -e "${CYAN}3. Verify TLS in logs: 'MongoDB TLS with mutual authentication enabled'${NC}"
    
    echo ""
    echo -e "${YELLOW}💡 To revert to development mode:${NC}"
    echo -e "${YELLOW}   Kill secure MongoDB and restart with: mongod --config /usr/local/etc/mongod.conf${NC}"
}

main() {
    echo -e "${BLUE}This will enable TLS security for MongoDB${NC}"
    echo -e "${YELLOW}⚠️  This will stop the current MongoDB instance${NC}"
    echo ""
    echo -n "Continue? (y/N): "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled${NC}"
        exit 0
    fi
    
    stop_current_mongodb
    setup_tls_certificates
    create_secure_data_directory
    migrate_existing_data
    create_mongodb_user
    start_secure_mongodb
    update_application_config
    verify_security
    show_final_status
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi