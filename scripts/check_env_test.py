from pathlib import Path
import tempfile
import unittest

from check_env import check_environment


class LocalEnvironmentTests(unittest.TestCase):
    def check(self, extra="", *, app="app", client="client", project="project"):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "app config.env"
            path.write_text(f"PRIVY_APP_ID={app}\nPRIVY_CLIENT_ID={client}\n"
                            f"REOWN_PROJECT_ID={project}\n{extra}", encoding="utf-8")
            return check_environment(path)

    def test_public_values_support_comments_quotes_crlf_and_default_origin(self):
        values = self.check("# comment\r\n", app="'app' # app id", client='"client"')
        self.assertEqual(values["PRIVY_APP_ID"], "app")
        self.assertEqual(values["PRIVY_CLIENT_ID"], "client")
        self.assertEqual(values["WALLET_LOGIN_ORIGIN"], "https://app.vanta.exchange")

    def test_shell_syntax_is_literal_and_never_executed(self):
        values = self.check(app="'$(exit 99)'", client="'${SOME_VARIABLE}'")
        self.assertEqual(values["PRIVY_APP_ID"], "$(exit 99)")
        self.assertEqual(values["PRIVY_CLIENT_ID"], "${SOME_VARIABLE}")

    def test_blank_and_quoted_blank_required_values_are_rejected(self):
        for value in ["", '""', "''", "# comment", "' '"]:
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "PRIVY_APP_ID"):
                self.check(app=value)

    def test_secrets_and_unknown_keys_cannot_be_compiled_into_the_app(self):
        for key in ["OPENAI_KEY", "ANDROID_KEYSTORE_PASSWORD", "APP_STORE_CONNECT_PRIVATE_KEY_BASE64", "TYPO"]:
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "Unsupported") as error:
                self.check(f"{key}=sensitive-value\n")
            self.assertNotIn("sensitive-value", str(error.exception))

    def test_duplicate_keys_and_malformed_values_fail_without_exposing_values(self):
        for extra in ["PRIVY_APP_ID=secret-value", "export PRIVY_APP_ID=secret-value",
                      "PRIVY_CLIENT_ID", 'WALLET_LOGIN_ORIGIN="secret-value',
                      "WALLET_LOGIN_ORIGIN=secret value"]:
            with self.subTest(extra=extra), self.assertRaises(ValueError) as error:
                self.check(extra)
            self.assertNotIn("secret-value", str(error.exception))

    def test_wallet_origin_uses_the_same_validation_as_ci(self):
        self.assertEqual(self.check("WALLET_LOGIN_ORIGIN=https://example.com/")["WALLET_LOGIN_ORIGIN"],
                         "https://example.com")
        with self.assertRaisesRegex(ValueError, "HTTPS origin"):
            self.check("WALLET_LOGIN_ORIGIN=http://example.com")

    def test_vanta_api_origin_is_optional_and_https_only(self):
        self.assertEqual(self.check()["VANTA_API_ORIGIN"], "")
        self.assertEqual(self.check("VANTA_API_ORIGIN=https://api.example.com/")["VANTA_API_ORIGIN"],
                         "https://api.example.com")
        for value in ["http://api.example.com", "https://api.example.com/v1"]:
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "VANTA_API_ORIGIN"):
                self.check(f"VANTA_API_ORIGIN={value}")
