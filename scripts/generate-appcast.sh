#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
./scripts/fetch-sparkle.sh
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/LinkCard.app/Contents/Info.plist)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/linkcard-appcast.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT
cp dist/LinkCard-macos-arm64.zip "$work_dir/"
.build/sparkle-2.10.0/bin/generate_appcast --account linkcard-updates --maximum-deltas 0 \
  --download-url-prefix "https://github.com/Papersboys/card-generator/releases/download/v$version/" \
  --link https://github.com/Papersboys/card-generator \
  "$work_dir"
cp "$work_dir/appcast.xml" dist/appcast.xml
.build/sparkle-2.10.0/bin/sign_update --account linkcard-updates --verify dist/appcast.xml

./scripts/verify-update.sh
