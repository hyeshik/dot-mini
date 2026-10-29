# Implementation status

Updated 2026-10-30 (Asia/Seoul). This is an acceptance record, not a declaration
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
  Real sandbox access across relaunch was subsequently checked below; a dedicated
  browser app with a real dot session remains untested.

All **46 tests in 8 suites** and the full native integration check pass.
Latest deferred bundle: **build 8**, `build/staged.bc4JYo/YourDotMini.app`, with
warnings-as-errors build and strict ad-hoc signature verification. It contains
all prior footer, autofocus, and default-shortcut changes and supersedes build 7.
The installed bundle remains build 3. Nothing was installed, restarted, registered
for login, notarized, or published during these checks.

Sandbox browser-app integration (2026-10-29, macOS 27.0.1):

- Added `scripts/build-sandbox-checks.sh` and an isolated `SandboxChecks` target.
  It builds two signed test apps with the same sandbox entitlements as the product:
  `local.YourDotMini.SandboxChecks` and `local.YourDotMini.SandboxChecks.Target`.
  The test uses the production app selector, preferences, bookmark resolution,
  and `NSWorkspace` launcher. No web view or account data is involved.
- In `build/sandbox-checks.YaVJav`, choosing the generated fixture through the
  native file panel stored a read-only security-scoped bookmark. Opening the
  fixture started its separate process (PID 15684; test app PID 15473).
- After both processes exited and absence was independently checked, the identical
  test app relaunched as PID 16301 and reported a saved fixture. Without another
  file-selection dialog, production launch code started the fixture. A controlled
  repeat at 23:20:51 KST confirmed new fixture PID 16660 before any accessibility
  observation of the fixture, excluding observation-triggered launch as evidence.
- The test executable SHA-256 stayed
  `95de8ea2f289e4f05cd2c358ccdbe5c922befc1a12cc96011c501395794dbd99`;
  strict signatures passed for both bundles. All test processes were confirmed
  absent after cleanup. The product and frozen authentication pilot were unchanged.

This passes the sandbox app-selection/bookmark/relaunch mechanism on this host.
It does not prove Safari/other browser web-app authentication, direct dot targeting,
window activation semantics, older-OS compatibility, or product login-item behavior.
After adding the target, all 46 tests in 8 suites pass, and every SwiftPM product
compiles in Release with Swift warnings treated as errors. These builds do not
replace either installed app. The one-time P0-08 follow-up is scheduled for
2026-10-30 10:30 KST; the actual next-day result remains pending.

Notarization build support (2026-10-30):

- Both builders accept `release --notarize`, automatically create a fresh staging
  directory, and require an exact Developer ID Application identity plus a named
  `notarytool` Keychain profile. Local builds retain ad-hoc signing by default;
  the pilot builder now also supports `--stage` without notarization.
- The release path uses a secure signing timestamp and hardened runtime, submits
  an archive to Apple, requires `Accepted`, staples and validates the ticket, and
  runs strict signature verification and Gatekeeper assessment. The final ZIP and
  SHA-256 checksum are emitted after verification and successful packaging.
  Credentials are not stored in source or build metadata.
- Eight build-script tests cover both builders using isolated fixtures and mocked
  compiler/signing/Apple-service commands, with real ZIP/plist/checksum tools.
  Coverage includes preserved installed bundles, local defaults, invalid signing
  identities, absent profile configuration, rejection/incomplete responses, and
  signing, stapling, validation, Gatekeeper, packaging, and checksum failures.
  The product's `--dmg` option also covers a separately notarized disk image
  containing the stapled app and an Applications shortcut.
- Both actual local Release builds passed strict ad-hoc signature verification
  in fresh staging directories. No installed app or retained pilot was replaced.

Live product app and DMG notarization (2026-10-30):

- Built YourDotMini 0.2.0 (build 8), arm64, in `build/staged.THFAUW`, signed with
  Developer ID Application and a secure timestamp, using a Keychain profile for
  Apple authentication. No credential values were exported or stored in source.
- Apple accepted app submission `f9eb11c1-a17f-4a3a-8e18-bbf37215e682` and DMG
  submission `a4e38701-c80e-4511-b4fb-272761878e8b`. Both tickets were stapled and
  validated; strict signature verification and Gatekeeper assessment passed.
- Mounted the final DMG read-only and verified its app's signature, stapled ticket,
  and Gatekeeper acceptance, plus its `/Applications` shortcut and arm64 binary.
  The image was ejected without installing or launching the app. Its SHA-256 check
  passed: `4fdadc3c591ea6a006a720eb280a32b4dff2c1e53750ea7b12bec76c3e3c8e02`.
- Outputs are `build/staged.THFAUW/YourDotMini.dmg`, its `.sha256` checksum,
  the stapled app, and the notarized ZIP. Receipts remain under `notarization/`.
  This validates packaging and notarization; product runtime and authenticated
  persistence under the Developer ID identity still require acceptance testing.

## Remaining scope

### Requirement audit — 2026-10-29

Scope decision: the user waived macOS 14 / oldest-release runtime validation on
2026-10-29. Runtime acceptance now uses the reference Mac running macOS 27.0.1.
The existing 14.0 deployment target is unchanged; it is not a compatibility claim.
The waived test is excluded from completion gates, not recorded as passed.

The source, test coverage, recorded pilot observations, and staged build were
compared against SPEC. A passing synthetic test proves only its stated mechanism;
it does not substitute for a real-account, operating-system, or distribution trial.
Historical product observations predate the deferred build 8 unless stated otherwise.

| SPEC item | Evidence available | Remaining proof / decision |
| --- | --- | --- |
| Phase 0A artifacts | Pilot source, unchanged signed Release bundle, README, and POC_REPORT exist. | None for the pilot deliverable itself. |
| P0-01–07, P0-11 | Ordered real-account pilot evidence and user confirmations in POC_REPORT; three process exits, forced exit, and reboot recorded. | Gate passed for that account and pilot identity, not universal provider compatibility. |
| P0-08 | Follow-up scheduled for 2026-10-30 10:30 KST. | Actual next-day result from the unchanged pilot. |
| P0-09 | Clearing followed by manual sign-in recovered. | Website sign-out, genuine expiration, and account-switch scenarios; clearing is not their substitute. |
| P0-10 | Pilot file picker opened/cancelled; browser dispatch succeeded. | Actual harmless upload, task/approval details, external link, download handoff, and browser-side result. No task approval should be granted merely to test. |
| P0-12 | Pilot ad-hoc Release persistence passed; all current SwiftPM products compile in Release. | Developer ID/notarized builds and production-identity persistence are separate checks. |
| FR-01 | Status item and accessory app implemented; historical product launch/user confirmation. | Repeat on the final acceptance bundle and reference Mac. |
| FR-02 | Menu click and shortcut both call `toggleDot`; user confirmed original menu toggle. Later double-toggle fix is implemented. | Confirm repeated real status-item clicks after applying the deferred fix. |
| FR-03 | User confirmed real pilot message/reply; separate product sign-in and composer were observed. | Send/receive with the final product bundle; pilot success alone is insufficient. |
| FR-04 | Same production controllers retain window/view/draft for 50 synthetic cycles; earlier product draft survived ten cycles. | Final authenticated 50-cycle and scroll-position continuity trial. |
| FR-05 | Source review finds no browser/ChatGPT credential import, Keychain access, or session extraction. | Satisfied by current implementation; preserve during subsequent changes. |
| FR-06 | Defaults, punctuation choices, persistence, OS reservations, exclusive cross-process conflicts, and queued-event suppression pass. | Actual keyboard invocation from another foreground app and menu/hotkey equivalence. Shared/app-local conflicts remain the documented platform limitation. |
| FR-07 | Product constructs `.default()` website storage before WebKit creation under its own stable identity. | Authenticated product quit/relaunch and longevity trials; pilot identity cannot prove this. |
| FR-08 | Default-browser action and safe entry URL implemented; pilot native dispatch succeeded. | Verify the resulting browser window actually reaches the user's dot. |
| FR-09 | All menu/Settings handlers exist; first-run Settings rendered; browser-mode menu guards implemented. | Exercise every command, keyboard access, Settings persistence, and onboarding on the final bundle. |
| FR-10 | ServiceManagement status/idempotence/failure/concurrency tests pass with an injected backend. | User opt-in at a stable installed location, actual OS registration, then reboot. No registration has been performed. |
| FR-11 | Geometry tests cover small screens, negative origins, oversized frames, and disconnected-screen coordinates. | Physical display changes, scaling, notch, full-screen Spaces, and menu-bar auto-hide. |
| FR-12 | URL validation and preference persistence pass; native reset confirmation and recovery code exist; pilot reload/reset recovery observed. | Final product Reload, Save and Open, and reset Cancel/Confirm recovery trials. Preserve the longevity pilot until P0-08 is complete. |
| FR-13 | Navigation policy tests, native file-picker delegate, and explicit popup/download/media browser handoffs exist. | Real website workflows and browser handoffs from the acceptance matrix. |
| FR-14 | Production controllers pass native synthetic pinning and focus-loss checks, including inactive Settings and owned-sheet protection. | Final live-site multi-window/dialog behavior. |
| FR-15 / Phase 3 | Editable/native app icon and opt-in ZIP/DMG notarization workflow implemented. Build-script fixtures, live product Developer ID signing, Apple submissions, stapling, and Gatekeeper/mounted-image checks pass. | Final-product runtime and persistence acceptance under the signed identity, distribution/update design, and update smoke checks. No external release destination is configured. |
| FR-16 / §13 | Explicitly conditional, uncommitted future capabilities. | No multiple-profile implementation is required without a supported upstream capability and an agreed user need. |
| §5.1 composer focus refinement | Visible/hidden/missing/covered/disabled/ambiguous inputs, bounded hydration, cancellation, passive focus, first load, unhide, and restoration pass in fixtures. | Verify the current real ChatGPT composer after installing the deferred update. Missing markup remains a silent no-op. |
| §5.2 Escape and dialogs | Real native key routing in the fixture preserves web-owned Escape and attached sheets, and hides on unhandled Escape. | Real website modals, pickers, and in-page operations. |
| §5.3 / §7.5 defaults and onboarding | Native unofficial explanation, mode choice, help link, optional login control, shortcut, validated entry URL, and documented defaults are implemented. | Full first-run interaction and assistive-technology check on the acceptance build. |
| §5.6 recovery | Injected offline, cancelled, HTTP-independent navigation, and web-process errors have safe explicit recovery paths; async browser-launch failure returns to Settings. | Actual offline/reconnect, upstream error, stale session, and WebKit process recovery with a real account. |
| §7.1–7.4 architecture | Swift/AppKit/SwiftUI, single retained WebKit instance, visibility state, optional preload, persistent per-app storage, top-level routing, and confirmable reset are implemented; deployment target is 14.0. | Verify the composed lifecycle on the reference Mac. Build success is not runtime compatibility proof; macOS 14 testing is waived. |
| §7.6 privacy and identity | About/Settings disclose unofficial status and separate local-computer connector; no native message bridge, private API, user-agent spoof, browser data import, telemetry, or arbitrary keyboard monitor. The sole focus script is first-party and metadata-only. | Recheck service/OAuth policies and distribution entitlements before release; technical embedding success is not an endorsement. |
| §8 warm/cold latency | No valid measured latency acceptance series exists. | 20 real click/hotkey trials at ≤250 ms; fresh-process icon appearance at ≤2 s. Measure final product, not test harness startup. |
| §8 idle CPU / memory | No complete app-plus-WebKit baseline exists. No YourDotMini process was running during this audit. | Settle the real page, measure hidden CPU and combined process memory before/after 50 cycles. Do not treat wrapper-only RSS as total memory. |
| §9 accessibility / appearance | Native labels and template icon exist; icon variants were visually inspected. Passive-focus fixtures pass. | VoiceOver, full keyboard operation, native light/dark/high-contrast surfaces, and unrelated-notification behavior. |
| §10 platform / resilience / fallback matrix | macOS 27.0.1 synthetic checks and sandbox bookmark restoration pass. macOS 14 runtime testing is waived by the user. | Sleep/wake/display scenarios on the reference Mac, and a real dedicated browser web app with its own login and dot target. |

### Next acceptance gate

The next gate is final-product live acceptance, not more isolated test passes.
Build 8 is prepared and verified, but applying updates was explicitly deferred by
the user. Do not replace or launch the real app to bypass that choice. When the
user chooses to apply it, run the outstanding real-account/window/workflow and
performance checks against that exact bundle, retaining its identity and hash.
Manual authentication, account switching, an opt-in login item, and reboot require
the user's participation. A macOS 14 test environment is no longer required.

Release readiness remains gated on the above MVP acceptance. Successful product
signing and notarization validate packaging; final-product runtime, authenticated
persistence, and update smoke checks remain separate acceptance requirements.
The full objective is incomplete. The pending evidence and user/environment
dependencies above must remain visible rather than being converted to passes.

The implementation is not release-ready. Product Developer ID signing and
notarization passed; no launch-at-login registration, external publication, or
installation of the notarized artifact was performed.
