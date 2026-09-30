#!/usr/bin/env bash
#
# Creates the key pair that signs LocalBolo's updates. Run it once, ever.
#
# Sparkle, which installs updates, only accepts files signed with the private
# key. The key is saved in your login keychain; back it up (for example with
# --export into a password manager), because without it you can't ship updates
# to people who already have LocalBolo.
#
# Usage:
#   scripts/generate-sparkle-keys.sh            Create the keys (or reuse them) and print the public key
#   scripts/generate-sparkle-keys.sh --export   Print the private key, to store it as a secret
#
# After creating the keys:
#   1. Set SPARKLE_PUBLIC_KEY in apps/mac/Config/Production.xcconfig to the public key.
#   2. Give the release workflow the private key:
#        scripts/generate-sparkle-keys.sh --export | gh secret set SPARKLE_PRIVATE_KEY --env production

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGES="$ROOT/build/SourcePackages"
TOOLS="$PACKAGES/artifacts/sparkle/Sparkle/bin"

# Sparkle's tools come with its Swift package; fetch it if needed.
if [[ ! -x "$TOOLS/generate_keys" ]]; then
  xcodebuild -resolvePackageDependencies \
    -project "$ROOT/apps/mac/LocalBolo.xcodeproj" \
    -clonedSourcePackagesDirPath "$PACKAGES" \
    -skipPackagePluginValidation -quiet >&2
fi

if [[ "${1:-}" == "--export" ]]; then
  file="$(mktemp)"
  trap 'rm -f "$file"' EXIT
  "$TOOLS/generate_keys" -x "$file" >&2
  cat "$file"
else
  "$TOOLS/generate_keys"
fi
