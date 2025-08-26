#!/usr/bin/env bash
# Entrypoint for running TypeScript scripts
SCRIPT_NAME="$1"
shift
cd "$(dirname "$0")/typescript"
if [ -f "$SCRIPT_NAME" ]; then
    if [ ! -d "node_modules" ]; then
        npm install
    fi
    npx ts-node "$SCRIPT_NAME" "$@"
else
    echo "TypeScript script $SCRIPT_NAME not found."
    exit 1
fi
