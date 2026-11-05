import 'dart:typed_data';
import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/portfolio/application/asset_index_provider.dart';
import 'package:vanta/features/portfolio/application/asset_metadata_provider.dart';
import 'package:vanta/features/portfolio/application/asset_yield_provider.dart';
import 'package:vanta/features/portfolio/data/asset_metadata_mapper.dart';
import 'package:vanta/features/portfolio/domain/asset_metadata.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/aster_spot_account.dart';
import 'package:vanta/features/portfolio/presentation/asset_identity.dart';
import 'package:vanta/features/portfolio/presentation/aster_account_rows.dart';
import 'package:vanta/features/portfolio/presentation/spot_balance_rows.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/asset_metadata.dart';
import '../../support/asset_indices.dart';
import '../../support/asset_yields.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4);
  late ProviderContainer c;
  late TestAssetMetadataRepository repository;
  late int imageReads, retries;
  void checkWidgets(String description, Future<void> Function(WidgetTester) run) {
    testWidgets(description, (t) async {
      try {
        await run(t);
      } finally {
        await t.pumpWidget(const SizedBox());
        c.dispose();
        await t.pump(const Duration(milliseconds: 1));
      }
    });
  }

  Future<void> mount(
    WidgetTester t,
    Widget child, {
    String locale = 'en',
    double width = 320,
    double height = 844,
    FutureOr<Uint8List> Function(Uri)? image,
  }) async {
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    imageReads = 0;
    retries = 0;
    repository = TestAssetMetadataRepository(now: () => now);
    for (final source in AssetMetadataSource.values) {
      repository.snapshots[source] = mapAssetMetadata(
        metadataPayload(source),
        source: source,
        receivedAt: now,
      );
    }
    c = ProviderContainer(
      overrides: [
        assetMetadataClockProvider.overrideWithValue(() => now),
        assetMetadataRepositoryProvider.overrideWithValue(repository),
        assetLogoProvider.overrideWith((ref, uri) {
          imageReads++;
          return image?.call(uri) ?? metadataPng;
        }),
        assetLogoRetryProvider.overrideWith(
          (ref) => (uri) {
            retries++;
            ref.invalidate(assetLogoProvider(uri));
          },
        ),
        assetIndexClockProvider.overrideWithValue(() => now),
        assetIndexRepositoryProvider.overrideWithValue(TestAssetIndexRepository(now: () => now)),
        assetYieldClockProvider.overrideWithValue(() => now),
        assetYieldRepositoryProvider.overrideWithValue(TestAssetYieldRepository(now: () => now)),
      ],
    );

    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f.hitTestable());
    await t.pumpAndSettle();
  }

  AsterSpotAccount spots() => AsterSpotAccount(
    address: '0x1111111111111111111111111111111111111111',
    receivedAt: now,
    balances: [
      AsterSpotBalance(
        asset: 'USDT',
        free: Decimal.parse('1.000000000000000001'),
        locked: Decimal.zero,
      ),
      AsterSpotBalance(asset: 'BTC', free: Decimal.one, locked: Decimal.zero),
    ],
  );
  AsterAccount futures() => AsterAccount(
    address: '0x1111111111111111111111111111111111111111',
    receivedAt: now,
    assets: [
      AsterAssetBalance(asset: 'USDT', walletBalance: Decimal.parse('1.000000000000000001')),
      AsterAssetBalance(asset: 'BTC', walletBalance: Decimal.one),
    ],
    positions: const [],
  );
  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    for (final spot in [true, false]) {
      checkWidgets(
        'names/icons shared source, search by localized or English name preserves exact $spot balances at $spec',
        (t) async {
          await mount(
            t,
            spot ? SpotBalanceRows(account: spots()) : AsterAccountRows(account: futures()),
            locale: spec.$3,
            width: spec.$1,
            height: spec.$2,
          );
          final search = find.byKey(Key(spot ? 'spot-asset-search' : 'account-asset-search'));
          final expected = spec.$3 == 'zh' ? '泰达币' : 'TetherUS';
          expect(find.text(expected), findsOneWidget);
          expect(find.text('1.000000000000000001 USDT'), findsWidgets);
          expect(find.byType(Image), findsNWidgets(2));
          expect(repository.calls.where((s) => s == AssetMetadataSource.names).length, 1);
          expect(repository.calls.where((s) => s == AssetMetadataSource.logos).length, 1);
          await t.ensureVisible(search);
          await t.enterText(search, 'bitcoin');
          await t.pumpAndSettle();
          expect(find.text('USDT'), findsNothing);
          expect(find.text('BTC'), findsOneWidget);
          await t.enterText(search, '泰达');
          await t.pumpAndSettle();
          expect(find.text('USDT'), findsOneWidget);
          expect(find.text('BTC'), findsNothing);
          await t.enterText(search, 'UNKNOWN');
          await t.pumpAndSettle();
          expect(find.text('USDT'), findsNothing);
          await t.enterText(search, '');
          await t.pumpAndSettle();
          expect(find.text('USDT'), findsOneWidget);
          expect(t.takeException(), null);
        },
      );
    }
  }
  checkWidgets('unknown metadata leaves symbol and generic icon without guessing display name', (
    t,
  ) async {
    await mount(
      t,
      const Column(
        children: [
          AssetMetadataStatus(),
          AssetIdentity(symbol: 'UNKNOWN'),
        ],
      ),
    );
    expect(find.text('UNKNOWN'), findsOneWidget);
    expect(imageReads, 0);
    expect(find.byIcon(Icons.token_outlined), findsOneWidget);
    expect(t.takeException(), null);
  });
  checkWidgets(
    'single-source refresh failure retains names, other source remains usable and manual retry recovers',
    (t) async {
      await mount(
        t,
        const Column(
          children: [
            AssetMetadataStatus(),
            AssetIdentity(symbol: 'USDT'),
          ],
        ),
      );
      repository.failures[AssetMetadataSource.names] = StateError('sensitive failure');
      await tap(t, find.byKey(const Key('asset-metadata-refresh')));
      final l = AppLocalizations.of(t.element(find.byType(AssetMetadataStatus)));
      expect(find.text(l.assetMetadataNamesFailed), findsOneWidget);
      expect(find.text(l.assetMetadataIconsFailed), findsNothing);
      expect(find.text('TetherUS'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('sensitive failure'), findsNothing);
      repository.failures.clear();
      await tap(t, find.byKey(const Key('asset-metadata-refresh')));
      expect(find.text(l.assetMetadataNamesFailed), findsNothing);
      expect(t.takeException(), null);
    },
  );
  checkWidgets(
    'failed image has manual retry and no silent repeat while name/balance remain usable',
    (t) async {
      bool fail = true;
      await mount(
        t,
        const Column(
          children: [
            AssetMetadataStatus(),
            AssetIdentity(symbol: 'USDT'),
          ],
        ),
        image: (_) {
          if (fail) throw StateError('fixture');
          return metadataPng;
        },
      );
      final l = AppLocalizations.of(t.element(find.byType(AssetIdentity)));
      expect(find.text('TetherUS'), findsOneWidget);
      expect(imageReads, 1);
      await t.pump(const Duration(seconds: 1));
      expect(imageReads, 1);
      fail = false;
      await tap(t, find.byTooltip(l.assetMetadataRetryIcon));
      expect(retries, 1);
      expect(find.byType(Image), findsOneWidget);
      expect(imageReads, 2);
      expect(t.takeException(), null);
    },
  );
  checkWidgets('same logo URI is shared between simultaneous cards without another request', (
    t,
  ) async {
    await mount(
      t,
      const Column(
        children: [
          AssetIdentity(symbol: 'USDT'),
          AssetIdentity(symbol: 'USDT'),
        ],
      ),
    );
    expect(imageReads, 1);
    expect(repository.calls.length, 2);
    expect(t.takeException(), null);
  });
  checkWidgets('background status disables public metadata refresh without changing symbols', (
    t,
  ) async {
    await mount(
      t,
      const Column(
        children: [
          AssetMetadataStatus(),
          AssetIdentity(symbol: 'USDT'),
        ],
      ),
    );
    c.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    await t.pumpAndSettle();
    expect(find.text('USDT'), findsOneWidget);
    expect(t.widget<IconButton>(find.byKey(const Key('asset-metadata-refresh'))).onPressed, null);
    expect(repository.calls.length, 2);
    expect(t.takeException(), null);
  });
}
