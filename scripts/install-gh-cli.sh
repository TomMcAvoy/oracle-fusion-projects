#!/bin/bash
# Install GitHub CLI (gh) on Ubuntu/Debian
set -e

# Install dependencies
sudo apt-get update
sudo apt-get install -y curl apt-transport-https

# Add GitHub CLI repository
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# Install gh
sudo apt-get update
sudo apt-get install -y gh

echo "GitHub CLI (gh) installed successfully. Run 'gh auth login' to authenticate."
