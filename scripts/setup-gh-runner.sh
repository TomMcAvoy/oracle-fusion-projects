#!/bin/bash
set -e

# Config
OWNER="TomMcAvoy"
REPO="oracle-fusion-projects"
RUNNER_NAME="vault-runner-$(hostname)"
RUNNER_DIR="$HOME/actions-runner-$REPO"
LABELS="self-hosted,linux,vault"

# Create runner directory
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# Get latest runner version
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/v//')
RUNNER_PKG="actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

# Download runner
curl -O -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_PKG}"
tar xzf "$RUNNER_PKG"

# Get registration token using gh CLI
REG_TOKEN=$(gh api -X POST /repos/$OWNER/$REPO/actions/runners/registration-token --jq .token)

# Configure runner
./config.sh --url "https://github.com/$OWNER/$REPO" --token "$REG_TOKEN" --name "$RUNNER_NAME" --labels "$LABELS" --unattended

# Start runner in background
./run.sh &

echo "Self-hosted GitHub Actions runner setup complete and running."
