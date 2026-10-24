#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
staging=$(mktemp -d "${TMPDIR:-/tmp}/linkcard-tests.XXXXXX")
trap 'rm -rf -- "$staging"' EXIT
xcrun swiftc -parse-as-library -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macosx13.0 -swift-version 5 -module-cache-path "${TMPDIR:-/tmp}/linkcard-swift-cache" -o "$staging/NativeTests" Source/ProductFeatures.swift Source/Accounts.swift Source/WalletFeatures.swift Source/ErrorReports.swift Source/Support.swift Source/Model.swift Source/Localization.swift Source/NativeLink.swift Tests/NativeTests.swift -framework Security
"$staging/NativeTests"
