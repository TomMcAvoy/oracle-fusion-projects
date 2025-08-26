#!/usr/bin/env bash
# Watch for code changes and trigger Maven build, deploy, and test
# Features can be enabled/disabled with environment variables:
#   ENABLE_DEPLOY=true/false, ENABLE_TEST=true/false

ENABLE_DEPLOY=${ENABLE_DEPLOY:-true}
ENABLE_TEST=${ENABLE_TEST:-true}

cd "$(dirname "$0")/../../"
while true; do
  inotifywait -r -e modify,create,delete auth-*/src/ || break
  echo "[INFO] Detected code change. Rebuilding..."
  mvn install -DskipTests
  echo "[INFO] Build complete."

  if [ "$ENABLE_DEPLOY" = "true" ]; then
    echo "[INFO] Deploying to WildFly..."
    # Copy all WARs to WildFly deployments directory
    find . -name "*.war" -exec cp {} wildfly-37.0.0.Final/standalone/deployments/ \;
    echo "[INFO] Deployment complete."
  fi

  if [ "$ENABLE_TEST" = "true" ]; then
    echo "[INFO] Running tests..."
    mvn test
    echo "[INFO] Tests complete."
  fi
done
