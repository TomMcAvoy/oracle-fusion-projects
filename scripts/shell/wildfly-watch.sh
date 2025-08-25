#!/usr/bin/env bash
# Watch for code changes and trigger Maven build
cd "$(dirname "$0")/../../"
while true; do
  inotifywait -r -e modify,create,delete src/ || break
  echo "[INFO] Detected code change. Rebuilding..."
  mvn install -DskipTests
  # Optionally, redeploy to WildFly here
  echo "[INFO] Build complete."
done
