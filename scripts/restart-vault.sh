#!/bin/bash
# Restart Vault Docker Compose and return to original directory
ORIG_DIR="$(pwd)"
cd /home/tom/GitHub/oracle-fusion-projects/sec-devops-tools/docker/vault || exit 1
docker compose down
docker compose up -d --build
cd "$ORIG_DIR"
