import base64
import json
from pathlib import Path
import tempfile
import unittest

from vanta_api_contract import check, digest, sync


class VantaApiContractTests(unittest.TestCase):
    def test_vendored_contract_matches_lock(self):
        self.assertRegex(check()["commit"], r"^[0-9a-f]{40}$")

    def test_sync_pins_resolved_commit_and_hash(self):
        body = b"---\nopenapi: 3.1.0\n"
        calls = []

        def fetch(*arguments):
            calls.append(arguments[0])
            return "a" * 40 if "/commits/" in arguments[0] else base64.b64encode(body).decode()

        with tempfile.TemporaryDirectory() as temporary:
            spec, lock = Path(temporary) / "openapi.yaml", Path(temporary) / "lock.json"
            self.assertEqual(sync("main", fetch=fetch, spec=spec, lock=lock), "a" * 40)
            self.assertEqual(spec.read_bytes(), body)
            self.assertEqual(json.loads(lock.read_text())["sha256"], digest(body))
            self.assertIn("ref=" + "a" * 40, calls[1])
            check(spec=spec, lock=lock)
            spec.write_bytes(body + b"# edited\n")
            with self.assertRaisesRegex(ValueError, "does not match"):
                check(spec=spec, lock=lock)


if __name__ == "__main__":
    unittest.main()
