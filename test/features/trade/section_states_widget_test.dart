import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/domain/market.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/presentation/trade_open_orders_section.dart';
import 'package:vanta/features/trade/presentation/widgets/compact_order_book.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';
import '../../support/trading_agents.dart';
import '../../support/workspace_navigation.dart';

Finder inBook(Finder finder) =>
    find.descendant(of: find.byType(CompactOrderBook), matching: finder);
Finder inOrders(Finder finder) =>
    find.descendant(of: find.byType(TradeOpenOrdersSection), matching: finder);
const retry = Key('status-retry');
const spinner = Key('status-action-loading');

void main() {
  testWidgets('compact book shows a skeleton, then a retryable failure, then rows', (tester) async {
    final books = StreamController<OrderBook>.broadcast();
    addTearDown(books.close);
    final container = setup(tester, language: const Locale('en'), bookStream: books.stream);
    await tester.pumpWidget(const SizedBox());
    await launch(tester, container);
    await selectWorkspace(tester, chart: false);

    expect(inBook(find.byKey(const Key('order-book-skeleton'))), findsOneWidget);
    expect(inBook(find.byKey(const Key('status-failure'))), findsNothing);

    books.addError(StateError('socket closed'));
    await tester.pumpAndSettle();
    expect(inBook(find.text('Unable to Load')), findsOneWidget);
    expect(inBook(find.text('Order book disconnected. Reconnecting.')), findsOneWidget);

    await tester.ensureVisible(inBook(find.byKey(retry)));
    await tester.tap(inBook(find.byKey(retry)));
    await tester.pump();
    expect(inBook(find.byKey(spinner)), findsOneWidget);

    books.add(const OrderBook(asks: [BookLevel(80001, 1)], bids: [BookLevel(80000, 2)]));
    await tester.pumpAndSettle();
    expect(inBook(find.byKey(const Key('status-failure'))), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('BTCUSDT/ask/0')),
        matching: find.text('80,001'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the book beside the order form shows as many level pairs as fit its height', (
    tester,
  ) async {
    final books = StreamController<OrderBook>.broadcast();
    addTearDown(books.close);
    final container = setup(tester, language: const Locale('en'), bookStream: books.stream);
    await tester.pumpWidget(const SizedBox());
    await launch(tester, container);
    await selectWorkspace(tester, chart: false);
    books.add(
      OrderBook(
        asks: [for (var i = 0; i < 20; i++) BookLevel(80001.0 + i, 1)],
        bids: [for (var i = 0; i < 20; i++) BookLevel(80000.0 - i, 1)],
      ),
    );
    await tester.pumpAndSettle();
    int levels(String side) {
      var count = 0;
      while (find.byKey(ValueKey('BTCUSDT/$side/$count')).evaluate().isNotEmpty) {
        count++;
      }
      return count;
    }

    // Both sides keep the same count, and the book ends near the form's
    // bottom: not below it, and less than one level pair above it.
    expect(levels('ask'), levels('bid'));
    final form = tester.getRect(find.byKey(const Key('trade-live-order')));
    final book = tester.getRect(find.byType(CompactOrderBook));
    final row = tester.getSize(find.byKey(const ValueKey('BTCUSDT/bid/0'))).height;
    expect(book.bottom, lessThanOrEqualTo(form.bottom + 1));
    expect(form.bottom - book.bottom, lessThan(2 * row + 1));
    expect(levels('ask'), isNot(8));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a missing device agent leads to Enable trading, not a bare retry', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestOpenOrdersRepository()
      ..failure = const AccountReadFailure('accountPermissionRequired', code: -1000);
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: orders,
      language: const Locale('en'),
      tradingAgentStore: await tester.runAsync(activeAgentStore),
      verifiedApiSession: true,
    );
    await launch(tester, container);
    await awaitTradingAgent(tester, container);
    await revealFuturesAccountTabs(tester);
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(TradeOpenOrdersSection)));
    expect(inOrders(find.text(l.enableTradingTitle)), findsOneWidget);
    expect(inOrders(find.byKey(const Key('trade-order-retry'))), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Signing out clears the snapshot and its expiry timer.
    identity.events.add(null);
    await tester.pumpAndSettle();
  });

  testWidgets('an account Aster has not opened yet (-5050) shows no orders, not a failure', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestOpenOrdersRepository()
      ..failure = const AccountReadFailure('accountDepositRequired', code: -5050);
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: orders,
      language: const Locale('en'),
      tradingAgentStore: await tester.runAsync(activeAgentStore),
      verifiedApiSession: true,
    );
    await launch(tester, container);
    await awaitTradingAgent(tester, container);
    await revealFuturesAccountTabs(tester);
    await tester.pumpAndSettle();
    expect(orders.calls, 1);
    expect(inOrders(find.byKey(const Key('status-failure'))), findsNothing);
    expect(inOrders(find.textContaining('-5050')), findsNothing);
    expect(inOrders(find.byKey(const Key('open-orders-empty'))), findsOneWidget);
    expect(tester.takeException(), isNull);
    identity.events.add(null);
    await tester.pumpAndSettle();
  });

  testWidgets('failed first order read retries in place and then shows the empty state', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestOpenOrdersRepository()
      ..failure = const AccountReadFailure('accountReadFailed', code: -1001);
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: orders,
      language: const Locale('en'),
      // Signed-in launches pass trading onboarding before the workspace shows.
      tradingAgentStore: await tester.runAsync(activeAgentStore),
      verifiedApiSession: true,
    );
    await launch(tester, container);
    await awaitTradingAgent(tester, container);
    await revealFuturesAccountTabs(tester);
    // The active grant makes the first read automatically and silently.
    await tester.pumpAndSettle();
    expect(orders.calls, 1);

    expect(inOrders(find.text('Unable to Load')), findsOneWidget);
    expect(inOrders(find.textContaining('Aster error code: -1001')), findsOneWidget);
    expect(find.byKey(const Key('read-open-orders')), findsNothing);

    orders
      ..failure = null
      ..gate = Completer<void>()
      ..result = AsterOpenOrders(
        address: accountAddress,
        receivedAt: DateTime.utc(2026),
        orders: [],
      );
    await tester.ensureVisible(inOrders(find.byKey(retry)));
    await tester.pumpAndSettle();
    await tester.tap(inOrders(find.byKey(retry)));
    await tester.pump();
    expect(orders.calls, 2);
    expect(inOrders(find.byKey(spinner)), findsOneWidget);
    await tester.tap(inOrders(find.byKey(retry)));
    await tester.pump();
    expect(orders.calls, 2);

    orders.gate!.complete();
    await tester.pumpAndSettle();
    expect(inOrders(find.byKey(const Key('status-failure'))), findsNothing);
    expect(inOrders(find.text('No Data Yet')), findsOneWidget);
    expect(find.text('No open perpetual orders in this account.'), findsOneWidget);
    // Reads are signed silently by the device grant; no manual read button.
    expect(find.byKey(const Key('read-open-orders')), findsNothing);
    expect(tester.takeException(), isNull);
    // Signing out clears the snapshot and its expiry timer.
    identity.events.add(null);
    await tester.pumpAndSettle();
  });
}
