"""Exercise the real build scripts without signing credentials or Apple uploads.

Compiler, signing, and Apple-service commands are replaced in an isolated fixture.
Archive creation, plist parsing, and checksum generation use the macOS tools.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[2]
IDENTITY = "Developer ID Application: Build Fixture (TESTTEAMID)"
FINGERPRINT = "A" * 40

MOCK_TOOL = r'''
import json, os, pathlib, plistlib, sys
tool = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["MOCK_COMMAND_LOG"], "a") as log:
    log.write(json.dumps([tool, *args]) + "\n")
root = pathlib.Path(os.environ["MOCK_ROOT"])
failure = os.environ.get("MOCK_FAIL", "")

if tool == "security":
    print('  1) ' + 'A' * 40 + ' "Developer ID Application: Build Fixture (TESTTEAMID)"')
    print('  2) ' + 'B' * 40 + ' "Apple Development: Build Fixture (TESTTEAMID)"')
    if os.environ.get("MOCK_DUPLICATE_IDENTITY"):
        print('  3) ' + 'C' * 40 + ' "Developer ID Application: Build Fixture (TESTTEAMID)"')
elif tool == "swift":
    if args == ["--version"]:
        print("Swift fixture")
    elif "--show-bin-path" in args:
        print(root / "fake-bin")
    else:
        product = args[args.index("--product") + 1]
        binary = root / "fake-bin" / product
        binary.parent.mkdir(exist_ok=True)
        binary.write_text("synthetic build; never executed")
elif tool == "codesign":
    step = "sign" if "--sign" in args else "signature-verify"
    if failure == step or (args[-1].endswith(".dmg") and failure == "dmg-" + step):
        sys.exit(1)
elif tool == "spctl":
    if failure == "gatekeeper" or (args[-1].endswith(".dmg") and failure == "dmg-gatekeeper"):
        sys.exit(1)
elif tool == "hdiutil":
    if failure == "dmg-" + args[0]:
        sys.exit(1)
    if args[0] == "create":
        contents = pathlib.Path(args[args.index("-srcfolder") + 1])
        app = next(contents.glob("*.app"))
        pathlib.Path(args[-1]).write_text(json.dumps({
            "files": sorted(p.name for p in contents.iterdir()),
            "applications_link": os.readlink(contents / "Applications"),
            "app_ticket": (app / "fixture-notary-ticket").is_file(),
        }))
    elif args[0] != "verify" or not pathlib.Path(args[1]).is_file():
        sys.exit("Unexpected hdiutil call")
elif tool == "ditto":
    if failure == "archive" and pathlib.Path(args[-1]).name != "submission.zip":
        pathlib.Path(args[-1]).write_text("partial archive")
        sys.exit(1)
    os.execv("/usr/bin/ditto", ["ditto", *args])
elif tool == "shasum":
    if (failure == "checksum" and args[-1].endswith(".zip")) or (failure == "dmg-checksum" and args[-1].endswith(".dmg")):
        sys.exit(1)
    os.execv("/usr/bin/shasum", ["shasum", *args])
elif tool == "xcrun":
    if args[0] == "--find":
        if failure == "missing-tool":
            sys.exit(1)
        print(root / "mock-bin" / args[1])
    elif args[:2] == ["notarytool", "submit"]:
        response = os.environ.get("MOCK_RESPONSE", "Accepted")
        if args[2].endswith(".dmg"):
            response = os.environ.get("MOCK_DMG_RESPONSE", response)
        if response == "malformed":
            print("service failed without a structured response")
        else:
            result = {"status": response, "id": "12345678-1234-1234-1234-123456789abc"}
            if response == "missing-id":
                result = {"status": "Accepted"}
            sys.stdout.buffer.write(plistlib.dumps(result))
        sys.exit(int(os.environ.get("MOCK_SUBMISSION_EXIT", "0")))
    elif args[:2] == ["notarytool", "log"]:
        pathlib.Path(args[3]).write_text('{"issues": ["synthetic rejection"]}')
    elif args[0] == "stapler":
        if failure == args[1] or (args[2].endswith(".dmg") and failure == "dmg-" + args[1]):
            sys.exit(1)
        if args[1] == "staple":
            target = pathlib.Path(args[2])
            if target.is_dir():
                (target / "fixture-notary-ticket").write_text("stapled")
            else:
                with target.open("a") as image:
                    image.write("\nfixture-notary-ticket")
    else:
        sys.exit("Unexpected xcrun call")
else:
    sys.exit("Unexpected tool")
'''


class NotarizationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="YourDotMini build test ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / "scripts", self.root / "scripts")
        shutil.copytree(ROOT / "Resources", self.root / "Resources")
        (self.root / "scripts/build-icon.sh").write_text(
            "#!/bin/bash\nset -eu\nmkdir -p build/app-icon/compiled\n"
            "printf 'fixture icon' > build/app-icon/compiled/AppIcon.icns\n"
        )
        mock_bin = self.root / "mock-bin"
        mock_bin.mkdir()
        tool = mock_bin / "mock-tool"
        tool.write_text(f"#!{sys.executable}\n" + MOCK_TOOL)
        tool.chmod(0o755)
        for name in ("swift", "security", "codesign", "spctl", "xcrun", "ditto", "shasum", "hdiutil"):
            (mock_bin / name).symlink_to(tool)
        self.log = self.root / "commands.jsonl"
        self.env = os.environ.copy()
        # Tests never inherit real notarization or signing settings.
        self.env.update(
            PATH=f"{mock_bin}:/usr/bin:/bin:/usr/sbin:/sbin",
            MOCK_ROOT=str(self.root),
            MOCK_COMMAND_LOG=str(self.log),
            DOT_SIGNING_IDENTITY=IDENTITY,
            PILOT_SIGNING_IDENTITY=IDENTITY,
            NOTARY_KEYCHAIN_PROFILE="fixture-profile",
        )
        for key in ("MOCK_FAIL", "MOCK_RESPONSE", "MOCK_DMG_RESPONSE", "MOCK_SUBMISSION_EXIT", "MOCK_DUPLICATE_IDENTITY"):
            self.env.pop(key, None)

    def run_build(self, target="app", args=("release", "--notarize"), **environment):
        self.env.update(environment)
        return subprocess.run(
            ["/bin/bash", f"scripts/build-{target}.sh", *args],
            cwd=self.root, env=self.env, text=True, capture_output=True, timeout=30,
        )

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def stages(self):
        return list((self.root / "build").glob("staged.*"))

    def assert_no_distribution(self):
        self.assertFalse(list((self.root / "build").glob("staged.*/*.zip")))
        self.assertFalse(list((self.root / "build").glob("staged.*/*.sha256")))

    def test_accepted_builds_preserve_installed_apps_and_archive_the_ticket(self):
        for target, name in (("app", "YourDotMini"), ("pilot", "YourDotMiniAuthPilot")):
            with self.subTest(target=target):
                installed = self.root / "build" / f"{name}.app" / "preserve-me"
                installed.parent.mkdir(parents=True)
                installed.write_text("installed trial")
                result = self.run_build(target)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(installed.read_text(), "installed trial")
                archive = next((self.root / "build").glob(f"staged.*/{name}.zip"))
                with zipfile.ZipFile(archive) as bundle:
                    self.assertIn(f"{name}.app/fixture-notary-ticket", bundle.namelist())
                with zipfile.ZipFile(archive.parent / "notarization/submission.zip") as bundle:
                    self.assertNotIn(f"{name}.app/fixture-notary-ticket", bundle.namelist())
                checksum = subprocess.run(
                    ["/usr/bin/shasum", "-a", "256", "-c", f"{name}.zip.sha256"],
                    cwd=archive.parent, capture_output=True,
                )
                self.assertEqual(checksum.returncode, 0)
                info_name = "APP_BUILD_INFO.txt" if target == "app" else "BUILD_INFO.txt"
                self.assertIn("Notarization: Accepted", (archive.parent / info_name).read_text())
        commands = self.commands()
        for command in commands:
            if command[:2] == ["codesign", "--force"]:
                self.assertIn("--timestamp", command)
                self.assertIn("runtime", command)
                self.assertIn(FINGERPRINT, command)
            if command[:3] == ["xcrun", "notarytool", "submit"]:
                self.assertIn("--wait", command)
                self.assertIn("--keychain-profile", command)
                self.assertNotIn("--password", command)
                self.assertNotIn("--key", command)
        gatekeeper_checks = [c for c in commands if c[0] == "spctl"]
        self.assertEqual(len(gatekeeper_checks), 2)

    def test_development_builds_remain_local_and_adhoc(self):
        for target in ("app", "pilot"):
            with self.subTest(target=target):
                result = self.run_build(target, ("debug", "--stage"),
                                        DOT_SIGNING_IDENTITY="-", PILOT_SIGNING_IDENTITY="-",
                                        NOTARY_KEYCHAIN_PROFILE="")
                self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.commands()
        self.assertFalse(any(c[0] in ("xcrun", "security", "spctl") for c in commands))
        for command in commands:
            if "--sign" in command:
                self.assertEqual(command[command.index("--sign") + 1], "-")
                self.assertIn("--timestamp=none", command)
        self.assert_no_distribution()

    def test_preflight_rejects_invalid_configuration_before_building(self):
        cases = [
            (("debug", "--notarize"), {}),
            (("release", "--notarize"), {"NOTARY_KEYCHAIN_PROFILE": ""}),
            (("release", "--notarize"), {"DOT_SIGNING_IDENTITY": "-", "PILOT_SIGNING_IDENTITY": "-"}),
            (("release", "--notarize"), {"DOT_SIGNING_IDENTITY": "B" * 40, "PILOT_SIGNING_IDENTITY": "B" * 40}),
            (("release", "--notarize"), {"MOCK_DUPLICATE_IDENTITY": "1"}),
            (("release", "--notarize"), {"MOCK_FAIL": "missing-tool"}),
            (("release", "--unknown"), {}),
            (("release", "--dmg"), {}),
        ]
        baseline = self.env.copy()
        for target in ("app", "pilot"):
            for args, environment in cases:
                with self.subTest(target=target, args=args, environment=environment):
                    self.env = baseline.copy()
                    result = self.run_build(target, args, **environment)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(any(c[0] == "swift" for c in self.commands()))
                    self.assertFalse((self.root / "build").exists())

    def test_sha1_disambiguates_duplicate_identity_names(self):
        result = self.run_build(
            args=("release", "--stage", "--notarize"),
            DOT_SIGNING_IDENTITY=FINGERPRINT.lower(), MOCK_DUPLICATE_IDENTITY="1",
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejected_incomplete_or_malformed_responses_do_not_staple(self):
        for response, exit_code in (("Invalid", "0"), ("In Progress", "0"),
                                    ("malformed", "0"), ("missing-id", "0"), ("Accepted", "1")):
            with self.subTest(response=response, exit_code=exit_code):
                result = self.run_build(MOCK_RESPONSE=response, MOCK_SUBMISSION_EXIT=exit_code)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("did not complete with Accepted", result.stderr)
                self.assert_no_distribution()
                self.assertFalse(any(c[:2] == ["xcrun", "stapler"] for c in self.commands()))
        responses = list((self.root / "build").glob("staged.*/notarization/submission.plist"))
        self.assertEqual(len(responses), 5)
        self.assertTrue(list((self.root / "build").glob("staged.*/notarization/log.json")))

    def test_signing_stapling_verification_or_packaging_failure_prevents_distribution(self):
        for step in ("sign", "signature-verify", "staple", "validate", "gatekeeper", "archive", "checksum"):
            with self.subTest(step=step):
                result = self.run_build(MOCK_FAIL=step)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Distribution archive:", result.stdout)
                self.assert_no_distribution()

    def test_notarized_dmg_contains_stapled_app_and_applications_shortcut(self):
        result = self.run_build(args=("release", "--notarize", "--dmg"))
        self.assertEqual(result.returncode, 0, result.stderr)
        image = next((self.root / "build").glob("staged.*/YourDotMini.dmg"))
        manifest, ticket = image.read_text().split("\n")
        self.assertEqual(ticket, "fixture-notary-ticket")
        self.assertEqual(json.loads(manifest), {
            "files": ["Applications", "YourDotMini.app"],
            "applications_link": "/Applications", "app_ticket": True,
        })
        checksum = subprocess.run(
            ["/usr/bin/shasum", "-a", "256", "-c", "YourDotMini.dmg.sha256"],
            cwd=image.parent, capture_output=True,
        )
        self.assertEqual(checksum.returncode, 0)
        commands = self.commands()
        submissions = [c for c in commands if c[:3] == ["xcrun", "notarytool", "submit"]]
        self.assertEqual(len(submissions), 2)
        self.assertTrue(submissions[1][3].endswith(".dmg"))
        assessment = next(c for c in commands if c[0] == "spctl" and c[-1].endswith(".dmg"))
        self.assertIn("context:primary-signature", assessment)
        self.assertEqual(assessment[assessment.index("--type") + 1], "open")
        signing = next(c for c in commands if c[0] == "codesign" and "--sign" in c and c[-1].endswith(".dmg"))
        self.assertIn("--timestamp", signing)
        self.assertIn(FINGERPRINT, signing)

    def test_failed_dmg_build_or_notarization_does_not_publish_an_image(self):
        cases = [
            {"MOCK_FAIL": "dmg-create"}, {"MOCK_FAIL": "dmg-verify"},
            {"MOCK_FAIL": "dmg-sign"}, {"MOCK_DMG_RESPONSE": "Invalid"},
            {"MOCK_FAIL": "dmg-staple"}, {"MOCK_FAIL": "dmg-validate"},
            {"MOCK_FAIL": "dmg-gatekeeper"}, {"MOCK_FAIL": "dmg-checksum"},
        ]
        baseline = self.env.copy()
        for environment in cases:
            with self.subTest(environment=environment):
                self.env = baseline.copy()
                result = self.run_build(args=("release", "--notarize", "--dmg"), **environment)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Notarized disk image:", result.stdout)
                self.assertFalse(list((self.root / "build").glob("staged.*/*.dmg")))
                self.assertFalse(list((self.root / "build").glob("staged.*/*.dmg.sha256")))


if __name__ == "__main__":
    unittest.main()
