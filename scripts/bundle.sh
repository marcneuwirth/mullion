#!/bin/bash
# Builds build/Mullion.app from the Swift package and signs it.
#
# macOS ties the Accessibility permission to the app's signature. Signing with a stable certificate
# (see README, "Signing") keeps the permission across rebuilds; the ad-hoc fallback works, but you
# have to re-enable Mullion in System Settings after every rebuild.
set -euo pipefail

cd "$(dirname "$0")/.."
IDENTITY="${SIGN_IDENTITY:-Mullion Code Signing}"
APP=build/Mullion.app

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Mullion"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Mullion"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if security find-identity -p codesigning | grep -qF "\"$IDENTITY\""; then
    codesign --force --sign "$IDENTITY" "$APP"
    echo "Signed with \"$IDENTITY\""
else
    codesign --force --sign - "$APP"
    echo "warning: no \"$IDENTITY\" certificate found, signed ad-hoc." >&2
    echo "         Accessibility permission will need re-enabling after each rebuild (see README)." >&2
fi
echo "Built $APP"
