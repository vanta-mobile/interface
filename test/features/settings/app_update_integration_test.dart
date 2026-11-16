import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/core/vanta_api/vanta_api_http.dart';
import 'package:vanta/features/settings/application/settings_providers.dart';
import 'package:vanta/features/settings/data/app_update_repository.dart';
import 'package:vanta/features/settings/domain/app_version.dart';
import 'package:vanta/features/settings/presentation/settings_app_card.dart';
import 'package:vanta/features/settings/presentation/settings_update_sheet.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/vanta_api.dart';

Map<String, Object?> release({
  String latest = '2.0.0',
  bool force = false,
  Object? url = 'https://example.test/app',
}) => {
  'latest_version': latest,
  'force_update': force,
  'store_url': url,
  'release_notes': {'en': 'Improved order history', 'zh': '完善订单历史'},
};
AppVersion version(String text) => AppVersion.tryParse(text)!;

void main() {
  test('platform selection, language fallback and forced/minimum version comparisons', () {
    final config = mapAppUpdateConfiguration({
      'min_supported_version': '1.1.0',
      'update': {'ios': release(latest: '3.0.0', force: true), 'android': release()},
    }, 'android');
    expect(config.release!.latest.text, '2.0.0');
    expect(() => config.release!.latest.parts[0] = 9, throwsUnsupportedError);
    expect(config.release!.notesFor('zh-Hant'), '完善订单历史');
    expect(config.release!.notesFor('fr'), 'Improved order history');
    expect(config.release!.storeUri, Uri.parse('https://example.test/app'));
    final optional = AppUpdateCheck(
      current: version('1.5.0'),
      minimum: config.minimum,
      release: config.release,
    );
    expect(optional.updateAvailable, isTrue);
    expect(optional.updateRequired, isFalse);
    final forced = mapAppUpdateConfiguration({
      'update': {'ios': release(force: true)},
    }, 'ios');
    expect(
      AppUpdateCheck(current: version('1.5.0'), release: forced.release).updateRequired,
      isTrue,
    );
    expect(
      AppUpdateCheck(current: version('2.0.0'), release: forced.release).updateRequired,
      isFalse,
    );
    expect(
      AppUpdateCheck(current: version('2.1.0'), release: forced.release).updateAvailable,
      isFalse,
    );
    expect(
      AppUpdateCheck(
        current: version('1.0.0'),
        minimum: config.minimum,
        release: config.release,
      ).updateRequired,
      isTrue,
    );
    expect(
      mapAppUpdateConfiguration({
        'update': {'ios': release()},
      }, 'android').release,
      isNull,
    );
    expect(mapAppUpdateConfiguration({'update': <String, Object?>{}}, 'ios').release, isNull);
    expect(() => config.release!.releaseNotes.clear(), throwsUnsupportedError);
  });
  test('invalid release fields and unsafe download links fail rather than report up to date', () {
    for (final change in [
      {'latest_version': 'latest'},
      {'force_update': 'true'},
      {'release_notes': 'notes'},
      {
        'release_notes': {'en': 42},
      },
      {'store_url': 'javascript:alert(1)'},
      {'store_url': 'https://user:secret@example.test/app'},
      {'store_url': 1},
    ]) {
      expect(
        () => mapAppUpdateConfiguration({
          'update': {
            'android': {...release(), ...change},
          },
        }, 'android'),
        throwsFormatException,
      );
    }
    expect(
      () => mapAppUpdateConfiguration({
        'min_supported_version': '3.0.0',
        'update': {'android': release()},
      }, 'android'),
      throwsFormatException,
    );
  });
  test('check shares a pending read and waits until platform metadata settles', () async {
    final backend = Backend(), gate = Completer<void>();
    backend.routes['GET /v1/app/bootstrap'] = (_) async {
      await gate.future;
      return json({
        'config': {
          'update': {'ios': release(latest: '3.0.0'), 'android': release()},
        },
      });
    };
    final repository = AppUpdateRepository(
      VantaApiHttp(baseUri: Uri.https('api.vanta.test'), client: backend.client),
    );
    addTearDown(repository.close);
    final container = ProviderContainer(
      overrides: [
        appUpdateRepositoryProvider.overrideWithValue(repository),
        appVersionProvider.overrideWith((ref) async => version('1.5.0')),
        appUpdatePlatformProvider.overrideWithValue('ios'),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(appUpdateCheckProvider, (_, _) {});
    addTearDown(sub.close);
    final controller = container.read(appUpdateCheckProvider.notifier);
    final first = controller.check(), second = controller.check();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appUpdateCheckProvider), isTrue);
    expect(backend.requests, hasLength(1));
    gate.complete();
    final values = await Future.wait([first, second]);
    expect(values.map((v) => v.target!.text), ['3.0.0', '3.0.0']);
    expect(container.read(appUpdateCheckProvider), isFalse);
  });

  test(
    'leaving settings during native version lookup never dispatches a late update request',
    () async {
      final backend = Backend(), gate = Completer<AppVersion?>();
      final repository = AppUpdateRepository(
        VantaApiHttp(baseUri: Uri.https('api.vanta.test'), client: backend.client),
      );
      addTearDown(repository.close);
      final container = ProviderContainer(
        overrides: [
          appUpdateRepositoryProvider.overrideWithValue(repository),
          appVersionProvider.overrideWith((ref) => gate.future),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(appUpdateCheckProvider, (_, _) {});
      final pending = container.read(appUpdateCheckProvider.notifier).check();
      final failure = expectLater(pending, throwsA(isA<VantaApiFailure>()));
      subscription.close();
      await container.pump();
      gate.complete(version('1.0.0'));
      await failure;
      expect(backend.requests, isEmpty);
    },
  );

  for (final locale in ['en', 'zh']) {
    testWidgets(
      'manual update shows localized release notes and opens the returned link: $locale',
      (t) async {
        t.view.physicalSize = const Size(320, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final backend = Backend();
        backend.routes['GET /v1/app/bootstrap'] = (_) => json({
          'config': {
            'update': {'android': release(force: true)},
          },
        });
        final repository = AppUpdateRepository(
          VantaApiHttp(baseUri: Uri.https('api.vanta.test'), client: backend.client),
        );
        addTearDown(repository.close);
        final launchGate = Completer<bool>();
        final launched = <Uri>[];
        final container = ProviderContainer(
          overrides: [
            appUpdateRepositoryProvider.overrideWithValue(repository),
            appVersionProvider.overrideWith((ref) async => version('1.0.0')),
            appUpdatePlatformProvider.overrideWithValue('android'),
            appUpdateLauncherProvider.overrideWithValue((uri) {
              launched.add(uri);
              return launchGate.future;
            }),
          ],
        );
        addTearDown(container.dispose);
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: vantaTheme(),
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const Scaffold(body: SingleChildScrollView(child: SettingsAppCard())),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.ensureVisible(find.byKey(const Key('settings-check-update')));
        await t.tap(find.byKey(const Key('settings-check-update')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('settings-update-sheet')), findsOneWidget);
        expect(find.text(locale == 'en' ? 'Improved order history' : '完善订单历史'), findsOneWidget);
        expect(
          find.text(
            locale == 'en' ? 'Please update to version 2.0.0 or later' : '请更新至 2.0.0 或更高版本',
          ),
          findsOneWidget,
        );
        final action = find.byKey(const Key('settings-update-download'));
        await t.ensureVisible(action);
        await t.tap(action);
        await t.pump();
        await t.tap(action);
        await t.pump();
        expect(launched, [Uri.parse('https://example.test/app')]);
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        launchGate.complete(false);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('missing download link does not offer an update button', (t) async {
    final config = mapAppUpdateConfiguration({
      'update': {'android': release(url: null)},
    }, 'android');
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: vantaTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsUpdateSheet(
              AppUpdateCheck(current: version('1'), release: config.release),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('settings-update-download')), findsNothing);
    expect(find.text('A download link has not been provided.'), findsOneWidget);
  });
  test('invalid metadata keeps the typed API error', () async {
    final backend = Backend();
    backend.routes['GET /v1/app/bootstrap'] = (_) => json({
      'config': {
        'update': {
          'android': {'latest_version': '2'},
        },
      },
    });
    final repository = AppUpdateRepository(
      VantaApiHttp(baseUri: Uri.https('api.vanta.test'), client: backend.client),
    );
    addTearDown(repository.close);
    await expectLater(
      repository.read('android'),
      throwsA(isA<VantaApiFailure>().having((e) => e.key, 'key', vantaApiDataInvalid)),
    );
  });
}
