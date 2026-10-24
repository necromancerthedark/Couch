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

# Prefer the stable local identity (Scripts/setup-signing.sh): the Accessibility
# grant then survives rebuilds. Fall back to ad-hoc (grant resets each build).
IDENTITY="Couch Local Signing"
if security find-identity -p codesigning | grep -q "$IDENTITY"; then
  echo "==> Signing with '$IDENTITY'..."
  codesign --force --sign "$IDENTITY" "$APP"
else
  echo "==> Ad-hoc signing (run Scripts/setup-signing.sh to keep the Accessibility grant across builds)..."
  codesign --force --sign - "$APP"
fi

echo "==> Done: $APP"

if [ "${1:-}" = "run" ]; then
  echo "==> Launching..."
  open "$APP"
fi