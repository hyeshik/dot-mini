# Implementation status

Updated 2026-10-29 (Asia/Seoul). This is an acceptance record, not a declaration
that the full specification is complete.

## Phase 0 — GO (embedded)

See [POC_REPORT.md](POC_REPORT.md) for the ordered authentication, process restart,
force-quit, and OS reboot evidence. The user confirmed successful chat and both
compact viewports. The validated pilot app remains unchanged for next-day testing.
The pilot source now also defaults to the requested Command-1 size when rebuilt.

## Phase 1 — menu bar MVP

Implemented in the separate `YourDotMini` target:

- Accessory app (`LSUIElement`) with template menu bar icon and context menu.
- Custom vector dot icon with exactly three transparent circular holes in a
  centered, downward-pointing equilateral triangle (user-requested button face).
  Rendered at 1×, 2×, and enlarged for visual inspection.
- One long-lived persistent WebKit view; hiding/expanding does not reconstruct it.
- Key-capable floating native window; close hides, explicit Quit terminates.
- Initial 480 × 720 web viewport, matching the pilot's Command-1 preset.
- Status-item anchoring and visible-screen clamping, including negative coordinates.
- Expand/restore, reload, return-to-dot, browser fallback, and native Edit commands.
- Native loading/error status, authentication host consent, file chooser, and
  explicit popup/download/media fallback.
- Sandbox, stable product identifier `local.YourDotMini`, no cookie import or
  native script-message bridge. Product storage is separate from
  `local.YourDotMini.AuthPilot`. A later user-requested, narrowly scoped composer
  focus helper is documented below; the authentication pilot remains unchanged.

Verified: debug build with Swift warnings treated as errors; ad-hoc code signature;
15 tests in 3 suites covering navigation, redaction, and window geometry. The app
launched at the requested compact size and rendered the normal sign-in flow.

Verified live: the user completed manual sign-in under the separate product
identity, and the dot route and composer were observed. The user confirmed both
left-click toggle and right-click context menu. An unsent test draft survived ten
native hide/show cycles and expand/restore, and was then removed without sending.
Phase 1 verification permits Phase 2 work to begin. This is not full release
acceptance or a substitute for the remaining longevity/platform tests.

## Phase 2 — implementation in progress

Settings, shortcut registration, login-item controls, saved window preferences,
focus-loss/pinning behavior, and a browser-app selector are implemented and now
included in the local development build. End-to-end acceptance remains pending.
The initial Phase 2 build started and rendered Settings correctly. Launch at
Login was left off; at that run ServiceManagement reported that the development
app was not found. Real opt-in registration/reboot acceptance remains pending.

Current verification: 46 tests in 8 suites pass, including preference migration,
disabled-shortcut persistence, URL validation, composer focus, login-item state,
browser-error recovery, and browser-app fallback. The app builds with Swift
warnings treated as errors and passes strict ad-hoc signature verification.
The CLT SDK's missing SwiftUI State macro plugin is avoided by selecting the
existing macOS 14-compatible property wrapper through a type alias.

Menu-bar toggle regression (2026-10-29): user clicks on an already visible dot
caused focus-loss dismissal before the status button's mouse-up toggle, producing
hide/show pairs roughly 12–35 ms apart in redacted logs. Focus-loss handling now
defers to a status-item press or context menu, and queued dismissal is invalidated
when presentation changes. Repeated hiding is idempotent. The updated bundle
builds and passes the same 22 tests; actual status-item mouse-click confirmation
is pending from the user because native automation could not safely inspect the
signed-in app. App startup is verified through redacted process events.

Shortcut punctuation update: added `, . / ; ' [ ] \ - =` to the shared key list
used by Settings, validation, and labels. All ten choices pass a preference
save/load check, and the existing 22 tests pass. A signed development build is
staged at `build/shortcut-update/YourDotMini.app` and installed at
`build/YourDotMini.app` after the user confirmed quitting it. Process exit was
verified before replacement; the installed executable matches the staged build
and its strict code-signature verification passes.

App icon (explicit user request during Phase 2): created an editable Icon Composer
document with the menu bar mark's exact three-hole proportions, a teal foreground,
and a pale background. Native macOS 27 rendering was checked in default, dark,
clear, and tinted appearances, plus at 32 px. Xcode's asset compiler generates
the layered `Assets.car` and a compatibility `.icns`; the build script integrates
both, with a checked-in `.icns` fallback for Command Line Tools-only environments.
Installed as build 3 after confirming process exit. The complete app build,
bundle icon declarations, asset compilation, and strict ad-hoc signature checks
pass. The installed bundle's icon was also resolved through macOS IconServices
and visually inspected, along with its compatibility `.icns`. This icon work
does not imply distribution or full MVP acceptance.

Conversation footer update: removed the idle unofficial-companion text and
collapsed its reserved space. Loading, navigation errors, and browser-handoff
messages still show a temporary status area. Default/preset sizes now describe
the full idle web viewport, and resizing while a status is visible saves that
idle size. Build 4 compiles with Swift warnings treated as errors and passes
strict signature verification. It is staged at `build/footer-update/YourDotMini.app`.
The user chose to apply it later. It is also included in the deferred build 5.

Composer focus on appearance (user request, 2026-10-29): implemented a default-on
Settings switch and a first-party focus helper in an isolated WebKit content world.
Hidden-to-visible transitions (including initial presentation, occlusion changes,
app unhide, and window restoration) request focus only for a visible, editable,
uncovered, unambiguous composer. Already-visible show/resize does not request it.
Missing/changed markup, disabled/hidden inputs, modals, and JavaScript errors are
silent no-ops. The helper reads no message contents, does not modify drafts, does
not send, and does not activate the application or make a window key.

The initial navigation can complete before focusing, with at most 20 attempts
100 ms apart for delayed composer mounting. Hide, keyboard/mouse/scroll input
within the app, owned dialogs, errors, and the Settings switch cancel the request.
There is no idle polling. Background preloading does not start a focus request.

Verified with `scripts/test.sh`: **31 tests in 5 suites pass**, including real
WebKit synthetic fixtures for visible textarea/contenteditable composers, hidden,
offscreen, disabled, ambiguous and covered controls, changed layout, deferred
mounting, cancellation, bounded retries, first-party URL boundaries, and preference
migration/persistence. Tests use nonpersistent stores and network-disabled HTML.

Verified separately with `scripts/test-focus-window.sh`: the production window
and browser controllers pass **initial-load focus and 50 hide/show cycles** under
a real AppKit event loop. Selecting a synthetic message before each hide returns
focus to its composer. The same window/view and draft survive without a reload.
Passive appearances preserve the foreground app, do not make the test window key,
and repeated show while already visible preserves the current input target.
App unhide, minimize/restore, and hidden preload also pass. A 100 ms one-shot
occlusion check ignores transient WindowServer visibility changes during window
reordering; explicit hide/minimize cancels immediately. This avoids a spurious
second focus request when a visible window is ordered forward again.
This is native integration evidence, not a claim about real ChatGPT markup,
authenticated longevity, or the performance acceptance targets.

The full window check passed twice consecutively after the occlusion correction.
Build **5** compiles with warnings treated as errors and passes strict ad-hoc
signature verification. It is staged at `build/staged.EzFnAX/YourDotMini.app`.
`scripts/build-app.sh debug --stage` now creates a fresh output directory without
replacing the installed bundle. The installed bundle remains build **3**, as the
user requested applying updates later. After installation, live confirmation of
composer focus with the actual site remains pending; no private chat content was
inspected to run these checks.

Default shortcut update (user request, 2026-10-29): changed the default from
Control + Option + D to **Control + Option + period (⌃⌥.)**. Fresh settings and
older preference files with no shortcut key receive the new default. Saved
shortcuts and an explicitly disabled shortcut remain unchanged. The 7 preference
tests pass; the app builds with warnings treated as errors and passes strict
ad-hoc signature verification. Build **6**, including the deferred footer and
composer-focus changes, is staged at `build/staged.om4DRn/YourDotMini.app` and
supersedes the staged build 5. Installation remains deferred at the user's request.

Daily-use correctness and acceptance expansion (2026-10-29):

- Shortcut registration now rejects enabled macOS symbolic shortcuts and probes
  for another process's exclusive reservation before replacing the active key.
  A failed replacement retains the previous registration. Queued events arriving
  after disabling the shortcut no longer invoke its action.
- The final registration remains nonexclusive. On this macOS 27 host, an exclusive
  registration could preempt another process's nonexclusive subscription instead
  of failing. The public APIs do not provide a universal inventory of shared or
  app-local shortcuts. Detection of those combinations remains a limitation;
  Settings advises choosing another combination if another app also responds.
  The implementation adds no event tap or arbitrary keyboard monitoring.
- A visible but inactive Settings window no longer suppresses automatic hiding
  when switching to another app. Losing app activation also checks dismissal,
  covering the path from the dot to Settings and then to another application.
  Pinning, owned-dialog guards, status-item interaction, and stale-dismissal
  cancellation remain in place.
- Login-item updates refresh the actual OS status before deciding whether to
  register/unregister. Already-requested enable operations are idempotent, and
  overlapping changes stay suppressed until an asynchronous update completes.
  Seven tests use an injected backend for enabled, approval-required, off, missing,
  stale, failed, and in-flight states. No real login-item setting was changed.
- Embedded reload/viewport commands in the application menu are disabled in
  browser-app mode, matching the status menu. Settings now links to the official
  dot setup/troubleshooting article; its destination was checked successfully.
- Four browser delegate tests inject offline, cancelled, generic navigation, and
  web-process failures into a nonpersistent recording web view. They verify
  recovery messages, error-detail redaction, retained wrapper identity, no
  automatic retry, and explicit Reload. These are not real network-disconnection
  or authenticated web-process recovery trials.

`scripts/test-focus-window.sh` now additionally verifies pinning/focus-loss policy,
system-shortcut rejection, a genuine cross-process exclusive-key conflict,
preservation of the previous key, disabled-event suppression, and cleanup. The
helper process temporarily reserves an all-modifier function-key combination;
it generates no physical keyboard input. The window tests and all **42 tests in
7 suites** pass. Focus checks ensure the test app remains inactive; switching
between other apps during a run is not misclassified as focus stealing.

Escape and browser-app recovery checks (2026-10-29):

- Native Escape events delivered directly to the synthetic WebKit window confirm
  that a page handler calling `preventDefault()` keeps the window visible. An
  attached native sheet also prevents wrapper dismissal. Unhandled Escape hides
  the window. This verifies native routing, not the live website's modal behavior.
- A browser-app launch can fail after `NSWorkspace` initially accepts the request.
  Such asynchronous failures now reopen Settings from the menu/shortcut path,
  making the recovery message visible. Both success and failure completions are
  covered with an injected launcher, without starting another application.
- Selected app bookmarks now explicitly request read-only access, matching the
  file-selection entitlement. Resolution suppresses UI and volume mounting and
  rechecks the bundle and executable before launch, rejecting YourDotMini itself
  and unavailable apps. Four tests cover these paths using temporary fixtures.
  Sandbox access across relaunch and a real dedicated browser app remain untested.

All **46 tests in 8 suites** and the full native integration check pass.
Latest deferred bundle: **build 8**, `build/staged.bc4JYo/YourDotMini.app`, with
warnings-as-errors build and strict ad-hoc signature verification. It contains
all prior footer, autofocus, and default-shortcut changes and supersedes build 7.
The installed bundle remains build 3. Nothing was installed, restarted, registered
for login, notarized, or published during these checks.

## Remaining scope

- Phase 2 live acceptance of implemented features: configurable global shortcut
  with conflict handling; Settings;
  opt-in launch at login; persisted dimensions/placement; focus-loss policy and
  pinning; safe Escape dismissal; first-run explanation and browser-app fallback.
- Acceptance: authenticated 50 hide/show cycles, hotkey/menu equivalence, idle/latency/memory
  measurements, offline recovery, attachment/link/task workflows, sleep/wake and
  display changes, oldest/current macOS, and next-day session retention.
- Phase 3: only after MVP acceptance, Developer ID signing/notarization,
  distribution/update strategy and smoke checks. Signing credentials and a release
  destination have not been supplied. Optional multi-profile support is not
  committed by SPEC and remains conditional on upstream support.

The implementation is not release-ready. No launch-at-login registration,
external publication, or distribution signing has been performed.
