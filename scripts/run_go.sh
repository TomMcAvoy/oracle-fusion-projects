#!/usr/bin/env bash
# Entrypoint for running Go scripts
SCRIPT_NAME="$1"
shift
cd "$(dirname "$0")/go"
if [ -f "$SCRIPT_NAME" ]; then
    go run "$SCRIPT_NAME" "$@"
else
    echo "Go script $SCRIPT_NAME not found."
    exit 1
fi
