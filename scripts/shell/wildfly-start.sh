#!/usr/bin/env bash
# Start WildFly server in the background
WILDFLY_HOME="$(dirname "$0")/../../wildfly-37.0.0.Final"
cd "$WILDFLY_HOME/bin"
nohup ./standalone.sh "$@" > /dev/null 2>&1 &
echo "WildFly started in background with PID $!"
