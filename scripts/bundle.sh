#!/bin/bash
# Builds build/Mullion.app from the Swift package and signs it.
#
# macOS ties the Accessibility permission to the app's signature. Signing with a stable certificate
# keeps the permission across rebuilds; the ad-hoc fallback works, but you have to re-enable Mullion in
# System Settings after every rebuild.
#
# Environment:
#   SIGN_IDENTITY     certificate to sign with (default: a Developer ID Application certificate if you
#                     have one, else "Mullion Code Signing", else ad-hoc)
#   REQUIRE_IDENTITY  1 to fail instead of falling back to ad-hoc signing
#   UNIVERSAL         1 to build for both Apple Silicon and Intel
#   VERSION, BUILD_NUMBER  override CFBundleShortVersionString and CFBundleVersion
set -euo pipefail

cd "$(dirname "$0")/.."
APP=build/Mullion.app

identities="$(security find-identity -v -p codesigning)"
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    for candidate in "Developer ID Application" "Mullion Code Signing"; do
        if grep -qF "\"$candidate" <<<"$identities"; then SIGN_IDENTITY="$candidate"; break; fi
    done
fi

build_flags=(-c release)
if [[ "${UNIVERSAL:-}" == 1 ]]; then build_flags+=(--arch arm64 --arch x86_64); fi
swift build "${build_flags[@]}"
BIN="$(swift build "${build_flags[@]}" --show-bin-path)/Mullion"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Mullion"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -n "${VERSION:-}" ]]; then plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"; fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"; fi

# Copied before signing, which seals everything in the bundle. scripts/icon.sh builds these.
mkdir -p "$APP/Contents/Resources"
cp Resources/Assets.car Resources/AppIcon.icns "$APP/Contents/Resources/"

if [[ -n "${SIGN_IDENTITY:-}" ]] && grep -qF "\"$SIGN_IDENTITY" <<<"$identities"; then
    # Notarization requires the hardened runtime and a secure timestamp. Mullion needs no entitlements:
    # Accessibility is a TCC permission, not an entitlement.
    flags=(--force --options runtime)
    if [[ "$SIGN_IDENTITY" == "Developer ID"* ]]; then flags+=(--timestamp); fi
    codesign "${flags[@]}" --sign "$SIGN_IDENTITY" "$APP"
    echo "Signed with \"$SIGN_IDENTITY\""
elif [[ "${REQUIRE_IDENTITY:-}" == 1 ]]; then
    echo "error: no \"${SIGN_IDENTITY:-}\" signing certificate in the keychain" >&2
    exit 1
else
    codesign --force --sign - "$APP"
    echo "warning: no signing certificate found, signed ad-hoc." >&2
    echo "         Accessibility permission will need re-enabling after each rebuild (see README)." >&2
fi
echo "Built $APP"
