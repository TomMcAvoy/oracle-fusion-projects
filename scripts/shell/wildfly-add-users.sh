#!/usr/bin/env bash
# Add default users to WildFly using add-user.sh
WILDFLY_HOME="$(dirname "$0")/../../wildfly-37.0.0.Final"
cd "$WILDFLY_HOME/bin"

# Example: Add admin user
./add-user.sh -a -u admin -p AdminPass123! -g admin

# Example: Add application user
./add-user.sh -a -u ci-bot -p CiBotPass123! -g deployer
./add-user.sh -a -u devuser -p DevUserPass123! -g developer
./add-user.sh -a -u monitoring -p MonitoringPass123! -g monitor
./add-user.sh -a -u auditor -p AuditorPass123! -g auditor
./add-user.sh -a -u appuser -p AppUserPass123! -g users

echo "Default users created."
echo "Default users and roles created."
