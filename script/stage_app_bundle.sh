#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-debug}"
APP_NAME="Noise"
BUNDLE_ID="com.crazyjal.noise"
MIN_SYSTEM_VERSION="13.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/release_version.sh"
SCRATCH_PATH="${NOISE_BUILD_PATH:-$ROOT_DIR/.build}"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Sources/Noise/Resources/AppIcon.icns"
RESOURCE_SOURCE="$ROOT_DIR/Sources/Noise/Resources"

cd "$ROOT_DIR"
export COPYFILE_DISABLE=1

if [ ! -f "$ICON_SOURCE" ]; then
  "$ROOT_DIR/script/generate_app_icon.swift"
fi

case "$CONFIG" in
  debug)
    swift build --scratch-path "$SCRATCH_PATH"
    BUILD_DIR="$(swift build --scratch-path "$SCRATCH_PATH" --show-bin-path)"
    ;;
  release)
    swift build --scratch-path "$SCRATCH_PATH" -c release
    BUILD_DIR="$(swift build --scratch-path "$SCRATCH_PATH" -c release --show-bin-path)"
    ;;
  *)
    echo "usage: $0 [debug|release]" >&2
    exit 2
    ;;
esac

BUILD_BINARY="$BUILD_DIR/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
if [ "$CONFIG" = "release" ]; then
  xcrun strip -S "$APP_BINARY"
fi

if [ -d "$RESOURCE_SOURCE/Sounds" ]; then
  cp -R -X "$RESOURCE_SOURCE/Sounds" "$APP_RESOURCES/"
fi

cp "$ICON_SOURCE" "$APP_RESOURCES/Noise.icns"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>Noise.icns</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 CrazyJal. All rights reserved.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "$INFO_PLIST" >/dev/null

echo "Staged $APP_BUNDLE"
