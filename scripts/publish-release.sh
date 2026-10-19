#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
if [[ $# -ne 1 || ! -f "$1" ]]; then
  echo 'Usage: ./scripts/publish-release.sh <release-notes-file>' >&2
  exit 1
fi
notes=$1
./test.sh
./package.sh
./scripts/generate-appcast.sh
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/LinkCard.app/Contents/Info.plist)
gh release create "v$version" dist/LinkCard-macos-arm64.zip dist/SHA256SUMS.txt dist/appcast.xml \
  --title "Link Card v$version" --notes-file "$notes" --latest --verify-tag
