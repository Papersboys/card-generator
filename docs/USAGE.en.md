# Link Card usage guide

[English](USAGE.en.md) | [简体中文](USAGE.zh-CN.md)

Link Card is a macOS menu-bar app for creating Link spend requests, retrieving approved virtual card details, and canceling requests. It does not place merchant orders or submit merchant checkout forms for you.

> Screenshots come from an offline demo using the actual interface code. Accounts, authorization phrases, requests, and card details are fictional; Costco is shown as the default example merchant and cannot be used for payment. Screenshots show both available interface languages; the English button names below correspond to their Chinese counterparts.

For first-time setup, follow the [installation guide](INSTALL.en.md).

## 1. Core feature: view and copy Visa virtual card details

**After approval, see the card number, CVC/CVV, expiration date, and billing address, ready to copy into the merchant's checkout.** The example shows a Visa virtual card; the actual network and available fields depend on Link's response.

![Card details shown in Chinese with a fictional number, CVC, expiration, billing address, and validity time](images/card-details-zh.jpg)

*Every account and card field shown is fictional, not a real payment credential.*

Missing fields display as `—`:

| Field | Meaning |
| --- | --- |
| Card number | Virtual card number returned by Link |
| CVC | Virtual card security code, also called CVV |
| Expiration | Card expiration month/year |
| Billing address | Billing address returned by Link |
| Brand | Card network |
| Valid until | The actual credential deadline returned by Link; missing values display as `—`. This is separate from request expiry and card expiration |
| Request expiry | The request expiry returned by Link |
| Spend request ID | The request ID, typically starting with `lsrq_` |
| Status | Current request status |
| Merchant / Merchant URL | Merchant information supplied when creating the request |
| Context | Purchase purpose |
| Created at | Request creation time |

### Already have an approved request?

1. Select **Requests / History**.
2. Click **Refresh list**.
3. Select the request.
4. Click **Show card details**.

Use the separate **Copy** buttons beside Card number, CVC/CVV, and Expiration. Each shows Copied after copying its value for checkout. Missing values cannot be copied. You can also select text and press **⌘C**. The app does not automatically copy or fill merchant forms. Full card numbers and CVCs appear directly in the panel.

Click **Clear card details** to clear the display. Closing the panel also clears displayed card details; pending approval checks can continue, without canceling the server-side request. Card responses use an ephemeral network session and are not written to credential JSON files.


First time here? Continue with launch, login, creation, and approval below. Pending requests do not expose full card details.

## 2. Menu bar dropdown panel

Launch **LinkCard.app**, then click the credit-card icon in the macOS menu bar to expand the panel. From v2.7.0, the app no longer opens a separate main window.

- Click the icon again, click outside the panel, or press Esc to close it.
- View, create, approve, log out, and check for updates in the panel. Scroll to reach more content.
- Right-click the icon for shortcuts including Check for Updates… and Quit. Quit is also available at the bottom of the panel.
- Closing the panel clears displayed card details and keeps existing requests in Link. Approval checks can continue; reopen the panel after approval to retrieve card details.

### Change language

Use **中文 / English** at the top of the panel. Controls, menu-bar items, confirmations, card field labels, and existing status messages update immediately. Your choice survives restarts. Merchant names, purchase context, IDs, and card data are preserved.

### Panel layout and editing shortcuts

The panel fits the available screen area and scrolls vertically. Older screenshots below illustrate field content; from v2.7.0 the actual interface is a menu bar dropdown panel.

| Narrow single-column form | Scroll to the bottom |
| --- | --- |
| ![Chinese form at 540-point window width](images/responsive-narrow-zh.jpg) | ![Generated context and create button remain accessible by scrolling](images/responsive-narrow-bottom-zh.jpg) |

All text input fields support **⌘C Copy, ⌘V Paste, ⌘X Cut, ⌘A Select All, ⌘Z Undo, and ⇧⌘Z Redo**, also available through the macOS Edit menu. Click a field first; use ⌘A followed by paste to replace its contents. The payment-method ID can be pasted or edited after selecting a method. Context is generated automatically and can be selected and copied; it needs no manual entry.

### Automatic updates (v2.6.0 onward)

Use Check for Updates… and the Automatically check for updates toggle in the footer. A check command is also available in the menu bar. Automatic checks run daily by default; manual checks remain available when disabled. Follow Sparkle's update dialog to download, install, and relaunch; finish current work before installing. Both the feed and archive are signature-verified. Older builds need one manual download to gain this feature.

![Automatic-check toggle and manual check button; Chinese interface](images/update-controls-zh.jpg)

![Successful check of the public signed feed: already up to date](images/update-check-en.jpg)

## 3. Log in to Link

1. Click **Log in to Link** below the title.
2. Click **Open Link authorization ↗** to open the official Link website.
3. Sign in to your account and enter the app's authorization phrase if requested.
4. Return to the app. The login button is replaced by **Logged in** and the name/email returned by Link.

![Login instructions with the fictional DEMO PHRASE; shown in Chinese](images/login-zh.jpg)

*The authorization phrase in this screenshot is only an example.*

On launch, the app checks the session and loads account details. If authentication expires and cannot be refreshed, the login button returns. Temporary network failures do not automatically sign you out; the app reports when account information is unavailable.

Authorizing the app and approving an individual purchase are separate steps. The independent app login is stored in macOS Keychain. No CLI, Node.js, or npm is required.

An existing unexpired CLI access token can be reused read-only without changing its configuration or using its refresh token. Once it expires, use the app's login button to establish an independent session.

### Log out

After signing in, click **Log out** beside the account information. This removes the app's Keychain credentials, clears account/card details and local lists, and stops approval checks. Log in to Link becomes available again. The app will not silently reuse a CLI login on restart after an explicit logout; sign in again to view existing server-side requests.

This signs out of this app only. It does not modify CLI configuration, sign out of Link in your browser, or cancel existing requests. Manage connections in Link if you want to revoke the server-side authorization.

## 4. Create a spend request

First confirm the item and final checkout total on the merchant's website. Then:

1. Select **Create**.
2. Click **Load** beside Payment method.
3. Select a method from the dropdown. Its ID fills automatically; you can also enter an existing payment-method ID manually.
4. Complete the form. Merchant name and URL default to **Costco** and **https://www.costco.com**, and remain editable. Amount and item examples are placeholders; enter the actual checkout amount and item.

![Editable Costco merchant defaults and amount/item placeholders; Chinese interface](images/create-defaults-zh.jpg)

USD amounts use cents: the minimum is `50` ($0.50); `1500` = $15.00 and `50000` = $500.00. Placeholder examples are not submitted values. Generated context updates as you edit the purchase fields.

![English creation form with a fictional payment method, merchant, amount, and purchase context](images/create-en.jpg)

*With currency `usd`, an amount of `1500` represents $15.00.*

| Field | What to enter | Example |
| --- | --- | --- |
| Payment method ID | The Link funding method, not a spend-request ID | Select from the dropdown |
| Merchant name | Actual merchant; defaults to Costco and is editable | Costco |
| Merchant URL | Complete HTTP/HTTPS URL; editable Costco default | `https://www.costco.com` |
| Amount | A positive integer in the currency's minor units | For USD $15.00, enter `1500` |
| Currency | Three-letter currency code | `usd` |
| Item | Purchase description; quantity is currently fixed at 1 and commas are not allowed in the name | Meal credit |
| Context | Generated automatically from merchant, URL, item, amount, and currency; no typing required | Review before creation |

5. Click **Review and create…**.
6. Check the merchant, URL, amount, item, and context in the confirmation dialog.
7. Click **Create and request approval**. Filling in the form alone does not submit a request.

![Review dialog showing the merchant, amount, and context](images/create-review-en.jpg)

*Choose Back to return and edit the form.*

Interpret the amount together with its currency: `10000` in `usd` means $100.00, not $10,000. Request amounts and statuses are not necessarily the merchant's final settlement amount.

This client does not support custom request expiry. Creation omits `expires_at`; card expiration and credential validity are determined by Link.

## 5. Approve and automatically show card details

1. After creation, the **Approve** tab opens. Click **Approve in Link ↗**. You can also select earlier pending requests here to review their merchant, amount, and generated context. If no link is available yet, click **Get approval link**.
2. Review and personally approve the request on the official Link page.
3. The app can continue checking while the panel is closed. The app checks every two seconds for up to ten minutes and retrieves card details after approval when the panel is open; otherwise, reopen the panel to retrieve them.
4. If the display does not update, click **Refresh after approval**, or select the request and click **Show card details**.

![Approve tab showing an earlier pending request, purchase context, and Link approval link; Chinese interface](images/approve-zh.jpg)

**Return to an earlier request:** Open Approve, click Refresh list, and select a request to review its merchant URL, requested amount, and context. Use Get approval link if none is shown. Review request reloads its status and starts waiting for approval. Approved requests leave the pending list after refresh; use Requests / History to view their card details. An empty-state message appears when no requests need approval.

The app does not approve purchases for you. Reaching the ten-minute polling limit only stops automatic checks; it does not cancel the request.

## 6. Cancel a request

1. Select the request in **Requests / History**.
2. Click **Cancel request** in that row, or use the button below the list. Only created, pending-approval, or approved requests can be canceled.
3. Verify the merchant and request ID, then confirm **Cancel request**.
4. After Link confirms cancellation, the app clears the corresponding card display and stops approval polling. Canceled requests leave the active list; enable **Include history** to view them. Refresh to reload server state.

![Cancellation confirmation in Chinese explaining that completed payments are not reversed](images/cancel-confirmation-zh.jpg)

*Review the merchant and ID before confirming. No cancellation was submitted for this screenshot.*

The server can reject cancellation in some states; the app displays the error.

## 7. History

Enable **Include history** to reload past requests, including canceled and expired ones. You can select a record and try retrieving details, but full card credentials may no longer be available.

This is **spend-request history**. Row amounts are request amounts, not a dedicated query of actual merchant charges. The app currently has no separate merchant transaction ledger, refund tracker, or reconciliation view. Compare merchant receipts with the final posted funding-method transaction when checking actual charges.

## Troubleshooting

![Persistent error banner with Copy error and Dismiss controls; Chinese interface](images/error-banner-zh.jpg)

Errors appear in a persistent red banner at the top of the panel. It keeps the specific Link error through tab changes, refreshes, and scrolling. Use Copy error to copy the text, or × to dismiss it. Failed creation preserves the form and does not switch to Approve.



For `amount must be at least $0.50 usd`, enter at least `50` for USD. A rejected creation does not produce a request to approve. If an older build reports `expires_at is not supported for this client`, quit and update to v2.5.6 or later; custom expiry has been removed from creation.

| Situation | What to do |
| --- | --- |
| No active requests | Enable Include history or create a request |
| No payment methods | Check the account, click Load, and follow any account/payment-method instructions returned by Link |
| Create button is disabled | Check required fields, whether another action is running |
| Invalid amount or URL | Use positive integer minor units and a complete `http://` or `https://` URL |
| `pending_approval`, with no card number | Open that request's approval link, approve it, then refresh |
| Expired login or HTTP 401 | Use Log in to Link, then refresh |
| Card number, address, or CVC is `—` | The response did not include that field; check approval/status rather than inferring its value |
| Details disappeared after closing the panel | Reopen from the menu bar, select the request, and show details again |
| Creation returned an error | Refresh active requests and history before retrying, to avoid duplicate submissions |

## Current scope

- Apple Silicon, macOS 13 or later.
- Persistent Chinese/English switching.
- One item per request, quantity fixed at 1.
- No automatic merchant checkout, approval, launch at login, or refund operation.
- Local ad-hoc signing, without Apple notarization.

If `refresh_token is not active: status: revoked` appears, the saved refresh credential is no longer valid. From v2.5.7 onward, Log in to Link becomes available again; use it to authorize a fresh session. Do not share tokens.

### Missing approval link or phone notification

Update to v2.7.4 or later. Refresh the Approve tab, select the request, and click Get approval link. Requests in created, pending_approval, or requires_action are included. Open the returned Link approval URL, approve in Link, then refresh card details. If recovery fails, inspect the error banner before creating a duplicate request.

## Multiple Link accounts

Use the Account picker above the account header to switch accounts. **Add account** starts a new Link authorization without logging out the others. On the Link authorization page, choose or sign in to the intended account; Safari may already be signed in to another account.

Each account has its own Keychain token entry, API session, requests and spend limits. Log out affects only the selected account. Existing login is retained as the first account. Saved logins survive app restarts, subject to Link expiry or revocation. Form drafts are preserved per account during the current app session; displayed card credentials clear on switching. Pending approval checks already started can continue for other accounts while the app runs. Switching is disabled during an active operation or login; use Stop waiting to cancel login first. The CLI remains a separate single-account tool. Account limits are displayed independently and are not pooled or increased.
