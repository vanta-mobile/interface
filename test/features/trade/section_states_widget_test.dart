import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/domain/market.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/presentation/aster_open_orders_panel.dart';
import 'package:vanta/features/trade/presentation/widgets/compact_order_book.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';
import '../../support/workspace_navigation.dart';

Finder inBook(Finder finder) =>
    find.descendant(of: find.byType(CompactOrderBook), matching: finder);
Finder inOrders(Finder finder) =>
    find.descendant(of: find.byType(AsterOpenOrdersPanel), matching: finder);
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
    expect(find.byKey(const ValueKey('BTCUSDT/ask/80001.0')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed first order read retries in place and then shows the empty state', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestOpenOrdersRepository()
      ..failure = const AccountReadFailure('accountPermissionRequired', code: -2015);
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: orders,
      language: const Locale('en'),
    );
    await launch(tester, container);
    await container.read(openOrdersReadProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(inOrders(find.text('Unable to Load')), findsOneWidget);
    expect(inOrders(find.textContaining('Aster error code: -2015')), findsOneWidget);
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
    expect(find.byKey(const Key('read-open-orders')), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Signing out clears the snapshot and its expiry timer.
    identity.events.add(null);
    await tester.pumpAndSettle();
  });
}
