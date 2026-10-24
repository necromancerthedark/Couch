#!/bin/bash
# test.sh - run the unit tests (Swift Testing).
#
# With full Xcode this is just `swift test`. With only the Command Line Tools,
# the Testing framework lives outside the default search paths, so point the
# compiler and the runtime loader at it.
set -euo pipefail
cd "$(dirname "$0")/.."

CLT=/Library/Developer/CommandLineTools/Library/Developer
if [ -d "$CLT/Frameworks/Testing.framework" ] && ! xcode-select -p | grep -q 'Xcode'; then
  exec swift test \
    -Xswiftc -F -Xswiftc "$CLT/Frameworks" \
    -Xlinker -F -Xlinker "$CLT/Frameworks" \
    -Xlinker -rpath -Xlinker "$CLT/Frameworks" \
    -Xlinker -rpath -Xlinker "$CLT/usr/lib" "$@"
fi
exec swift test "$@"
