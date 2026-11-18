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

    def test_sentry_requires_public_dsn_and_explicit_environment(self):
        base = dict(PRIVY_APP_ID='app', PRIVY_CLIENT_ID='client', REOWN_PROJECT_ID='project')
        for dsn, environment in [
                ('https://key:secret@example.com/1', 'staging'),
                ('http://key@example.com/1', 'staging'),
                ('https://key@example.com/1?secret=value', 'staging'),
                ('https://key@example.com/1', ''),
                ('https://key@example.com/1', 'typo')]:
            with self.subTest(dsn=dsn), self.assertRaises(ValueError) as error:
                configuration(dict(base, SENTRY_DSN=dsn, SENTRY_ENVIRONMENT=environment))
            self.assertNotIn('secret=value', str(error.exception))
        result = configuration(dict(base, SENTRY_DSN='https://key@example.com/1',
                                    SENTRY_ENVIRONMENT='staging', SENTRY_AUTH_TOKEN='private-token'))
        self.assertEqual(result['SENTRY_ENVIRONMENT'], 'staging')
        self.assertNotIn('SENTRY_AUTH_TOKEN', result)
