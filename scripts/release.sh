#!/bin/bash
# Builds a universal, Developer ID-signed, notarized and stapled Mullion.app, zipped for download:
# build/Mullion-<version>.zip. CI runs this on every v* tag (.github/workflows/release.yml).
#
# Environment:
#   VERSION           release version (default: CFBundleShortVersionString in Resources/Info.plist)
#   SIGN_IDENTITY     default "Developer ID Application"
#   Notarization credentials, either
#     NOTARY_PROFILE  a keychain profile saved with `xcrun notarytool store-credentials <name>`, or
#     NOTARY_KEY, NOTARY_KEY_ID, NOTARY_ISSUER  an App Store Connect API key: .p8 path, key ID, issuer ID
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${VERSION:-$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)}"
APP=build/Mullion.app
ZIP="build/Mullion-$VERSION.zip"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    auth=(--keychain-profile "$NOTARY_PROFILE")
elif [[ -n "${NOTARY_KEY:-}" ]]; then
    auth=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
else
    echo "error: set NOTARY_PROFILE, or NOTARY_KEY, NOTARY_KEY_ID and NOTARY_ISSUER" >&2
    exit 1
fi

SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}" REQUIRE_IDENTITY=1 UNIVERSAL=1 \
    VERSION="$VERSION" BUILD_NUMBER="$(git rev-list --count HEAD)" scripts/bundle.sh

echo "Notarizing (usually a few minutes)..."
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
result="$(xcrun notarytool submit "$ZIP" "${auth[@]}" --wait --output-format json)"
status="$(plutil -extract status raw - <<<"$result")"
if [[ "$status" != Accepted ]]; then
    echo "error: notarization finished with status \"$status\"" >&2
    xcrun notarytool log "$(plutil -extract id raw - <<<"$result")" "${auth[@]}" >&2 || true
    exit 1
fi

# Staple the ticket so Gatekeeper can verify the app offline, then zip the stapled app.
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
spctl --assess --type execute --verbose "$APP"
echo "Built $ZIP"
