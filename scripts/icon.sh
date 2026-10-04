#!/bin/bash
# Compiles Resources/AppIcon.icon (edit it in Icon Composer) into Resources/Assets.car, which macOS 26
# uses, and Resources/AppIcon.icns for earlier versions. Needs Xcode 26; the outputs are committed so
# building the app only needs the command line tools.
set -euo pipefail

cd "$(dirname "$0")/.."
out="$(mktemp -d)"
xcrun actool "$PWD/Resources/AppIcon.icon" --compile "$out" --platform macosx --minimum-deployment-target 13.0 \
    --app-icon AppIcon --standalone-icon-behavior all --output-partial-info-plist "$out/partial.plist" >/dev/null
cp "$out/Assets.car" "$out/AppIcon.icns" Resources/
rm -rf "$out"
echo "Wrote Resources/Assets.car and Resources/AppIcon.icns"
