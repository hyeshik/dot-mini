# Phase 0 authentication and persistence report

**Gate status: GO (embedded) — mandatory Phase 0 acceptance checks passed.**

The user confirmed successful message/reply behavior, usability at both compact
sizes, and authenticated relaunch after reboot. The ordered hide/show, three
normal cold relaunches, and force-quit relaunch passed. The new macOS boot time
is 2026-10-29 10:37:17 KST; the pilot executable still has its original validated
hash and passes strict signature verification. Phase 1 may proceed under SPEC
§4 and §11. Next-day and broader workflow validation remain release checks.

## Environment and build

| Field | Value |
| --- | --- |
| Report date | 2026-10-29 (Asia/Seoul) |
| macOS | 27.0.1, build 26A434 |
| Toolchain | Apple Swift 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1); Command Line Tools; full Xcode unavailable |
| Bundle deployment target | 14.0; runtime behavior on macOS 14 is untested. The user subsequently waived that validation requirement on 2026-10-29. |
| Pilot version/build | 0.1.0 (1), Release; built 2026-10-29 10:00:24 KST; exact metadata in `build/BUILD_INFO.txt` |
| Commit | Not available at pilot validation: the supplied directory had not yet been initialized as a Git repository |
| Bundle identifier | `local.YourDotMini.AuthPilot` |
| App Sandbox | Enabled; network client, user-selected file read-only |
| Signing mode | Local ad-hoc; hardened runtime; not notarized |
| WebKit store | Persistent `.default()`, assigned before constructing the single view |
| Login provider / method | Initial Google sign-in completed manually. After data clearing, an OpenAI password page was observed and the user again completed sign-in; specific 2FA/passkey details were not recorded. |
| Browser handoff required | No browser handoff used for sign-in or persistence testing. The explicit Open in Browser command was tested separately afterward; no browser-to-pilot session transfer was used. |
| Real account with dot access | Confirmed by user: “I reach my dot conversation.” |

## Implementation verification

| Check | Observed result |
| --- | --- |
| Debug compilation | Pass; current source also compiled during the test run. |
| Release compilation | Pass; no Swift source warnings after correcting WebKit delegate actor annotations. |
| Automated tests | Pass: 11 tests in 2 suites, including 21 parameterized cases and 7 standalone cases (28 cases total). |
| Signature | `codesign --verify --strict` passed; embedded entitlements match the three documented sandbox permissions. |
| Deployment target | Mach-O `LC_BUILD_VERSION` confirms minimum macOS 14.0. |
| Local launch | Pass: ordinary native application launched at 10:00:54 KST. |
| Initial navigation | Redacted log shows `chatgpt.com` navigation committed and finished, about 1.27 seconds after process start. Page-load completion does not establish login or dot access. |
| Sign-in navigation | `auth.openai.com` then `accounts.google.com` observed. Native host-consent sheet inspected; subsequent allowed-host event and Google page load recorded. No login-page automation performed. |
| Supplemental cold relaunch | User hid the window at 10:03:58 KST and the process exited normally at 10:04:01. Pilot reopened at 10:05:39 with a new PID; `chatgpt.com` finished loading at 10:05:40 without an observed authentication redirect. This is preliminary evidence only: P0-03/P0-04 were not completed first, and no formal P0-05 cycle is claimed. |
| Storage/lifecycle review | One `WKWebView` construction; persistent store set beforehand; hiding only orders out the retained window. Same-process draft retention and authenticated process-restart persistence now verified below. |
| Privacy review | Wrapper log fields limited to event, host, allowlisted error code, and elapsed time; no script injection, cookie access, or user-agent override. |

Release executable SHA-256:
`7dbb9b1126a35fbaa5566021926bdf6b92aebe6f7c88186ef526bc3452314a80`.

The installed Swift 6.4 toolchain emits a deprecation warning for the native
SwiftPM build engine; the local build succeeds. The scripts currently use that
engine for the Command Line Tools-only workflow. No full Xcode installation or
Developer ID identity was used. These checks do not establish a successful pilot.

## Automated session tests — 2026-10-29, KST

The user explicitly requested the remaining automatable authentication and
persistence checks. The existing Release bundle was used throughout, with no
rebuild, identity change, cookie access, injected JavaScript, or login automation.
Its SHA-256 and strict code-signature verification remained unchanged. Native
accessibility observations were reduced to route/composer/sign-in-state checks;
no private conversation content or screenshots were saved as evidence.

- **Authenticated baseline:** the dot route and editable Message composer were
  present, with an empty draft and no sign-in prompt.
- **P0-04:** entered the unsent marker `YourDotMini persistence test draft — do not
  send.`, hid the window at 10:10:02, and revealed it at 10:10:30. The exact draft
  remained. Both events belonged to PID 78704; no intervening navigation appeared
  in the wrapper log. The test draft was subsequently removed without sending.
- **P0-11, automated portion:** invoked both 480 × 720 and 420 × 520 viewport
  presets. The editable composer remained accessible and the draft survived each
  change. This does not establish visual fit, scrolling comfort, or practical
  usability; those still need visual acceptance by the user. Final preset: 480 × 720.
- **P0-05/P0-06:** normal quits used the app's ⌘Q command. Each main-process exit
  was independently checked with `pgrep`, followed by an identical-bundle launch.
  Force quit used SIGKILL only after verifying the PID's executable path exactly
  matched this pilot. Every relaunch reached the dot route with an editable
  composer and no sign-in prompt. No authentication-host navigation appeared in
  these restart cycles. Message sending after restart was not exercised.
- **P0-10, file chooser portion:** Add photos and files opened a native
  `NSOpenPanel`; Cancel closed it and restored the authenticated composer. No
  file was selected or uploaded.
- **Recovery controls:** after manual reset recovery, ⌘R restored the authenticated
  dot route and composer without sign-in. Pilot → Open in Browser returned a
  successful native handoff status for the clean entry URL. Browser-side page
  behavior and ordinary off-site link routing were not evaluated. At 480-point
  width the browser toolbar item moves into the native overflow menu; it also
  remains available in the Pilot menu.
- **Reset/recovery:** the reset confirmation appeared correctly. It was confirmed
  during the session before the automation's intended Cancel action could run;
  the cancel branch therefore is **not** claimed as tested. Logs show actual
  data clearing at 10:16:21 and a fresh site load at 10:16:23. The clean page
  displayed cookie consent, followed by a normal authentication page. The user
  manually signed in, confirmed the dot returned, and automation verified the
  authenticated composer again. This is reset recovery, not a substitute for
  the separate website sign-out/expired-session scenario.

**Initial ordering limitation:** the exploratory persistence tests above ran
before P0-03 was completed. The subsequent reset and manual sign-in established
the clean baseline for the ordered continuation below; that continuation now
supersedes the exploratory run for P0-01–P0-06 acceptance.

## Ordered acceptance continuation — 2026-10-29, KST

1. **P0-01, 10:16:21–10:16:23:** pilot website data was cleared through the
   confirmation dialog, and the clean cookie-consent/authentication flow appeared.
2. **P0-02, by 10:18:26:** the user completed manual sign-in and confirmed the
   dot conversation returned. The authenticated composer was independently observed.
3. **P0-03, confirmed during the 10:27 continuation:** user reported that a
   harmless message and its reply work. Automation then used the site's Home
   link to navigate to `https://chatgpt.com/`, verified departure from the dot,
   and used Return to Dot. The dot route and editable composer returned; wrapper
   navigation finished at 10:29:08. No message contents were stored in this report.
4. **P0-04, 10:29:41:** the exact unsent marker `YourDotMini ordered pilot draft —
   do not send.` survived ⌘W/⌘0 in PID 79801. The marker was removed, with an
   empty composer confirmed before the restart tests.
5. **P0-05:** all three ordered cold relaunches below restored the authenticated
   dot composer without interactive sign-in. Every process exit was verified.
6. **P0-06:** at 10:31:32, SIGKILL was sent only to PID 82752 after its executable
   path matched this exact pilot bundle. Process absence was confirmed in the
   same second. Relaunch at 10:31:38 (PID 82851) restored the dot route and editable
   composer without sign-in. The strict code-signature check and executable hash
   remained unchanged throughout.
7. **P0-07:** passed. The user subsequently reported “Have rebooted the computer
   and it opens without authentication.” Live `kern.boottime` now reports
   2026-10-29 10:37:17 KST, replacing the pre-test October 1 boot. Pilot PID 2367
   was running after reboot; its SHA-256 remained
   `7dbb9b1126a35fbaa5566021926bdf6b92aebe6f7c88186ef526bc3452314a80`
   and `codesign --verify --strict` passed. The same bundle completed the gate.

**P0-11 user acceptance:** the user explicitly reported “Yes, both sizes are
usable” after checking ⌘1 and ⌘2. This complements the automated composer/draft
checks and completes the compact-layout gate. The pilot is left at 480 × 720.

### Ordered P0-05 evidence

| Cycle | Normal quit | Main process confirmed absent | Relaunch | Authentication result |
| --- | --- | --- | --- | --- |
| 1 | 10:29:51, PID 79801 | 10:30:02 | 10:30:10, PID 82569 | Dot composer restored; no interactive sign-in |
| 2 | 10:30:23, PID 82569 | 10:30:36 | 10:30:42, PID 82668 | Dot composer restored; no interactive sign-in |
| 3 | 10:30:51, PID 82668 | 10:31:01 | 10:31:08, PID 82752 | Dot composer restored; no interactive sign-in |

The mandatory ordered run is complete. Preserve the validated pilot bundle for
the next-day check while developing the separate menu bar app. The user requested
that initial sizing match ⌘1; this is a subsequent UI change, not evidence from
the validated binary. The product must validate sign-in under its own identity.

## Ordered scenario matrix

Pass is scoped to the observations stated in each row. Conditional means that
only part of the scenario was exercised. Pending means it has not been tested.
No wrapper authentication/persistence failure was observed in this session.

| ID | Scenario | Result | Failure category / observation / required interaction |
| --- | --- | --- | --- |
| P0-01 | Clear pilot data; initial login/onboarding | Pass | Confirmed clearing at 10:16:21 and normal cookie-consent/authentication UI establish the baseline for the ordered run. |
| P0-02 | Real provider sign-in including SSO/2FA/passkeys | Pass (user-reported) | User completed sign-in and confirmed reaching the dot conversation. Google host navigation observed; no login automation. Specific 2FA/passkey path remains unrecorded. |
| P0-03 | Send/receive and navigate away/back | Pass | User confirmed message/reply success. Automation navigated to the first-party home page and back; dot route and composer returned. |
| P0-04 | Same-window hide/show with unsent draft | Pass | Ordered retest at 10:29:41 preserved the exact unsent draft in the same PID. Test draft removed afterward. |
| P0-05 | Three normal quits and cold relaunches | Pass | 3/3 ordered full process exits and authenticated relaunches passed at 10:29–10:31, after P0-03/P0-04. |
| P0-06 | Force quit and cold relaunch | Pass | Ordered SIGKILL/absence/relaunch check at 10:31:32–10:31:38 restored the authenticated composer. |
| P0-07 | OS reboot and relaunch | Pass | User confirmed no authentication required after reboot. New boot time 2026-10-29 10:37:17 KST; pilot hash/signature unchanged, PID 2367 running. |
| P0-08 | Next-day session check | Pending | One-time thread follow-up scheduled for 2026-10-30 10:30 KST, after 24 hours since the final sign-in (~10:18 KST). Requires a user-reported result; the follow-up will not inspect or alter the pilot. |
| P0-09 | Sign out / invalid session / sign back in | Conditional | Reset followed by manual sign-in recovered successfully; website sign-out and genuine expiration remain untested. |
| P0-10 | Approval/task detail, attachment, external link | Conditional | Native file chooser opened/cancelled successfully; explicit Open in Browser dispatch succeeded. Actual upload, task/approval details, ordinary external links, browser-side results, and downloads remain untested. |
| P0-11 | 480 × 720 and 420 × 520 web viewports | Pass | Both presets preserved the accessible composer/draft; user explicitly confirmed that both sizes are usable. |
| P0-12 | Signed Release identity and persistence | Pass (local ad-hoc only) | All current persistence trials used the unchanged, sandboxed, ad-hoc-signed Release bundle. Developer ID/notarized distribution and a future product identity remain untested. |

### Earlier exploratory quit/relaunch evidence (P0-05)

| Cycle | Quit time | Process confirmed absent | Relaunch time | Interactive sign-in? | Dot UI | Result |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 10:12:48, PID 78704 | Yes, 10:13:00 | 10:13:07, PID 79479 | No | Editable composer returned | Pass |
| 2 | 10:13:24, PID 79479 | Yes, 10:13:33 | 10:13:37, PID 79575 | No | Editable composer returned | Pass |
| 3 | 10:13:53, PID 79575 | Yes, 10:14:01 | 10:14:07, PID 79671 | No | Editable composer returned | Pass |

Times are 2026-10-29, Asia/Seoul (UTC+09:00), from wrapper lifecycle logs and
process-absence checks. All three restored the known dot route; no message was
sent to test response delivery. No data clearing or binary replacement occurred
between these cycles.

### Other persistence evidence

| Scenario | Termination / idle start | Relaunch / retest | Sign-in required? | Classification | Result |
| --- | --- | --- | --- | --- | --- |
| Force quit, exploratory | SIGKILL 10:14:44, PID 79671; absence checked 10:14:45 | 10:14:49, PID 79801 | No | Exact pilot executable verified; authenticated composer restored | Pass |
| Force quit, ordered | SIGKILL 10:31:32, PID 82752; absence checked 10:31:32 | 10:31:38, PID 82851 | No | Same verified bundle; authenticated composer restored | Pass |
| OS reboot | Boot 2026-10-29 10:37:17 KST | Same validated bundle, PID 2367 | No (user-confirmed) | New boot independently verified; hash/signature unchanged | Pass |
| Next day | — | — | — | — | Pending |

## Checks requiring user input or elapsed time

1. **Next day (P0-08):** retest on 2026-10-30 after a realistic idle period. Do not
   clear data, rebuild, or change signing/bundle identity during the trial. The
   final sign-in was around 10:18 KST on 2026-10-29.
   A one-time follow-up in this thread is scheduled for 2026-10-30 10:30 KST
   (automation `yourdotmini`); scheduling is not a passing test result.
2. **Session recovery/workflows (P0-09/P0-10):** after the persistence trial,
   sign out through the website and sign in again manually. Choose a harmless
   file for a real upload, a suitable task/approval-detail page to inspect, and
   an external link/download to test. No task approval should be granted merely
   for testing. Provider login/2FA/passkey interactions remain manual.

The embedded GO gate has passed. Additional signing identities and other identity
providers require their corresponding environments; these are not established by
the current local Release run. The user waived oldest-release/macOS 14 runtime
validation on 2026-10-29. It remains untested but is no longer an acceptance gate.

## Known restrictions and mitigation

- The pilot does not create popup windows. A provider requiring opener/popup
  semantics may fail. Record this explicitly and decide whether a compliant
  architecture change or browser-backed pivot is needed.
- Unknown top-level HTTPS redirects require manual host approval on each run.
  Ordinary clicked external links use the browser; an unfamiliar SSO link may
  need further policy review. Do not treat an interrupted redirect as proven
  provider rejection without distinguishing the wrapper's routing decision.
- Browser handoff opens the clean `/dots` entry point with an independent browser
  session. It does not transfer the pilot's authentication state.
- Downloads and media capture need browser fallback. Attachment upload, task
  details, dialogs, and passkeys require actual testing.
- App identity and signing must stay fixed throughout a persistence trial.
  Changing the future product's bundle identifier requires a fresh validation.
- No private-content screenshots are captured. Add only non-sensitive error
  screenshots if needed, with reproducible steps and a redacted description.

## Decision record

**Decision: GO (embedded). Proceed to Phase 1.** Reopen this decision if the
next-day check or production-identity testing reveals repeated session loss.

- **GO (embedded):** P0-01 through P0-07 and P0-11 pass with the actual account,
  including working chat and all three authenticated cold relaunches.
- **PIVOT (browser-backed):** embedded authentication/persistence is blocked;
  verify the dedicated browser site app's first login, relaunch, and activation.
- **STOP:** neither mode provides reliable dedicated dot access.

P0-08 and additional provider combinations remain release validation even after
an initial GO. Repeated-login failures reopen the gate.
