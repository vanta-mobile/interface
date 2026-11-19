from pathlib import Path
import sys
import tempfile
import unittest

from retry_transient_build import is_transient, run

RATE_LIMITED = ("> Could not HEAD 'https://repo.maven.apache.org/maven2/a.jar'. "
                "Received status code 429 from server: Too Many Requests")


def script(*outputs_and_codes):
    """A command that prints the next scripted output and exits with its code."""
    lines = ";".join(
        f"print({output!r}) if n == {index} else None;"
        f"sys.exit({code}) if n == {index} else None"
        for index, (output, code) in enumerate(outputs_and_codes))
    return [sys.executable, "-c",
            "import sys, pathlib;"
            "p = pathlib.Path(sys.argv[1]); n = int(p.read_text()) if p.exists() else 0;"
            "p.write_text(str(n + 1));" + lines]


class RetryTransientBuildTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.counter = str(Path(directory.name) / "attempts")
        self.sleeps = []

    def command(self, *outputs_and_codes):
        return script(*outputs_and_codes) + [self.counter]

    def test_detects_maven_rate_limit_and_server_errors(self):
        self.assertTrue(is_transient(RATE_LIMITED))
        self.assertTrue(is_transient("Received status code 503 from server: Service Unavailable"))
        self.assertFalse(is_transient("e: lib/main.kt: Unresolved reference: foo"))
        self.assertFalse(is_transient("Received status code 404 from server: Not Found"))

    def test_retries_rate_limited_build_until_success(self):
        code = run(self.command((RATE_LIMITED, 1), ("BUILD SUCCESSFUL", 0)),
                   sleep=self.sleeps.append)
        self.assertEqual(code, 0)
        self.assertEqual(self.sleeps, [60])

    def test_does_not_retry_other_failures(self):
        code = run(self.command(("Compilation error", 1), ("BUILD SUCCESSFUL", 0)),
                   sleep=self.sleeps.append)
        self.assertEqual(code, 1)
        self.assertEqual(self.sleeps, [])

    def test_stops_after_last_attempt(self):
        code = run(self.command(*[(RATE_LIMITED, 1)] * 4), attempts=3,
                   sleep=self.sleeps.append)
        self.assertEqual(code, 1)
        self.assertEqual(self.sleeps, [60, 180])


if __name__ == "__main__":
    unittest.main()
