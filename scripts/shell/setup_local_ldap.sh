#!/bin/bash
# Setup Local OpenLDAP Server with 1000 Test Users
# Alternative to Docker setup for immediate testing

set -e

echo "🔧 Setting up Local OpenLDAP Server..."
echo "======================================"

# Check if OpenLDAP is installed
if ! command -v slapd &> /dev/null; then
    echo "📦 Installing OpenLDAP via Homebrew..."
    brew install openldap
fi

# Create LDAP data directory
LDAP_DIR="/usr/local/var/lib/ldap"
LDAP_CONFIG_DIR="/usr/local/etc/openldap"
DATA_DIR="$HOME/ldap-data"

echo "📁 Creating LDAP directories..."
mkdir -p "$DATA_DIR"/{data,config,logs}

# Create slapd.conf configuration
echo "⚙️  Creating LDAP configuration..."
cat > "$DATA_DIR/slapd.conf" << 'EOF'
# OpenLDAP Configuration for White Startups Test
include /usr/local/etc/openldap/schema/core.schema
include /usr/local/etc/openldap/schema/cosine.schema
include /usr/local/etc/openldap/schema/inetorgperson.schema
include /usr/local/etc/openldap/schema/nis.schema

pidfile /usr/local/var/run/slapd.pid
argsfile /usr/local/var/run/slapd.args

loglevel 256

# Database configuration
database mdb
suffix "dc=whitestartups,dc=com"
rootdn "cn=admin,dc=whitestartups,dc=com"
rootpw {SSHA}WhiteStartups2024!

directory /usr/local/var/lib/ldap

index objectClass eq
index uid eq
index cn eq
index mail eq
index employeeNumber eq

# Access control
access to attrs=userPassword,shadowLastChange
    by dn="cn=admin,dc=whitestartups,dc=com" write
    by anonymous auth
    by self write
    by * none

access to *
    by dn="cn=admin,dc=whitestartups,dc=com" write
    by * read
EOF

# Create systemd-style launch agent for macOS
echo "🚀 Creating LDAP startup script..."
cat > "$DATA_DIR/start-ldap.sh" << EOF
#!/bin/bash
echo "Starting OpenLDAP server..."
/usr/local/libexec/slapd -f "$DATA_DIR/slapd.conf" -h "ldap://0.0.0.0:389" -d 256
EOF

chmod +x "$DATA_DIR/start-ldap.sh"

# Create stop script
cat > "$DATA_DIR/stop-ldap.sh" << 'EOF'
#!/bin/bash
echo "Stopping OpenLDAP server..."
pkill -f slapd
EOF

chmod +x "$DATA_DIR/stop-ldap.sh"

# Create base LDIF
echo "📄 Creating base LDAP structure..."
cat > "$DATA_DIR/base.ldif" << 'EOF'
# Base DN
dn: dc=whitestartups,dc=com
objectClass: top
objectClass: dcObject
objectClass: organization
o: White Startups Inc
dc: whitestartups

# People OU
dn: ou=people,dc=whitestartups,dc=com
objectClass: organizationalUnit
ou: people

# Groups OU  
dn: ou=groups,dc=whitestartups,dc=com
objectClass: organizationalUnit
ou: groups

# Admin user
dn: cn=admin,dc=whitestartups,dc=com
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: admin
userPassword: {SSHA}WhiteStartups2024!
description: LDAP administrator
EOF

echo "✅ Local LDAP setup created!"
echo ""
echo "🚀 To start LDAP server:"
echo "   $DATA_DIR/start-ldap.sh"
echo ""
echo "🛑 To stop LDAP server:"
echo "   $DATA_DIR/stop-ldap.sh" 
echo ""
echo "📁 LDAP data directory: $DATA_DIR"
echo ""
echo "📝 Next steps:"
echo "   1. Start LDAP server: $DATA_DIR/start-ldap.sh"
echo "   2. Load base structure: ldapadd -x -D 'cn=admin,dc=whitestartups,dc=com' -w 'WhiteStartups2024!' -f $DATA_DIR/base.ldif"
echo "   3. Load 1000 test users: ldapadd -x -D 'cn=admin,dc=whitestartups,dc=com' -w 'WhiteStartups2024!' -f ldap/ldif/02-1000-test-users.ldif"
echo "   4. Test with: python3 test_ldap_credentials.py"
echo "   4. Test with: python3 ../python/test_ldap_credentials.py"