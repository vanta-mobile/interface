import 'package:vanta/features/portfolio/application/asset_metadata_provider.dart';

import '../../support/asset_metadata.dart';

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/portfolio/application/asset_index_provider.dart';
import 'package:vanta/features/portfolio/application/asset_yield_provider.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/aster_spot_account.dart';
import 'package:vanta/features/portfolio/domain/asset_yield.dart';
import 'package:vanta/features/portfolio/presentation/aster_account_rows.dart';
import 'package:vanta/features/portfolio/presentation/asset_yield_badge.dart';
import 'package:vanta/features/portfolio/presentation/spot_balance_rows.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/asset_indices.dart';
import '../../support/asset_yields.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4, 12);
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    Widget child = const Column(
      children: [
        AssetYieldBadge(symbol: 'USDF'),
        AssetYieldBadge(symbol: 'ASBNB'),
      ],
    ),
    TestAssetYieldRepository? repository,
    String language = 'en',
    double width = 390,
    double height = 844,
    double scale = 1,
    bool settle = true,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        assetMetadataRepositoryProvider.overrideWithValue(TestAssetMetadataRepository()),
        assetYieldClockProvider.overrideWithValue(() => now),
        assetYieldRepositoryProvider.overrideWithValue(
          repository ?? TestAssetYieldRepository(now: () => now),
        ),
        assetIndexClockProvider.overrideWithValue(() => now),
        assetIndexRepositoryProvider.overrideWithValue(TestAssetIndexRepository(now: () => now)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return container;
  }

  Future<void> expand(WidgetTester tester, String asset) async {
    final title = find.byKey(Key('asset-yield-rate-$asset'));
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pumpAndSettle();
  }

  Future<void> refresh(WidgetTester tester, String asset) async {
    final button = find.byKey(Key('asset-yield-refresh-$asset'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    testWidgets('both sources expand with dates, caveats and refresh at $spec / text 1.5', (
      tester,
    ) async {
      final repository = TestAssetYieldRepository(now: () => now);
      final container = await mount(
        tester,
        repository: repository,
        width: spec.$1,
        height: spec.$2,
        language: spec.$3,
        scale: 1.5,
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(AssetYieldBadge).first));
      expect(find.text(l10n.assetYieldUsdf('11.45')), findsOneWidget);
      expect(find.text(l10n.assetYieldAsbnb('1.45')), findsOneWidget);
      expect(find.text(l10n.assetYieldParts('1.75', '9.70')), findsNothing);
      await expand(tester, 'USDF');
      expect(find.text(l10n.assetYieldParts('1.75', '9.70')), findsOneWidget);
      expect(find.text(l10n.assetYieldUsdfScope), findsOneWidget);
      expect(find.text(l10n.assetYieldSourceDate('2026-11-04')), findsOneWidget);
      await refresh(tester, 'USDF');
      await expand(tester, 'ASBNB');
      expect(find.text(l10n.assetYieldAsbnbScope), findsOneWidget);
      expect(find.text(l10n.assetYieldSourceDate('2026-11-04')), findsNWidgets(2));
      await refresh(tester, 'ASBNB');
      expect(repository.calls, [
        YieldAsset.usdf,
        YieldAsset.asbnb,
        YieldAsset.usdf,
        YieldAsset.asbnb,
      ]);
      expect(tester.takeException(), null);
      await close(tester, container);
    });
  }
  testWidgets('unsupported assets never subscribe to a yield source', (tester) async {
    final repository = TestAssetYieldRepository(now: () => now);
    final container = await mount(
      tester,
      repository: repository,
      child: const Column(
        children: [
          AssetYieldBadge(symbol: 'USDT'),
          AssetYieldBadge(symbol: 'BNB'),
        ],
      ),
    );
    expect(repository.calls, isEmpty);
    expect(find.byType(ExpansionTile), findsNothing);
    await close(tester, container);
  });
  testWidgets('stale source date remains visible after a new public read', (tester) async {
    final repository = TestAssetYieldRepository(now: () => now);
    final quote = assetYieldFixture(YieldAsset.usdf, now.subtract(const Duration(days: 12)));
    repository.quotes[YieldAsset.usdf] = AssetYieldQuote(
      asset: quote.asset,
      percent: quote.percent,
      sourceDay: quote.sourceDay,
      receivedAt: now,
      basePercent: quote.basePercent,
      tradePercent: quote.tradePercent,
    );
    final container = await mount(tester, repository: repository);
    final l10n = AppLocalizations.of(tester.element(find.byType(AssetYieldBadge).first));
    expect(find.text(l10n.assetYieldStale), findsOneWidget);
    await expand(tester, 'USDF');
    expect(find.text(l10n.assetYieldSourceDate('2026-10-23')), findsOneWidget);
    await refresh(tester, 'USDF');
    expect(find.text(l10n.assetYieldStale), findsOneWidget);
    await close(tester, container);
  });
  testWidgets(
    'partial source failure does not hide other rate; safe errors and retry retain values',
    (tester) async {
      final repository = TestAssetYieldRepository(now: () => now);
      repository.failures[YieldAsset.usdf] = const AccountReadFailure('accountDataInvalid');
      final container = await mount(tester, repository: repository);
      final l10n = AppLocalizations.of(tester.element(find.byType(AssetYieldBadge).first));
      expect(find.text(l10n.assetYieldInvalid), findsOneWidget);
      expect(find.text(l10n.assetYieldUsdf('—')), findsOneWidget);
      expect(find.text(l10n.assetYieldAsbnb('1.45')), findsOneWidget);
      await expand(tester, 'USDF');
      repository.failures.clear();
      await refresh(tester, 'USDF');
      expect(find.text(l10n.assetYieldInvalid), findsNothing);
      expect(find.text(l10n.assetYieldUsdf('11.45')), findsOneWidget);
      repository.failures[YieldAsset.usdf] = StateError('private transport details');
      await refresh(tester, 'USDF');
      expect(find.text(l10n.assetYieldUsdf('11.45')), findsOneWidget);
      expect(find.text(l10n.assetYieldFailed), findsOneWidget);
      expect(find.textContaining('private transport'), findsNothing);
      await close(tester, container);
    },
  );
  testWidgets('loading/paused states disable refresh; resume reads without wallet interaction', (
    tester,
  ) async {
    final repository = TestAssetYieldRepository(now: () => now);
    repository.gates[YieldAsset.usdf] = Completer();
    final container = await mount(
      tester,
      repository: repository,
      child: const AssetYieldBadge(symbol: 'USDF'),
      settle: false,
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(AssetYieldBadge)));
    expect(find.text(l10n.assetYieldLoading), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    repository.gates.remove(YieldAsset.usdf)!.complete(assetYieldFixture(YieldAsset.usdf, now));
    await tester.pumpAndSettle();
    await expand(tester, 'USDF');
    container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    await tester.pumpAndSettle();
    expect(find.text(l10n.assetYieldPaused), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byKey(const Key('asset-yield-refresh-USDF'))).onPressed,
      null,
    );
    container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await tester.pumpAndSettle();
    expect(find.text(l10n.assetYieldPaused), findsNothing);
    expect(repository.calls.length, 2);
    await close(tester, container);
  });
  testWidgets('Spot and Futures show rates without adding APY to financial quantities', (
    tester,
  ) async {
    final repository = TestAssetYieldRepository(now: () => now);
    final container = await mount(
      tester,
      repository: repository,
      child: Column(
        children: [
          AsterAccountRows(
            account: AsterAccount(
              address: '0x1111111111111111111111111111111111111111',
              receivedAt: now,
              positions: [],
              assets: [
                AsterAssetBalance(
                  asset: 'USDF',
                  walletBalance: Decimal.parse('12.000000000000000001'),
                ),
              ],
            ),
          ),
          SpotBalanceRows(
            account: AsterSpotAccount(
              address: '0x1111111111111111111111111111111111111111',
              receivedAt: now,
              balances: [
                AsterSpotBalance(
                  asset: 'USDF',
                  free: Decimal.fromInt(2),
                  locked: Decimal.fromInt(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    expect(find.byKey(const Key('asset-yield-rate-USDF')), findsNWidgets(2));
    expect(repository.calls, [YieldAsset.usdf]);
    expect(find.text('3 USDF'), findsOneWidget);
    expect(find.text('2 USDF'), findsOneWidget);
    expect(find.textContaining('12.000000000000000001'), findsOneWidget);
    expect(tester.takeException(), null);
    await close(tester, container);
  });
}
