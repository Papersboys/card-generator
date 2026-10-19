# Signed update publishing / 签名更新发布

Link Card 2.6.0 introduces Sparkle 2.10.0. The first upgrade from 2.5.x must be installed manually; later versions can be installed through Check for Updates. Automatic checks run daily by default, with user confirmation before installation.

2.6.0 首次加入 Sparkle；2.5.x 需要手动升级一次，此后可在 App 内更新。默认每日检查，安装前由用户确认。

## Keys and feed / 密钥与更新源

- `Info.plist` embeds the public Ed25519 key and the HTTPS feed URL: `https://github.com/Papersboys/card-generator/releases/latest/download/appcast.xml`.
- The private key is in the release maintainer's macOS Keychain, account `linkcard-updates`. It is not stored in this repository or the app. Preserve this key when migrating the release machine; do not generate a replacement for an existing feed.
- Sparkle verifies the signed feed and update archive before extraction. Apple Developer ID signing/notarization remains a separate distribution step; current app builds are ad-hoc signed.
- The pinned official Sparkle archive is cached in `.build/`, verified with SHA-256 when fetched, and excluded from Git. Its license is bundled in the app.

公钥随 App 分发；私钥只保存在发布机器的 Keychain（`linkcard-updates`），不提交 Git。不应为已发布的更新源随意换钥。更新签名与 Apple 公证是两回事。

## Publish / 发布

1. Increment `CFBundleVersion` and `CFBundleShortVersionString` in `Info.plist`.
2. Commit and push the change. Create and push the corresponding annotated `v<version>` tag.
3. Write release notes to a file, then run:

```bash
./scripts/publish-release.sh /absolute/path/to/release-notes.md
```

This runs offline API tests, builds and signs the app, packages and verifies the ZIP, signs the feed/archive with the Keychain key, tests signatures and tamper rejection, and publishes all three required assets together:

- `LinkCard-macos-arm64.zip`
- `SHA256SUMS.txt`
- `appcast.xml`

以此脚本发布，确保最新 Release 同时包含更新清单。不要发布缺少 `appcast.xml` 的新 Latest Release，否则已安装 App 无法检查更新。

To prepare without publishing:

```bash
./test.sh
./package.sh
./scripts/generate-appcast.sh
```

`Tests/UpdateTests.swift` verifies the feed and archive against the embedded public key, rejects a modified archive, and checks that versions and version-specific download URLs agree. These tests do not install over a user's app or access Link credentials.
