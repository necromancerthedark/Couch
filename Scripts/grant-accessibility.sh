#!/bin/bash
# grant-accessibility.sh - open the Accessibility pane and reveal the app so
# you can drag it in / toggle it on. Relaunch Couch afterwards.
cd "$(dirname "$0")/.."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
open -R dist/Couch.app
