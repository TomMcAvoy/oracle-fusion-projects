#!/bin/bash
# Install all OpenJDK versions available via apt on Ubuntu
set -e

sudo apt-get update
sudo apt-get install -y openjdk-8-jdk openjdk-11-jdk openjdk-17-jdk openjdk-21-jdk

echo "Installed OpenJDK versions:"
update-alternatives --list java || echo "No alternatives found."
echo "To switch Java versions, run: sudo update-alternatives --config java"
