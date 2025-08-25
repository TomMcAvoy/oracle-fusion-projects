#!/usr/bin/env bash
# Start WildFly server
WILDFLY_HOME="$(dirname "$0")/../../wildfly-37.0.0.Final"
cd "$WILDFLY_HOME/bin"
./standalone.sh "$@"
