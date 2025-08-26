#!/usr/bin/env bash
# Entrypoint for running Java scripts
SCRIPT_NAME="$1"
shift
cd "$(dirname "$0")/java"
if [ -f "$SCRIPT_NAME" ]; then
    javac "$SCRIPT_NAME"
    java "${SCRIPT_NAME%.java}" "$@"
else
    echo "Java script $SCRIPT_NAME not found."
    exit 1
fi
