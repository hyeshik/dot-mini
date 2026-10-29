# YourDotMini

The embedded authentication gate has passed; see [POC_REPORT.md](POC_REPORT.md).
The menu bar app is being implemented according to [SPEC.md](SPEC.md), with
current verification and remaining work in [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md).

Build and launch the menu bar app:

```sh
./scripts/build-app.sh
open build/YourDotMini.app
```

The default web viewport matches the pilot's ⌘1 preset (480 × 720 points).
Click the dot in the menu bar to show/hide the retained window; right-click it
for commands. ⌘0 shows, ⌘W hides, ⌘Q quits, and ⌘1/⌘2 select viewport presets.
Settings → Global shortcut offers letters, function keys, and the punctuation keys
`, . / ; ' [ ] \ - =`. Choose modifiers and a key, then select Apply Shortcut.
The default is ⌃⌥. (Control + Option + period); previously saved shortcuts stay unchanged.
Enabled macOS shortcuts and other apps' exclusive reservations are rejected while
preserving the previous binding. Shared or app-local shortcuts may not be detectable;
choose another combination if another app also responds.
The product has its own sandbox identity (`local.YourDotMini`), so sign in through
the website once; it does not copy the pilot's or any browser's cookies.

When the window becomes visible, it focuses the message input if that input is
visible and usable. A missing/changed composer quietly leaves focus alone.
Background window focus stays within that window; explicit menu/hotkey opening
still activates the app. Settings → Window can disable this helper. Its narrow,
first-party script calls `focus()` without reading messages or changing drafts.

To prepare an update while the installed app remains running:

```sh
./scripts/build-app.sh debug --stage
```

The command prints a fresh `build/staged.*/YourDotMini.app` path. It does not
replace or restart the installed app. Quit and apply the staged update later.

The instructions below describe the independently retained authentication pilot.

## App icon

The editable source is `Resources/YourDotMini/AppIcon.icon`, created with Apple
Icon Composer. Its vector foreground preserves the menu bar mark's three equal
holes and equilateral spacing. A pale background and teal foreground use native
Liquid Glass rendering, with system-generated dark, clear, and tinted appearances.
The artwork has no baked-in shadows or corner mask.

`scripts/build-app.sh` invokes `scripts/build-icon.sh` to compile `Assets.car` and
the compatibility `AppIcon.icns` with Xcode's `actool`. It uses a local Xcode path
without changing the system developer-directory setting. When only Command Line
Tools are available, it uses the checked-in `Resources/YourDotMini/AppIcon.icns`.
After editing the layered source, regenerate that fallback with Xcode:

```sh
./scripts/build-icon.sh
cp build/app-icon/compiled/AppIcon.icns Resources/YourDotMini/AppIcon.icns
```

Design references: [Apple app icon guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons/)
and [Icon Composer documentation](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).

## Build and launch

Requires macOS 14+ and Apple Swift 6.0+ (Xcode or Command Line Tools). There are no
third-party dependencies. This is a local development bundle, not a notarized release.

```sh
./scripts/build-pilot.sh
open build/YourDotMiniAuthPilot.app
```

The script builds and ad-hoc signs `build/YourDotMiniAuthPilot.app`, verifies its
signature, and writes toolchain/build details to `build/BUILD_INFO.txt`. The native
SwiftPM build engine works with Command Line Tools alone. The `--disable-sandbox`
build flag is for SwiftPM; **the app itself always has App Sandbox enabled**.

Keep this exact app bundle for a persistence trial. Do not rebuild, change its
identifier, change its signing identity, or clear its data between restart cycles.
The build script refuses to replace a running pilot. Launch through `open` or
Finder, not `swift run`; the bare executable rejects a missing bundle identity.

- Bundle identifier: `local.YourDotMini.AuthPilot`
- Deployment target: macOS 14.0
- Website store: `WKWebsiteDataStore.default()`, configured before creating the view
- Sandbox: enabled; outbound network and read-only user-selected files
- Signing: ad-hoc by default; optional `PILOT_SIGNING_IDENTITY` for a local signing identity
- App storage: managed by macOS/WebKit under this app's own sandbox identity

For a separate Release trial, first finish and record the current trial, then use
`./scripts/build-pilot.sh release`. This uses the same bundle path, identifier, and
entitlements. Ad-hoc Release is not Developer ID signing or notarization. A future
product identity must repeat the authentication gate; pilot success cannot prove
session migration into a differently identified app.

## Pilot controls

The pilot uses one ordinary Dock-visible window and one long-lived `WKWebView`.
It loads `https://chatgpt.com/dots` without changing the user agent or injecting scripts.

| Control | Behavior |
| --- | --- |
| Reload / ⌘R | Reload the current page. |
| Return to Dot | Navigate to the entry URL. |
| Open in Browser | Open the entry URL in the default browser, using that browser's separate session. |
| Pilot → Clear Pilot Website Data… | Confirm, replace the active page with a blank page, delete only this app's WebKit data, then load a fresh session. |
| Window → Hide Window / ⌘W | Hide without recreating the view or quitting. The close button does the same. |
| Window → Show Pilot / ⌘0 | Reveal the same view; clicking the Dock icon also reopens it. |
| Window → 480 × 720 / ⌘1 | Set the web content viewport to 480 × 720 points. Native toolbar/status chrome is extra. |
| Window → 420 × 520 / ⌘2 | Set the smaller test viewport. |
| App menu → Quit Completely / ⌘Q | Terminate the application process without clearing website data. |

Normal Edit commands support copy/paste, selection, and undo in web content.
The app does not infer authentication from page content: “Loaded” only reports a
completed navigation, not a successful login or a passing pilot test.

## Execute the gate

Follow P0-01 through P0-07 in order and record observations in `POC_REPORT.md`.
Sign in manually through the site's normal controls with the real account/provider.
Do not automate sign-in or import another app's session. A fresh pilot has its own
empty store; use the confirmed clear-data action to establish the P0-01 baseline.

1. Verify the expected initial login/onboarding page.
2. Complete sign-in, including the actual SSO/2FA/passkey requirements.
3. Send a harmless message and verify the reply and navigation away/back.
4. Type a draft, use ⌘W and ⌘0, and check that the draft remains.
5. Choose **Quit Completely**, confirm process exit, and reopen the **identical**
   bundle. Repeat **three times**, recording whether sign-in was needed each time.
6. After a successful login, force quit only the pilot in Activity Monitor and
   relaunch. Do not confuse its WebKit child processes with other apps' processes.
7. Save other work, reboot manually, and reopen the same bundle.
8. Complete the next-day, sign-out/recovery, workflow, and viewport checks.

To confirm the main process has exited:

```sh
pgrep -x YourDotMiniAuthPilot
# No output and exit status 1 means the main process is absent.
open build/YourDotMiniAuthPilot.app
```

Do not force quit or reboot a machine merely to test this app without arranging
it with the person using the machine. A successful unauthenticated cold launch is
not evidence of authenticated session persistence.

## Diagnostics and restrictions

In Console, filter on subsystem `local.YourDotMini.AuthPilot`, or use:

```sh
log stream --style compact --level info \
  --predicate 'subsystem == "local.YourDotMini.AuthPilot"'
```

Wrapper events contain only fixed event names, destination hostnames, allowlisted
error domains/codes, and milliseconds since process start. No page titles, paths,
queries, error descriptions, cookie/token values, messages, or file names are
recorded. WebKit and macOS may separately emit their own system diagnostics;
review exports before sharing. A force kill cannot emit a graceful exit event.

- Exact first-party hosts stay embedded. Ordinary clicked external HTTPS links
  targeting the current window open in the default browser. New-window links are
  covered by the popup restriction below. Other top-level redirects and known provider hosts
  require a host-only confirmation, valid only for the current run. Inspect the
  host and allow it only as part of the sign-in you initiated.
- Unknown SSO links may initially open in a browser. Record this honestly as a
  restriction; browser sign-in does not transfer into the pilot.
- Popups are explicitly blocked to preserve the one-window/one-view pilot. If the
  actual provider requires a popup/opener flow, record that as an authentication
  blocker; no popup is silently rewritten into a same-window OAuth flow.
- A standard file chooser supports user-selected attachments. Upload success
  remains a manual website test. File names/content are not logged.
- Downloads and microphone/camera access are not implemented. The status strip
  explains the limitation; use Open in Browser and repeat the action there.
- No automatic retries, session scraping, script bridges, custom URL handlers,
  TLS exceptions, browser-profile access, launch-at-login, or menu bar UI.
- The pilot is unofficial and does not provide the dot's optional local-computer
  connection. [OpenAI's setup documentation](https://learn.chatgpt.com/docs/dots/getting-started)
  describes that connection separately; it does not establish embedded WebKit support.

## Development checks

```sh
./scripts/test.sh
./scripts/test-focus-window.sh
./scripts/build-pilot.sh release
```

Unit tests cover top-level navigation decisions, host-boundary attacks, scoped
authentication-host approval, unsupported schemes, and diagnostic redaction.
Focus tests use synthetic, network-disabled pages in a nonpersistent WebKit store.
The window-focus check opens a temporary test window, runs the production window
and browser controllers through 50 hide/show cycles, and verifies initial-load
focus, selected-message refocus, draft/view retention, background focus,
app unhide, minimize/restore, and hidden preloading.
It uses its own AppKit event loop; the command-line unit runner does not deliver
window occlusion notifications. Neither suite accesses signed-in page contents.
The same integration check covers pinning/automatic hiding and shortcut conflicts.
It temporarily reserves all-modifier F12/F19 combinations in a test process and
helper, releases them on exit, and dispatches only internal Carbon test events.
`./scripts/test-focus-window.sh --hotkey-only` runs just the shortcut checks.
Login-item tests use a fake backend and do not change macOS Login Items. Browser
recovery tests inject errors without disconnecting the network or killing WebKit.
They cannot validate real account access, provider compatibility, or persistence
across process termination/reboot. Use the pilot matrix for those requirements.

Source layout: `Sources/PilotCore` contains pure navigation/redaction logic;
`Sources/YourDotMiniAuthPilot` contains the native app and WebKit delegates;
`Resources` holds the fixed bundle metadata and sandbox entitlements.
