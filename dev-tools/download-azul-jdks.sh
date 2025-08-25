#!/bin/bash
# Download Azul Zulu OpenJDKs 8-25 for Linux x64
set -e
cd ~/Downloads

# Array of Azul Zulu JDK versions and URLs
JDKS=(
  "8 https://cdn.azul.com/zulu/bin/zulu8.74.0.17-ca-jdk8.0.402-linux_x64.tar.gz"
  "11 https://cdn.azul.com/zulu/bin/zulu11.70.17-ca-jdk11.0.23-linux_x64.tar.gz"
  "17 https://cdn.azul.com/zulu/bin/zulu17.48.15-ca-jdk17.0.11-linux_x64.tar.gz"
  "21 https://cdn.azul.com/zulu/bin/zulu21.32.17-ca-jdk21.0.3-linux_x64.tar.gz"
  "22 https://cdn.azul.com/zulu/bin/zulu22.28.13-ca-jdk22.0.1-linux_x64.tar.gz"
  "23 https://cdn.azul.com/zulu/bin/zulu23.32.97-ca-jdk23.0.2-linux_x64.tar.gz"
  "24 https://cdn.azul.com/zulu/bin/zulu24.30.11-ca-jdk24.0.1-linux_x64.tar.gz"
  "25 https://cdn.azul.com/zulu/bin/zulu25.28.5-ca-jdk25-ea-linux_x64.tar.gz"
)

for entry in "${JDKS[@]}"; do
  set -- $entry
  VER=$1
  URL=$2
  echo "Downloading JDK $VER..."
  wget -c "$URL"
done

echo "All Azul Zulu JDKs downloaded to ~/Downloads."
for entry in "${JDKS[@]}"; do
  set -- $entry
  VER=$1
  URL=$2
  echo "Checking JDK $VER..."
  if curl --head --silent --fail "$URL" > /dev/null; then
    echo "  Available. Downloading..."
    wget -c "$URL"
  else
    echo "  Not found on Azul CDN: $URL"
  fi
done

echo "Check complete. Available Azul Zulu JDKs downloaded to ~/Downloads."
