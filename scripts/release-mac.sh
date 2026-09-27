#!/usr/bin/env bash
#
# Builds LocalBolo for distribution: archives the production app, signs it
# with the Developer ID, has Apple notarize it, and packages it as a signed,
# notarized disk image at build/release/LocalBolo.dmg.
#
# Usage: scripts/release-mac.sh <version>        e.g. scripts/release-mac.sh 0.2.0
#
# Needs the "Developer ID Application" certificate for team 4M5LV534N5 in the
# keychain, and notarization credentials in one of two forms:
#   - On a Mac: a notarytool keychain profile named "LocalBolo", created once with
#       xcrun notarytool store-credentials LocalBolo --apple-id <you@example.com> --team-id 4M5LV534N5
#   - In CI: an App Store Connect API key in NOTARY_KEY_PATH, NOTARY_KEY_ID and NOTARY_ISSUER_ID.

set -euo pipefail

VERSION="${1:?Usage: $0 <version>, e.g. $0 0.2.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: THINKING SOUND LAB PRIVATE LIMITED (4M5LV534N5)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/release"
ARCHIVE="$OUT/LocalBolo.xcarchive"
APP="$OUT/export/LocalBolo.app"
DMG="$OUT/LocalBolo.dmg"

notarize() {
  if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
    xcrun notarytool submit "$1" --wait \
      --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID"
  else
    xcrun notarytool submit "$1" --wait --keychain-profile LocalBolo
  fi
}

rm -rf "$OUT"
mkdir -p "$OUT"

echo "▸ Archiving LocalBolo $VERSION (build $BUILD_NUMBER)"
xcodebuild archive \
  -project "$ROOT/apps/mac/LocalBolo.xcodeproj" \
  -scheme LocalBolo \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE" \
  -skipPackagePluginValidation \
  -quiet \
  ARCHS=arm64 \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

echo "▸ Exporting with the Developer ID"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$ROOT/apps/mac/Config/ExportOptions.plist" \
  -exportPath "$OUT/export" \
  -quiet

# Notarize and staple the app itself, so it opens without a network check
# even after it's copied out of the disk image.
echo "▸ Notarizing the app"
ditto -c -k --keepParent "$APP" "$OUT/LocalBolo.zip"
notarize "$OUT/LocalBolo.zip"
xcrun stapler staple "$APP"

echo "▸ Packaging the disk image"
STAGING="$OUT/dmg"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname LocalBolo -srcfolder "$STAGING" -format UDZO -ov "$DMG" -quiet
codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG"

echo "▸ Notarizing the disk image"
notarize "$DMG"
xcrun stapler staple "$DMG"

echo "▸ Checking that Gatekeeper accepts it"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
spctl --assess --type execute --verbose "$APP"

echo "✓ Built $DMG"
