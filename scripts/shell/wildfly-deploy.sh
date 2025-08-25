#!/usr/bin/env bash
# Build and deploy all Maven modules to WildFly
cd "$(dirname "$0")/../../"
mvn clean install -DskipTests
# Deploy logic can be added here if needed (e.g., copy WARs to WildFly deployments)
