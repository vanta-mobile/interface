import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/trade/presentation/trade_theme.dart';
import 'package:vanta/features/market/domain/market.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/order_book.dart';

import 'support/trade_fixture.dart';
import 'support/workspace_navigation.dart';

Finder rowFor(String side, double price) => find.byKey(ValueKey('BTCUSDT/$side/$price'));

Finder barFor(String side, double price) => find.descendant(
  of: rowFor(side, price),
  matching: find.byKey(const Key('order-book-quantity-bar')),
);

void main() {
  testWidgets('order quantity backgrounds fill the row height', (tester) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: false);
    final price = find
        .descendant(of: find.byType(OrderBookPanel), matching: find.text('80,001'))
        .first;
    await tester.ensureVisible(price);
    await tester.pumpAndSettle();
    final row = find.ancestor(of: price, matching: find.byType(InkWell)).first;
    final bar = find.descendant(of: row, matching: find.byType(ColoredBox));
    expect(tester.getSize(bar).height, greaterThan(10));
    expect(tester.getSize(bar).width, greaterThan(0));
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('real depth updates animate bars on a shared scale and preserve price tapping', (
    tester,
  ) async {
    final updates = StreamController<OrderBook>();
    addTearDown(updates.close);
    final container = setup(tester, bookStream: updates.stream);
    updates.add(
      const OrderBook(
        asks: [BookLevel(80001, 1), BookLevel(80002, 4)],
        bids: [BookLevel(80000, 2), BookLevel(79999, 8)],
      ),
    );
    await launch(tester, container);
    await selectWorkspace(tester, chart: false);
    final row = rowFor('ask', 80001);
    final bar = barFor('ask', 80001);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final width = tester.getSize(row).width;
    final initial = tester.getSize(bar).width;
    expect(initial, closeTo(width / 8, .01));
    expect(tester.getSize(barFor('bid', 80000)).width, closeTo(width / 4, .01));
    expect(tester.getTopRight(bar).dx, tester.getTopRight(row).dx);
    expect(tester.widget<ColoredBox>(bar).color, TradeColors.negative.withValues(alpha: .15));
    expect(
      tester.widget<ColoredBox>(barFor('bid', 80000)).color,
      TradeColors.positive.withValues(alpha: .15),
    );
    updates.add(
      const OrderBook(
        asks: [BookLevel(80001, 6), BookLevel(80002, 4)],
        bids: [BookLevel(80000, 2), BookLevel(79999, 8)],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.getSize(bar).width, greaterThan(initial));
    expect(tester.getSize(bar).width, lessThan(width * .75));
    await tester.pumpAndSettle();
    expect(tester.getSize(bar).width, closeTo(width * .75, .01));
    expect(find.descendant(of: row, matching: find.text('6')), findsOneWidget);
    updates.add(
      const OrderBook(
        asks: [BookLevel(80001, 6), BookLevel(80002, 4), BookLevel(80003, 16)],
        bids: [BookLevel(80000, 2), BookLevel(79999, 8)],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(bar).width, closeTo(width * .375, .01));
    expect(tester.getTopRight(bar).dx, tester.getTopRight(row).dx);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(container.read(orderPriceProvider), '80001');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('zero quantities draw no width and reduced motion applies updates immediately', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final updates = StreamController<OrderBook>();
    addTearDown(updates.close);
    final container = setup(tester, bookStream: updates.stream);
    updates.add(const OrderBook(asks: [BookLevel(80001, 0)], bids: [BookLevel(80000, 0)]));
    await launch(tester, container);
    await selectWorkspace(tester, chart: false);
    final row = rowFor('ask', 80001);
    final bar = barFor('ask', 80001);
    expect(tester.getSize(bar).width, 0);
    expect(tester.getSize(bar).height, greaterThan(10));
    updates.add(const OrderBook(asks: [BookLevel(80001, 2)], bids: [BookLevel(80000, 4)]));
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(bar).width, closeTo(tester.getSize(row).width * .5, .01));
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
