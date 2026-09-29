#!/usr/bin/env bash
#
# Builds LocalBolo for download from the website (not the Mac App Store):
# archives the production app, signs it with the Developer ID, has Apple
# notarize it, and packages it as a signed, notarized disk image at
# build/release/LocalBolo.dmg. It also signs the disk image for Sparkle, the
# in-app updater, and writes the update's details to build/release/sparkle.txt
# for the release notes, where the website's update feed reads them.
#
# Notarization is Apple's automated malware check. Without it, macOS refuses
# to open apps downloaded from the internet. Nothing is published anywhere.
#
# Usage: scripts/release-mac.sh <version>        e.g. scripts/release-mac.sh 0.2.0
#
# Needs the "Developer ID Application" certificate for team 4M5LV534N5 in the
# keychain, and an Apple ID on that team with an app-specific password for
# notarization, in one of two forms:
#   - On a Mac: a notarytool keychain profile named "LocalBolo", created once with
#       xcrun notarytool store-credentials LocalBolo --apple-id <you@example.com> --team-id 4M5LV534N5
#   - In CI: NOTARY_APPLE_ID and NOTARY_PASSWORD.
#
# Signing for Sparkle uses the private key from scripts/generate-sparkle-keys.sh:
# from this Mac's keychain, or from SPARKLE_PRIVATE_KEY in CI.

set -euo pipefail

VERSION="${1:?Usage: $0 <version>, e.g. $0 0.2.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: THINKING SOUND LAB PRIVATE LIMITED (4M5LV534N5)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/release"
# Packages go in a known place so Sparkle's signing tool can be found. They're
# kept between runs.
PACKAGES="$ROOT/build/SourcePackages"
ARCHIVE="$OUT/LocalBolo.xcarchive"
APP="$OUT/export/LocalBolo.app"
DMG="$OUT/LocalBolo.dmg"

notarize() {
  if [[ -n "${NOTARY_APPLE_ID:-}" ]]; then
    xcrun notarytool submit "$1" --wait \
      --apple-id "$NOTARY_APPLE_ID" --password "$NOTARY_PASSWORD" --team-id 4M5LV534N5
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
  -clonedSourcePackagesDirPath "$PACKAGES" \
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

# Without the public key the app can't verify updates, so this version could
# never update itself. Catch that before spending time on notarization.
if [[ -z "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP/Contents/Info.plist" 2>/dev/null)" ]]; then
  echo "error: SPARKLE_PUBLIC_KEY isn't set in apps/mac/Config/Production.xcconfig. Run scripts/generate-sparkle-keys.sh first." >&2
  exit 1
fi

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

# Sparkle checks this signature before installing an update, so sign the final,
# stapled disk image.
echo "▸ Signing the disk image for Sparkle"
SIGN_UPDATE="$PACKAGES/artifacts/sparkle/Sparkle/bin/sign_update"
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  SIGNATURE="$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE" --ed-key-file - "$DMG")"
else
  SIGNATURE="$("$SIGN_UPDATE" "$DMG")"
fi
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
MINIMUM_SYSTEM="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
# An HTML comment: invisible in the release notes, read by the website's appcast.
echo "<!-- sparkle version=\"$VERSION\" build=\"$BUILD\" minimumSystemVersion=\"$MINIMUM_SYSTEM\" $SIGNATURE -->" > "$OUT/sparkle.txt"

echo "✓ Built $DMG"
