#!/bin/zsh
# Build local developer downloads. Publishing is handled separately by GitHub Actions.
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
task_version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Songcrumb/Info.plist)"
if [[ ! "$task_version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  echo 'Expected a numeric major.minor.patch app version.' >&2; exit 1
fi
task_output="$task_root/build/release"
mkdir -p "$task_output"
task_stage="$(mktemp -d "$task_root/build/release-stage.XXXXXX")"
trap 'rm -rf "$task_stage"' EXIT
SONGCRUMB_BUILD_DIR="$task_root/build/release-native" ./Scripts/build.sh
codesign --verify --deep --strict "$task_root/build/release-native/Songcrumb.app"
[[ "$(lipo -archs "$task_root/build/release-native/Songcrumb.app/Contents/MacOS/Songcrumb")" == arm64 ]]
python3 Scripts/check_public.py
mkdir -p "$task_stage/disk"
ditto "$task_root/build/release-native/Songcrumb.app" "$task_stage/disk/Songcrumb.app"
ln -s /Applications "$task_stage/disk/Applications"
cp LICENSE "$task_stage/disk/LICENSE.txt"
cp docs/INSTALL.txt "$task_stage/disk/Read Me First.txt"
git rev-parse HEAD > "$task_stage/disk/Source Commit.txt"
task_name="Songcrumb-$task_version-arm64"
hdiutil create -volname "Songcrumb $task_version" -srcfolder "$task_stage/disk" -format UDZO -ov "$task_output/$task_name.dmg"
ditto -c -k --sequesterRsrc --keepParent "$task_root/build/release-native/Songcrumb.app" "$task_output/$task_name.zip"
ditto -c -k --keepParent YouTubeMusicCompanion "$task_output/YouTubeMusicCompanion-$task_version.zip"
(
  cd "$task_output"
  shasum -a 256 "$task_name.dmg" "$task_name.zip" "YouTubeMusicCompanion-$task_version.zip" > SHA256SUMS.txt
)
cp docs/INSTALL.txt "$task_output/INSTALL.txt"
echo "Developer downloads: $task_output"
