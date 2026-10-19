#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/linkcard-update-tests.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "${TMPDIR:-/tmp}/linkcard-swift-cache" Tests/UpdateTests.swift -o "$work_dir/UpdateTests"
"$work_dir/UpdateTests" "$PWD"
