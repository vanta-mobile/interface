import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from upload_sentry_symbols import symbol_map_pairs, upload, upload_symbol_map


class SymbolUploadTests(unittest.TestCase):
    def test_missing_credentials_stop_before_any_upload(self):
        with patch('upload_sentry_symbols.subprocess.run') as run:
            with self.assertRaisesRegex(ValueError, 'SENTRY_AUTH_TOKEN'):
                upload('android', {})
            run.assert_not_called()

    def test_uploads_both_android_symbol_sets_without_sources_or_token_arguments(self):
        environment = dict(SENTRY_AUTH_TOKEN='private-token', SENTRY_ORG='org', SENTRY_PROJECT='app')
        with patch('upload_sentry_symbols.shutil.which', return_value='/cli'), \
             patch('upload_sentry_symbols.Path.is_dir', return_value=True), \
             patch('upload_sentry_symbols.Path.rglob', side_effect=lambda _: iter(['symbol'])), \
             patch('upload_sentry_symbols.symbol_map_pairs', return_value=[]), \
             patch('upload_sentry_symbols.subprocess.run') as run:
            upload('android', environment)
            args = run.call_args.args[0]
            self.assertIn('build/symbols/android', args)
            self.assertIn('build/symbols/android-bundle', args)
            self.assertIn('--wait', args)
            self.assertNotIn('--include-sources', args)
            self.assertNotIn('private-token', args)

    def test_missing_symbol_directory_fails(self):
        environment = dict(SENTRY_AUTH_TOKEN='token', SENTRY_ORG='org', SENTRY_PROJECT='app')
        with patch('upload_sentry_symbols.shutil.which', return_value='/cli'), \
             patch('upload_sentry_symbols.Path.is_dir', return_value=False), \
             patch('upload_sentry_symbols.subprocess.run') as run:
            with self.assertRaisesRegex(ValueError, 'Missing symbols'):
                upload('ios', environment)
            run.assert_not_called()


class SymbolMapTests(unittest.TestCase):
    def setUp(self):
        self.previous = os.getcwd()
        self.directory = tempfile.TemporaryDirectory()
        os.chdir(self.directory.name)

    def tearDown(self):
        os.chdir(self.previous)
        self.directory.cleanup()

    def test_pairs_each_android_map_with_its_own_build_symbols(self):
        for build in ('android', 'android-bundle'):
            Path(f'build/symbols/{build}').mkdir(parents=True)
            Path(f'build/symbols/{build}/app.android-arm64.symbols').touch()
            Path(f'build/symbols/{build}/app.android-x64.symbols').touch()
        Path('build/obfuscation').mkdir()
        Path('build/obfuscation/android.json').write_text('[]')
        Path('build/obfuscation/android-bundle.json').write_text('[]')
        pairs = symbol_map_pairs('android')
        self.assertEqual(len(pairs), 4)
        self.assertIn(('build/obfuscation/android-bundle.json',
                       'build/symbols/android-bundle/app.android-x64.symbols'), pairs)
        self.assertNotIn(('build/obfuscation/android.json',
                          'build/symbols/android-bundle/app.android-x64.symbols'), pairs)

    def test_missing_map_fails_instead_of_silently_skipping(self):
        with self.assertRaisesRegex(ValueError, 'Missing obfuscation map'):
            symbol_map_pairs('ios')

    def test_map_upload_prefixes_debug_id_marker_and_removes_temporary_file(self):
        Path('map.json').write_text(json.dumps(['a', 'b']))
        uploaded = []

        def run(args, **_):
            if args[1] == 'debug-files':
                return subprocess.CompletedProcess(args, 0, stdout=json.dumps(
                    {'variants': [{'debug_id': 'abc-123'}]}))
            uploaded.append(json.loads(Path(args[3]).read_text()))
            self.assertEqual(args[1:3], ['dart-symbol-map', 'upload'])
            self.assertEqual(args[4], 'app.symbols')
            return subprocess.CompletedProcess(args, 0)

        with patch('upload_sentry_symbols.subprocess.run', side_effect=run):
            upload_symbol_map('/cli', 'map.json', 'app.symbols', {})
        self.assertEqual(uploaded, [['SENTRY_DEBUG_ID_MARKER', 'abc-123', 'a', 'b']])
        self.assertEqual(sorted(p.name for p in Path('.').iterdir()), ['map.json'])
        self.assertEqual(json.loads(Path('map.json').read_text()), ['a', 'b'])
