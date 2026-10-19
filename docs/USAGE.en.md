# Link Card usage guide

[English](USAGE.en.md) | [简体中文](USAGE.zh-CN.md)

Link Card is a macOS menu-bar app for creating Link spend requests, retrieving approved virtual card details, and canceling requests. It does not place merchant orders or submit merchant checkout forms for you.

> Screenshots come from an offline demo using the actual interface code. Accounts, authorization phrases, requests, merchants, and card details are fictional and cannot be used for payment. Screenshots show both available interface languages; the English button names below correspond to their Chinese counterparts.

For first-time setup, follow the [installation guide](INSTALL.en.md).

## 1. Launch and menu bar

After building as described in the README:

```bash
./build.sh
open dist/LinkCard.app
```

A credit-card icon appears in the macOS menu bar:

- **Open Link Card** shows the main window.
- **Quit** exits the app.

Closing the window leaves the app in the menu bar. Reopen it from the icon. The app does not automatically enable launch at login.

![Chinese request history showing a fictional signed-in account and request statuses](images/overview-zh.jpg)

*The header shows the account; rows show request IDs, amounts, and statuses.*

### Change language

Use **中文 / English** at the top of the window. Controls, menu-bar items, confirmations, card field labels, and existing status messages update immediately. Your choice survives restarts. Merchant names, purchase context, IDs, and card data are preserved.

## 2. Log in to Link

1. Click **Log in to Link** at the top right.
2. Click **Open Link authorization ↗** to open the official Link website.
3. Sign in to your account and enter the app's authorization phrase if requested.
4. Return to the app. The login button is replaced by **Logged in** and the name/email returned by Link.

![Login instructions with the fictional DEMO PHRASE; shown in Chinese](images/login-zh.jpg)

*The authorization phrase in this screenshot is only an example.*

On launch, the app checks the session and loads account details. If authentication expires and cannot be refreshed, the login button returns. Temporary network failures do not automatically sign you out; the app reports when account information is unavailable.

Authorizing the app and approving an individual purchase are separate steps. The independent app login is stored in macOS Keychain. No CLI, Node.js, or npm is required.

An existing unexpired CLI access token can be reused read-only without changing its configuration or using its refresh token. Once it expires, use the app's login button to establish an independent session.

## 3. Create a spend request

First confirm the item and final checkout total on the merchant's website. Then:

1. Select **Create**.
2. Click **Load** beside Payment method.
3. Select a method from the dropdown. Its ID fills automatically; you can also enter an existing payment-method ID manually.
4. Complete the form.

![English creation form with a fictional payment method, merchant, amount, and purchase context](images/create-en.jpg)

*With currency `usd`, an amount of `1500` represents $15.00.*

| Field | What to enter | Example |
| --- | --- | --- |
| Payment method ID | The Link funding method, not a spend-request ID | Select from the dropdown |
| Merchant name | The actual merchant receiving payment | Example Store |
| Merchant URL | A complete HTTP/HTTPS URL | `https://example.com` |
| Amount | A positive integer in the currency's minor units | For USD $15.00, enter `1500` |
| Currency | Three-letter currency code | `usd` |
| Valid until | Request expiry in local date/time; defaults to 24 hours from opening the form. Use One day from now to reset it | Tomorrow at the current time |
| Item | Purchase description; quantity is currently fixed at 1 and commas are not allowed in the name | Meal credit |
| Context | At least 100 characters describing the purchase, merchant, amount, and purpose | See below |

Example context; adapt it to the actual purchase:

```text
Requesting approval to purchase 15 USD of meal credit from Example Store at https://example.com. This request is for the checkout total I reviewed and will be paid using my selected Link payment method.
```

5. Click **Review and create…**.
6. Check the merchant, URL, amount, item, and context in the confirmation dialog.
7. Click **Create and request approval**. Filling in the form alone does not submit a request.

![Review dialog showing the merchant, amount, and context](images/create-review-en.jpg)

*Choose Back to return and edit the form.*

Interpret the amount together with its currency: `10000` in `usd` means $100.00, not $10,000. Request amounts and statuses are not necessarily the merchant's final settlement amount.

The selected Valid until is included in the review dialog and sent as request `expires_at` in Unix seconds. It must be in the future. This sets the requested expiry, not a guaranteed card lifetime: [Stripe currently documents a 12-hour card credential lifetime](https://github.com/stripe/link-cli#spend-request-lifecycle). The actual card deadline is whatever Link returns.

## 4. Approve and automatically show card details

1. After creation, click **Approve in Link ↗**.
2. Review and personally approve the request on the official Link page.
3. Keep the app window open. The app checks every two seconds for up to ten minutes and retrieves card details once approved.
4. If the display does not update, click **Refresh after approval**, or select the request and click **Show card details**.

The app does not approve purchases for you. Reaching the ten-minute polling limit only stops automatic checks; it does not cancel the request.

## 5. View or copy card details

1. Select **Requests / History**.
2. Click **Refresh list**.
3. Select the request.
4. Click **Show card details**.

![Card details shown in Chinese with a fictional number, CVC, expiration, billing address, and validity time](images/card-details-zh.jpg)

*Every account and card field shown is fictional, not a real payment credential.*

Missing fields display as `—`:

| Field | Meaning |
| --- | --- |
| Spend request ID | The request ID, typically starting with `lsrq_` |
| Status | Current request status |
| Merchant / Merchant URL | Merchant information supplied when creating the request |
| Context | Purchase purpose |
| Created at | Request creation time |
| Card number | Virtual card number returned by Link |
| CVC | Virtual card security code, also called CVV |
| Brand | Card network |
| Expiration | Card expiration month/year |
| Billing address | Billing address returned by Link |
| Request expiry | The request expiry returned by Link |
| Valid until | The actual credential deadline returned by Link; missing values display as `—`. This is separate from request expiry and card expiration |

Select text and press **⌘C** to copy it to your own checkout form. The app does not automatically copy or fill merchant forms. Full card numbers and CVCs appear directly in the window.

Click **Clear card details** to clear the display. Closing the window also clears it and stops approval checks, without canceling the server-side request. Card responses use an ephemeral network session and are not written to credential JSON files.

## 6. Cancel a request

1. Select the request in **Requests / History**.
2. Click **Cancel request** in that row, or use the button below the list. Only created, pending-approval, or approved requests can be canceled.
3. Verify the merchant and request ID, then confirm **Cancel request**.
4. After Link confirms cancellation, the app clears the corresponding card display and stops approval polling. Canceled requests leave the active list; enable **Include history** to view them. Refresh to reload server state.

![Cancellation confirmation in Chinese explaining that completed payments are not reversed](images/cancel-confirmation-zh.jpg)

*Review the merchant and ID before confirming. No cancellation was submitted for this screenshot.*

**Canceling a request does not issue a refund or automatically reverse completed merchant payments.** Contact the merchant or Link support as appropriate for an actual payment. The server can reject cancellation in some states; the app displays the error.

## 7. History

Enable **Include history** to reload past requests, including canceled and expired ones. You can select a record and try retrieving details, but full card credentials may no longer be available.

This is **spend-request history**. Row amounts are request amounts, not a dedicated query of actual merchant charges. The app currently has no separate merchant transaction ledger, refund tracker, or reconciliation view. Compare merchant receipts with the final posted funding-method transaction when checking actual charges.

## Troubleshooting

| Situation | What to do |
| --- | --- |
| No active requests | Enable Include history or create a request |
| No payment methods | Check the account, click Load, and follow any account/payment-method instructions returned by Link |
| Create button is disabled | Check required fields, the 100-character context minimum, and whether another action is running |
| Invalid amount or URL | Use positive integer minor units and a complete `http://` or `https://` URL |
| `pending_approval`, with no card number | Open that request's approval link, approve it, then refresh |
| Expired login or HTTP 401 | Use Log in to Link, then refresh |
| Card number, address, or CVC is `—` | The response did not include that field; check approval/status rather than inferring its value |
| Details disappeared after closing | Reopen from the menu bar, select the request, and show details again |
| A canceled request still has a charge | Cancellation is not a refund; check merchant and funding-account records |
| Creation returned an error | Refresh active requests and history before retrying, to avoid duplicate submissions |

## Current scope

- Apple Silicon, macOS 13 or later.
- Persistent Chinese/English switching.
- One item per request, quantity fixed at 1.
- No automatic merchant checkout, approval, launch at login, or refund operation.
- Local ad-hoc signing, without Apple notarization.
