import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import 'package:vanta/features/market/domain/market.dart';
import 'package:vanta/features/trade/application/navigation_provider.dart';
import 'package:vanta/features/trade/application/page_refresh_provider.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/market_sheet.dart';
import 'package:vanta/features/trade/presentation/widgets/trade_icon.dart';
import 'package:vanta/features/trade/presentation/widgets/primitives.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/features/trade/presentation/trade_theme.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';
import '../../support/workspace_navigation.dart';

void main() {
  testWidgets('restored identity without account read still shows configuration previews', (
    t,
  ) async {
    final f = NavigationFixture(t, signedIn: true);
    await launch(t, f.container);
    final l = AppLocalizations.of(t.element(find.byType(LiveOrderScreen)));
    expect(find.text(l.cross), findsOneWidget);
    expect(find.text(l.assetModeMulti), findsOneWidget);
    f.expectNoAccountMutation();
    await f.close(t);
  });
  testWidgets('first visit selects order form and exposes public price without account reads', (
    t,
  ) async {
    final f = NavigationFixture(t, signedIn: false);
    await launch(t, f.container);
    expect(f.container.read(futuresWorkspaceTabProvider), FuturesWorkspaceTab.trade);
    expect(find.byType(LiveOrderScreen), findsOneWidget);
    expect(find.byType(KChartWidget), findsNothing);
    final selected = find.byKey(const Key('trade-workspace-trade'));
    expect(t.widget<Semantics>(selected).properties.selected, true);
    final button = t.widget<IconButton>(
      find.descendant(of: selected, matching: find.byType(IconButton)),
    );
    expect(button.style!.backgroundColor!.resolve({}), TradeColors.card);
    final field = t.widget<TextFormField>(find.byType(TextFormField));
    expect(field.initialValue, marketInput(f.container.read(currentMarketProvider)!.price));
    expect(t.widget<ValueRow>(find.byKey(const Key('trade-available'))).value, '—');
    expect(t.widget<TextField>(find.byKey(const Key('trade-pending-quantity'))).enabled, false);
    await selectWorkspace(t, chart: true);
    expect(find.byType(KChartWidget), findsOneWidget);
    expect(
      t.widget<Semantics>(find.byKey(const Key('trade-workspace-chart'))).properties.selected,
      true,
    );
    await selectWorkspace(t, chart: false);
    f.container.read(orderPriceProvider.notifier).setPrice('123.45');
    await t.pumpAndSettle();
    expect(t.widget<TextFormField>(find.byType(TextFormField)).initialValue, '123.45');
    f.expectNoAccountMutation();
    expect(t.takeException(), isNull);
    await f.close(t);
  });
  testWidgets('chart trades allow multiple fills in the same millisecond across updates', (
    t,
  ) async {
    final updates = StreamController<OrderBook>();
    addTearDown(updates.close);
    final f = NavigationFixture(t, signedIn: false, booksForSymbol: (_) => updates.stream);
    await launch(t, f.container);
    await selectWorkspace(t, chart: true);
    const trade = MarketTrade(price: 90123, quantity: 0.5, buy: true, time: 1700000000000);
    for (final count in [2, 5, 3]) {
      updates.add(OrderBook(asks: book.asks, bids: book.bids, trades: List.filled(count, trade)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('22:13:20'), findsNWidgets(count));
    }
    await f.close(t);
  });
  for (final language in ['en', 'zh']) {
    for (final size in [const Size(320, 700), const Size(844, 390), const Size(768, 1024)]) {
      testWidgets('Trade design, selector and keyboard fit $language $size', (t) async {
        final f = NavigationFixture(
          t,
          language: language,
          width: size.width,
          scale: 1.5,
          signedIn: false,
        );
        t.view.physicalSize = size;
        await launch(t, f.container);
        await selectWorkspace(t, chart: true);
        expect(find.byType(KChartWidget), findsOneWidget);
        expect(find.byKey(const Key('chart-order-book')), findsOneWidget);
        await selectWorkspace(t, chart: false);
        expect(find.byType(KChartWidget), findsNothing);
        expect(find.byType(LiveOrderScreen), findsOneWidget);
        expect(f.container.read(accountProvider).connected, false);
        expect(t.widget<TextField>(find.byKey(const Key('trade-pending-quantity'))).enabled, false);
        expect(
          t.widget<TextField>(find.byKey(const Key('trade-pending-quantity'))).controller?.text ??
              '',
          isEmpty,
        );
        expect(t.widget<ValueRow>(find.byKey(const Key('trade-available'))).value, '—');
        expect(find.text('12.5K USDT'), findsNothing);
        expect(find.text('3.03'), findsNothing);
        await t.ensureVisible(find.byKey(const Key('trade-market-selector')));
        await t.tap(find.byKey(const Key('trade-market-selector')));
        await t.pumpAndSettle();
        expect(find.byType(MarketSheet), findsOneWidget);
        await t.ensureVisible(find.byKey(const Key('market-search')));
        await t.enterText(find.byKey(const Key('market-search')), 'ETH');
        await t.pumpAndSettle();
        expect(find.byKey(const Key('market-ETHUSDT')), findsOneWidget);
        await t.ensureVisible(find.byKey(const Key('close-market-selector')));
        await t.tap(find.byKey(const Key('close-market-selector')));
        await t.pumpAndSettle();
        expect(f.container.read(symbolProvider), 'BTCUSDT');
        expect(find.byKey(const Key('enter-demo')), findsNothing);
        expect(t.takeException(), null);
        f.expectNoAccountMutation();
        await f.close(t);
      });
    }
    testWidgets('Trade header actions follow designed spacing $language', (t) async {
      final f = NavigationFixture(t, language: language, width: 393);
      await launch(t, f.container);
      await selectWorkspace(t, chart: true);
      final settings = t.getRect(find.byKey(const Key('trade-settings')));
      final bell = t.getRect(find.byKey(const Key('notifications-entry')));
      final ai = t.getRect(find.byKey(const Key('trade-ask-ai')));
      expect(ai.right, 393 - 16);
      expect(ai.height, 44);
      expect(ai.width, greaterThanOrEqualTo(78));
      expect(settings.size, const Size(24, 44));
      expect(bell.size, const Size(24, 44));
      expect(bell.left - settings.right, 8);
      expect(ai.left - bell.right, 8);
      expect(t.takeException(), null);
      await f.close(t);
    });
    testWidgets('Trade settings match the two account-mode rows and retain AI entry $language', (
      t,
    ) async {
      final f = NavigationFixture(t, language: language, width: 320, scale: 1.5);
      await launch(t, f.container);
      await selectWorkspace(t, chart: true);
      expect(find.byType(TradeIcon), findsNWidgets(5));
      await t.tap(find.byKey(const Key('trade-settings')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('settings-asset-mode')), findsOneWidget);
      expect(find.byKey(const Key('settings-position-mode')), findsOneWidget);
      expect(find.byKey(const Key('order-recovery-entry')), findsNothing);
      Navigator.of(t.element(find.byKey(const Key('settings-asset-mode')))).pop();
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('trade-ask-ai')));
      await t.pumpAndSettle();
      expect(f.container.read(appDestinationProvider), AppDestination.assistant);
      expect(t.takeException(), null);
      f.expectNoAccountMutation();
      await f.close(t);
    });
  }
  testWidgets('Futures refresh waits for the replacement public book, including failure', (
    t,
  ) async {
    final nextBook = StreamController<OrderBook>();
    var subscriptions = 0;
    final f = NavigationFixture(
      t,
      booksForSymbol: (_) => subscriptions++ == 0 ? Stream.value(book) : nextBook.stream,
    );
    await launch(t, f.container);
    await selectWorkspace(t, chart: true);
    var completed = false;
    final refresh = f.container.read(pageRefreshProvider).futures().then((_) => completed = true);
    await t.pump();
    expect(subscriptions, 2);
    expect(completed, false);
    nextBook.addError(StateError('synthetic book refresh failure'));
    await t.pump();
    await t.pumpAndSettle();
    expect(completed, true);
    await refresh;
    f.expectNoAccountMutation();
    await f.close(t);
    unawaited(nextBook.close());
  });
}
