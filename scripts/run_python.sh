#!/usr/bin/env bash
# Entrypoint for running Python scripts in their own venv
SCRIPT_NAME="$1"
shift
cd "$(dirname "$0")/python"
if [ -f "$SCRIPT_NAME" ]; then
    if [ ! -d ".venv" ]; then
        python3 -m venv .venv
    fi
    source .venv/bin/activate
    pip install -r requirements.txt 2>/dev/null || true
    python "$SCRIPT_NAME" "$@"
    deactivate
else
    echo "Python script $SCRIPT_NAME not found."
    exit 1
fi
