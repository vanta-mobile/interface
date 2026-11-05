import base64
import copy
from datetime import datetime, timedelta
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import stat
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch
import zipfile

import ios_release as release


TEAM = "ABCDE12345"
PROFILE_UUID = "12345678-1234-1234-1234-123456789ABC"
CERTIFICATE = b"test distribution certificate"
IDENTITY = hashlib.sha1(CERTIFICATE).hexdigest().upper()


def distribution_profile():
    return {
        "UUID": PROFILE_UUID,
        "TeamIdentifier": [TEAM],
        "ApplicationIdentifierPrefix": [TEAM],
        "ExpirationDate": datetime.now() + timedelta(days=30),
        "DeveloperCertificates": [CERTIFICATE],
        "Entitlements": {
            "application-identifier": f"{TEAM}.{release.BUNDLE_ID}",
            "com.apple.developer.team-identifier": TEAM,
            "get-task-allow": False,
        },
    }


class SigningProfileTests(unittest.TestCase):
    def validate(self, profile):
        return release.validate_profile(profile, TEAM, {IDENTITY})

    def test_accepts_distribution_profile_and_matches_private_key_identity(self):
        self.assertEqual(self.validate(distribution_profile()), (PROFILE_UUID, IDENTITY))

    def test_preserves_original_uuid_case_for_xcode_profile_lookup(self):
        for profile_uuid in [PROFILE_UUID, PROFILE_UUID.lower()]:
            with self.subTest(profile_uuid=profile_uuid):
                profile = distribution_profile()
                profile["UUID"] = profile_uuid
                actual_uuid, identity = self.validate(profile)
                self.assertEqual(actual_uuid, profile_uuid)
                self.assertEqual(
                    release.export_options(TEAM, actual_uuid, identity)["provisioningProfiles"],
                    {release.BUNDLE_ID: profile_uuid},
                )

    def test_rejects_wrong_team_bundle_or_identity(self):
        for field, value, message in [
            ("TeamIdentifier", ["OTHER12345"], "APPLE_TEAM_ID"),
            ("DeveloperCertificates", [b"another certificate"], "private key"),
            ("UUID", "invalid-profile-id", "invalid UUID"),
        ]:
            with self.subTest(field=field):
                profile = distribution_profile()
                profile[field] = value
                with self.assertRaisesRegex(release.ReleaseError, message):
                    self.validate(profile)
        profile = distribution_profile()
        profile["Entitlements"]["application-identifier"] = f"{TEAM}.another.app"
        with self.assertRaisesRegex(release.ReleaseError, release.BUNDLE_ID):
            self.validate(profile)

    def test_accepts_legacy_app_id_prefix_distinct_from_team(self):
        profile = distribution_profile()
        profile["ApplicationIdentifierPrefix"] = ["LEGACY1234"]
        profile["Entitlements"]["application-identifier"] = f"LEGACY1234.{release.BUNDLE_ID}"
        self.assertEqual(self.validate(profile), (PROFILE_UUID, IDENTITY))

    def test_rejects_expired_development_ad_hoc_and_enterprise_profiles(self):
        cases = [
            ("ExpirationDate", datetime.now() - timedelta(days=1), "expired"),
            ("ProvisionedDevices", ["test-device"], "App Store Connect"),
            ("ProvisionsAllDevices", True, "App Store Connect"),
        ]
        for field, value, message in cases:
            with self.subTest(field=field):
                profile = distribution_profile()
                profile[field] = value
                with self.assertRaisesRegex(release.ReleaseError, message):
                    self.validate(profile)

    def test_vanta_profile_requires_team_and_disables_debugging(self):
        for field, value in [("com.apple.developer.team-identifier", "OTHER12345"), ("get-task-allow", True)]:
            profile = distribution_profile()
            profile["Entitlements"][field] = value
            with self.assertRaises(release.ReleaseError):
                self.validate(profile)

    def test_export_requires_manual_app_store_signing_and_preserves_build_number(self):
        options = release.export_options(TEAM, PROFILE_UUID, IDENTITY)
        self.assertEqual(options["method"], "app-store-connect")
        self.assertEqual(options["destination"], "export")
        self.assertEqual(options["provisioningProfiles"], {release.BUNDLE_ID: PROFILE_UUID})
        self.assertEqual(options["signingCertificate"], IDENTITY)
        self.assertEqual(options["teamID"], TEAM)
        self.assertFalse(options["manageAppVersionAndBuildNumber"])
        self.assertEqual(plistlib.loads(plistlib.dumps(options)), options)


class TestFlightTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.output = self.directory / "outputs"
        self.environment = patch.dict(os.environ, {"GITHUB_OUTPUT": str(self.output)}, clear=True)
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def configure_credentials(self):
        key = b"-----BEGIN PRIVATE KEY-----\ntest-key\n-----END PRIVATE KEY-----\n"
        os.environ.update({
            "APP_STORE_CONNECT_KEY_ID": "KEY1234567",
            "APP_STORE_CONNECT_ISSUER_ID": "12345678-1234-1234-1234-123456789abc",
            "APP_STORE_CONNECT_PRIVATE_KEY_BASE64": base64.b64encode(key).decode(),
        })
        return key

    def test_no_credentials_skips_without_creating_key(self):
        release.configure_testflight(self.directory)
        self.assertEqual(self.output.read_text(), "enabled=false\n")
        self.assertFalse((self.directory / "private_keys").exists())

    def test_partial_configuration_reports_missing_names(self):
        os.environ["APP_STORE_CONNECT_KEY_ID"] = "KEY1234567"
        with self.assertRaisesRegex(release.ReleaseError, "APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_PRIVATE_KEY_BASE64"):
            release.configure_testflight(self.directory)
        self.assertFalse(self.output.exists())

    def test_complete_configuration_writes_private_key_with_restricted_permissions(self):
        key = self.configure_credentials()
        release.configure_testflight(self.directory)
        path = self.directory / "private_keys/AuthKey_KEY1234567.p8"
        self.assertEqual(path.read_bytes(), key)
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(path.parent.stat().st_mode), 0o700)
        self.assertEqual(self.output.read_text(), "enabled=true\n")

    def test_invalid_credentials_never_echo_private_key(self):
        for name, value, message in [
            ("APP_STORE_CONNECT_KEY_ID", "invalid/id", "KEY_ID"),
            ("APP_STORE_CONNECT_KEY_ID", " KEY1234567 ", "KEY_ID"),
            ("APP_STORE_CONNECT_ISSUER_ID", "invalid-issuer", "ISSUER_ID"),
            ("APP_STORE_CONNECT_ISSUER_ID", " 12345678-1234-1234-1234-123456789abc ", "ISSUER_ID"),
            ("APP_STORE_CONNECT_PRIVATE_KEY_BASE64", "not-base64!", "valid base64"),
            ("APP_STORE_CONNECT_PRIVATE_KEY_BASE64", base64.b64encode(b"sensitive-key-content").decode(), "downloaded .p8"),
        ]:
            with self.subTest(name=name, value=value):
                self.configure_credentials()
                os.environ[name] = value
                with self.assertRaisesRegex(release.ReleaseError, message) as caught:
                    release.configure_testflight(self.directory)
                self.assertNotIn(value, str(caught.exception))
                self.assertNotIn("sensitive-key-content", str(caught.exception))


class Pkcs12CompatibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not shutil.which("openssl"):
            raise unittest.SkipTest("OpenSSL 3 is required for PKCS#12 integration tests")
        version = subprocess.run(["openssl", "version"], capture_output=True, text=True)
        if not version.stdout.startswith("OpenSSL 3."):
            raise unittest.SkipTest("OpenSSL 3 is required for PKCS#12 integration tests")

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.password = "test-p12-export-password"
        environment = patch.dict(os.environ, {
            "IOS_DISTRIBUTION_CERTIFICATE_PASSWORD": self.password,
        })
        environment.start()
        self.addCleanup(environment.stop)
        self.key = self.directory / "test.key"
        self.certificate = self.directory / "test.pem"
        self.p12 = self.directory / "test.p12"
        release.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-noenc",
            "-keyout", str(self.key), "-out", str(self.certificate),
            "-subj", "/CN=Vanta Signing Test", "-days", "1",
        ])

    def create_p12(self, extra_options=()):
        release.run([
            "openssl", "pkcs12", "-export", "-inkey", str(self.key),
            "-in", str(self.certificate), "-out", str(self.p12),
            "-passout", "env:IOS_DISTRIBUTION_CERTIFICATE_PASSWORD",
            *extra_options,
        ])

    def test_normalizes_modern_and_legacy_p12_without_changing_identity_or_password(self):
        for options in [(), ("-legacy",), ("-name", "Vanta Distribution")]:
            with self.subTest(options=options):
                self.create_p12(options)
                command = ["openssl", "pkcs12", "-legacy", "-in", str(self.p12),
                           "-passin", "env:IOS_DISTRIBUTION_CERTIFICATE_PASSWORD", "-noenc"]
                original_material = release.run(command)
                original_files = set(self.directory.iterdir())
                release.normalize_pkcs12(self.p12)
                # Compare cryptographic identity, allowing bag attributes
                # such as a Keychain friendly name to change during export.
                normalized_material = release.run(command)
                for identity_command in [
                    ["openssl", "x509", "-outform", "DER"],
                    ["openssl", "pkey", "-pubout", "-outform", "DER"],
                ]:
                    self.assertEqual(
                        release.run(identity_command, stdin=normalized_material),
                        release.run(identity_command, stdin=original_material),
                    )
                self.assertEqual(set(self.directory.iterdir()), original_files)
                self.assertEqual(stat.S_IMODE(self.p12.stat().st_mode), 0o600)
                info = subprocess.run([
                    "openssl", "pkcs12", "-in", str(self.p12), "-info", "-noout",
                    "-passin", "env:IOS_DISTRIBUTION_CERTIFICATE_PASSWORD",
                ], capture_output=True, text=True)
                self.assertEqual(info.returncode, 0, info.stderr)
                self.assertIn("MAC: sha1,", info.stderr)
                self.assertIn("pbeWithSHA1And3-KeyTripleDES-CBC", info.stderr)
                self.assertNotIn("AES-256-CBC", info.stderr)

    def test_wrong_export_password_is_reported_before_keychain_import(self):
        self.create_p12()
        original_p12 = self.p12.read_bytes()
        os.environ["IOS_DISTRIBUTION_CERTIFICATE_PASSWORD"] = "wrong-test-password"
        with self.assertRaisesRegex(release.ReleaseError, "Export Password.*invalid password") as caught:
            release.normalize_pkcs12(self.p12)
        self.assertNotIn("wrong-test-password", str(caught.exception))
        self.assertNotIn(self.password, str(caught.exception))
        self.assertEqual(self.p12.read_bytes(), original_p12)

    @unittest.skipUnless(sys.platform == "darwin", "macOS Keychain import requires macOS")
    def test_mac_keychain_imports_normalized_openssl_p12(self):
        self.create_p12()
        release.normalize_pkcs12(self.p12)
        keychain = self.directory / "test-signing.keychain-db"
        try:
            release.run(["security", "create-keychain", "-p", self.password, str(keychain)])
            release.run(["security", "unlock-keychain", "-p", self.password, str(keychain)])
            release.run([
                "security", "import", str(self.p12), "-P", self.password,
                "-T", "/usr/bin/codesign", "-k", str(keychain),
            ])
        finally:
            if keychain.exists():
                release.run(["security", "delete-keychain", str(keychain)])

    def test_corrupt_p12_does_not_expose_secret_contents(self):
        invalid = b"private-invalid-p12-content"
        release.write_private(self.p12, invalid)
        with self.assertRaisesRegex(release.ReleaseError, "complete .p12") as caught:
            release.normalize_pkcs12(self.p12)
        self.assertNotIn(invalid.decode(), str(caught.exception))
        self.assertNotIn(self.password, str(caught.exception))


class ReleaseToolTests(unittest.TestCase):
    def test_formal_release_guard_still_requires_main(self):
        workflow = Path(__file__).resolve().parents[1] / ".github/workflows/release.yml"
        step = workflow.read_text().split("      - name: Validate version and decide release\n", 1)[1]
        script = step.split("        run: |\n", 1)[1].split("          git fetch --tags --force\n", 1)[0]
        guard = textwrap.dedent(script)
        for branch, version, expected_status in [
            ("main", "0.8.1+29", 0),
            ("release/0.8.1", "0.8.1+29", 1),
            ("release/0.8.1", "0.8.1-rc.1+29", 0),
        ]:
            with self.subTest(branch=branch, version=version), tempfile.TemporaryDirectory() as temporary:
                Path(temporary, "pubspec.yaml").write_text(f"version: {version}\n")
                result = subprocess.run(["bash", "-c", guard], cwd=temporary,
                                        env={**os.environ, "TARGET_BRANCH": branch},
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, expected_status, result.stderr)
                if expected_status:
                    self.assertIn("Formal releases are only allowed from the main branch", result.stderr)

    def test_prepares_target_signing_configuration_and_temporary_keychain(self):
        with tempfile.TemporaryDirectory() as temporary:
            temporary = Path(temporary)
            directory = temporary / "signing"
            outputs = temporary / "outputs"
            environment = {
                "APPLE_TEAM_ID": TEAM,
                "IOS_DISTRIBUTION_CERTIFICATE_BASE64": base64.b64encode(b"p12").decode(),
                "IOS_DISTRIBUTION_CERTIFICATE_PASSWORD": "test-password",
                "IOS_PROVISIONING_PROFILE_BASE64": base64.b64encode(b"profile").decode(),
                "GITHUB_OUTPUT": str(outputs),
            }

            def command(arguments, *, stdin=None):
                if arguments[:2] == ["openssl", "pkcs12"]:
                    return b"mock normalized p12" if "-export" in arguments else b"mock private signing material"
                if arguments == ["security", "list-keychains", "-d", "user"]:
                    return b'"/original/login.keychain-db"\n'
                if arguments[:2] == ["security", "cms"]:
                    return plistlib.dumps(distribution_profile())
                if arguments[:2] == ["security", "find-identity"]:
                    return f'  1) {IDENTITY} "Apple Distribution: Test"\n'.encode()
                if arguments[:2] == ["security", "import"]:
                    self.assertEqual(Path(arguments[2]).read_bytes(), b"mock normalized p12")
                return b""

            with patch.dict(os.environ, environment, clear=True), patch.object(release.Path, "home", return_value=temporary), patch.object(release, "run", side_effect=command) as calls:
                release.prepare_signing(directory)
                settings = (directory / "RunnerSigning.xcconfig").read_text()
                self.assertIn(f"DEVELOPMENT_TEAM = {TEAM}", settings)
                self.assertIn(f"PROVISIONING_PROFILE_SPECIFIER = {PROFILE_UUID}", settings)
                self.assertIn(f"CODE_SIGN_IDENTITY = {IDENTITY}", settings)
                self.assertNotIn("test-password", settings + outputs.read_text())
                self.assertFalse((directory / "distribution.p12").exists())
                self.assertEqual(plistlib.loads((directory / "ExportOptions.plist").read_bytes())["signingStyle"], "manual")
                self.assertIn(["security", "list-keychains", "-d", "user", "-s",
                               str(directory / "signing.keychain-db"), "/original/login.keychain-db"],
                              [call.args[0] for call in calls.call_args_list])
                release.cleanup(directory)
            self.assertFalse(directory.exists())
            installed = temporary / "Library/Developer/Xcode/UserData/Provisioning Profiles" / f"{PROFILE_UUID}.mobileprovision"
            self.assertFalse(installed.exists())

    def test_installed_profile_and_signing_specifier_preserve_lowercase_uuid(self):
        with tempfile.TemporaryDirectory() as temporary:
            temporary = Path(temporary)
            directory = temporary / "signing"
            profile = distribution_profile()
            profile_uuid = PROFILE_UUID.lower()
            profile["UUID"] = profile_uuid
            payload = plistlib.dumps(profile)
            environment = {
                "APPLE_TEAM_ID": TEAM,
                "IOS_DISTRIBUTION_CERTIFICATE_BASE64": base64.b64encode(b"p12").decode(),
                "IOS_DISTRIBUTION_CERTIFICATE_PASSWORD": "test-password",
                "IOS_PROVISIONING_PROFILE_BASE64": base64.b64encode(payload).decode(),
                "GITHUB_OUTPUT": str(temporary / "outputs"),
            }

            def command(arguments):
                if arguments == ["security", "list-keychains", "-d", "user"]:
                    return b'"/original/login.keychain-db"\n'
                if arguments[:2] == ["security", "cms"]:
                    return payload
                if arguments[:2] == ["security", "find-identity"]:
                    return f'  1) {IDENTITY} "Apple Distribution: Test"\n'.encode()
                return b""

            installed = temporary / "Library/Developer/Xcode/UserData/Provisioning Profiles" / f"{profile_uuid}.mobileprovision"
            with patch.dict(os.environ, environment, clear=True), patch.object(release.Path, "home", return_value=temporary), patch.object(release, "normalize_pkcs12"), patch.object(release, "run", side_effect=command):
                release.prepare_signing(directory)
                self.assertEqual(installed.read_bytes(), payload)
                self.assertIn(
                    f"PROVISIONING_PROFILE_SPECIFIER = {profile_uuid}\n",
                    (directory / "RunnerSigning.xcconfig").read_text(),
                )
                options = plistlib.loads((directory / "ExportOptions.plist").read_bytes())
                self.assertEqual(options["provisioningProfiles"], {release.BUNDLE_ID: profile_uuid})
                release.cleanup(directory)
            self.assertFalse(installed.exists())

    def test_failed_security_command_does_not_log_password_arguments(self):
        result = subprocess.CompletedProcess([], 1, b"", b"MAC verification failed (wrong password?)")
        with patch.object(release.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(release.ReleaseError, "wrong password") as caught:
                release.run(["security", "import", "certificate.p12", "-P", "secret-password"])
        self.assertNotIn("secret-password", str(caught.exception))

    def test_missing_signing_configuration_fails_before_calling_security(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(release, "run") as command:
            with self.assertRaisesRegex(release.ReleaseError, "IOS_DISTRIBUTION_CERTIFICATE_BASE64"):
                release.prepare_signing(Path("unused"))
            command.assert_not_called()

    def test_cleanup_removes_keys_and_profile_even_if_keychain_restore_fails(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "signing"
            profile = Path(temporary) / "test.mobileprovision"
            profile.write_bytes(b"profile")
            release.write_private(directory / "original-keychains.txt", b'"/original/login.keychain-db"\n')
            release.write_private(directory / "signing.keychain-db", b"keychain")
            release.write_private(directory / "private_keys/AuthKey_TEST.p8", b"key")
            release.write_private(directory / "installed-profile-path.txt", str(profile).encode())
            with patch.object(release, "run", side_effect=[release.ReleaseError("restore failed"), b""]) as command:
                with self.assertRaisesRegex(release.ReleaseError, "restore failed"):
                    release.cleanup(directory)
                self.assertEqual(command.call_count, 2)
            self.assertFalse(directory.exists())
            self.assertFalse(profile.exists())

    def test_ipa_verifier_checks_exported_entitlements_and_certificate(self):
        for invalid_debug in [False, True]:
            with self.subTest(invalid_debug=invalid_debug), tempfile.TemporaryDirectory() as temporary:
                directory = Path(temporary)
                ipa = directory / "test.ipa"
                with zipfile.ZipFile(ipa, "w") as archive:
                    archive.writestr("Payload/Runner.app/Info.plist", plistlib.dumps({"CFBundleIdentifier": release.BUNDLE_ID, "CFBundleExecutable": "Runner"}))
                profile = distribution_profile()
                signed = copy.deepcopy(profile["Entitlements"])
                if invalid_debug:
                    signed["get-task-allow"] = True

                def command(arguments):
                    if arguments[0] == "ditto":
                        with zipfile.ZipFile(arguments[3]) as archive:
                            archive.extractall(arguments[4])
                    elif "--entitlements" in arguments:
                        return plistlib.dumps(signed)
                    elif arguments[0] == "codesign" and arguments[2].startswith("--extract-certificates="):
                        Path(arguments[2].partition("=")[2] + "0").write_bytes(CERTIFICATE)
                    elif arguments[:2] == ["security", "cms"]:
                        return plistlib.dumps(profile)
                    return b""

                with patch.dict(os.environ, {"APPLE_TEAM_ID": TEAM}), patch.object(release, "run", side_effect=command):
                    if invalid_debug:
                        with self.assertRaisesRegex(release.ReleaseError, "get-task-allow"):
                            release.verify_ipa(ipa, directory)
                    else:
                        release.verify_ipa(ipa, directory)


if __name__ == "__main__":
    unittest.main()
