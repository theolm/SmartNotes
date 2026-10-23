#!/usr/bin/env bash
#
# Packages a built SmartNotes.app into a compressed DMG.
#
# Usage:
#   package_macos.sh <app-bundle> <version> <arch> <output-directory>
#
# The build is ad-hoc signed by Xcode/Flutter only. Developer ID signing and
# notarization are intentionally disabled; see the commented block below and
# docs/release.md to enable them later.

set -euo pipefail

APP="${1:?app bundle path is required}"
VERSION="${2:?version is required}"
ARCH="${3:?architecture is required}"
OUT_DIR="${4:?output directory is required}"

NAME="SmartNotes"
DMG="$OUT_DIR/${NAME}-${VERSION}-macos-${ARCH}.dmg"

if [[ ! -d "$APP" ]]; then
  echo "error: app bundle not found: $APP" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

STAGE="$(mktemp -d "${RUNNER_TEMP:-/tmp}/smartnotes-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

# Keep the bundle name stable regardless of the Xcode product name.
ditto "$APP" "$STAGE/${NAME}.app"
ln -s /Applications "$STAGE/Applications"

# ---------------------------------------------------------------------------
# Optional: Developer ID signing and notarization (disabled by default).
#
# Enabling this requires an Apple Developer Program membership. Import the
# Developer ID Application certificate in the workflow, export the App Store
# Connect API key, and uncomment the commands below.
#
# codesign --force --deep --options runtime --timestamp \
#   --entitlements macos/Runner/Release.entitlements \
#   --sign "$MACOS_SIGNING_IDENTITY" "$STAGE/${NAME}.app"
# ---------------------------------------------------------------------------

hdiutil create \
  -volname "${NAME} ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

# ---------------------------------------------------------------------------
# Optional: sign, notarize and staple the DMG (disabled by default).
#
# codesign --force --timestamp --sign "$MACOS_SIGNING_IDENTITY" "$DMG"
# xcrun notarytool submit "$DMG" \
#   --key "$APPSTORE_API_KEY_PATH" \
#   --key-id "$APPSTORE_API_KEY_ID" \
#   --issuer "$APPSTORE_ISSUER_ID" \
#   --wait
# xcrun stapler staple "$DMG"
# xcrun stapler validate "$DMG"
# ---------------------------------------------------------------------------

echo "Created $DMG"
