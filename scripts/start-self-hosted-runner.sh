#!/bin/bash

# Start Self-Hosted GitHub Actions Runner
# This script will start your self-hosted runner for oracle-fusion-projects

set -e

echo "🏃‍♂️ STARTING SELF-HOSTED GITHUB ACTIONS RUNNER"
echo "==============================================="
echo ""

# Check if runner directory exists
RUNNER_DIRS=(
    "$HOME/actions-runner-oracle-fusion-projects"
    "$HOME/actions-runner-$USER"
    "$HOME/actions-runner"
)

RUNNER_DIR=""
for dir in "${RUNNER_DIRS[@]}"; do
    if [[ -d "$dir" && -f "$dir/run.sh" ]]; then
        RUNNER_DIR="$dir"
        echo "✅ Found runner directory: $RUNNER_DIR"
        break
    fi
done

if [[ -z "$RUNNER_DIR" ]]; then
    echo "❌ GitHub Actions runner not found in common locations:"
    for dir in "${RUNNER_DIRS[@]}"; do
        echo "   • $dir"
    done
    echo ""
    echo "💡 Need to set up a runner? Run:"
    echo "   ./scripts/setup-gh-runner.sh"
    exit 1
fi

cd "$RUNNER_DIR"

# Check if runner is already running
if pgrep -f "Runner.Listener" > /dev/null; then
    echo "⚠️ Runner appears to already be running"
    echo ""
    echo "📊 Process info:"
    ps aux | grep -v grep | grep "Runner.Listener" || echo "   No Runner.Listener process found"
    echo ""
    echo "🔍 To stop existing runner:"
    echo "   pkill -f Runner.Listener"
    echo ""
    read -p "Kill existing runner and restart? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🛑 Stopping existing runner..."
        pkill -f "Runner.Listener" || true
        sleep 3
    else
        echo "✅ Keeping existing runner"
        exit 0
    fi
fi

echo "🚀 Starting GitHub Actions runner..."
echo "Directory: $RUNNER_DIR"
echo ""

# Start runner in foreground (recommended for testing)
echo "💡 Starting runner in foreground mode"
echo "   Press Ctrl+C to stop the runner"
echo "   For background mode, use: nohup ./run.sh &"
echo ""
echo "Starting in 3 seconds..."
sleep 3

./run.sh