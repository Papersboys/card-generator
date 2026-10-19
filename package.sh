#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
./build.sh
codesign --verify --deep --strict dist/LinkCard.app
ditto -c -k --keepParent --noextattr --norsrc dist/LinkCard.app dist/LinkCard-macos-arm64.zip
(cd dist && shasum -a 256 LinkCard-macos-arm64.zip > SHA256SUMS.txt)
verify_dir=$(mktemp -d "${TMPDIR:-/tmp}/linkcard-package-check.XXXXXX")
trap 'rm -rf -- "$verify_dir"' EXIT
ditto -x -k dist/LinkCard-macos-arm64.zip "$verify_dir"
codesign --verify --deep --strict "$verify_dir/LinkCard.app"
printf 'Release assets: dist/LinkCard-macos-arm64.zip and dist/SHA256SUMS.txt\n'
