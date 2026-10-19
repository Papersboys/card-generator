# Link Card installation guide

[English](INSTALL.en.md) | [简体中文](INSTALL.zh-CN.md)

After installation, open Link Card from the credit-card icon in the macOS menu bar. It connects directly to Link; no `link-cli`, Node.js, or npm installation is required.

## Choose an installation method

| What you have | Method |
| --- | --- |
| A packaged `LinkCard.zip` or `LinkCard.app` | Method 1; Xcode is not required |
| The Git repository or a source ZIP | Method 2: build, then install |

Download the prebuilt app from [GitHub Releases](https://github.com/Papersboys/card-generator/releases/latest). App bundles are distributed as release assets rather than tracked in Git. Method 2 is optional for users who want to build from source.

## Requirements

| Component | Requirement |
| --- | --- |
| Mac | Apple Silicon, such as M1–M4; the current script builds `arm64` |
| macOS | Version 13 or later |
| Network | Access to official Link services for login, account information, and requests |
| Account | A personal Link account eligible for the relevant features; eligibility is determined by Link |
| Source builds | Xcode, its macOS SDK, and Swift; the project has been built with Swift 6.2 |

Running a packaged app does not require Xcode. The current build script does not produce an Intel or Universal version.

## Method 1: install a packaged app

1. Download [LinkCard-macos-arm64.zip](https://github.com/Papersboys/card-generator/releases/latest/download/LinkCard-macos-arm64.zip), then double-click it in Finder to extract it.
2. Drag `LinkCard.app` into **Applications**, or the **Applications** folder inside your home folder.
3. Double-click the installed app.
4. Check that the credit-card icon appears in the menu bar.

Current builds use a local ad-hoc signature and are not Apple-notarized. Obtain packages from a trusted source. If macOS or a managed device blocks launch, check the source and system message, or build from source below. Do not disable system security protections to work around the issue.

### Optional: verify the download

Download [SHA256SUMS.txt](https://github.com/Papersboys/card-generator/releases/latest/download/SHA256SUMS.txt) from the same release. Put it beside the ZIP and run in that folder:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

The ZIP should report `OK`. No Xcode, Terminal commands, or compilation are required for the normal Finder installation above.

## Method 2: build from source

### 1. Set up Xcode

Install Xcode, open it at least once, and complete its first-launch setup.

Check your developer tools in Terminal:

```bash
xcode-select -p
xcrun --find swiftc
xcrun --show-sdk-path
```

If multiple Xcode versions are installed, or another developer-tools directory is selected, choose the Xcode installation you intend to use. For the usual installation path:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Use your actual path if Xcode is installed elsewhere. If the build reports an incomplete license or missing components, open Xcode and finish setup before retrying.

### 2. Get the source

```bash
git clone https://github.com/Papersboys/card-generator.git
cd card-generator
```

If you already have a checkout, enter that folder instead of cloning again. You can also extract a source ZIP and enter the project root containing `build.sh` and `Info.plist`.

### 3. Build

```bash
./build.sh
```

The script compiles Swift, generates the icon, assembles the bundle, and signs and verifies it locally. On success:

```text
Built: /path/to/card-generator/dist/LinkCard.app
```

Try the app directly:

```bash
open dist/LinkCard.app
```

Optionally run the offline tests. They use mocked APIs and do not create real requests or charges:

```bash
./test.sh
```

### 4. Install in your personal Applications folder

If the app is running, choose **Quit** from its menu-bar menu before copying:

```bash
mkdir -p "$HOME/Applications"
ditto dist/LinkCard.app "$HOME/Applications/LinkCard.app"
open "$HOME/Applications/LinkCard.app"
```

These commands install or replace the copy in your personal Applications folder. Use that location for subsequent launches. Alternatively, drag the built app into `/Applications` in Finder and authorize the copy if prompted.

## First launch and login

1. Click **Log in to Link**.
2. Open the official authorization link and sign in to your Link account in the browser.
3. Enter the phrase shown by the app when requested, and authorize the connection.
4. Return to the app and wait for **Logged in** and the name/email returned by Link.
5. Select **中文 / English** at the top to change the interface language.

The independent app login is stored in macOS Keychain; the language preference survives restarts. Do not commit authorization phrases, credentials, or full card details to Git.

![Login authorization screen with fictional demo data; the interface is shown in Chinese](images/login-zh.jpg)

Continue with the [illustrated usage guide](USAGE.en.md) for creation, approval, card display, and cancellation.

## Menu bar and quitting

- Click the credit-card icon → **Open Link Card** to reopen the window.
- Closing the window does not quit the app or cancel server-side requests.
- Choose **Quit** from the menu-bar menu to exit completely.
- Installation does not automatically enable launch at login.

## Updating

1. Quit the running app from its menu-bar menu.
2. Enter your source checkout. Save any local changes, then update and rebuild:

   ```bash
   git pull --ff-only
   ./build.sh
   ```

3. Replace the installed app with `dist/LinkCard.app`.
4. Reopen it and check the account and language settings.

For a personal Applications installation:

```bash
ditto dist/LinkCard.app "$HOME/Applications/LinkCard.app"
open "$HOME/Applications/LinkCard.app"
```

Replacing the bundle does not intentionally remove Keychain credentials or language preferences. Signature or access-permission changes may require confirming Keychain access or logging in again.

For a packaged installation, download the new ZIP from [the latest release](https://github.com/Papersboys/card-generator/releases/latest), quit the old app, and replace the bundle. There is no automatic updater.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| `swiftc` or the macOS SDK is missing | Install/open Xcode; check `xcode-select -p` and `xcrun --show-sdk-path` |
| Xcode license or components are incomplete | Complete Xcode setup, then rebuild |
| `./build.sh: permission denied` | Run `chmod +x build.sh test.sh` in the project root, then retry |
| `build.sh` cannot be found | Enter the project root containing `Source/`, `build.sh`, and `Info.plist` |
| No permission to install | Use `$HOME/Applications`, or authorize the Finder copy when prompted |
| A downloaded app will not open | Check its source, extraction, and the system message; consider a source build rather than disabling security protections |
| No Dock icon appears | This is a menu-bar app; look for the credit-card icon at the top of the screen |
| The window disappeared | Choose **Open Link Card** from the menu-bar icon |
| Multiple copies appear | Quit old copies and consistently open the installed bundle instead of also launching `dist/` |
| Login expired or account information is unavailable | Follow the app's network/login prompts and the usage guide |
| App will not run on Intel | The current script only builds for Apple Silicon; Intel requires separate adaptation and verification |

## Uninstalling

1. Choose **Quit** from the menu-bar menu.
2. Move the installed `LinkCard.app` to Trash in Finder.

Deleting the bundle does not cancel spend requests or refund payments. If you stop using the app, you can remove its authorization in Link's connected applications. Local Keychain entries and language preferences are not automatically removed with the bundle.
