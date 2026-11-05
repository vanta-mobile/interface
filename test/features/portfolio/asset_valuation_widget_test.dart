import 'package:vanta/features/portfolio/application/asset_metadata_provider.dart';

import '../../support/asset_metadata.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/application/asset_index_provider.dart';
import 'package:vanta/features/portfolio/application/asset_yield_provider.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/aster_spot_account.dart';
import 'package:vanta/features/portfolio/presentation/aster_account_rows.dart';
import 'package:vanta/features/portfolio/presentation/asset_valuation_rows.dart';
import 'package:vanta/features/portfolio/presentation/spot_balance_rows.dart';
import 'package:vanta/features/trade/presentation/widgets/primitives.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/asset_indices.dart';
import '../../support/asset_yields.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);
  AsterSpotBalance spot(String asset, String free, [String locked = '0']) =>
      AsterSpotBalance(asset: asset, free: Decimal.parse(free), locked: Decimal.parse(locked));
  AsterSpotAccount spots(List<AsterSpotBalance> balances) => AsterSpotAccount(
    address: '0x1111111111111111111111111111111111111111',
    receivedAt: now,
    balances: balances,
  );
  Future<ProviderContainer> mount(
    WidgetTester tester,
    Widget child, {
    TestAssetIndexRepository? repository,
    String locale = 'en',
    double width = 390,
    double height = 844,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        assetMetadataRepositoryProvider.overrideWithValue(TestAssetMetadataRepository()),
        assetYieldClockProvider.overrideWithValue(() => now),
        assetYieldRepositoryProvider.overrideWithValue(TestAssetYieldRepository(now: () => now)),
        assetIndexClockProvider.overrideWithValue(() => now),
        assetIndexRepositoryProvider.overrideWithValue(
          repository ?? TestAssetIndexRepository(now: () => now),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  Future<void> lowFilter(WidgetTester tester) async {
    final filter = find.byKey(const Key('spot-hide-low-balance'));
    await tester.ensureVisible(filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'low filter uses free plus locked and retains missing prices; search does not change wallet subtotal',
    (tester) async {
      final repository = TestAssetIndexRepository(now: () => now)
        ..result = assetIndexFixture(
          now,
          prices: {'USDT': '1', 'BTC': '80000', 'ABOVE': '1', 'BELOW': '1', 'LOCKED': '1'},
        );
      final container = await mount(
        tester,
        SpotBalanceRows(
          account: spots([
            spot('USDT', '8'),
            spot('ABOVE', '8.00000000000000000001'),
            spot('BELOW', '7.99999999999999999999'),
            spot('LOCKED', '0', '9'),
            spot('UNKNOWN', '1'),
          ]),
        ),
        repository: repository,
      );
      expect(find.text('33 USD'), findsOneWidget);
      await lowFilter(tester);
      expect(find.text('USDT'), findsNothing);
      expect(find.text('BELOW'), findsNothing);
      expect(find.text('ABOVE'), findsOneWidget);
      expect(find.text('LOCKED'), findsOneWidget);
      expect(find.text('UNKNOWN'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('spot-asset-search')));
      await tester.enterText(find.byKey(const Key('spot-asset-search')), 'locked');
      await tester.pumpAndSettle();
      expect(find.text('ABOVE'), findsNothing);
      expect(find.text('33 USD'), findsOneWidget);
      expect(find.text('9 USD'), findsOneWidget); // available remains zero.
      expect(find.text('0 USD'), findsOneWidget);
      await close(tester, container);
    },
  );
  for (final staleAccount in [false, true]) {
    testWidgets('low filter retains stale ${staleAccount ? 'account' : 'prices'} estimates', (
      tester,
    ) async {
      final repository = TestAssetIndexRepository(now: () => now)
        ..result = assetIndexFixture(
          staleAccount ? now : now.subtract(const Duration(minutes: 2)),
          receivedAt: now,
        );
      final container = await mount(
        tester,
        SpotBalanceRows(account: spots([spot('USDT', '1')]), accountStale: staleAccount),
        repository: repository,
      );
      await lowFilter(tester);
      expect(find.text('USDT'), findsOneWidget);
      expect(find.textContaining('older or incomplete'), findsWidgets);
      await close(tester, container);
    });
  }
  testWidgets('all-unknown summary shows unavailable values rather than a zero wallet', (
    tester,
  ) async {
    final container = await mount(
      tester,
      AssetWalletSummary(label: 'Test wallet', quantities: {'UNKNOWN': Decimal.one}),
    );
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('0 USD'), findsNothing);
    expect(find.textContaining('1 asset(s) have no USD price'), findsOneWidget);
    await close(tester, container);
  });
  testWidgets('public refresh failure retains estimates and retry recovers', (tester) async {
    final repository = TestAssetIndexRepository(now: () => now);
    final container = await mount(
      tester,
      AssetWalletSummary(label: 'Test wallet', quantities: {'USDT': Decimal.fromInt(100)}),
      repository: repository,
    );
    expect(find.text('99.836 USD'), findsOneWidget);
    repository.failure = StateError('sensitive transport detail');
    await tester.tap(find.byKey(const Key('asset-index-refresh')));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(AssetIndexStatus)));
    expect(find.text(l10n.assetIndexFailed), findsOneWidget);
    expect(find.text('99.836 USD'), findsOneWidget);
    expect(find.textContaining('sensitive transport detail'), findsNothing);
    repository.failure = null;
    await tester.tap(find.byKey(const Key('asset-index-refresh')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.assetIndexFailed), findsNothing);
    expect(repository.calls, 3);
    await close(tester, container);
  });
  for (final spec in [(320.0, 844.0, 'zh'), (320.0, 844.0, 'en'), (844.0, 390.0, 'en')]) {
    testWidgets('Spot estimates and filters fit $spec with 1.5 text', (tester) async {
      final container = await mount(
        tester,
        SpotBalanceRows(
          account: spots([
            spot('USDT', '100.000000000000000001'),
            spot('BTC', '0.000000000000000001'),
          ]),
        ),
        width: spec.$1,
        height: spec.$2,
        locale: spec.$3,
        scale: 1.5,
      );
      expect(find.text('99.83600000000000000099836 USD'), findsNWidgets(2));
      await lowFilter(tester);
      expect(find.text('BTC'), findsNothing);
      expect(find.text('USDT'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.ensureVisible(find.text('USDT'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await close(tester, container);
    });

    testWidgets('wallet valuations, margin and required zero assets fit $spec with 1.5 text', (
      tester,
    ) async {
      final account = AsterAccount(
        address: '0x1111111111111111111111111111111111111111',
        receivedAt: now,
        positions: [],
        assets: [
          AsterAssetBalance(
            asset: 'USDT',
            walletBalance: Decimal.fromInt(10),
            unrealizedProfit: Decimal.fromInt(-2),
          ),
          AsterAssetBalance(asset: 'BTC', walletBalance: Decimal.parse('-0.000000000000000001')),
          for (final asset in ['USDF', 'ASBNB', 'ZERO'])
            AsterAssetBalance(asset: asset, walletBalance: Decimal.zero),
        ],
      );
      final container = await mount(
        tester,
        AsterAccountRows(account: account),
        width: spec.$1,
        height: spec.$2,
        locale: spec.$3,
        scale: 1.5,
      );
      expect(find.text('USDF'), findsOneWidget);
      expect(find.text('ASBNB'), findsOneWidget);
      expect(find.text('ZERO'), findsNothing);
      expect(find.text('7.98688 USD'), findsOneWidget); // (wallet + UPL) x actual USDT index.
      expect(find.text('9.9836 USD'), findsOneWidget);
      final btcCard = find.ancestor(of: find.text('BTC'), matching: find.byType(Panel));
      expect(
        find.descendant(of: btcCard, matching: find.text('—')),
        findsWidgets,
      ); // Missing UPL is unknown.
      expect(tester.takeException(), null);
      await tester.ensureVisible(find.text('ASBNB'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await close(tester, container);
    });
  }
}
