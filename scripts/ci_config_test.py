import unittest

from ci_config import configuration


class ConfigurationTests(unittest.TestCase):
    def test_release_uses_only_vanta_public_configuration(self):
        values = configuration(dict(PRIVY_APP_ID='app', PRIVY_CLIENT_ID='client',
                                    REOWN_PROJECT_ID='project', UNUSED_SECRET='sensitive'))
        self.assertEqual(values, dict(PRIVY_APP_ID='app', PRIVY_CLIENT_ID='client',
                                     REOWN_PROJECT_ID='project',
                                     WALLET_LOGIN_ORIGIN='https://app.vanta.exchange',
                                     VANTA_API_ORIGIN=''))

    def test_missing_variables_fail_without_exposing_values(self):
        with self.assertRaisesRegex(ValueError, 'PRIVY_CLIENT_ID, REOWN_PROJECT_ID') as error:
            configuration({'PRIVY_APP_ID': 'private-value'})
        self.assertNotIn('private-value', str(error.exception))

    def test_rejects_invalid_wallet_origins(self):
        for origin in ['http://example.com', 'https://user:password@example.com',
                       'https://example.com/path', 'https://example.com?secret=value', 'invalid']:
            with self.subTest(origin=origin), self.assertRaises(ValueError):
                configuration(dict(PRIVY_APP_ID='app', PRIVY_CLIENT_ID='client',
                                   REOWN_PROJECT_ID='project', WALLET_LOGIN_ORIGIN=origin))
