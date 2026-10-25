#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
python3 scripts/build-agent-assets.py
staging=$(mktemp -d "${TMPDIR:-/tmp}/linkcard-mcp-package.XXXXXX")
trap 'rm -rf -- "$staging"' EXIT
mkdir -p "$staging/link-card-agent/skills" dist
cp dist/LinkCard.app/Contents/MacOS/link-card-mcp "$staging/link-card-agent/link-card-mcp"
cp -R Agent/skills/link-card "$staging/link-card-agent/skills/link-card"
cp Agent/mcp-config.json "$staging/link-card-agent/mcp-config.json"
cp Agent/README.md "$staging/link-card-agent/README.md"
cp LICENSE "$staging/link-card-agent/LICENSE"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$staging/link-card-agent" dist/link-card-agent-macos-arm64.zip
shasum -a 256 dist/link-card-agent-macos-arm64.zip > dist/link-card-agent-SHA256SUMS.txt
printf 'Packaged local MCP binary and skill\n'
