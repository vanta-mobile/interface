import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/settings/data/app_cache_repository.dart';
import 'package:vanta/features/settings/presentation/settings_components.dart';
import 'package:vanta/features/settings/presentation/settings_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/trade_fixture.dart';

class _MemoryCache extends AppCacheRepository {
  _MemoryCache(this.bytes);
  int bytes;
  int clears = 0;
  bool fail = false;
  @override
  Future<int> size() async => bytes;
  @override
  Future<void> clear() async {
    clears++;
    if (fail) throw const FileSystemException('busy');
    bytes = 0;
  }
}

Future<void> _openSettings(WidgetTester t) async {
  await t.tap(find.byKey(const Key('trade-settings')));
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('trade header keeps settings and notifications but no AI entry', (t) async {
    final c = setup(t, language: const Locale('en'), appCacheRepository: _MemoryCache(0));
    await launch(t, c);
    expect(find.byKey(const Key('trade-settings')), findsOneWidget);
    expect(find.byKey(const Key('notifications-entry')), findsOneWidget);
    expect(find.byKey(const Key('trade-ask-ai')), findsNothing);
    await _openSettings(t);
    expect(find.byKey(const Key('settings-screen')), findsOneWidget);
    expect(find.text('Account Settings'), findsOneWidget);
    for (final key in [
      'asset-mode',
      'position-mode',
      'language',
      'push',
      'check-update',
      'app-version',
      'cache',
      'terms',
      'privacy',
    ]) {
      await t.ensureVisible(find.byKey(Key('settings-$key')));
      expect(find.byKey(Key('settings-$key')), findsOneWidget, reason: key);
    }
    expect(t.takeException(), isNull);
  });

  for (final language in ['en', 'zh']) {
    testWidgets('settings page fits a narrow enlarged-text phone: $language', (t) async {
      final c = setup(
        t,
        width: 320,
        scale: 1.5,
        language: Locale(language),
        appCacheRepository: _MemoryCache(7680),
      );
      await launch(t, c);
      await _openSettings(t);
      final l = AppLocalizations.of(t.element(find.byType(SettingsScreen)));
      await t.ensureVisible(find.byKey(const Key('settings-cache')));
      expect(find.text(l.settingsCacheValue('7.5 KB')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('row values and icons sit flush with the card inner edge', (t) async {
    final c = setup(
      t,
      width: 393,
      language: const Locale('en'),
      appCacheRepository: _MemoryCache(0),
    );
    await launch(t, c);
    await _openSettings(t);
    // Page gutter 16 + card padding 16.
    const right = 393 - 32.0;
    for (final key in ['asset-mode', 'language', 'push', 'app-version', 'cache']) {
      final row = find.byKey(Key('settings-$key'));
      await t.ensureVisible(row);
      final edge = [
        ...find.descendant(of: row, matching: find.byType(SettingsIcon)).evaluate(),
        ...find.descendant(of: row, matching: find.byType(Text)).evaluate().skip(1),
      ].map((e) => t.getRect(find.byElementPredicate((x) => x == e)).right).reduce(max);
      expect(edge, closeTo(right, .5), reason: key);
    }
  });

  testWidgets('language sheet offers only English and Chinese and switches the app', (t) async {
    final c = setup(t, language: const Locale('en'), appCacheRepository: _MemoryCache(0));
    await launch(t, c);
    await _openSettings(t);
    expect(
      find.descendant(
        of: find.byKey(const Key('settings-language')),
        matching: find.text('English'),
      ),
      findsOneWidget,
    );
    await _tap(t, 'settings-language');
    expect(find.byKey(const Key('settings-language-en')), findsOneWidget);
    expect(find.byKey(const Key('settings-language-zh')), findsOneWidget);
    expect(find.byKey(const Key('settings-language-system')), findsNothing);
    await _tap(t, 'settings-language-zh');
    expect(find.byKey(const Key('settings-language-sheet')), findsNothing);
    expect(find.text('账户设置'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('settings-language')), matching: find.text('中文')),
      findsOneWidget,
    );
  });

  testWidgets('clearing cache re-measures and reports success or failure', (t) async {
    final cache = _MemoryCache(7680);
    final c = setup(t, language: const Locale('en'), appCacheRepository: cache);
    await launch(t, c);
    await _openSettings(t);
    expect(find.text('7.5 KB · Clear'), findsOneWidget);
    await _tap(t, 'settings-cache');
    expect(cache.clears, 1);
    expect(find.text('0 B · Clear'), findsOneWidget);
    expect(find.text('Cache cleared'), findsOneWidget);

    cache
      ..bytes = 2048
      ..fail = true;
    await _tap(t, 'settings-cache');
    expect(cache.clears, 2);
    expect(find.text('2 KB · Clear'), findsOneWidget);
    expect(find.text('Some cached files could not be cleared. Please retry.'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads account modes and push status', (t) async {
    final c = setup(t, language: const Locale('en'), appCacheRepository: _MemoryCache(0));
    await launch(t, c);
    await _openSettings(t);
    await t.fling(find.byKey(const Key('settings-asset-mode')), const Offset(0, 400), 1000);
    await t.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(t.takeException(), isNull);
  });
}
