# Link Card

[English](README.md) | [简体中文](README.zh-CN.md)

<img src="Assets/AppIcon.png" alt="Link Card app icon" width="128" />

A native macOS menu-bar app to create Link spend requests, approve them in Link, display virtual card details, and cancel unused requests. Built with SwiftUI, AppKit, and URLSession.

[Product website](https://papersboys.github.io/card-generator/?lang=en) · [Download for Apple Silicon](https://github.com/Papersboys/card-generator/releases/latest/download/LinkCard-macos-arm64.zip) · [All releases and checksums](https://github.com/Papersboys/card-generator/releases)

Download the ZIP, extract it, and drag **LinkCard.app** into Applications. Open the installed app and click the menu-bar credit-card icon to expand the panel; no separate main window is opened. No compilation is required.

**No link-cli binary, Node.js, npm, shell helpers, or local server is required.** Requires Apple Silicon and macOS 13+.

Payment method selection shows the nickname saved in Link, followed by the card brand and last four digits. Cards without a nickname show their brand and last four digits.

Click outside the menu-bar panel or press Esc to close it. Reopening preserves the creation form during the current app session; displayed card credentials are cleared when closed.

## Download: App or CLI

| Version | Download | Requirements |
| --- | --- | --- |
| macOS menu-bar App | [LinkCard-macos-arm64.zip](https://github.com/Papersboys/card-generator/releases/latest/download/LinkCard-macos-arm64.zip) | Apple Silicon, macOS 13+; no CLI dependencies |
| Terminal tool | [link-card-cli.tar.gz](https://github.com/Papersboys/card-generator/releases/latest/download/link-card-cli.tar.gz) | Bash, Python 3, jq, and authenticated `link-cli` |

### Install the terminal tool

The CLI download bundles the existing shell/Python scripts and all helper files; it is not a standalone native binary. Install dependencies and log in first:

```sh
brew install python jq
npm install -g @stripe/link-cli --registry=https://registry.npmjs.org/
link-cli auth login
```

Download and extract `link-card-cli.tar.gz`, then run these commands inside the extracted `link-card-cli` folder:

```sh
./install.sh
export PATH="$HOME/bin:$PATH"
link-card --help
```

The installer backs up an existing `~/bin/link-card`, installs helpers under `~/.local/lib/link-card`, and creates the launcher at `~/bin/link-card`. Add the PATH line to `~/.zshrc` to retain it in new terminals.

```sh
link-card create               # Select payment method, enter details, confirm and approve in Link
link-card show                 # Select an active request and show its card details
link-card show lsrq_EXAMPLE     # Show a specific request (replace with your request ID)
link-card history              # Select from current and past requests
link-card cancel               # Select a request and type yes to confirm cancellation
```

Full card details are displayed in a colored terminal table. `show` saves a private JSON response in the temporary directory; add `--delete` to remove it after display or `--path` to show its location. Card numbers and CVCs remain visible in terminal scrollback. See the [complete CLI guide](cli/README.md) and [release checksums](https://github.com/Papersboys/card-generator/releases/latest).

## Core feature: view Visa virtual card details

**After approval, view and copy the card number, CVC/CVV, expiration date, and billing address for merchant checkout.** No terminal JSON to search through. Select an existing approved request to retrieve its card details again. The actual network and available fields depend on Link's response.

![Visa card number, CVC, expiration, and billing address; fictional demonstration data](docs/images/card-details-zh.jpg)

All card details shown are fictional and cannot be used for payment. [Start the guide with card details](docs/USAGE.en.md#1-core-feature-view-and-copy-visa-virtual-card-details).

## Documentation

| Guide | English | 简体中文 |
| --- | --- | --- |
| Installation | [Requirements, setup, and updates](docs/INSTALL.en.md) | [安装指南](docs/INSTALL.zh-CN.md) |
| Usage | [Illustrated usage guide](docs/USAGE.en.md) | [带截图的使用说明](docs/USAGE.zh-CN.md) |

## Screenshots

| Requests and history · 中文 | Create a request · English |
| --- | --- |
| ![Chinese request history with a fictional signed-in account](docs/images/overview-zh.jpg) | ![English creation form with fictional purchase details](docs/images/create-en.jpg) |

Screenshots show v2.5.6 with fictional demo data. The [illustrated usage guide](docs/USAGE.en.md) also covers approval review, narrow-window layouts, editing shortcuts, login, card details, and confirmations.

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

From **v2.6.0**, the app checks for updates daily by default. Turn this off with Automatically check for updates, or use Check for Updates… in the footer or menu bar. Confirm the offered update to download, install, and relaunch. Sparkle verifies Ed25519 signatures on both the feed and archive. Older versions require one manual download of v2.6.0 or later. Source builds can still use `git pull --ff-only` and `./build.sh`. No login-item setup is changed; builds remain ad-hoc signed and not Apple notarized.

## Language

Use the **中文 / English** selector at the top of the window. Changes apply immediately to the interface, menu-bar menu, confirmations, card field labels, statuses, and app-authored messages. Your choice is remembered after restarting. Merchant names, purchase context, IDs, and card data are preserved.

## Login

Once signed in, the login button is replaced with a **Logged in** indicator and the name/email returned by Link. The app restores account details on launch. If authentication expires and cannot be refreshed, the login button returns; a temporary network error does not sign you out.

Click **登录 Link**, open the official Link authorization link, and complete authorization in your browser using the phrase displayed in the app. The app waits for approval and stores its independent login in macOS Keychain, with automatic token refresh.

For convenience, an existing unexpired Link CLI access token can be reused read-only from its standard preferences file. The app never writes that file or uses its refresh token. When that temporary session expires, use the app's Login button; thereafter no CLI installation or configuration is needed.

This personal app uses the public device-flow client and API protocol from Stripe's MIT-licensed implementation, labeled “Link Card.” New authorizations display this name without a computer hostname; existing connections keep their original names until reauthorized. For distributing a product to other users, register your own OAuth client with Stripe rather than relying on the public CLI client.

Use **Log out** beside your account to clear this app's local credentials and displayed data. CLI login and existing requests are unaffected.

## Usage

📖 **[Usage guide](docs/USAGE.en.md)** · **[中文使用说明](docs/USAGE.zh-CN.md)** — step-by-step login, creation, approval, card display, cancellation, history, and troubleshooting.

- **Requests / History:** refresh, include history, select a request, show card details, or cancel from its row with confirmation. Successful cancellation clears that request's displayed card details.
- **Create:** load a payment method; enter merchant, URL, amount in minor units (USD $15 = 1500), and item. Context is generated automatically. Review and confirm. Custom request expiry is not supported; Link determines card validity.
- Approve the purchase yourself in Link. The app checks approval every two seconds for up to ten minutes, then automatically retrieves full card details. Manual refresh is also available.
- Card number, CVC/CVV, and Expiration have individual Copy buttons; other fields are selectable; missing fields show `—`. Card responses are handled in memory with an ephemeral network session, without credential JSON files.
- Closing the panel clears displayed card data; pending approval checks can continue.
- History is spend-request history, not merchant settlement history.

The app has a local ad-hoc signature, not an Apple notarized distribution signature. No startup/login-item setting is changed. No real purchase or cancellation was used in development tests. Live checks used only history and payment-method reads.

## Supported currencies

The app defaults to **USD (`usd`)**. Its Currency field accepts a three-letter ISO currency code and sends it to Link; actual availability is determined by Link for the request.

| Currency | Code | Amount example | Status |
| --- | --- | --- | --- |
| US dollar | `usd` | `1500` = $15.00; minimum `50` = $0.50 | App default; USD requests have been used with this project |
| Japanese yen | `jpy` | `100` = ¥100, not ¥1 | Minor-unit example in Link's official documentation; not verified with this app/account |

[Link's official documentation](https://github.com/stripe/link-cli#spend-request-lifecycle) allows supported three-letter currency codes but does **not enumerate a complete supported-currency list**. Other codes are not guaranteed merely because the app accepts text input. Stripe's general payment-acceptance currency list is not a verified list for Link virtual-card requests.

Use the merchant checkout currency and its correct minor units. The app performs no currency conversion. A USD minimum must not be assumed for another currency. The current app explicitly sends the Currency field (default `usd`); it does not automatically use the account's default currency.

## Source and build

`Source/Support.swift` contains shared data helpers, `Source/Model.swift` manages accounts and requests, and `Source/Localization.swift` provides bilingual copy. `Source/LinkCard.swift` contains the interface; `Source/NativeLink.swift` contains native URLSession API calls, browser device authorization, token refresh, and Keychain storage. Payment and login calls do not invoke a CLI; Sparkle uses its bundled helpers to install app updates.

Build on Apple Silicon with Xcode using `./build.sh`. Run `./test.sh` for offline tests of the native API transport, authentication refresh, and device authorization. Tests use a mocked URLSession and do not read real login credentials or send network requests.

API/auth protocol references: [Stripe Link SDK and CLI](https://github.com/stripe/link-cli). Stripe's MIT notice is included in `STRIPE-LICENSE.txt` and the app bundle.

For maintainers: `./package.sh` builds and verifies `dist/LinkCard-macos-arm64.zip` and generates `dist/SHA256SUMS.txt`.

## App icon

The source icon is in `Assets/AppIcon.png`. The build script uses macOS `sips` and `iconutil` to generate a multi-resolution `.icns` file and embed it in the app. The original image-generation prompt is in `Assets/AppIcon.prompt.txt`.

## License

This project is licensed under the [Apache License 2.0](LICENSE), copyright © 2026 Yuanxi Li.

The Link API and authentication implementation follows Stripe's open-source Link SDK and CLI. Stripe's original MIT copyright and permission notice is preserved in [STRIPE-LICENSE.txt](STRIPE-LICENSE.txt) and included in the app bundle.

This is an independent project and is not an official Stripe or Link application.

Automatic updates use [Sparkle](https://sparkle-project.org/); its license is preserved in [ThirdParty/Sparkle-LICENSE.txt](ThirdParty/Sparkle-LICENSE.txt). See [update publishing](docs/UPDATES.md) for maintainers.

## Local error logs

Errors are recorded locally at `~/Library/Logs/LinkCard/error-log.jsonl` (up to 200 entries / 256 KiB, owner-only access). Records contain time, app/macOS versions, HTTP status, and a fixed error category; raw errors, account details, card data and credentials are excluded. Click **Send error logs** in the error banner to open the macOS share menu and choose a destination. Nothing is uploaded automatically or sent directly to S3.
