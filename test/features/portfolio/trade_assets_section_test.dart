import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vanta/core/motion/animated_number_text.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/portfolio_overview_provider.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_asset_row.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_assets.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_asset_details.dart';
import 'package:vanta/features/trade/presentation/futures_workspace.dart';

import '../../support/asset_indices.dart';
import '../../support/aster_account.dart';
import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';

Decimal d(String value) => Decimal.parse(value);

AsterAssetBalance balance(String symbol, String quantity, {String? pnl}) => AsterAssetBalance(
  asset: symbol,
  walletBalance: d(quantity),
  availableBalance: d(quantity),
  unrealizedProfit: pnl == null ? null : d(pnl),
);

AsterAccount account(List<AsterAssetBalance> assets) => AsterAccount(
  address: accountAddress,
  receivedAt: DateTime.now().toUtc(),
  assets: assets,
  positions: const [],
);

Finder get workspaceScroll => find
    .descendant(of: find.byKey(const Key('futures-workspace')), matching: find.byType(Scrollable))
    .first;

Future<void> selectAssets(WidgetTester t) async {
  final tab = find.byKey(const Key('futures-account-tab-2'));
  await t.scrollUntilVisible(tab, 250, scrollable: workspaceScroll);
  await t.pumpAndSettle();
  await t.tap(tab);
  await t.pumpAndSettle();
}

void expectTotalRightAligned(WidgetTester t, double width) {
  final button = find.byKey(const Key('trade-assets-deposit'));
  final deposit = t.getRect(button);
  final icon = t.getRect(find.descendant(of: button, matching: find.byType(SvgPicture)));
  final total = t.getRect(find.byKey(const Key('trade-assets-total')));
  expect(deposit.size, const Size(44, 44));
  expect(icon.size, const Size(16, 16));
  expect(icon.right, closeTo(width - 16, 0.01));
  expect(total.right, closeTo(icon.left - 8, 0.01));
}

Future<NavigationFixture> mount(
  WidgetTester t, {
  required AsterAccount data,
  TestAssetIndexRepository? prices,
  String language = 'en',
  double width = 393,
  double scale = 1,
}) async {
  final f = NavigationFixture(
    t,
    assetIndexRepository: prices,
    language: language,
    width: width,
    scale: scale,
  );
  t.view.physicalSize = Size(width, width == 844 ? 390 : 844);
  f.account.result = data;
  await launch(t, f.container);
  await f.container.read(accountReadProvider.notifier).refresh();
  await selectAssets(t);
  return f;
}

void main() {
  testWidgets('first account read uses a scoped skeleton and displays assets when settled', (
    t,
  ) async {
    final f = NavigationFixture(t);
    f.account.gate = Completer<void>();
    await launch(t, f.container);
    final read = f.container.read(accountReadProvider.notifier).refresh();
    await selectAssets(t);
    expect(find.byKey(const Key('trade-assets-loading')), findsOneWidget);
    expect(find.byType(PortfolioAssetRow), findsNothing);
    f.account.gate!.complete();
    await read;
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const Key('portfolio-asset-USDT')),
      250,
      scrollable: workspaceScroll,
    );
    expect(find.byKey(const Key('trade-assets-loading')), findsNothing);
    expect(f.account.calls, 1);
    expect(t.takeException(), isNull);
    await f.close(t);
  });

  testWidgets('preview assets stay labeled and funding actions cannot submit real operations', (
    t,
  ) async {
    final f = NavigationFixture(t, signedIn: false);
    await launch(t, f.container);
    f.container.read(portfolioPreviewProvider.notifier).select(true);
    await selectAssets(t);
    final list = t.widget<PortfolioAssetList>(find.byType(PortfolioAssetList));
    expect(list.preview, true);
    expectTotalRightAligned(t, 390);
    final deposit = find.byKey(const Key('trade-assets-deposit'));
    await t.ensureVisible(deposit);
    await t.pumpAndSettle();
    await t.tapAt(t.getTopLeft(deposit) + const Offset(2, 22));
    await t.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    f.expectNoAccountMutation();
    expect(t.takeException(), isNull);
    await f.close(t);
  });

  testWidgets('trade uses portfolio valuations, sorting, filtering and asset detail units', (
    t,
  ) async {
    final prices = TestAssetIndexRepository()
      ..result = assetIndexFixture(
        DateTime.now().toUtc(),
        prices: {'USDT': '0.98', 'BNB': '700', 'BTC': '80000'},
      );
    final f = await mount(
      t,
      prices: prices,
      data: account([
        balance('USDT', '10', pnl: '-0.3'),
        balance('BNB', '0.002', pnl: '0.001'),
        balance('BTC', '0.000001'),
        balance('UNKNOWN', '2'),
      ]),
    );
    final list = t.widget<PortfolioAssetList>(find.byType(PortfolioAssetList));
    expect(list.overview, same(f.container.read(portfolioOverviewProvider)));
    expect(list.overview.assets.map((a) => a.symbol), ['USDT', 'BNB', 'BTC', 'UNKNOWN']);
    expect(t.widget<AnimatedNumberText>(find.byKey(const Key('trade-assets-total'))).value, '—');
    expectTotalRightAligned(t, 393);
    expect(find.text(r'−$0.294'), findsOneWidget);
    await t.tap(find.byKey(const Key('portfolio-hide-small-assets')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-asset-BTC')), findsNothing);
    await t.scrollUntilVisible(
      find.byKey(const Key('portfolio-asset-UNKNOWN')),
      150,
      scrollable: workspaceScroll,
    );
    expect(find.byKey(const Key('portfolio-asset-UNKNOWN')), findsOneWidget);
    final bnb = find.byKey(const Key('portfolio-asset-BNB'));
    await t.scrollUntilVisible(bnb, -150, scrollable: workspaceScroll);
    await t.pumpAndSettle();
    await t.tap(bnb);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-asset-details')), findsOneWidget);
    expect(find.text('Available for order'), findsOneWidget);
    expect(find.text('0.003'), findsOneWidget);
    expect(find.text('0.002 BNB'), findsOneWidget);
    expect(find.text(r'+$0.70'), findsOneWidget);
    final badge = find.byType(PortfolioAssetBadge).last;
    expect(t.widget<PortfolioAssetBadge>(badge).size, 40);
    final icon = find.descendant(of: badge, matching: find.byType(SvgPicture));
    expect(t.getTopRight(icon).dx - t.getTopLeft(icon).dx, closeTo(40, 0.01));
    await t.tap(find.byKey(const Key('asset-details-close')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-asset-details')), findsNothing);
    expect(t.takeException(), isNull);
    await f.close(t);
  });

  testWidgets('1,000 trade assets build only visible rows in the page scroll', (t) async {
    final prices = TestAssetIndexRepository()
      ..result = assetIndexFixture(
        DateTime.now().toUtc(),
        prices: {for (var i = 0; i < 1000; i++) 'COIN$i': '1'},
      );
    final f = await mount(
      t,
      prices: prices,
      data: account(List.generate(1000, (i) => balance('COIN$i', '1'))),
    );
    expect(find.byType(PortfolioAssetRow).evaluate().length, lessThan(20));
    expect(find.byKey(const Key('portfolio-asset-COIN999')), findsNothing);
    await t.scrollUntilVisible(
      find.byKey(const Key('portfolio-asset-COIN30')),
      500,
      scrollable: workspaceScroll,
    );
    expect(find.byKey(const Key('portfolio-asset-COIN30')), findsOneWidget);
    expect(find.byType(PortfolioAssetRow).evaluate().length, lessThan(20));
    expect(t.takeException(), isNull);
    await f.close(t);
  });

  testWidgets('pull refresh awaits account and index failure while retaining asset rows', (
    t,
  ) async {
    final prices = TestAssetIndexRepository();
    final f = await mount(t, prices: prices, data: account([balance('USDT', '10')]));
    final rows = find.byKey(const Key('portfolio-asset-USDT'));
    prices.gate = Completer<AssetIndexSnapshot>();
    f.account.gate = Completer<void>();
    f.account.failure = const AccountReadFailure('accountReadFailed');
    var settled = false;
    final refresh = t
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show()
        .then((_) => settled = true);
    await t.pump(const Duration(seconds: 1));
    await t.pump();
    expect(settled, false);
    expect(find.byKey(const Key('trade-assets-loading')), findsNothing);
    expect(f.container.read(portfolioOverviewProvider).assets.single.symbol, 'USDT');
    f.account.gate!.complete();
    await t.pump(const Duration(seconds: 1));
    expect(settled, false);
    prices.gate!.completeError(StateError('synthetic index failure'));
    await t.pumpAndSettle();
    await refresh;
    expect(settled, true);
    await t.scrollUntilVisible(rows, 250, scrollable: workspaceScroll);
    await t.pumpAndSettle();
    expect(rows, findsOneWidget);
    expect(find.byKey(const Key('account-read-error')), findsOneWidget);
    expect(t.takeException(), isNull);
    await f.close(t);
  });

  for (final language in ['en', 'zh']) {
    for (final width in [320.0, 844.0]) {
      testWidgets('trade assets and details fit $language at $width with enlarged text', (t) async {
        final f = await mount(
          t,
          language: language,
          width: width,
          scale: 1.5,
          data: account([balance('USDT', '100000.123456789', pnl: '-0.3')]),
        );
        expectTotalRightAligned(t, width);
        final row = find.byKey(const Key('portfolio-asset-USDT'));
        await t.scrollUntilVisible(row, 250, scrollable: workspaceScroll);
        await t.pumpAndSettle();
        await t.tap(row);
        await t.pumpAndSettle();
        expect(find.byKey(const Key('portfolio-asset-details')), findsOneWidget);
        expect(t.takeException(), isNull);
        await f.close(t);
      });
    }
  }

  testWidgets('disconnected assets offer wallet connection without account requests', (t) async {
    final f = NavigationFixture(t, signedIn: false);
    await launch(t, f.container);
    await selectAssets(t);
    expect(find.byKey(const Key('trade-assets-login')), findsOneWidget);
    expect(find.byType(PortfolioAssetRow), findsNothing);
    expect(find.byType(FuturesWorkspace), findsOneWidget);
    f.expectNoAccountMutation();
    await f.close(t);
  });
}
