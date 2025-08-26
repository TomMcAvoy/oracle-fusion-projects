#!/bin/bash
# Script to install Oracle JDKs (23, 24, 25) from tar.gz files in ~/Downloads and register with update-alternatives

set -e
JVM_DIR="/usr/lib/jvm"

sudo mkdir -p "$JVM_DIR"

for VER in 23 24 25; do
  TAR=~/Downloads/jdk-${VER}_linux-x64_bin.tar.gz
  if [ -f "$TAR" ]; then
    tar -xzf "$TAR"
    DIR=$(tar -tf "$TAR" | head -1 | cut -f1 -d"/")
    sudo mv "$DIR" "$JVM_DIR/jdk-$VER"
    sudo update-alternatives --install /usr/bin/java java "$JVM_DIR/jdk-$VER/bin/java" ${VER}00
    sudo update-alternatives --install /usr/bin/javac javac "$JVM_DIR/jdk-$VER/bin/javac" ${VER}00
    echo "Oracle JDK $VER installed and registered."
  else
    echo "Tarball for JDK $VER not found in ~/Downloads. Please download it from Oracle first."
  fi
done

echo "To switch Java versions, run: sudo update-alternatives --config java"
echo "To switch javac versions, run: sudo update-alternatives --config javac"
