#!/bin/bash
set -euo pipefail

BUILD_DIR="build/Release"

echo "Building Cirrus (Release)..."
xcodebuild \
  -scheme Cirrus \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' \
  build \
  2>&1 | tail -5

APP_PATH="$BUILD_DIR/Build/Products/Release/Cirrus.app"

if [ -d "$APP_PATH" ]; then
  echo ""
  echo "Build succeeded: $APP_PATH"
  open -R "$APP_PATH"
else
  echo "Build failed: app not found at $APP_PATH"
  exit 1
fi
