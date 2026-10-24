#!/bin/bash
# build-app.sh - build the release binary, package it into a .app bundle,
# then ad-hoc sign it (see ADR-006, ADR-007).
#
#   ./Scripts/build-app.sh          -> dist/Couch.app (ad-hoc signed)
#   ./Scripts/build-app.sh run      -> build, sign, and launch it
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Couch"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "==> Building (release)..."
swift build -c release

BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
if [ ! -f "$BIN" ]; then
  echo "error: binary not found at $BIN" >&2
  exit 1
fi

echo "==> Packaging $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Ad-hoc signing..."
codesign --force --sign - "$APP"

echo "==> Done: $APP"

if [ "${1:-}" = "run" ]; then
  echo "==> Launching..."
  open "$APP"
fi