import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../support/locale_preferences.dart';
import '../support/trade_fixture.dart';

void main() {
  test('English and Chinese ARB catalogs have identical nonempty message coverage', () {
    Map<String, dynamic> catalog(String language) =>
        jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync()) as Map<String, dynamic>;
    final en = catalog('en'), zh = catalog('zh');
    final keys = en.keys.where((key) => !key.startsWith('@')).toSet();
    expect(zh.keys.where((key) => !key.startsWith('@')).toSet(), keys);
    for (final key in keys) {
      expect(en[key], isA<String>().having((text) => text.isNotEmpty, 'not empty', true));
      expect(zh[key], isA<String>().having((text) => text.isNotEmpty, 'not empty', true));
    }
  });

  test(
    'language preference saves, restores, and reports recoverable persistence failures',
    () async {
      final store = MemoryLocalePreferences();
      final first = ProviderContainer(
        overrides: [localePreferencesProvider.overrideWithValue(store)],
      );
      expect(first.read(localeProvider), null);
      await first.read(localeProvider.notifier).select('en');
      expect(store.value, 'en');
      first.dispose();
      final second = ProviderContainer(
        overrides: [
          localePreferencesProvider.overrideWithValue(store),
          initialLocaleProvider.overrideWithValue(localeFromPreference(await store.read())),
        ],
      );
      expect(second.read(localeProvider), const Locale('en'));
      store.fail = true;
      await second.read(localeProvider.notifier).select('zh');
      expect(second.read(localeProvider), const Locale('zh'));
      expect(second.read(localeSaveErrorProvider), true);
      store.fail = false;
      await second.read(localeProvider.notifier).select('zh');
      expect(second.read(localeSaveErrorProvider), false);
      expect(store.value, 'zh');
      await second.read(localeProvider.notifier).select(null);
      expect(store.value, null);
      expect(second.read(localeProvider), null);
      await second.read(localeProvider.notifier).select('unsupported');
      expect(second.read(localeProvider), null);
      second.dispose();
    },
  );

  testWidgets('language picker updates the open application and preserves chart selection', (
    tester,
  ) async {
    final store = MemoryLocalePreferences();
    final container = setup(tester, localePreferences: store);
    await launch(tester, container);
    container.read(symbolProvider.notifier).select('ETHUSDT');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trade-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    expect(find.text('跟随系统'), findsOneWidget);
    await tester.tap(find.byKey(const Key('language-en')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trade-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(container.read(symbolProvider), 'ETHUSDT');
    expect(store.value, 'en');
    await tester.tap(find.byKey(const Key('account-button')));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byKey(const Key('login-email'))));
    expect(l10n.localeName, 'en');
    expect(find.text(l10n.authWelcome), findsOneWidget);
    expect(find.text(l10n.authWalletContinue), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'system language follows Chinese and falls back to English for unsupported languages',
    (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final container = setup(tester, language: null);
      await launch(tester, container);
      var context = tester.element(find.byType(Scaffold).first);
      expect(AppLocalizations.of(context).language, '语言');
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      await tester.pumpAndSettle();
      context = tester.element(find.byType(Scaffold).first);
      expect(AppLocalizations.of(context).language, 'Language');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
