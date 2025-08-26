# WildFly environment setup for local development
export WILDFLY_HOME="$(pwd)/wildfly-37.0.0.Final"
export PATH="$WILDFLY_HOME/bin:$PATH"

# WildFly admin credentials for Maven plugin deployment
export WILDFLY_ADMIN_USER=admin
export WILDFLY_ADMIN_PASS=changeme
