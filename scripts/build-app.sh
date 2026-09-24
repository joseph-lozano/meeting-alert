#!/usr/bin/env bash
# Builds build/Meeting Alert.app. Pass --install to copy it into /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP="build/Meeting Alert.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/MeetingAlert" "$APP/Contents/MacOS/MeetingAlert"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x MeetingAlert || true
  rm -rf "/Applications/Meeting Alert.app"
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/Meeting Alert.app"
fi
