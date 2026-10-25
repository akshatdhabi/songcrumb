#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_build_root="${SONGCRUMB_BUILD_DIR:-$task_root/build}"
task_app="$task_build_root/Songcrumb.app"
mkdir -p "$task_app/Contents/MacOS" "$task_app/Contents/Resources" "$task_build_root/module-cache"
xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 \
  -module-cache-path "$task_build_root/module-cache" \
  -O -whole-module-optimization -parse-as-library \
  "$task_root"/Songcrumb/Core/*.swift "$task_root"/Songcrumb/App/*.swift \
  -o "$task_app/Contents/MacOS/Songcrumb" -module-name Songcrumb \
  -framework SwiftUI -framework AppKit -framework Network -framework CryptoKit
cp "$task_root/Songcrumb/Info.plist" "$task_app/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string io.github.akshatdhabi.songcrumb "$task_app/Contents/Info.plist"
if [[ -f "$task_root/Songcrumb/AppIcon.icns" ]]; then cp "$task_root/Songcrumb/AppIcon.icns" "$task_app/Contents/Resources/"; fi
codesign --force --sign - --options runtime --entitlements "$task_root/Songcrumb/Songcrumb.entitlements" "$task_app"
echo "Built: $task_app"
echo "Launch: open \"$task_app\""
