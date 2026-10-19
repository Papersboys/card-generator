# Link Card

A native macOS menu-bar app to create Link spend requests, approve them in Link, display virtual card details, and cancel unused requests. Built with SwiftUI, AppKit, and URLSession.

Run `./build.sh`, then open **dist/LinkCard.app**. Use the credit-card icon in the macOS menu bar to open the window or quit. You can move the app to Applications.

**No link-cli binary, Node.js, npm, shell helpers, or local server is required.** Requires Apple Silicon and macOS 13+.

## Quick start

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

Build output is excluded from Git. To keep the app installed, move `dist/LinkCard.app` to your Applications folder.

## Login

Click **登录 Link**, open the official Link authorization link, and complete authorization in your browser using the phrase displayed in the app. The app waits for approval and stores its independent login in macOS Keychain, with automatic token refresh.

For convenience, an existing unexpired Link CLI access token can be reused read-only from its standard preferences file. The app never writes that file or uses its refresh token. When that temporary session expires, use the app's Login button; thereafter no CLI installation or configuration is needed.

This personal app uses the public device-flow client and API protocol from Stripe's MIT-licensed implementation, labeled “Link Card.” For distributing a product to other users, register your own OAuth client with Stripe rather than relying on the public CLI client.

## Usage

- **Requests / History:** refresh, include history, select a request, show card details, or cancel with confirmation.
- **Create:** load a payment method; enter merchant, URL, amount in minor units (USD $15 = 1500), item, and at least 100 characters of context. Review and confirm creation.
- Approve the purchase yourself in Link. The app checks approval every two seconds for up to ten minutes, then automatically retrieves full card details. Manual refresh is also available.
- Full card details are selectable; missing fields show `—`. Card responses are handled in memory with an ephemeral network session, without credential JSON files.
- Closing the window clears displayed card data and stops approval checks. Canceling a request does **not** refund completed payments.
- History is spend-request history, not merchant settlement history.

The app has a local ad-hoc signature, not an Apple notarized distribution signature. No startup/login-item setting is changed. No real purchase or cancellation was used in development tests. Live checks used only history and payment-method reads.

## Source and build

`Source/Support.swift` contains shared data helpers. `Source/LinkCard.swift` contains the interface; `Source/NativeLink.swift` contains native URLSession API calls, browser device authorization, token refresh, and Keychain storage. No child processes are launched by the app.

Build on Apple Silicon with Xcode using `./build.sh`. Run `./test.sh` for offline tests of the native API transport, authentication refresh, and device authorization. Tests use a mocked URLSession and do not read real login credentials or send network requests.

API/auth protocol references: [Stripe Link SDK and CLI](https://github.com/stripe/link-cli). Stripe's MIT notice is included in `STRIPE-LICENSE.txt` and the app bundle.

## License

This project is licensed under the [MIT License](LICENSE), copyright © 2026 Yuanxi Li.

The Link API and authentication implementation follows Stripe's open-source Link SDK and CLI. Stripe's original MIT copyright and permission notice is preserved in [STRIPE-LICENSE.txt](STRIPE-LICENSE.txt) and included in the app bundle.

This is an independent project and is not an official Stripe or Link application.
