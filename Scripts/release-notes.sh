#!/bin/bash
# release-notes.sh - print the CHANGELOG.md section for one version, for use as
# GitHub release notes:
#
#   Scripts/release-notes.sh 0.3 > notes.md
#   gh release create v0.3 dist.zip --title "Couch v0.3" --notes-file notes.md
#
# Pass "Unreleased" to preview the pending notes.
set -euo pipefail
cd "$(dirname "$0")/.."

[ $# -eq 1 ] || { echo "usage: $0 <version>   e.g. $0 0.3" >&2; exit 1; }
VERSION="${1#v}"

NOTES="$(awk -v v="$VERSION" '
  /^## \[/ { if (found) exit; if (index($0, "## [" v "]") == 1) { found = 1; next } }
  found { print }
' CHANGELOG.md)"

if [ -z "$(printf '%s' "$NOTES" | tr -d '[:space:]')" ]; then
  echo "error: no CHANGELOG.md section for '$VERSION'" >&2
  exit 1
fi
printf '%s\n' "$NOTES" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
