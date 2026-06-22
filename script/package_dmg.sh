#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Noise"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/Noise-0.1.0-macos-arm64.dmg"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

"$ROOT_DIR/script/stage_app_bundle.sh" release

CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign "$CODE_SIGN_IDENTITY" "$APP_BUNDLE"
  codesign --verify --deep --strict "$APP_BUNDLE"
fi

rm -rf "$DMG_ROOT" "$DMG_PATH" "$DMG_PATH.sha256"
mkdir -p "$DMG_ROOT"
cp -R "$APP_BUNDLE" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$DMG_PATH")" >"$(basename "$DMG_PATH").sha256"
)

echo "Created $DMG_PATH"
echo "Created $DMG_PATH.sha256"
