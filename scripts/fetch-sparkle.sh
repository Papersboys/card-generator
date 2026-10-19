#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
version=2.10.0
checksum=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
root="$PWD/.build/sparkle-$version"
archive="$PWD/.build/Sparkle-$version.tar.xz"
if [[ -d "$root/Sparkle.framework" && -x "$root/bin/generate_appcast" ]]; then exit 0; fi
mkdir -p .build
if [[ ! -f "$archive" ]]; then
  curl --fail --location --silent --show-error "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz" -o "$archive"
fi
printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c -
mkdir -p "$root"
tar -xJf "$archive" -C "$root"
