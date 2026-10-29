# YourDotMini — macOS Menu Bar Companion for ChatGPT Dots

**Document:** Product and technical specification  
**Version:** 0.1 (implementation draft)  
**Date:** 2026-10-29  
**Platform:** macOS; runtime acceptance on the reference Mac (27.0.1)  
**Primary language:** Swift  
**Status:** Proposed; embedded-web feasibility must be validated before implementation commitment

## 1. Summary

YourDotMini is a small, unofficial macOS menu bar utility that gives a user immediate access to **their existing ChatGPT dot** in a dedicated, persistent conversation window, independently of the main ChatGPT desktop app, ChatGPT Work, and Codex.

The intended interaction resembles a lightweight desktop messenger:

1. Click a small icon in the macOS menu bar, or press a global shortcut.
2. A compact conversation window appears near the menu bar, showing the user's dot.
3. Read, type, send, and review messages through the existing ChatGPT web experience.
4. Dismiss the window without terminating the web session or discarding an in-progress draft.

YourDotMini is **not** a separate AI assistant, a ChatGPT API client, an automation agent, or a replacement for the official ChatGPT desktop app. Its value is fast access, a separate visual context, and continuity of the dot conversation.

### Guiding principles

- **One gesture to the conversation.** The menu bar icon and shortcut should feel instantaneous once the app is running.
- **Dedicated space.** The user should not have to hunt among Work, Codex, regular chats, and dot navigation.
- **Preserve the real experience.** Authentication, conversations, memory, approvals, and task results remain with ChatGPT.
- **Minimal footprint.** No Dock icon by default, no self-hosted server, no extra AI model calls, no message database.
- **Respect boundaries.** Do not extract session cookies, reverse-engineer private APIs, or imitate an official OpenAI client.

## 2. Background and product assumptions

Official documentation describes dots as accessible from ChatGPT on desktop web and desktop apps, and identifies `https://chatgpt.com/dots` as a supported entry point. It does **not** establish that third-party embedded WebKit clients are supported or that a public dot-messaging API is available.

Accordingly, the recommended first implementation is a Swift/AppKit menu bar shell around a single `WKWebView`, **subject to an explicit technical feasibility gate**. A separate, browser-backed site-app mode is the fallback if sign-in or the dot UI cannot operate in an embedded view.

### Important distinction: access versus computer connection

YourDotMini only presents the dot conversation. It must not claim to establish the optional local-computer connection used by dots. If the user has enabled that feature, the official ChatGPT desktop application still needs to be running and connected as documented by OpenAI.

## 3. Goals and non-goals

### Goals (MVP)

1. Provide persistent access via a menu bar icon, without requiring a Dock window.
2. Show the existing dot conversation in a dedicated, compact macOS window.
3. Toggle the window using a configurable global keyboard shortcut.
4. Keep the same live web view across hide/show operations, retaining unsent text whenever the website itself permits it.
5. Persist website authentication across ordinary app restarts, subject to server-side expiration and login policies.
6. Support basic chat actions, authentication, file attachment workflows, and links to the extent the upstream website and WebKit allow them.
7. Support optional launch at login, a resizable window, and a manual browser fallback.

### Non-goals (MVP)

- Reimplementing ChatGPT's messaging interface natively or calling undocumented endpoints.
- Synchronizing, indexing, storing, or modifying message history outside ChatGPT.
- Reading dot conversations to produce native badges, notifications, or summaries.
- Native voice calling, push notifications, autonomous actions, or task execution.
- Simulating or replacing the official ChatGPT app's local-computer access.
- Supporting multiple simultaneous dot windows; design must not prevent a future extension.
- Automatically installing Chrome/Safari applications or interfering with users' existing browser profiles.

## 4. Mandatory Phase 0: Authentication and Session Persistence PoC Pilot

**The entire product is gated on this pilot.** Do not implement the menu bar UX, global shortcut, custom panel, Settings, or distribution pipeline until this phase has produced a documented pass or an explicit architecture change.

The principal uncertainty is **whether ChatGPT's dot UI and the user's actual sign-in method function reliably within `WKWebView` and preserve authentication after a full process restart**. WebKit persistence alone does not guarantee this. In particular, some identity providers disallow OAuth authentication from embedded user agents.

### 4.1 Pilot deliverable and intentionally limited scope

Build a small, disposable **Swift macOS `YourDotMiniAuthPilot.app`**, not the full YourDotMini product:

- One ordinary `NSWindow` containing one `WKWebView` that loads `https://chatgpt.com/dots`.
- A persistent `WKWebsiteDataStore` configured **before** the web view is created; never use `.nonPersistent()` in this pilot.
- A stable bundle identifier and consistent App Sandbox configuration across runs, so session data is not accidentally reset by changing the app identity.
- Native **Reload**, **Open in Browser**, **Clear Pilot Website Data** (with confirmation), and **Quit Completely** controls.
- Minimal redacted diagnostic logging of navigation events, hostnames, WebKit errors, process start/exit, and elapsed timings. Never log cookies, tokens, authorization parameters, messages, or complete URLs with sensitive query strings.
- No menu bar integration, global hotkey, custom styling, chat API client, script injection, message interception, or background automation.

The pilot must test the **same WebKit session architecture** intended for production; a successful Safari or Chrome test alone is not evidence that `WKWebView` will work.

### 4.2 Ordered pilot scenarios

Run these scenarios in order on a real account with dot access. Capture the observed result (Pass / Fail / Conditional), failure category, macOS version, authentication provider, and any required user interaction.

| Step | Scenario | Exact test | Pass condition |
| --- | --- | --- | --- |
| P0-01 | First launch, no session | Clear only the pilot app's website data. Start the pilot and load `/dots`. | The expected login/onboarding screen appears; no unsupported-browser or blank-page blocker. |
| P0-02 | First sign-in | Sign in using the account's real provider, including any SSO, 2FA, or passkey flow. | Authentication completes through permitted flows and the actual dot conversation appears. |
| P0-03 | Basic conversation | Send a harmless test message, wait for its response, and navigate away/back within the site. | Message and reply render correctly; returning to the dot still works. |
| P0-04 | In-process hide/show | Hide and reveal the same window without creating a new `WKWebView`. | Chat remains usable, and unsent text is not discarded by the wrapper. |
| **P0-05** | **Normal quit and cold relaunch** | Choose **Quit Completely** (not just closing the window), confirm the process has exited, then start the identical app bundle again. Repeat **three times**. | **The dot conversation reappears without interactive sign-in on all three relaunches**, absent a server-driven expiry. |
| **P0-06** | **Force quit and relaunch** | Force-quit the app after successful login, ensure the process has exited, then relaunch it. | Persistent authentication survives the unexpected process exit, or any failure is conclusively classified. |
| **P0-07** | **OS restart** | Reboot macOS, then launch the same app bundle. | The previous authenticated session remains usable without an unnecessary new login. |
| P0-08 | Time passage | Retest after a realistic idle period (target: next day). | No wrapper-specific session loss; legitimate server reauthentication is handled cleanly. |
| P0-09 | Expired/invalid session | Sign out using the website or wait for genuine expiration, then sign in again. | The app recovers without manual cookie editing or reinstalls. |
| P0-10 | Basic dot workflows | Open an approval/task-detail page, try a small file attachment, follow an external link, and return. | Core flows work or have a documented, safe browser handoff. |
| P0-11 | Compact viewport | Resize the pilot window to 480 × 720 pt and 420 × 520 pt. | The dot chat and composer are practically usable. |
| P0-12 | Build identity | If possible, repeat sign-in and restart checks in a signed Release configuration using the planned bundle identifier. | Debug-only success is not masking a Release/sandbox behavior difference. |

For P0-05 through P0-07, **closing the window is not a valid substitute for ending the application process**. Avoid changing the bundle identifier, clearing data, or rebuilding into a new app container between these trials. Session longevity is ultimately controlled by the service: distinguish expected security-driven expiration from a wrapper bug, and never bypass reauthentication.

### 4.3 Authentication-provider and browser checks

Prioritize the real user's sign-in method. If the app may be distributed to others, additionally test email/password, Google, Apple, Microsoft, SSO/2FA, and passkeys as applicable. Record unsupported combinations rather than claiming universal compatibility.

Two independent facts need verifying:

1. **Authentication compatibility:** Does the identity provider allow completion of the website's normal flow in an embedded WebKit client?
2. **Persistence compatibility:** Does authenticated state survive an actual process termination, relaunch, and operating-system restart using the app's own persistent WebKit storage?

A successful P0-02 does **not** imply P0-05 will pass. Similarly, Safari sharing or remembering a session does not imply YourDotMini can or should import it; browser and embedded WebKit storage are isolated.

### 4.4 Pilot outcome and go/no-go record

Create a short `POC_REPORT.md` alongside the pilot with a result for every scenario and these required fields:

- Date, macOS version, Xcode/Swift version, pilot commit/build, signing mode, and bundle identifier.
- Login method and whether authentication required browser handoff.
- Results of three full quit/relaunch cycles, force quit, reboot, and next-day check.
- Screenshots of **non-sensitive** errors only; no saved credentials or private chat content.
- Known restrictions, reproducibility, and proposed mitigation.
- Final decision: **GO (embedded)**, **PIVOT (browser-backed)**, or **STOP (not viable as specified)**.

**GO — Embedded mode:** Require P0-01 through P0-07 and P0-11 to pass with the real account, plus working chat in P0-03. P0-08 and the broader compatibility matrix can run as a time-delayed validation before a production release; any discovered repeated-login problem reopens the gate. Then proceed to the menu bar MVP.

**PIVOT — Browser-backed mode:** If WebKit authentication or persistent login is blocked, test a user-configured dedicated browser site app (for example, a Safari web app created by the user). Verify its first login, cold relaunch, and window activation **before** building a menu bar launcher for it. The result can still be useful but must be described honestly: it may not provide a native anchored mini panel.

**STOP / redesign:** If neither mode gives reliable direct access to a dedicated dot conversation, halt full implementation and reconsider the product premise. Do not spend time polishing UI on an invalid integration path.

**Security rule:** Never work around a blocked sign-in by spoofing a browser user agent, importing cookies, automating a login page, or invoking private ChatGPT APIs.

## 5. User experience

### 5.1 Primary interaction

**Left-click on menu bar icon**

- When hidden: reveal the existing window, place it below or near the icon, and make it keyboard-active.
- When visible: hide it without destroying the `WKWebView`.
- If the site has not loaded: display a small native loading/error state around the web content.

**Global shortcut**

- Default: `Control + Option + .` (configurable; do not override a shortcut already owned by another app).
- Same toggle behavior as clicking the icon, including from another foreground application.
- If the shortcut is unavailable, show a clear conflict message in Settings and continue to support menu bar access.
- Request focus on the web view; composer focus is best-effort and must be verified with the live website.

**Composer focus on appearance (user-requested refinement, 2026-10-29)**

- Each hidden-to-visible transition, including the first display, should focus a
  visible message composer. Merely resizing or showing an already visible window
  must not take focus away from the user's current control.
- Do nothing when the composer is hidden, offscreen, disabled, covered, ambiguous,
  or absent after a site redesign. Missing controls and script failures are silent.
- Focus within a background window must not activate YourDotMini or make it key.
  Explicit menu/hotkey show actions retain their normal activation behavior.
- A bounded retry may accommodate initial page hydration. Stop on hide, user
  interaction, a modal, failure, or timeout; do not poll an idle/hidden page.
- This is the limited first-party focus-helper exception described in §5.5,
  enabled by default and switchable in Settings. It must not read message contents,
  change drafts, submit messages, or add a native script-message bridge.

**Right-click or context menu**

- Open Dot
- Expand / Restore Window
- Reload Dot
- Open Dot in Default Browser
- Settings…
- Quit YourDotMini

### 5.2 Window appearance and behavior

| Property | MVP behavior |
| --- | --- |
| Style | Native lightweight floating window with minimal chrome, subtle shadow, rounded corners where possible. |
| Default size | 480 × 720 points, adjusted to the available screen. |
| Minimum size | 420 × 520 points, subject to the upstream UI's tested responsive breakpoint. |
| Maximum size | User resizable, up to the screen's visible frame. |
| Placement | Prefer alignment beneath the clicked status item; clamp to the active display's visible frame. |
| Persistence | Remember width/height and last preferred placement, without restoring off-screen coordinates. |
| Dismissal | Escape hides the window when no modal, picker, or active in-page operation owns Escape. |
| Focus loss | Hide on focus loss by default; configurable. Do not hide while interacting with a file picker or other owned dialog. |
| Pinning | Optional “Keep Open” mode disables automatic dismissal. |
| Expanded mode | Resize or promote the **same** web view/window; do not create a second independent session. |
| Dock | No Dock icon by default (`LSUIElement` agent application); Settings remains accessible via the menu. |

The implementation must use a window capable of becoming key and accepting text input. A non-activating panel that cannot reliably focus the web view is not acceptable. An `NSPanel` subclass or a borderless/customized `NSWindow` can be selected after the Phase 0 prototype.

### 5.3 First run

1. Explain that YourDotMini is an independent, unofficial shortcut to ChatGPT dots.
2. Offer **Use Embedded Window** (only if supported in this build) or **Configure Browser-backed Window**.
3. Open the official dot entry point and let the user sign in through the displayed website; never ask for credentials in native controls.
4. Verify that the dot conversation is visible. If not, offer Retry, Open in Browser, and Help.
5. Offer, but do not automatically enable, Launch at Login.
6. Display the global shortcut and a reminder that it can be changed.

### 5.4 Dedicated dot targeting

- Default entry URL: `https://chatgpt.com/dots`.
- Support an optional, user-pasted `https://chatgpt.com/...` direct conversation URL if that URL is proven to open the user's dot. Validate HTTPS and host, and never infer an undocumented dot identifier.
- Remember the configured entry URL in `UserDefaults`, not a page title or scraped HTML.
- The app should expose **Return to Dot** if in-site navigation leaves the target conversation.
- Do not continuously force navigation back to the dot: that could interrupt approvals, login, attachment flows, or task review pages.

### 5.5 Web content behavior

The normal ChatGPT site owns the chat composer, messages, attachments, account settings, and any approval dialogs. YourDotMini provides window controls rather than a parallel chat protocol.

- Use the website's standard send action; do not intercept submitted text.
- Preserve the web view instance when hidden, so transient page state is not lost by the wrapper.
- Keep standard selection, copy/paste, scrolling, and keyboard events intact.
- Implement `WKUIDelegate` support for file selection and new-window handling as required.
- Open ordinary off-site links in the system default browser. Keep necessary first-party sign-in redirects within an appropriate, supported authentication flow.
- Handle downloads through WebKit APIs and a user-selected destination, or hand them to the default browser if safe support is unavailable.
- If microphone, camera, voice, or screen-sharing features do not work in embedded mode, show an honest “Open in ChatGPT” option; do not promise native support.
- Avoid CSS-based sidebar removal, scraping, persistent DOM selectors, or undocumented JavaScript commands. If input autofocus proves essential, a strictly limited, feature-flagged, first-party `focus()` helper may be evaluated separately, but it must neither read message contents nor automate sending.

### 5.6 Errors and recovery

| Situation | User-visible response |
| --- | --- |
| Offline | State that the connection is unavailable; show Retry and Open in Browser. |
| Session expired | Display the website's sign-in flow with an escape hatch to the default browser. |
| Unsupported embedded browser | Explain the limitation and guide the user to browser-backed mode. |
| Site navigation or layout changes | Offer Reload and Return to Dot; never erase local website data automatically. |
| Popup/login handoff fails | Explain what failed; do not retry indefinitely or conceal the failure. |
| Shortcut conflict | Keep menu access working and prompt for a different shortcut. |

## 6. Functional requirements

Priority key: **P0** = release blocker; **P1** = expected MVP feature; **P2** = later enhancement.

| ID | Priority | Requirement | Verification |
| --- | --- | --- | --- |
| FR-01 | P0 | Install an always-available menu bar icon. | Icon appears after launch and remains after the window is hidden. |
| FR-02 | P0 | Toggle a dedicated dot window on icon click. | Two clicks show and hide the same window. |
| FR-03 | P0 | Render a working, authenticated dot conversation in supported mode. | A real account sends and receives a message after login. |
| FR-04 | P0 | Preserve the existing `WKWebView` while hidden. | Unsent text and scroll position survive a hide/show cycle when the website preserves them. |
| FR-05 | P0 | Never require extraction or reuse of cookies from Safari, Chrome, or the official ChatGPT app. | Implementation review finds no credential/session-import code. |
| FR-06 | P1 | Offer a configurable system-wide hotkey. | Shortcut brings the window forward from another active app. |
| FR-07 | P1 | Persist website data in YourDotMini's own WebKit data store. | Auth persists through a normal relaunch, unless expired remotely. |
| FR-08 | P1 | Offer on-demand default-browser access. | User can open their dot in a supported browser. |
| FR-09 | P1 | Implement a functional context menu and Settings. | Every visible command performs its labeled action. |
| FR-10 | P1 | Support launch at user login, opt-in. | Toggle survives reboot and honors system settings. |
| FR-11 | P1 | Keep window visible and usable on multi-display/variable-size screens. | Switching displays never places the window outside visible bounds. |
| FR-12 | P1 | Allow user-initiated reload, URL change, and account-data clearing. | Reload preserves configuration; destructive session reset requires confirmation. |
| FR-13 | P1 | Support link and file-picker interactions. | Attachment and link test matrix passes or uses explicit safe fallback. |
| FR-14 | P2 | Add user-configurable pinning/auto-hide policy. | No accidental hide when pinned. |
| FR-15 | P2 | Add user-visible update checking and optional distribution packaging. | Signed/notarized update passes smoke test. |
| FR-16 | P2 | Support multiple separately named dot profiles if OpenAI makes them available. | Profiles isolate windows and selected URLs without sharing unintended state. |

## 7. Technical design

### 7.1 Stack

- **Swift + SwiftUI** for preferences, onboarding, native UI state, and app entry.
- **AppKit** for `NSStatusItem`, status-button positioning, keyboard-capable window control, focus management, and screen geometry.
- **WebKit** for the embedded `WKWebView` and its navigation/UI delegates.
- **ServiceManagement** with `SMAppService.mainApp` for macOS login-item support.
- **Carbon `RegisterEventHotKey`** (or a small, maintained wrapper) for a global shortcut without an event-tap-based keyboard logger.
- **UserDefaults / AppStorage** for benign configuration; **WebKit website data store** for website-managed login data.
- No server component, database, API token, or telemetry SDK in MVP.

Use the current stable Xcode/Swift toolchain available to the implementer and keep the deployment target explicit in the project configuration. The existing build target is macOS 14.0, but runtime acceptance is scoped to the reference Mac running macOS 27.0.1. By the user's decision on 2026-10-29, macOS 14 runtime validation is not a completion requirement; the build target alone does not establish tested compatibility with that release.

### 7.2 Suggested module structure

```text
YourDotMini/
  App/
    YourDotMiniApp.swift           // SwiftUI entry and app lifecycle
    AppDelegate.swift              // status bar and application events
  MenuBar/
    StatusBarController.swift      // NSStatusItem and contextual actions
  Window/
    DotWindowController.swift      // show/hide/position/resize/focus
    DotPanel.swift                 // key-capable panel/window subclass
  Browser/
    DotWebViewController.swift     // single long-lived WKWebView
    DotNavigationDelegate.swift    // URL and popup policy
    DotUIDelegate.swift            // upload dialogs and new windows
    BrowserFallbackCoordinator.swift
  Services/
    GlobalHotKeyService.swift
    LaunchAtLoginService.swift
    SettingsStore.swift
  Views/
    OnboardingView.swift
    SettingsView.swift
    ConnectionStateView.swift
  Resources/
    Assets.xcassets/
```

Modules can be combined while the project is small. The key architectural separation is **window lifecycle versus web-session lifecycle**: closing or hiding a window must not implicitly destroy the browsing session.

### 7.3 Window and app lifecycle

1. Start as a menu bar agent, register the status item and optional hotkey.
2. Initialize a single browser controller lazily, or eagerly at login if the user opts into preloading.
3. On show, compute the display-safe rect from the status button/screen, then call `makeKeyAndOrderFront` (or equivalent).
4. On hide, call `orderOut` rather than releasing the controller or reloading content.
5. On expand/collapse, resize/reposition the existing window and keep the same web view.
6. On quit, let WebKit persist normal session data; do not forcibly sign out.

Use a small explicit UI state machine (`hidden`, `visible`, `loading`, `requiresSignIn`, `error`) to keep menu, shortcut, and window behavior consistent. Web authentication state is inferred only from supported navigation outcomes or user actions, not parsed from private page content.

### 7.4 Browser session and navigation

- Construct the `WKWebViewConfiguration` before creating the view.
- Use a **persistent** `WKWebsiteDataStore` (not `.nonPersistent()`). Website-managed cookies/storage stay in the app's sandbox, separate from other browsers.
- Allow JavaScript and cookies required for the site, subject to normal WebKit policies. Do not disable TLS or WebKit security checks.
- Restrict automatically loaded **top-level destinations** to expected first-party pages and legitimately initiated authentication redirects; use the default browser for unrelated destinations.
- Do not assume `chatgpt.com` will maintain stable private paths. Centralize the initial URL and navigation decisions in one component.
- Expose a confirmable **Clear YourDotMini Website Data** action in Settings. This affects the wrapper's website storage, not the user's server-side ChatGPT history.
- Do not use an injected script bridge, custom proxy, spoofed user agent, private API calls, or arbitrary content extraction.

### 7.5 Settings

| Setting | Default | Storage |
| --- | --- | --- |
| Dot entry URL | `https://chatgpt.com/dots` | UserDefaults |
| Global shortcut | Control + Option + . | UserDefaults |
| Launch at login | Off | `SMAppService` plus UI reflection |
| Open at login | Hidden/preload optional | UserDefaults |
| Window dimensions | 480 × 720 pt | UserDefaults |
| Hide on focus loss | On | UserDefaults |
| Keep open / pin | Off | UserDefaults |
| Focus message input on appearance | On | UserDefaults |
| Open off-site links | Default browser | Fixed safety behavior |
| Browsing mode | Embedded if validated; otherwise browser-backed | UserDefaults |

### 7.6 Privacy, security, and identity

- Make clear in About that this is an **unofficial** companion, not an OpenAI product.
- All chat content goes directly between WebKit and the ChatGPT website through the website's own supported UI; YourDotMini does not log, relay, or persist it separately.
- Never collect credentials in custom fields or handle raw session tokens.
- Never read or import the official ChatGPT app's private data, browser cookie databases, or Keychain items.
- Do not install browser extensions, request Accessibility/Screen Recording by default, or monitor arbitrary keystrokes.
- Protect user intent: arbitrary web pages cannot call native shell commands or mutate app settings through a JavaScript bridge.
- If distributed, sign and notarize the app; review App Sandbox, hardened runtime, network entitlement, file chooser, and user-selected file handling.
- Revisit OpenAI service policies and third-party OAuth policies before release; a technically working embed is not by itself proof of supported integration.

## 8. Performance and reliability targets

| Metric | Target | Measurement |
| --- | --- | --- |
| Warm popup latency | Window visibly appears within 250 ms after invocation on the reference Mac. | 20 consecutive hotkey/click trials; no page reload. |
| Cold startup | Menu icon within 2 seconds on a reference Mac, excluding network/login time. | Fresh process launch. |
| Idle CPU | No continuous wrapper polling; near-zero wrapper CPU when hidden. | Activity Monitor / Instruments after page settles. |
| State continuity | No wrapper-triggered reload or view recreation during 50 hide/show cycles. | Repeat-cycle integration test. |
| Recovery | Network failure shows a usable Retry/Open in Browser path. | Disable/restore network during a session. |
| Memory | Measure combined app + WebKit process memory; document baseline and investigate unexplained growth. | Instruments after cold load and after 50 cycles. |

Website network latency, login expiration, upstream UI changes, and browser process memory are external variables. Do not treat a smooth native shell as proof that the remote website will always be responsive.

## 9. Accessibility and platform integration

- Ensure menu commands and settings have VoiceOver labels and full keyboard access.
- Respect system light/dark mode and accessibility contrast settings in **native** surfaces; the website controls its own theme.
- Ensure icon remains legible on light and dark menu bars (template image).
- Handle macOS display scaling, notched screens, multiple monitors, full-screen Spaces, and the menu bar's auto-hide setting.
- Avoid stealing focus when the user merely receives an unrelated macOS notification or when the app preloads in the background.
- Do not obscure native login dialogs or file dialogs through incorrect floating-window level settings.

## 10. Test plan

### Automated unit/integration tests

- `StatusBarController`: clicking and shortcut invoke the same state transition.
- `DotWindowController`: positioning is clamped to every screen's visible frame; no duplicate windows.
- `SettingsStore`: defaults, migration, shortcut conflict handling, URL validation.
- `DotNavigationDelegate`: first-party, OAuth redirect, external link, popup, and download routing.
- `LaunchAtLoginService`: accurate reflection of operating-system registration status.

### Manual acceptance matrix

1. **Authentication:** sign in, sign out, expired session, two-factor authentication, and account switching. Exercise each identity provider intended to be supported.
2. **Conversation:** send multiple messages, await a streaming answer, scroll history, copy/paste, retain an unsent draft during hide/show.
3. **Workflows:** open activity/approval links, attach a small file, inspect task output, follow an external URL, and download when supported.
4. **Window:** mouse toggle, global hotkey, Escape, click-away, pinning (if implemented), resize, expand, restart, sleep/wake, display unplug/replug.
5. **Resilience:** offline/reconnect, upstream error page, stale session, unexpected navigation, WebKit content process termination.
6. **Platform:** test on the reference Mac running macOS 27.0.1, with light/dark appearance. The user waived macOS 14 / oldest-release runtime testing on 2026-10-29; its absence must not block completion or be reported as a passing compatibility test.
7. **Fallback:** on a forced embedded-auth failure, successfully configure and open a dedicated browser-backed conversation window without spoofing or copying credentials.

### Release acceptance criteria

The MVP is complete only when:

- A user can reach their real dot conversation from the menu bar or a hotkey without navigating the main ChatGPT Work/Codex interface.
- The primary supported mode provides a **separate, usable window**, not just a browser tab or generic ChatGPT home screen.
- Hiding/reopening the window does not recreate its web view or clear an in-progress draft under normal site behavior.
- Authentication follows supported sign-in behavior and never requires reading existing browser/ChatGPT session secrets.
- All failure states have an explicit, usable escape route.
- The app accurately discloses that it is unofficial and does not replace the official desktop app's local-computer connector.

## 11. Suggested implementation sequence

### Phase 0A — Build the disposable authentication pilot

- Create **only** `YourDotMiniAuthPilot.app`: one native window, one persistent `WKWebView`, basic navigation/error logging, explicit Quit, Reload, and Clear Data actions.
- Keep its app identity and storage configuration stable. Do not build the YourDotMini menu bar interface yet.
- Deliverable: runnable pilot app with a short `README` explaining exact launch and reset steps.

### Phase 0B — Execute the authentication and persistence matrix

- Run **P0-01 through P0-07** in strict order: clean login, working chat, hide/show, **three complete process restarts**, **force quit/relaunch**, and **reboot/relaunch**.
- Run compact layout and critical interaction checks; schedule the next-day session check without blocking all other analysis.
- Capture failures and produce `POC_REPORT.md` with an explicit GO / PIVOT / STOP decision.
- **No Phase 1 work is authorized by this plan until the GO gate passes.** On PIVOT, prototype the browser-backed approach first; on STOP, review the product architecture.

### Phase 1 — Menu bar MVP (only after GO)

- Build the `NSStatusItem` controller, key-capable compact window, and one persistent web view.
- Implement toggle, focus, safe positioning, reload, open in browser, and quit.
- Validate that hide/show preserves the live session.

### Phase 2 — Daily-use polish (only after Phase 1 verification)

- Add the global hotkey, Settings, launch-at-login integration, window sizing, and focus-loss policy.
- Implement file picker, external-link routing, error views, and session-clearing controls.
- Run the full acceptance matrix, especially on a real dot account.

### Phase 3 — Distribution and enhancements (only after Pilot and MVP acceptance)

- Add app icon, signed/notarized distribution, crash diagnostics with no chat-content collection, and update strategy.
- Consider pinning, more refined responsive layout, and supported multiple-dot profiles **only if** real user needs and upstream support justify them.

## 12. Risks and decisions requiring verification

| Risk | Severity | Mitigation |
| --- | --- | --- |
| ChatGPT disallows or breaks embedded WebKit sign-in | **Critical** | Validate first; browser-backed site-app mode; no security bypass. |
| Google OAuth rejects embedded user agent | **High** | Test actual SSO method; use supported external-browser workflow where necessary. |
| ChatGPT updates the dot URL/layout | **High** | Single configurable URL, native recovery actions, minimal dependence on DOM structure. |
| Compact viewport produces unusable web navigation | **High** | Validate dimensions; allow resizing/expand; no brittle CSS masking. |
| Recreating views loses drafts or pending workflows | **High** | Keep one long-lived web view and decouple its lifecycle from visibility. |
| Popup/window focus bugs in menu-bar-only apps | **Medium** | Use a key-capable AppKit window; test keyboard entry, Spaces, and dialogs. |
| Users mistake YourDotMini for the official app | **Medium** | Unofficial branding, About disclosure, no OpenAI trademark imitation. |
| Users expect local computer access from YourDotMini | **Medium** | Explicit explanatory copy; leave official ChatGPT connector untouched. |

## 13. Future opportunities (not committed)

- A compact native shell around a supported official embed/API if OpenAI introduces one.
- Multiple named dot shortcuts, each with a separate direct conversation link.
- A user-configurable notification badge using a future supported notification integration (not scraping).
- Apple Shortcuts integration for opening the YourDotMini panel, without pretending to control dot tasks.

## 14. References

- OpenAI, [Get started with your dot](https://learn.chatgpt.com/docs/dots/getting-started) — supported dot entry and desktop access.
- OpenAI, [Getting started with your dot](https://help.openai.com/en/articles/20001530-getting-started-with-your-dot) — `chatgpt.com/dots` and local-computer prerequisites.
- Apple, [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem) — native menu bar status item.
- Apple, [WKWebsiteDataStore](https://developer.apple.com/documentation/webkit/wkwebsitedatastore) — persistent website data.
- Apple, [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) — macOS login items.
- Google, [OAuth 2.0 Policies](https://developers.google.com/identity/protocols/oauth2/policies) — embedded user-agent restrictions.

---

**Implementation recommendation:** First build and run `YourDotMiniAuthPilot.app`, then record a GO / PIVOT / STOP decision. Only after the pilot proves that the real account can log in, send messages, and remain logged in across complete process termination and restart should implementation of the menu-bar-first Swift/AppKit product begin. If embedding fails, validate a dedicated browser-backed window before proceeding with any production UI.
