#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
staging=$(mktemp -d "${TMPDIR:-/tmp}/linkcard-build.XXXXXX")
trap 'rm -rf -- "$staging"' EXIT
bundle="$staging/LinkCard.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp Info.plist "$bundle/Contents/Info.plist"
cp STRIPE-LICENSE.txt "$bundle/Contents/Resources/STRIPE-LICENSE.txt"
iconset="$staging/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Assets/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" Assets/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$bundle/Contents/Resources/AppIcon.icns"
xcrun swiftc -parse-as-library -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macosx13.0 -swift-version 5 -module-cache-path "${TMPDIR:-/tmp}/linkcard-swift-cache" -o "$bundle/Contents/MacOS/LinkCard" Source/Support.swift Source/LinkCard.swift Source/NativeLink.swift -framework Security -framework AppKit -framework SwiftUI
xattr -cr "$bundle"
codesign --force --sign - "$bundle"
codesign --verify "$bundle"
mkdir -p dist
ditto --noextattr --norsrc "$bundle" dist/LinkCard.app
codesign --verify dist/LinkCard.app
printf 'Built: %s/dist/LinkCard.app\n' "$PWD"
