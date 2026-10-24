#!/bin/bash
# make-screenshots.sh - render the Settings window tabs (with demo data) into
# docs/screenshots/*.png for the README. Uses the built app, so run
# build-app.sh first. No pad, no permissions needed; it sends no key events.
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="dist/Couch.app/Contents/MacOS/Couch"
[ -x "$BIN" ] || { echo "error: build first (./Scripts/build-app.sh)" >&2; exit 1; }
"$BIN" --screenshots docs/screenshots
