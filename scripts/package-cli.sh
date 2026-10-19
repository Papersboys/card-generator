#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/link-card-cli" dist
for name in link-card .link-card-create .link-card-show-select .link-card-show link-card-cancel _link_card_display.py install.sh README.md; do
  cp "cli/$name" "$staging/link-card-cli/$name"
done
cp LICENSE "$staging/link-card-cli/LICENSE"
COPYFILE_DISABLE=1 tar -czf dist/link-card-cli.tar.gz -C "$staging" link-card-cli
shasum -a 256 dist/link-card-cli.tar.gz > dist/link-card-cli-SHA256SUMS.txt
printf 'Packaged dist/link-card-cli.tar.gz\n'
