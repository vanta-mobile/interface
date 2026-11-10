import 'package:vanta/features/trade/application/navigation_provider.dart';

import '../../support/workspace_navigation.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/domain/market.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/market_header.dart';
import 'package:vanta/main.dart';

import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';

Finder buttonQuote(String side, String quote) =>
    find.descendant(of: find.byKey(Key('quick-order-$side')), matching: find.text(quote));

void main() {
  testWidgets('unloaded chart summary has unknown values; data replaces placeholders', (
    tester,
  ) async {
    final markets = StreamController<Market>(sync: true);
    final fixture = NavigationFixture(tester, marketStream: markets.stream);
    addTearDown(markets.close);
    fixture.container.read(futuresWorkspaceTabProvider.notifier).select(FuturesWorkspaceTab.chart);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: fixture.container, child: const VantaApp()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final header = find.byType(MarketHeader);
    expect(find.descendant(of: header, matching: find.text('00:00:00')), findsNothing);
    expect(find.descendant(of: header, matching: find.text('—')), findsWidgets);
    markets.add(fixtureMarket('BTCUSDT', '1m'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: header, matching: find.text(r'$80,000')), findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('—')), findsNothing);
    fixture.expectNoAccountMutation();
    expect(tester.takeException(), null);
    await fixture.close(tester);
  });

  testWidgets('new symbol loading never displays retained prior book quote', (tester) async {
    final btc = StreamController<OrderBook>(sync: true);
    final eth = StreamController<OrderBook>(sync: true);
    addTearDown(btc.close);
    addTearDown(eth.close);
    final fixture = NavigationFixture(
      tester,
      booksForSymbol: (symbol) => symbol == 'BTCUSDT' ? btc.stream : eth.stream,
    );
    await launch(tester, fixture.container);
    await selectWorkspace(tester, chart: true);
    btc.add(book);
    await tester.pumpAndSettle();
    expect(buttonQuote('buy', '80001.0 USDT'), findsOneWidget);
    expect(buttonQuote('sell', '80000.0 USDT'), findsOneWidget);
    fixture.container.read(symbolProvider.notifier).select('ETHUSDT');
    await tester.pumpAndSettle();
    final loading = fixture.container.read(bookProvider);
    expect(loading.isLoading, true);
    expect(
      loading.value,
      same(book),
      reason: 'Exercise Riverpod retained data during a symbol change',
    );
    expect(buttonQuote('buy', '—'), findsOneWidget);
    expect(buttonQuote('sell', '—'), findsOneWidget);
    eth.add(const OrderBook(asks: [BookLevel(2001, 1)], bids: [BookLevel(1999, 1)]));
    await tester.pumpAndSettle();
    expect(buttonQuote('buy', '2001.0 USDT'), findsOneWidget);
    expect(buttonQuote('sell', '1999.0 USDT'), findsOneWidget);
    fixture.expectNoAccountMutation();
    expect(tester.takeException(), null);
    await fixture.close(tester);
  });

  testWidgets('book stream error suppresses retained quotes until a fresh event', (tester) async {
    final books = StreamController<OrderBook>(sync: true);
    addTearDown(books.close);
    final fixture = NavigationFixture(tester, booksForSymbol: (_) => books.stream);
    await launch(tester, fixture.container);
    await selectWorkspace(tester, chart: true);
    books.add(book);
    await tester.pumpAndSettle();
    expect(buttonQuote('buy', '80001.0 USDT'), findsOneWidget);
    books.addError(StateError('synthetic public book failure'));
    await tester.pumpAndSettle();
    expect(fixture.container.read(bookProvider).hasError, true);
    expect(fixture.container.read(bookProvider).value, same(book));
    expect(buttonQuote('buy', '—'), findsOneWidget);
    expect(buttonQuote('sell', '—'), findsOneWidget);
    books.add(const OrderBook(asks: [BookLevel(80003, 1)], bids: [BookLevel(80002, 1)]));
    await tester.pumpAndSettle();
    expect(buttonQuote('buy', '80003.0 USDT'), findsOneWidget);
    expect(buttonQuote('sell', '80002.0 USDT'), findsOneWidget);
    fixture.expectNoAccountMutation();
    expect(tester.takeException(), null);
    await fixture.close(tester);
  });

  for (final disconnected in [true, false]) {
    testWidgets('offline/disconnected book has no live quick prices $disconnected', (tester) async {
      final fixture = NavigationFixture(
        tester,
        booksForSymbol: (_) => Stream.value(
          OrderBook(
            asks: book.asks,
            bids: book.bids,
            connected: !disconnected,
            offline: !disconnected,
          ),
        ),
      );
      await launch(tester, fixture.container);
      await selectWorkspace(tester, chart: true);
      expect(buttonQuote('buy', '—'), findsOneWidget);
      expect(buttonQuote('sell', '—'), findsOneWidget);
      fixture.expectNoAccountMutation();
      expect(tester.takeException(), null);
      await fixture.close(tester);
    });
  }
}
