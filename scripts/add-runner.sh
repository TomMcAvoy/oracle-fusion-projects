#!/bin/bash

# GitHub Actions Self-Hosted Runner Setup Script
# ⚠️ WARNING: This will create NEW INFRASTRUCTURE COSTS!
# Each runner requires a separate VM ($20-50/month)

echo "💰 COST WARNING: ADDING RUNNERS COSTS MONEY!"
echo "============================================"
echo "💸 Each runner needs a separate VM: $20-50/month"
echo "💸 5 runners = $100-250/month infrastructure cost"
echo ""
read -p "🤔 Are you sure you need additional runners? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "✅ Smart choice! Current 1 runner + trigger optimization should be sufficient."
    echo "💡 Try the optimized setup first. Add runners only if bottlenecks persist."
    exit 0
fi

echo "🏃‍♂️ PROCEEDING WITH RUNNER SETUP"
echo "================================"

# Check if running as root (needed for service installation)
if [[ $EUID -eq 0 ]]; then
   echo "❌ Don't run as root. Run as the user who will own the runner."
   exit 1
fi

RUNNER_NAME="oracle-fusion-runner-$(hostname)-$(date +%s)"
RUNNER_VERSION="2.319.1"
REPO_URL="https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)"

echo "📋 Configuration:"
echo "  Runner Name: $RUNNER_NAME"
echo "  Repository: $REPO_URL"
echo "  Version: $RUNNER_VERSION"
echo ""

# Create runner directory
RUNNER_DIR="$HOME/actions-runner-$RUNNER_NAME"
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

echo "📥 Downloading GitHub Actions Runner..."
curl -O -L "https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-linux-x64-$RUNNER_VERSION.tar.gz"

echo "📦 Extracting runner..."
tar xzf "./actions-runner-linux-x64-$RUNNER_VERSION.tar.gz"

echo "🔐 Getting registration token..."
if ! RUNNER_TOKEN=$(gh api repos/:owner/:repo/actions/runners/registration-token --jq '.token' 2>/dev/null); then
    echo "❌ Failed to get registration token"
    echo "💡 Make sure you're authenticated with 'gh auth login'"
    exit 1
fi

echo "⚙️ Configuring runner..."
./config.sh \
    --url "$REPO_URL" \
    --token "$RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "self-hosted,linux,oracle-fusion" \
    --work "_work" \
    --replace \
    --unattended

echo "🚀 Installing as service..."
sudo ./svc.sh install
sudo ./svc.sh start

echo ""
echo "✅ RUNNER SETUP COMPLETE!"
echo "========================"
echo "Runner: $RUNNER_NAME"
echo "Status: $(sudo ./svc.sh status)"
echo ""
echo "📊 Check runner status:"
echo "gh api repos/:owner/:repo/actions/runners --jq '.runners[] | \"Name: \\(.name) | Status: \\(.status) | Busy: \\(.busy)\"'"