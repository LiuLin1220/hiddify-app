#!/usr/bin/env bash
set -euo pipefail

# Fastforge runs this after Flutter builds and before each installer is made.
# LaunchAtLogin's copied helper needs a fresh signature after its plist changes.
app=build/macos/Build/Products/Release/Hiddify.app
helper="$app/Contents/Library/LoginItems/LaunchAtLoginHelper.app"
test -d "$helper"
codesign --force --sign - --timestamp=none \
  --preserve-metadata=identifier,entitlements,flags "$helper"

# The pinned Cronet static libraries were built for macOS 12.0.
/usr/libexec/PlistBuddy -c 'Set :LSMinimumSystemVersion 12.0' "$app/Contents/Info.plist"
codesign --force --sign - --timestamp=none \
  --entitlements macos/Runner/Release.entitlements "$app"
codesign --verify --deep --strict --verbose=2 "$app"
