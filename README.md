# YourDotMini

A small, unofficial macOS menu bar app for your ChatGPT dot. Click the menu bar
icon or press a shortcut to open a compact conversation window, then hide it
without closing the page.

YourDotMini uses the ChatGPT website and your existing account; no API key is
required. It is an independent project, not an OpenAI product, and does not
provide the official ChatGPT app's local-computer connection.

## Download and install

**[Download v0.2.0 for Apple Silicon (.dmg)](https://github.com/hyeshik/dot-mini/releases/download/v0.2.0/YourDotMini.dmg)**
· [Release notes](https://github.com/hyeshik/dot-mini/releases/tag/v0.2.0)

- **Mac:** Apple Silicon (arm64). The download does not include an Intel build.
- **macOS:** targets macOS 14 or later. Tested on macOS 27.0.1; compatibility with
  older versions has not been verified.
- **Account:** a ChatGPT account with access to your dot.

The app and disk image are Developer ID signed and Apple-notarized, with stapled
notarization tickets.

1. Download and open `YourDotMini.dmg`.
2. Drag **YourDotMini.app** onto the **Applications** shortcut. If updating, quit
   the running copy first and replace the existing app.
3. Eject the disk image and open **YourDotMini** from **Applications**. Confirm
   the standard macOS first-launch prompt if it appears.
4. In the welcome window, choose **Use Embedded Window** and sign in through the
   website. Your browser's sign-in is separate from this app's session.

To verify the download, save the
[SHA-256 checksum file](https://github.com/hyeshik/dot-mini/releases/download/v0.2.0/YourDotMini.dmg.sha256)
beside the DMG and run this command in that directory:

```sh
shasum -a 256 -c YourDotMini.dmg.sha256
```

## Everyday use

Click the menu bar icon to show or hide the window. Right-click it for commands
such as **Keep Open**, **Expand Window**, **Reload Dot**, and **Settings…**.
Hiding retains the same page; quitting ends the app process.

| Shortcut | Action |
| --- | --- |
| Control + Option + period (`⌃⌥.`) | Show or hide the window from another app. |
| `⌘0` | Open Dot. |
| `⌘W` | Hide the conversation window. |
| `⌘R` | Reload the page. |
| `⌘1` / `⌘2` | Use the standard 480 × 720 or compact 420 × 520 viewport. |
| `⌘,` | Open Settings. |
| `⌘Q` | Quit YourDotMini. |

Only the global shortcut works while another app is active. Change or disable it
in **Settings → Global shortcut**, then select **Apply Shortcut**. If another app
also responds, choose a different combination.

The window remembers its resized dimensions. **Settings → Window** controls
hiding when you switch windows, keeping the window open, focusing the message
input, and preloading the page. Launch at login is optional and can be enabled
in **Settings → Launch at login**.

To open a specific dot or conversation, set a verified `https://chatgpt.com/`
link in **Settings → Dot destination**. Use a clean link without authentication
codes, tokens, or other secrets; see the privacy notes below.

## Browser mode and recovery

If a page stops responding, try **Reload Dot** or **Return to Dot** from the
right-click menu. If sign-in or a website feature does not work in the embedded
window, choose **Open Dot in Default Browser** and continue there. Signing in to
that browser does not sign in to YourDotMini.

You can also use a dedicated browser web app: create one for your dot in your
browser, then select it with **Settings → Browsing mode → Choose Web App…**.
Choose **Dedicated browser web app** under **Open with**. The menu bar icon and
global shortcut then open that app's window, using its separate sign-in.

To reset the embedded session, use **Settings → Website data → Clear YourDotMini
Website Data…**. This requires confirmation and signs out only this app. It does
not delete ChatGPT conversation history, your browser's data, or the saved dot
destination in Settings.

## Privacy and known limitations

- **Website sessions:** YourDotMini keeps website data in its own persistent
  macOS/WebKit storage. Hiding or quitting does not clear it. The app does not
  import browser cookies, extract session tokens, or add telemetry. ChatGPT's
  own website and service still handle your conversations and account data.
- **Saved links:** the complete dot destination, including any query string or
  fragment, is stored in plaintext preferences and passed to the default browser
  when you use the browser command. Save only clean links. Clearing website data
  does not remove this preference; replace a sensitive link in Settings.
- **Sign-in:** embedded authentication depends on the provider and may be blocked.
  Google's [OAuth policy](https://developers.google.com/identity/protocols/oauth2/policies#use-secure-browsers)
  prohibits developer-controlled embedded user agents. Use browser mode when
  embedded sign-in is unsupported. Embedded popups are blocked. An unfamiliar
  authentication redirect asks you to approve its exact hostname for the current
  app session; approval does not verify the site's identity. Cancel requests you
  cannot verify. The embedded window does not keep an address bar visible.
- **Files and media:** the file picker grants read access only to files you
  choose. Downloads, microphone, and camera workflows require the browser.
  Actual attachment uploads and task/approval-detail workflows still need live
  validation.
- **Message focus and diagnostics:** the optional focus helper focuses a usable
  message input without reading messages or changing drafts. Wrapper logs omit
  message contents, credentials, URL paths, queries, and fragments, but include
  hostnames. macOS/WebKit may emit separate diagnostics; review logs before sharing.

This is an early release. Authenticated restarts, long-term sessions, account
switching, and recovery still need validation with the final signed app.
Dedicated browser-app login and relaunch also need live verification. Successful
notarization verifies the distribution package, not those website workflows.

## Build from source

Requires macOS and Apple Swift 6.0 or later, supplied by Xcode or Command Line
Tools. There are no third-party package dependencies.

```sh
./scripts/build-app.sh
open build/YourDotMini.app
```

See [Development](docs/DEVELOPMENT.md) for staged builds, tests, icon editing, and
signed/notarized release packaging.

## Report a problem

[Open an issue](https://github.com/hyeshik/dot-mini/issues) with your macOS and app
versions, whether you use the embedded window or browser mode, and steps to
reproduce the problem. Redact private conversations, sensitive URLs, and account
information from screenshots and logs.
