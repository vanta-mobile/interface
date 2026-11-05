import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest

from google_play_release import SECRET


SCRIPT = Path(__file__).with_name("google_play_release.py")
FAKE_KEY = "-----BEGIN PRIVATE KEY-----\nFAKE-KEY-FOR-TEST-ONLY\n-----END PRIVATE KEY-----\n"


class GooglePlayReleaseTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.output = self.root / "outputs"
        self.credentials = self.root / "vanta-google-play" / "service-account.json"
        self.account = dict(type="service_account", project_id="test-project",
                            client_email="test@test-project.iam.gserviceaccount.com",
                            private_key=FAKE_KEY,
                            token_uri="https://oauth2.googleapis.com/token")

    def run_script(self, command="configure", raw=None):
        environment = dict(os.environ, RUNNER_TEMP=str(self.root),
                           GITHUB_OUTPUT=str(self.output))
        environment.pop(SECRET, None)
        if raw is not None:
            environment[SECRET] = raw
        return subprocess.run([sys.executable, str(SCRIPT), command],
                              env=environment, capture_output=True, text=True)

    def test_missing_or_whitespace_secret_skips_without_files(self):
        for raw in (None, "", " \n\t "):
            with self.subTest(raw=raw):
                self.output.unlink(missing_ok=True)
                result = self.run_script(raw=raw)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.output.read_text(), "enabled=false\n")
                self.assertFalse(self.credentials.parent.exists())
                self.assertEqual(result.stdout + result.stderr, "")

    def test_valid_json_is_private_and_cleanup_is_idempotent(self):
        raw = json.dumps(self.account, indent=2)
        result = self.run_script(raw=raw)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.credentials.read_text()), self.account)
        self.assertEqual(stat.S_IMODE(self.credentials.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.credentials.parent.stat().st_mode), 0o700)
        self.assertEqual(self.output.read_text(),
                         f"enabled=true\ncredentials_path={self.credentials}\n")
        self.assertEqual(result.stdout + result.stderr, "")
        self.assertNotIn(FAKE_KEY, self.output.read_text())
        for _ in range(2):
            result = self.run_script("cleanup")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(self.credentials.parent.exists())

    def test_invalid_credentials_fail_without_logging_payload(self):
        invalid = ["sensitive-invalid-json", "eyJ0eXBlIjogInNlcnZpY2VfYWNjb3VudCJ9",
                   "null", "[]", '"sensitive-json-string"',
                   json.dumps(dict(self.account, type="authorized_user")),
                   json.dumps(dict(self.account, token_uri="https://example.com/secret")),
                   json.dumps(dict(self.account, private_key="sensitive-key"))]
        for field in ("project_id", "client_email", "private_key", "token_uri"):
            for value in (None, " \n", 123):
                invalid.append(json.dumps(dict(self.account, **{field: value})))
        for raw in invalid:
            with self.subTest(raw=raw):
                result = self.run_script(raw=raw)
                self.assertEqual(result.returncode, 1)
                self.assertIn(SECRET, result.stderr)
                self.assertNotIn(raw, result.stderr)
                self.assertNotIn("sensitive-", result.stderr)
                self.assertNotIn("Traceback", result.stderr)
                self.assertFalse(self.credentials.parent.exists())
                self.assertFalse(self.output.exists())

    def test_cleanup_removes_credentials_after_output_failure(self):
        self.output.mkdir()
        result = self.run_script(raw=json.dumps(self.account))
        self.assertEqual(result.returncode, 1)
        self.assertTrue(self.credentials.exists())
        self.assertNotIn(FAKE_KEY, result.stderr)
        result = self.run_script("cleanup")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.credentials.parent.exists())

    def test_existing_directory_is_not_overwritten(self):
        self.credentials.parent.mkdir()
        self.credentials.write_text("existing")
        result = self.run_script(raw=json.dumps(self.account))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.credentials.read_text(), "existing")
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
