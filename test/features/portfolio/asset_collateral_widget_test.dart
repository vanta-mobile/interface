import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/market/domain/mark_prices.dart';
import 'package:vanta/features/portfolio/application/collateral_mark_prices_provider.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/asset_index_provider.dart';
import 'package:vanta/features/portfolio/application/asset_metadata_provider.dart';
import 'package:vanta/features/portfolio/application/asset_yield_provider.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';
import 'package:vanta/features/portfolio/presentation/aster_account_rows.dart';
import 'package:vanta/features/portfolio/presentation/asset_collateral_rows.dart';
import 'package:vanta/features/trade/presentation/widgets/primitives.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/asset_indices.dart';
import '../../support/asset_metadata.dart';
import '../../support/asset_yields.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4, 13);
  AssetIndexSnapshot indices({bool rates = true}) => AssetIndexSnapshot(
    receivedAt: now,
    indices: {
      'USDTUSD': AssetUsdIndex(
        symbol: 'USDTUSD',
        usd: Decimal.parse('1.01'),
        time: now,
        bidRate: rates ? Decimal.parse('0.9') : null,
        askRate: rates ? Decimal.parse('1.1') : null,
      ),
    },
  );
  AsterAssetBalance balance({String wallet = '100', String? pnl = '2', bool? eligible = true}) =>
      AsterAssetBalance(
        asset: 'USDT',
        walletBalance: Decimal.parse('1000'),
        unrealizedProfit: Decimal.parse('500'),
        crossWalletBalance: Decimal.parse(wallet),
        crossUnrealizedProfit: pnl == null ? null : Decimal.parse(pnl),
        marginAvailable: eligible,
      );
  Future<ProviderContainer> mount(
    WidgetTester tester,
    Widget child, {
    TestAssetIndexRepository? repository,
    String language = 'en',
    double width = 390,
    double height = 844,
    double scale = 1,
    Stream<MarkPrices>? marks,
    List<CollateralMarkScope>? scopes,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        collateralMarkPricesProvider.overrideWith((_, scope) {
          scopes?.add(scope);
          return marks ?? Stream.value(MarkPrices());
        }),
        assetIndexRepositoryProvider.overrideWithValue(
          repository ?? (TestAssetIndexRepository(now: () => now)..result = indices()),
        ),
        assetIndexClockProvider.overrideWithValue(() => now),
        assetMetadataRepositoryProvider.overrideWithValue(TestAssetMetadataRepository()),
        assetYieldClockProvider.overrideWithValue(() => now),
        assetYieldRepositoryProvider.overrideWithValue(TestAssetYieldRepository(now: () => now)),
      ],
    );
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
            body: ListView(padding: const EdgeInsets.all(16), children: [child]),
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

  Future<void> details(WidgetTester tester) async {
    final target = find.byKey(const ValueKey('asset-collateral-details-USDT'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Widget row({
    AsterAssetBalance? asset,
    bool stale = false,
    bool events = false,
    DateTime? receipt,
    List<AsterPosition> positions = const [],
    String? address,
  }) => Panel(
    padding: const EdgeInsets.all(16),
    child: AssetCollateralRows(
      accountAddress: address ?? '0x${'11' * 20}',
      positions: positions,
      asset: asset ?? balance(),
      accountReceivedAt: receipt ?? now,
      accountStale: stale,
      hasAccountEvents: events,
    ),
  );

  testWidgets(
    'exact reference and expanded source units/timestamps distinguish valuation from collateral',
    (tester) async {
      final c = await mount(tester, row());
      expect(find.text('91.80 USD'), findsOneWidget);
      await details(tester);
      expect(find.text('102 USDT'), findsOneWidget);
      expect(find.text('0.90 USD/USDT'), findsOneWidget);
      expect(find.text('1.10 USD/USDT'), findsOneWidget);
      expect(find.text('Account snapshot (UTC): 2026-11-04T13:00:00.000Z'), findsOneWidget);
      expect(find.text('Rate timestamp (UTC): 2026-11-04T13:00:00.000Z'), findsOneWidget);
      expect(find.textContaining('does not confirm the active margin mode'), findsOneWidget);
      expect(tester.takeException(), null);
      await close(tester, c);
    },
  );
  testWidgets('negative contribution retains negative sign instead of using positive-side rate', (
    tester,
  ) async {
    final c = await mount(
      tester,
      row(
        asset: balance(wallet: '-100', pnl: '-2'),
      ),
    );
    expect(find.text('-112.20 USD'), findsOneWidget);
    expect(find.text('-91.80 USD'), findsNothing);
    await close(tester, c);
  });
  testWidgets('unknown signed crossed pnl never displays fabricated contribution', (tester) async {
    final c = await mount(tester, row(asset: balance(pnl: null)));
    expect(find.textContaining('crossed unrealized PnL is missing'), findsOneWidget);
    expect(find.text('91.80 USD'), findsNothing);
    expect(find.text('—'), findsOneWidget);
    await close(tester, c);
  });
  testWidgets('ineligible asset has explicit explanation without zero value', (tester) async {
    final c = await mount(tester, row(asset: balance(eligible: false)));
    final l = AppLocalizations.of(tester.element(find.byType(AssetCollateralRows)));
    expect(find.text(l.accountCollateralIneligible), findsOneWidget);
    expect(find.text('0 USD'), findsNothing);
    await close(tester, c);
  });
  testWidgets('missing rates preserve price service, explicit refresh can recover contribution', (
    tester,
  ) async {
    final repo = TestAssetIndexRepository(now: () => now)..result = indices(rates: false);
    final c = await mount(tester, row(), repository: repo);
    expect(find.textContaining('Collateral bid/ask rates are unavailable'), findsOneWidget);
    expect(c.read(assetIndexProvider).failed, false);
    repo.result = indices();
    await c.read(assetIndexProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.text('91.80 USD'), findsOneWidget);
    expect(tester.takeException(), null);
    await close(tester, c);
  });
  for (final spec in [('account stale', true, false), ('account event', false, true)]) {
    testWidgets('${spec.$1} has safe independent notice', (tester) async {
      final c = await mount(tester, row(stale: spec.$2, events: spec.$3));
      if (spec.$3) {
        expect(find.textContaining('Account events changed this snapshot'), findsOneWidget);
        expect(find.text('91.80 USD'), findsNothing);
      } else {
        expect(find.text('91.80 USD'), findsOneWidget);
        expect(find.textContaining('stale snapshot'), findsOneWidget);
      }
      await close(tester, c);
    });
  }
  testWidgets('failed public refresh retains reference but marks it stale', (tester) async {
    final repo = TestAssetIndexRepository(now: () => now)..result = indices();
    final c = await mount(tester, row(), repository: repo);
    repo.failure = StateError('sensitive transport error');
    await c.read(assetIndexProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.text('91.80 USD'), findsOneWidget);
    expect(find.textContaining('stale snapshot'), findsOneWidget);
    expect(find.textContaining('sensitive'), findsNothing);
    await close(tester, c);
  });
  testWidgets('actual Futures asset card includes contribution and event invalidation', (
    tester,
  ) async {
    final account = AsterAccount(
      address: '0x${'11' * 20}',
      receivedAt: now,
      assets: [balance()],
      positions: [],
    );
    final c = await mount(tester, AsterAccountRows(account: account));
    expect(find.byKey(const ValueKey('asset-collateral-USDT')), findsOneWidget);
    expect(find.text('91.80 USD'), findsOneWidget);
    expect(
      find.text('1,010 USD'),
      findsNWidgets(2),
    ); // wallet reference valuation uses index1.01, not rates.
    expect(tester.takeException(), null);
    await close(tester, c);
  });
  testWidgets('hide zero preserves a nonzero crossed-profit-only asset', (tester) async {
    final asset = AsterAssetBalance(
      asset: 'USDT',
      walletBalance: Decimal.zero,
      unrealizedProfit: Decimal.zero,
      crossWalletBalance: Decimal.zero,
      crossUnrealizedProfit: Decimal.fromInt(2),
      marginAvailable: true,
    );
    final c = await mount(
      tester,
      AsterAccountRows(
        account: AsterAccount(
          address: '0x${'11' * 20}',
          receivedAt: now,
          assets: [asset],
          positions: [],
        ),
      ),
    );
    expect(find.byKey(const ValueKey('asset-collateral-USDT')), findsOneWidget);
    expect(find.text('1.80 USD'), findsOneWidget);
    expect(tester.takeException(), null);
    await close(tester, c);
  });
  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    testWidgets('expanded contribution details at $spec / text1.5', (tester) async {
      final c = await mount(
        tester,
        row(
          asset: balance(wallet: '-100000000000000000.000000000001', pnl: '-2'),
        ),
        language: spec.$3,
        width: spec.$1,
        height: spec.$2,
        scale: 1.5,
      );
      await details(tester);
      await tester.ensureVisible(find.textContaining('2026-11-04T13:00:00.000Z').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await close(tester, c);
    });
  }
  const units = AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'USDT');
  AsterPosition position({
    String symbol = 'BTCUSDT',
    String qty = '2',
    String entry = '100',
    bool? isolated = false,
    AsterContractUnits? contract = units,
  }) => AsterPosition(
    symbol: symbol,
    side: 'BOTH',
    quantity: Decimal.parse(qty),
    entryPrice: Decimal.parse(entry),
    isolated: isolated,
    units: contract,
  );
  MarkPrices liveMarks({
    String btc = '110',
    bool includeEth = false,
    MarkPriceConnection connection = MarkPriceConnection.online,
    Set<String> invalid = const {},
    Set<String> fresh = const {'BTCUSDT', 'ETHUSDT'},
  }) => MarkPrices(
    connection: connection,
    invalid: invalid,
    fresh: fresh,
    quotes: {
      'BTCUSDT': MarkPriceQuote(
        symbol: 'BTCUSDT',
        price: Decimal.parse(btc),
        eventTime: now,
        receivedAt: now,
      ),
      if (includeEth)
        'ETHUSDT': MarkPriceQuote(
          symbol: 'ETHUSDT',
          price: Decimal.fromInt(190),
          eventTime: now.subtract(const Duration(seconds: 1)),
          receivedAt: now,
        ),
    },
  );
  Future<void> publish(
    WidgetTester tester,
    StreamController<MarkPrices> feed,
    MarkPrices marks,
  ) async {
    feed.add(marks);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('public mark updates recompute contribution without another account read', (
    tester,
  ) async {
    var cancelled = 0;
    final feed = StreamController<MarkPrices>(onCancel: () => cancelled++);
    final c = await mount(tester, row(positions: [position()]), marks: feed.stream);
    expect(find.text('91.80 USD'), findsOneWidget);
    await publish(tester, feed, liveMarks());
    expect(find.text('108 USD'), findsOneWidget);
    final l = AppLocalizations.of(tester.element(find.byType(AssetCollateralRows)));
    expect(find.text(l.collateralLiveMarks), findsOneWidget);
    expect(find.text(l.collateralSnapshotPnl), findsNothing);
    await details(tester);
    expect(find.text('120 USDT'), findsOneWidget);
    expect(find.text(l.collateralMarkTime(now.toIso8601String())), findsOneWidget);
    await publish(tester, feed, liveMarks(btc: '120'));
    expect(find.text('126 USD'), findsOneWidget);
    expect(find.text('140 USDT'), findsOneWidget);
    expect(c.exists(accountReadProvider), false);
    expect(c.exists(authProvider), false);
    await close(tester, c);
    expect(cancelled, 1);
    await tester.runAsync(feed.close);
  });

  testWidgets('incomplete or invalid multi-symbol marks use full labelled signed snapshot', (
    tester,
  ) async {
    final feed = StreamController<MarkPrices>();
    final c = await mount(
      tester,
      row(
        positions: [
          position(),
          position(symbol: 'ETHUSDT', qty: '-3', entry: '200'),
        ],
      ),
      marks: feed.stream,
    );
    final l = AppLocalizations.of(tester.element(find.byType(AssetCollateralRows)));
    await publish(tester, feed, liveMarks());
    expect(find.text('91.80 USD'), findsOneWidget);
    expect(find.text(l.collateralSnapshotPnl), findsOneWidget);
    await publish(tester, feed, liveMarks(includeEth: true));
    expect(find.text('135 USD'), findsOneWidget);
    await details(tester);
    expect(
      find.text(l.collateralMarkTime(now.subtract(const Duration(seconds: 1)).toIso8601String())),
      findsOneWidget,
    );
    await publish(tester, feed, liveMarks(includeEth: true, invalid: {'BTCUSDT'}));
    expect(find.text('91.80 USD'), findsOneWidget);
    expect(find.text(l.collateralSnapshotPnl), findsOneWidget);
    expect(find.textContaining('Oldest mark'), findsNothing);
    await close(tester, c);
    await tester.runAsync(feed.close);
  });

  testWidgets('disconnect and stale marks preserve reference with stale warning', (tester) async {
    final feed = StreamController<MarkPrices>();
    final c = await mount(tester, row(positions: [position()]), marks: feed.stream);
    final l = AppLocalizations.of(tester.element(find.byType(AssetCollateralRows)));
    await publish(tester, feed, liveMarks());
    expect(find.text(l.collateralStale), findsNothing);
    for (final marks in [
      liveMarks(connection: MarkPriceConnection.offline),
      liveMarks(fresh: {}),
    ]) {
      await publish(tester, feed, marks);
      expect(find.text('108 USD'), findsOneWidget);
      expect(find.text(l.collateralStale), findsOneWidget);
    }
    await publish(tester, feed, liveMarks());
    expect(find.text(l.collateralStale), findsNothing);
    await close(tester, c);
    await tester.runAsync(feed.close);
  });

  testWidgets('account event invalidates live contribution and cancels marks until new snapshot', (
    tester,
  ) async {
    var cancelled = 0;
    final feed = StreamController<MarkPrices>(onCancel: () => cancelled++);
    final events = ValueNotifier(false);
    final c = await mount(
      tester,
      ValueListenableBuilder(
        valueListenable: events,
        builder: (_, changed, _) => row(positions: [position()], events: changed),
      ),
      marks: feed.stream,
    );
    await publish(tester, feed, liveMarks());
    expect(find.text('108 USD'), findsOneWidget);
    events.value = true;
    await tester.pumpAndSettle();
    expect(find.text('108 USD'), findsNothing);
    expect(find.text('91.80 USD'), findsNothing);
    expect(find.textContaining('Account events changed this snapshot'), findsOneWidget);
    expect(cancelled, 1);
    await close(tester, c);
    events.dispose();
    await tester.runAsync(feed.close);
  });

  testWidgets('no public mark subscription for isolated, unknown, nonlinear or ineligible rows', (
    tester,
  ) async {
    final scopes = <CollateralMarkScope>[];
    final rows = [
      position(isolated: true),
      position(isolated: null),
      position(contract: null),
      position(
        contract: const AsterContractUnits(base: 'BTC', quote: 'USD', margin: 'BTC'),
      ),
    ];
    final c = await mount(
      tester,
      Column(
        children: [
          for (final p in rows) row(positions: [p]),
          row(positions: [position()], asset: balance(eligible: false)),
        ],
      ),
      scopes: scopes,
    );
    expect(scopes, isEmpty);
    expect(c.exists(accountReadProvider), false);
    await close(tester, c);
  });

  testWidgets('same account cards share marks and last card disposal cancels feed', (tester) async {
    final feed = StreamController<MarkPrices>();
    final scopes = <CollateralMarkScope>[];
    final c = await mount(
      tester,
      Column(
        children: [
          row(positions: [position()]),
          row(positions: [position(qty: '3')]),
        ],
      ),
      marks: feed.stream,
      scopes: scopes,
    );
    expect(scopes.length, 1);
    await publish(tester, feed, liveMarks());
    expect(find.text('108 USD'), findsOneWidget);
    expect(find.text('117 USD'), findsOneWidget);
    await close(tester, c);
    expect(feed.hasListener, false);
    await tester.runAsync(feed.close);
  });

  testWidgets('wallet change drops former wallet mark data until new feed snapshot', (
    tester,
  ) async {
    final first = StreamController<MarkPrices>();
    final scopes = <CollateralMarkScope>[];
    final wallet = ValueNotifier('0x${'11' * 20}');
    // A broadcast source models the shared anonymous transport, but each new
    // wallet scope must start with no cached contribution from the old scope.
    final feed = first.stream.asBroadcastStream();
    final c = await mount(
      tester,
      ValueListenableBuilder(
        valueListenable: wallet,
        builder: (_, address, _) => row(positions: [position()], address: address),
      ),
      marks: feed,
      scopes: scopes,
    );
    await publish(tester, first, liveMarks());
    expect(find.text('108 USD'), findsOneWidget);
    wallet.value = '0x${'22' * 20}';
    await tester.pumpAndSettle();
    expect(scopes.length, 2);
    expect(find.text('108 USD'), findsNothing);
    expect(find.text('91.80 USD'), findsOneWidget);
    await publish(tester, first, liveMarks(btc: '120'));
    expect(find.text('126 USD'), findsOneWidget);
    await close(tester, c);
    wallet.dispose();
    await tester.runAsync(first.close);
  });
}
