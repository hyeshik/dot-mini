# YourDotMini

The authentication pilot passed the mandatory checks for the tested account and
pilot bundle; see [POC_REPORT.md](POC_REPORT.md). Final-product acceptance remains
pending, including authenticated product relaunch, session longevity, and recovery.
The menu bar app is being implemented according to [SPEC.md](SPEC.md), with current
verification and remaining work in [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md).

## Menu bar app

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
its website. Sessions can expire or require reauthentication. It does not copy
the pilot's or any browser's cookies.

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

## Product limitations and privacy

- **Embedded sign-in:** pilot success applies to the tested account and bundle.
  Other providers, account switching, genuine session expiration, and final-product
  persistence still need validation. Google's [OAuth policy](https://developers.google.com/identity/protocols/oauth2/policies#use-secure-browsers)
  prohibits directing authorization requests to developer-controlled embedded
  user agents. A successful sign-in trial does not establish provider support.
  Use browser mode when embedded authentication is unsupported; do not bypass
  provider restrictions or import session cookies.
- **Browser fallback:** the default browser and a selected dedicated browser web
  app use their own sign-in. Continue the workflow there; signing in there does
  not sign the embedded view in. Fixture tests verify app launching and bookmark
  restoration, while actual browser-app login, relaunch, and dot targeting remain
  unverified. Embedded popups are blocked; clicked external HTTPS links, including
  new-window links, can open in the default browser.
- **Authentication-host approval:** unknown top-level redirects require a manual
  choice. Approval permits that exact hostname for the current process; the app
  does not verify that it belongs to a legitimate sign-in flow and does not keep
  an origin indicator visible after loading. Cancel unfamiliar requests and
  continue in your browser if you cannot verify the destination.
- **Attachments and media:** file selection grants read access to files you
  choose. Actual uploads and task/approval-detail workflows still need live
  validation. Downloads, microphone, and camera features require continuing in
  the browser.
- **Saved destination URLs:** validation currently preserves query strings and
  fragments. The complete URL is stored in plaintext preferences (`UserDefaults`)
  and passed to the default browser when you choose Open Dot in Default Browser.
  Until validation rejects sensitive parameters, save only a clean dot or
  conversation URL without authentication codes, tokens, or other secrets.
  Clear Website Data removes WebKit data but leaves this saved preference intact;
  replace a sensitive saved URL in Settings with a clean destination.
- **Session storage and diagnostics:** hiding or quitting preserves website
  authentication data for future use. Wrapper logs omit URL paths, queries,
  fragments, credentials, and message contents, but include hostnames. WebKit and
  macOS can emit separate diagnostics; review log exports before sharing them.

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

## Build requirements and distribution

Both apps target macOS 14.0 and require Apple Swift 6.0+ (Xcode or Command Line
Tools). Runtime acceptance uses the reference Mac running macOS 27.0.1. Testing
on macOS 14 was waived by the user and is not a completion requirement; compatibility
with that release has not been verified. There are no third-party dependencies.

Both build scripts produce local development bundles, ad-hoc signed by default,
with signing timestamps disabled. Add `--notarize` to an explicit `release` build
to use Developer ID signing, a secure timestamp, and Apple's notarization service.
This option always creates a fresh `build/staged.*` directory, preserving the
installed app and the retained persistence-trial pilot. `--stage` is also available
for local builds of either app.

### Notarized Release builds

Install a valid **Developer ID Application** certificate and its private key in
your Keychain, and choose its full name or SHA-1 fingerprint from:

```sh
security find-identity -v -p codesigning
```

Store notarization credentials once using Apple's interactive prompts:

```sh
xcrun notarytool store-credentials "YourDotMini-notary"
```

The profile holds the credentials in the Keychain. Keep passwords and API private
keys out of the repository and command-line arguments. Builds use only the
profile name through `NOTARY_KEYCHAIN_PROFILE`; an Apple Development certificate
or ad-hoc signature is not accepted for notarization.

Build and notarize the menu bar app, replacing the example certificate name with
your actual identity (or its SHA-1 fingerprint):

```sh
DOT_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_KEYCHAIN_PROFILE='YourDotMini-notary' \
./scripts/build-app.sh release --notarize
```

To also build a notarized DMG with an Applications shortcut, add `--dmg`:

```sh
DOT_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_KEYCHAIN_PROFILE='YourDotMini-notary' \
./scripts/build-app.sh release --notarize --dmg
```

The app is notarized and stapled first, then copied into a compressed disk image.
The image is separately signed, submitted, stapled, and checked by Gatekeeper.
The final `YourDotMini.dmg` and `YourDotMini.dmg.sha256` appear beside the app only
after these checks pass. Its receipt and rejection diagnostics are kept in
`notarization/dmg/`. This option is available on the product builder and requires
`--notarize`.

For a separate notarized pilot build:

```sh
PILOT_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_KEYCHAIN_PROFILE='YourDotMini-notary' \
./scripts/build-pilot.sh release --notarize
```

The workflow verifies the signing identity before building, signs with hardened
runtime and the existing sandbox entitlements, and submits a ZIP with
`notarytool --wait`. This uploads the built app to Apple and waits for processing.
Only an `Accepted` result permits ticket stapling, ticket validation, strict
signature verification, and Gatekeeper assessment. After all checks pass, it
creates a final ZIP containing the stapled app and a SHA-256 checksum file.

For the product, the outputs are `build/staged.*/YourDotMini.app`,
`YourDotMini.zip`, and `YourDotMini.zip.sha256` in that same staging directory.
The pilot uses `YourDotMiniAuthPilot` in these names. The `notarization/`
subdirectory retains the unstapled upload ZIP and `submission.plist` receipt;
use the final ZIP beside the app for distribution. Failed submissions attempt to
save Apple's diagnostic log as `notarization/log.json` and exit without a final
distribution ZIP. If submission is interrupted, inspect `notarytool history`
with the same Keychain profile before submitting again.

Selecting a signing identity without `--notarize` still produces a local build.
Notarization does not establish runtime or authentication compatibility; the
remaining product acceptance checks still apply. See [Apple's notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Authentication pilot

The following subsections describe the independently retained
`YourDotMiniAuthPilot.app`. Its controls and restrictions are separate from the
menu bar product described above.

### Build and launch

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
The build script refuses to replace a running pilot. Use `--stage` to prepare a
separate bundle. Launch through `open` or Finder, not `swift run`; the bare
executable rejects a missing bundle identity.

- Bundle identifier: `local.YourDotMini.AuthPilot`
- Deployment target: macOS 14.0
- Website store: `WKWebsiteDataStore.default()`, configured before creating the view
- Sandbox: enabled; outbound network and read-only user-selected files
- Signing: ad-hoc by default; optional `PILOT_SIGNING_IDENTITY` for a local signing identity
- App storage: managed by macOS/WebKit under this app's own sandbox identity

For a separate local Release trial, first finish and record the current trial,
then use `./scripts/build-pilot.sh release`. This uses the same bundle path,
identifier, and entitlements. A notarized trial uses `release --notarize` as
described above and needs its own persistence validation under that signing
identity. The menu bar product's separate identity also requires its own
persistence validation; pilot success cannot establish persistence for that app.

### Pilot controls

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

### Execute the gate

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

### Pilot diagnostics and restrictions

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
- The pilot has no automatic retries, session scraping, script bridges, custom
  URL handlers, TLS exceptions, browser-profile access, launch-at-login, or menu
  bar UI. The menu bar product includes optional launch-at-login controls and
  the narrowly scoped composer-focus helper described above.
- The pilot is unofficial and does not provide the dot's optional local-computer
  connection. [OpenAI's setup documentation](https://learn.chatgpt.com/docs/dots/getting-started)
  describes that connection separately; it does not establish embedded WebKit support.

## Development checks

```sh
./scripts/test.sh
./scripts/test-focus-window.sh
./scripts/build-pilot.sh release
python3 Tests/BuildScripts/test_notarization.py -v
```

The build-script tests run in temporary fixtures with mocked compiler, signing,
and Apple-service commands. They check both builders, preserved installed bundles,
local-build defaults, identity and profile requirements, rejection/error handling,
stapling and verification failures, final archives containing a ticket, and the
DMG packaging and failure paths. ZIP, plist, and checksum checks use the real macOS
tools; disk-image creation is mocked in the fixture tests. These tests require Python 3
and do not upload an app or access real signing/notarization credentials; an actual
Apple submission is a separate end-to-end check. Live product app/DMG notarization
and mounted-image verification results are recorded in
[IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md).

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
The Escape check sends native key events directly to the synthetic test window;
web-handled Escape and attached sheets keep it visible, while unhandled Escape
hides it. Use `./scripts/test-focus-window.sh --escape-only` to run that check alone.
Login-item tests use a fake backend and do not change macOS Login Items. Browser
recovery tests inject errors without disconnecting the network or killing WebKit.
Browser-app fallback tests use temporary fixture bundles and an injected launcher
to verify asynchronous failure reporting, bookmark resolution, and invalid-app
rejection. They do not launch a browser or prove sandbox permission persistence.
They cannot validate real account access, provider compatibility, or persistence
across process termination/reboot. Use the pilot matrix for those requirements.

For a separate, real App Sandbox check of the browser-app selector and launcher:

```sh
./scripts/build-sandbox-checks.sh
```

The command prints two fresh app paths. Open `YourDotMiniSandboxChecks.app`, use
Choose Fixture App to select the printed `YourDotMiniFallbackFixture.app`, and
select Open Saved Fixture. Quit both test apps completely, reopen the identical
test app, and select Open Saved Fixture again without reselecting a file.
The fixture should launch after both trials. Both apps use separate test bundle
identifiers and the product's sandbox entitlements. They contain no website or
account data and do not access any browser profile. This validates saved app
selection and sandbox access; an actual browser web app still needs its own
login, relaunch, and dot-destination acceptance check.

Source layout: `Sources/PilotCore` contains shared navigation/redaction logic;
`Sources/YourDotMiniAuthPilot` contains the pilot app and WebKit delegates;
`Sources/YourDotMiniCore` and `Sources/YourDotMiniUI` contain the menu bar product's
preferences, native UI, and browser controllers. `Resources` holds bundle metadata
and sandbox entitlements for both apps.
