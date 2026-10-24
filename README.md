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

The signed-in account area shows **Spend limits** returned by Link: per-purchase limit, daily and rolling 30-day limits, usage and remaining amounts. Click Refresh limits to reload. Missing fields show Not provided; explicit null limits show Unlimited. No account limits are estimated or combined.

## Multiple Link accounts

Use the Account picker above the account header to switch accounts. **Add account** starts a new Link authorization without logging out the others. On the Link authorization page, choose or sign in to the intended account; Safari may already be signed in to another account.

Each account has its own Keychain token entry, API session, requests and spend limits. Log out affects only the selected account. Existing login is retained as the first account. Saved logins survive app restarts, subject to Link expiry or revocation. Form drafts are preserved per account during the current app session; displayed card credentials clear on switching. Pending approval checks already started can continue for other accounts while the app runs. Switching is disabled during an active operation or login; use Stop waiting to cancel login first. The CLI remains a separate single-account tool. Account limits are displayed independently and are not pooled or increased.

## Refreshed interface (v2.9.0)

New linked-card artwork in the app icon, menu bar and header; grouped account controls; collapsible spend limits; icon navigation; card number, CVC and expiration grouped with individual Copy buttons; actionable empty states. Earlier screenshots illustrate the workflow rather than the current styling. Reproducible icon source: `scripts/draw-icon.swift`.

Duplicate account protection (v2.9.1): after Link authorization returns the identity, Add account rejects an already-signed-in user, removes only the newly authorized local session, and returns to the existing account. User IDs are compared first, with normalized email as a fallback. Payment/request operations are blocked until the new identity is verified.

## Wallet tools (v2.10.0)

- **Activity:** choose Link, external-connection, or all transactions; optionally enter YYYY-MM-DD start/end dates, refresh, and load subsequent pages. Empty results and insufficient permissions are distinct. Data comes from Link or connected financial accounts and is not a full merchant settlement ledger.
- **Authorize transactions:** explicitly requests read_link_transactions and read_external_transactions in Link, merged with existing granted permissions. Confirm the current account in the browser. The previous local token is replaced only after the returned account matches. Canceling before approval keeps the existing local session; Link controls remote grant revocation. This public client/account may not support every requested permission, in which case the API error remains visible.
- **Cards:** load wallet payment methods; Edit opens nickname/default controls. A second confirmation saves both fields to Link. Empty nickname clears it; choosing a new default replaces the previous wallet default. Failures preserve the last confirmed local values.
- **Verification:** the account area shows the returned requirement or pending/completed status and a trusted Link action URL when provided. Complete verification on Link; this app does not collect identity documents or SSNs.

All views remain isolated to the selected Link account. Transaction data stays in memory and is cleared on logout/session invalidation; it is not included in local error logs. Implementations follow the official stripe/link-cli SDK resources. Offline tests cover APIs and state transitions; no live permission grants, financial reads, or wallet updates were performed during development verification.


## Recurring payment requests

In Create, enter the payment method, merchant, amount and item, then choose Payment frequency. One-time is the default; day, week, month and year support an interval count (for example every 1 month or every 2 weeks). The generated context, confirmation and request list show the schedule. Enter amounts in the selected currency's minor units; check the amount, merchant, schedule and final terms on Link's approval page.

Open the approval link after creation and approve in Link. Account/client support and recurrence rules are determined by Link; failures appear in the error banner. Review status and cancel eligible requests in the request list. The app does not schedule requests or initiate charges itself. Manage merchant subscriptions separately: canceling a Link request does not cancel a merchant subscription.

Developer validation uses mocked APIs for all four intervals, one-time requests and invalid counts. No real recurring payment was created.


## Merchant templates, subscriptions and status notifications (2.12.0)

### Merchant templates

1. In Create, enter the merchant, URL, item, amount, currency and one-time or recurring settings.
2. Expand Merchant templates, name the template and choose Save current form.
3. Select a saved template next time to populate purchase fields. Selecting a template replaces those fields.
4. Save again to update the selected template, or delete it. Saving does not create a payment request.

Templates are stored in local preferences per App account slot and survive restarts without cloud sync. They exclude payment method IDs, card numbers and CVCs. Logging out retains that slot's templates. Select a payment method and review/approve each new request in Link.

### Subscription management

Open Subscriptions to automatically load the current account's recurring requests. Select one to see its cadence, spending limit per period, currency, status and request expiry. View credentials, open an existing approval link, or cancel an eligible request. Include history shows ended recurring requests.

A period limit is not a charge. This manages Link recurring payment credentials, not a complete merchant subscription inventory. It does not estimate the next billing date. Cancel merchant subscriptions separately after revoking credentials.

### macOS status notifications

Enable Status notifications at the bottom of the panel and grant macOS notification permission. While the app runs, it checks logged-in accounts' Link requests about once a minute; approval waiting also observes changes. Notifications cover observed approval/request-failure transitions and payment success/failure changes reported by Link. Initial historical records and duplicate results stay silent.

Notifications exclude merchants, amounts, accounts, card numbers and CVCs. Turning off the option stops periodic checks; quitting the app stops monitoring. This is polling, not real-time webhooks. Sleep, network errors and Link data delays can delay notifications. Confirm final payment results against merchant records. Check macOS System Settings → Notifications → Link Card and Focus settings if delivery is missing.

Offline mock regressions and app compilation were verified. No real payments or wallet changes were made, and system notification delivery has not been tested live.


## Safari card autofill (2.13.0)

Choose Fill in Safari… in the card panel, review the payment website, and confirm filling. This uses macOS Safari automation without a browser extension, CLI, Node.js or local server.

### First-use setup

1. Enable Show features for web developers in Safari Settings → Advanced.
2. Enable Allow JavaScript from Apple Events in Safari's Develop menu or Developer settings. Its location varies by Safari version.
3. Allow Link Card to control Safari when macOS prompts. If denied, change System Settings → Privacy & Security → Automation.
4. The first permission dialog may dismiss the menu-bar panel. Reopen the panel and show the card after granting permission. Recheck permissions if they stop working after an update.

### Fill a checkout

1. Open an HTTPS checkout in Safari's current tab.
2. Show an approved request's card in Link Card, then choose Fill in Safari….
3. Review the website domain, requested merchant and detected fields. Different merchant/checkout domains receive an additional notice.
4. Confirm and fill. The app checks Safari's page URL again before filling; changing pages requires another review.
5. Review the results in Safari and submit payment yourself. The app never clicks a payment or submit button.

Common card-number, CVC, combined/separate expiry, month/year selects and explicitly marked billing-address fields are supported. Only names/addresses returned by Link are used. Missing data is not inferred. Shipping, hidden and unknown fields are skipped. Cross-origin payment iframes, Shadow DOM and custom controls may be inaccessible; use the existing copy buttons for those fields.

Credentials travel to Safari in memory, never through files, the clipboard, shell arguments or error logs. Closing the panel clears card details and structured billing fields. Confirmation URLs come from Safari itself. Page scripts return only field types and fill results, not field values.

DOM mock tests cover HTTPS/page-change checks, field formats, billing selection and credential cleanup. Safari permissions and real merchant checkout filling have not been tested live. Running the app needs no Node.js; developers need Node.js 18+ for the DOM regressions in `./test.sh`.


## Limit alerts and request search/filtering (2.14.0)

### Limit alerts

When signed in and Link returns explicit limits, the panel warns when daily or rolling 30-day remaining allowance is below 20% of its limit, or the returned allowance is zero. When creating a USD request, the form warns if the entered amount exceeds the returned per-transaction cap, daily remaining allowance or rolling 30-day remaining allowance.

Alerts use only USD-equivalent data returned by Link. Missing remaining amounts are not derived from usage; accounts are not combined; other currencies are not converted. Unlimited, missing or invalid data does not produce speculative warnings. Alerts do not block submission; limits may change and Link determines final approval. Refresh through Spend limits → Refresh limits. These are in-app alerts, not additional system notifications.

### Search and filters

Requests, Approve and Subscriptions now include search plus status, funding-card and request-type filters. Search covers merchant names, URLs, request IDs and context without case sensitivity. Multiple words and all selected filters must match. Choose Clear filters to reset.

Funding cards are grouped by payment-method IDs returned on requests. Matching loaded wallet data supplies nicknames/brand/last4; otherwise IDs are shown. Generated virtual-card last4 values are not used to guess funding cards. Request type supports all, one-time or recurring.

Filtering applies to the current account's loaded requests. Enable Include history for historical records. Approve still contains only pending requests, and Subscriptions only recurring requests. Counts show matching/loaded records for that view, not a server-wide total. Hiding the selected request clears its selection and card details. Successful creation resets filters so approval remains visible.

English/Chinese are synchronized. Limit boundaries and compound filters passed offline tests; real account limits and UI interactions have not been tested live.
