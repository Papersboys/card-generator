# Link Card

[English](README.md) | [简体中文](README.zh-CN.md)

<img src="Assets/AppIcon.png" alt="Link Card app icon" width="128" />

A native macOS menu-bar app to create Link spend requests, approve them in Link, display virtual card details, and cancel unused requests. Built with SwiftUI, AppKit, and URLSession.

[Download for Apple Silicon](https://github.com/Papersboys/card-generator/releases/latest/download/LinkCard-macos-arm64.zip) · [All releases and checksums](https://github.com/Papersboys/card-generator/releases)

Download the ZIP, extract it, and drag **LinkCard.app** into Applications. Open the installed app and use the menu-bar credit-card icon. No compilation is required.

**No link-cli binary, Node.js, npm, shell helpers, or local server is required.** Requires Apple Silicon and macOS 13+.

## Documentation

| Guide | English | 简体中文 |
| --- | --- | --- |
| Installation | [Requirements, setup, and updates](docs/INSTALL.en.md) | [安装指南](docs/INSTALL.zh-CN.md) |
| Usage | [Illustrated usage guide](docs/USAGE.en.md) | [带截图的使用说明](docs/USAGE.zh-CN.md) |

## Screenshots

| Requests and history · 中文 | Create a request · English |
| --- | --- |
| ![Chinese request history with a fictional signed-in account](docs/images/overview-zh.jpg) | ![English creation form with fictional purchase details](docs/images/create-en.jpg) |

Screenshots show v2.5.1 with fictional demo data. The [illustrated usage guide](docs/USAGE.en.md) also covers approval review, narrow-window layouts, editing shortcuts, login, card details, and confirmations.

## Installation

The **[installation guide](docs/INSTALL.en.md)** ([简体中文](docs/INSTALL.zh-CN.md)) covers packaged-app installation, Xcode setup, source builds, installation into Applications, first login, updates, and troubleshooting.

A packaged `.app` requires Apple Silicon and macOS 13+, without Xcode or CLI dependencies. Building from source requires Xcode and its macOS SDK. Prebuilt binaries and SHA-256 checksums are available on [GitHub Releases](https://github.com/Papersboys/card-generator/releases). Source builds remain optional.

### Quick start from source

Install Xcode and select its developer tools, then run:

```bash
git clone https://github.com/Papersboys/card-generator.git
cd card-generator
./build.sh
open dist/LinkCard.app
```

To run the offline tests:

```bash
./test.sh
```

Build output is excluded from Git. Quit any running copy, then install into your personal Applications folder:

```bash
mkdir -p "$HOME/Applications"
ditto dist/LinkCard.app "$HOME/Applications/LinkCard.app"
open "$HOME/Applications/LinkCard.app"
```

For updates, quit the app, save any local source changes, run `git pull --ff-only` and `./build.sh`, then replace the installed app. There is no automatic updater or automatic login-item setup. Current builds use an ad-hoc signature and are not notarized.

## Language

Use the **中文 / English** selector at the top of the window. Changes apply immediately to the interface, menu-bar menu, confirmations, card field labels, statuses, and app-authored messages. Your choice is remembered after restarting. Merchant names, purchase context, IDs, and card data are preserved.

## Login

Once signed in, the login button is replaced with a **Logged in** indicator and the name/email returned by Link. The app restores account details on launch. If authentication expires and cannot be refreshed, the login button returns; a temporary network error does not sign you out.

Click **登录 Link**, open the official Link authorization link, and complete authorization in your browser using the phrase displayed in the app. The app waits for approval and stores its independent login in macOS Keychain, with automatic token refresh.

For convenience, an existing unexpired Link CLI access token can be reused read-only from its standard preferences file. The app never writes that file or uses its refresh token. When that temporary session expires, use the app's Login button; thereafter no CLI installation or configuration is needed.

This personal app uses the public device-flow client and API protocol from Stripe's MIT-licensed implementation, labeled “Link Card.” New authorizations display this name without a computer hostname; existing connections keep their original names until reauthorized. For distributing a product to other users, register your own OAuth client with Stripe rather than relying on the public CLI client.

## Usage

📖 **[Usage guide](docs/USAGE.en.md)** · **[中文使用说明](docs/USAGE.zh-CN.md)** — step-by-step login, creation, approval, card display, cancellation, history, and troubleshooting.

- **Requests / History:** refresh, include history, select a request, show card details, or cancel from its row with confirmation. Successful cancellation clears that request's displayed card details.
- **Create:** load a payment method; enter merchant, URL, amount in minor units (USD $15 = 1500), item, and at least 100 characters of context. Choose Valid until (default: one day from now), then review and confirm creation. This submits request expiry; actual card validity is determined by Link.
- Approve the purchase yourself in Link. The app checks approval every two seconds for up to ten minutes, then automatically retrieves full card details. Manual refresh is also available.
- Full card details are selectable; missing fields show `—`. Card responses are handled in memory with an ephemeral network session, without credential JSON files.
- Closing the window clears displayed card data and stops approval checks.
- History is spend-request history, not merchant settlement history.

The app has a local ad-hoc signature, not an Apple notarized distribution signature. No startup/login-item setting is changed. No real purchase or cancellation was used in development tests. Live checks used only history and payment-method reads.

## Source and build

`Source/Support.swift` contains shared data helpers, `Source/Model.swift` manages accounts and requests, and `Source/Localization.swift` provides bilingual copy. `Source/LinkCard.swift` contains the interface; `Source/NativeLink.swift` contains native URLSession API calls, browser device authorization, token refresh, and Keychain storage. No child processes are launched by the app.

Build on Apple Silicon with Xcode using `./build.sh`. Run `./test.sh` for offline tests of the native API transport, authentication refresh, and device authorization. Tests use a mocked URLSession and do not read real login credentials or send network requests.

API/auth protocol references: [Stripe Link SDK and CLI](https://github.com/stripe/link-cli). Stripe's MIT notice is included in `STRIPE-LICENSE.txt` and the app bundle.

For maintainers: `./package.sh` builds and verifies `dist/LinkCard-macos-arm64.zip` and generates `dist/SHA256SUMS.txt`.

## App icon

The source icon is in `Assets/AppIcon.png`. The build script uses macOS `sips` and `iconutil` to generate a multi-resolution `.icns` file and embed it in the app. The original image-generation prompt is in `Assets/AppIcon.prompt.txt`.

## License

This project is licensed under the [Apache License 2.0](LICENSE), copyright © 2026 Yuanxi Li.

The Link API and authentication implementation follows Stripe's open-source Link SDK and CLI. Stripe's original MIT copyright and permission notice is preserved in [STRIPE-LICENSE.txt](STRIPE-LICENSE.txt) and included in the app bundle.

This is an independent project and is not an official Stripe or Link application.
