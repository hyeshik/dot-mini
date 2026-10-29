# Development

User installation and usage instructions are in the [README](../README.md).
Run the commands below from the repository root on macOS with Apple Swift 6.0+
(Xcode or Command Line Tools). Python 3 is needed for build-script tests.

## Local builds

```sh
./scripts/build-app.sh
open build/YourDotMini.app
```

Local builds are ad-hoc signed by default, with App Sandbox and hardened runtime
enabled. SwiftPM's `--disable-sandbox` flag affects the build process, not the
resulting app's sandbox. Launch the app bundle through Finder or `open`, rather
than running its bare executable.

The builder refuses to replace a running app. To prepare a separate build:

```sh
./scripts/build-app.sh release --stage
```

The command prints a fresh `build/staged.*/YourDotMini.app` path and writes
`APP_BUILD_INFO.txt` beside it. It does not install or launch the result. Local
builds target the build machine's architecture; the published v0.2.0 DMG is arm64.

## Tests

```sh
./scripts/test.sh
python3 Tests/BuildScripts/test_notarization.py -v
```

Swift tests cover navigation policy, host boundaries, diagnostic redaction,
preferences, geometry, composer focus, browser recovery, browser-app bookmarks,
and login-item state. WebKit fixtures use synthetic pages and a nonpersistent
store; login-item tests use a fake backend. They do not access signed-in pages
or change real Login Items.

Build-script tests use temporary fixtures and mocked compiler, signing,
notarization, and disk-image commands, with real ZIP, plist, and checksum tools.
They cover both builders, preservation of existing apps, local-build defaults,
credential configuration, rejection/error paths, stapling, Gatekeeper checks,
and final archive/DMG packaging. They do not use real credentials or submit to
Apple.

For native window and keyboard integration checks in a graphical macOS session:

```sh
./scripts/test-focus-window.sh
# Optional focused runs:
./scripts/test-focus-window.sh --hotkey-only
./scripts/test-focus-window.sh --escape-only
```

These checks open a synthetic test window and exercise hide/show retention,
composer focus, pinning, automatic hiding, preloading, Escape routing, and
shortcut conflicts. They temporarily reserve all-modifier function-key shortcuts
in test processes and release them on exit. They do not use real account data.

For a manual sandbox check of saved browser-app selection and launching:

```sh
./scripts/build-sandbox-checks.sh
```

Open the printed `YourDotMiniSandboxChecks.app`, use **Choose Fixture App** to
select the printed `YourDotMiniFallbackFixture.app`, then **Open Saved Fixture**.
Quit both apps, reopen the identical test app, and open the saved fixture again
without reselecting it. These apps use separate test identities and no website
data. This checks sandbox/bookmark access, not real browser authentication.

## Notarized releases

Install a valid **Developer ID Application** certificate and its private key in
your Keychain. List available signing identities with:

```sh
security find-identity -v -p codesigning
```

Store Apple's notarization credentials using its interactive prompts:

```sh
xcrun notarytool store-credentials "YourDotMini-notary"
```

Keep passwords and private keys out of source files and command-line arguments.
The build takes only a signing identity and a Keychain profile name:

```sh
DOT_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_KEYCHAIN_PROFILE='YourDotMini-notary' \
./scripts/build-app.sh release --notarize --dmg
```

Replace the example identity with its exact name or SHA-1 fingerprint. An Apple
Development identity or ad-hoc signature is not sufficient. `--notarize` requires
`release` and always creates a fresh staging directory; `--dmg` requires
`--notarize`. Omit `--dmg` for an app ZIP only. Selecting a signing identity
without `--notarize` does not submit to Apple.

The workflow signs with a secure timestamp, submits an app archive to Apple,
requires an `Accepted` result, staples and validates the ticket, and checks the
signature and Gatekeeper assessment. For a DMG, it packages the stapled app and
an Applications shortcut, then separately signs, notarizes, staples, and verifies
the disk image.

Successful builds produce the app, `YourDotMini.zip`, and its `.sha256` checksum
in the printed staging directory. `--dmg` adds `YourDotMini.dmg` and its
`.sha256` checksum. Publish the final archives beside the app, not the unstapled
upload archive in `notarization/`. Submission receipts and rejection diagnostics
remain under `notarization/` (or `notarization/dmg/` for the disk image).
After an interrupted submission, inspect `xcrun notarytool history` using the
same Keychain profile before submitting again.

## Manual release checks

The v0.2.0 app and DMG passed live Apple notarization, ticket validation, strict
signature verification, and Gatekeeper assessment. The mounted DMG's app and
Applications shortcut were also checked. These are packaging results; the
released app still needs live runtime and authentication validation.

For future releases, check the exact signed bundle that will be distributed:

- Sign-in, messaging, hide/show with a draft, authenticated quit/relaunch,
  long-term session retention, sign-out/account switching, and recovery.
- Actual uploads, task/approval details, external links, and browser handoffs.
- Dedicated browser web-app login, saved selection after relaunch, and dot targeting.
- Installation/update behavior and opt-in launch at login from a stable location.
- Keyboard access, VoiceOver, display/Spaces changes, appearance, and performance
  including WebKit child processes.

Keep bundle and signing identities fixed during persistence trials. Use normal
manual sign-in; do not import another app's cookies or bypass provider policies.
Arrange tests that clear sessions, alter Login Items, force quit, or reboot with
the person using the Mac. Runtime testing to date used macOS 27.0.1; the macOS 14
deployment target has not been validated on older systems.

## Authentication pilot

The separate pilot remains available for isolating WebKit authentication issues:

```sh
./scripts/build-pilot.sh release --stage
```

Open the printed `YourDotMiniAuthPilot.app` path. It has a separate identity
(`local.YourDotMini.AuthPilot`) and website store from the product
(`local.YourDotMini`). Pilot success does not establish product persistence.
Keep the same bundle, signature, and website data throughout a persistence trial.
The pilot also supports `release --notarize` with `PILOT_SIGNING_IDENTITY` and
`NOTARY_KEYCHAIN_PROFILE`; it does not accept `--dmg`.

## App icon and source layout

Edit `Resources/YourDotMini/AppIcon.icon` with Apple Icon Composer. The app builder
uses `scripts/build-icon.sh` to compile it with Xcode's `actool`, or uses the
checked-in `AppIcon.icns` fallback on Command Line Tools-only installations.
After editing the icon, regenerate the fallback with Xcode:

```sh
./scripts/build-icon.sh
cp build/app-icon/compiled/AppIcon.icns Resources/YourDotMini/AppIcon.icns
```

- `Sources/YourDotMiniCore`: preferences and geometry.
- `Sources/YourDotMiniUI`: native UI, window lifecycle, and browser controllers.
- `Sources/PilotCore`: shared navigation policy and diagnostic redaction.
- `Sources/YourDotMiniAuthPilot`: the standalone authentication test app.
- `Resources`: bundle metadata, sandbox entitlements, and app artwork.
- `Tests` and `scripts`: automated checks, integration tools, and packaging.

Generated builds and notarization receipts belong under the ignored `build/`
directory; SwiftPM caches belong under `.build/`.
