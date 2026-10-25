#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$task_root/build/module-cache" \
  Songcrumb/Core/*.swift Tests/CoreChecks/*.swift -o build/CoreChecks
build/CoreChecks
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$task_root/build/module-cache" \
  Songcrumb/Core/*.swift Songcrumb/App/Preferences.swift Songcrumb/App/LyricsService.swift Scripts/ProviderChecks.swift \
  -o build/ProviderChecks -framework SwiftUI -framework AppKit
build/ProviderChecks
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$task_root/build/module-cache" \
  Songcrumb/Core/*.swift Songcrumb/App/DesktopPlayer.swift Scripts/DesktopChecks.swift -o build/DesktopChecks
build/DesktopChecks
python3 Scripts/test_bridge.py
if command -v node >/dev/null 2>&1; then
  for task_js in YouTubeMusicCompanion/*.js; do node --check "$task_js"; done
  node Scripts/test_companion.cjs
fi
