import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import 'package:vanta/features/market/domain/market.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/order_book.dart';

import '../../support/trade_fixture.dart';
import '../../support/workspace_navigation.dart';

void main() {
  for (final spec in [(360.0, 1.0), (390.0, 1.5)]) {
    testWidgets('tiny prices survive display, candle details and book-to-order ${spec.$1}', (
      tester,
    ) async {
      const value = 0.0000010203;
      final tiny = Market(
        symbol: 'BTCUSDT',
        price: Decimal.parse('$value'),
        change: 1,
        mark: value,
        index: value,
        high: value,
        low: value,
        volume: 100,
        funding: .01,
        nextFunding: fixture.nextFunding,
        precision: const MarketPrecision(priceTick: '0.0000000001', quantityStep: '0.05'),
        candles: [
          for (final candle in fixture.candles)
            Candle(
              time: candle.time,
              open: value,
              high: 0.0000010204,
              low: 0.0000010202,
              close: value,
              volume: 100,
            ),
        ],
      );
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$2,
        precision: tiny.precision,
        marketStream: Stream.value(tiny),
        bookStream: Stream.value(
          const OrderBook(
            asks: [BookLevel(value, 1.15)],
            bids: [BookLevel(value, 1.20)],
            trades: [MarketTrade(price: value, quantity: 1.15, buy: true, time: 1)],
          ),
        ),
      );
      await launch(tester, container);
      expect(find.text('0.0000010203'), findsWidgets);
      expect(
        tester.widget<KChartWidget>(find.byType(KChartWidget)).fixedLength,
        greaterThanOrEqualTo(10),
      );
      final point = tester.getTopLeft(find.byType(KChartWidget)) + const Offset(120, 90);
      final gesture = await tester.startGesture(point);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      final detail = find.byKey(const Key('candle-detail'));
      expect(detail, findsOneWidget);
      expect(find.descendant(of: detail, matching: find.text('0.0000010203')), findsNWidgets(2));
      expect(tester.takeException(), null);
      await gesture.up();
      await tester.pumpAndSettle();

      await selectWorkspace(tester, chart: false);
      final row = find.byKey(const ValueKey('BTCUSDT/ask/0.0000010203'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(container.read(orderPriceProvider), '0.0000010203');
      expect(
        tester.widget<TextField>(find.byKey(const Key('price-input'))).controller!.text,
        '0.0000010203',
      );
      final trades = find.descendant(of: find.byType(OrderBookPanel), matching: find.text('最新成交'));
      await tester.ensureVisible(trades);
      await tester.pumpAndSettle();
      await tester.tap(trades);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(OrderBookPanel), matching: find.text('0.0000010203')),
        findsOneWidget,
      );
      expect(tester.takeException(), null);

      container.read(accountProvider.notifier).connect();
      await tester.enterText(find.byKey(const Key('quantity-input')), '1.15');
      await tester.pumpAndSettle();
      final submit = find.byKey(const Key('submit-order'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm-order')), findsOneWidget);
      expect(find.text('0.0000010203 USDT'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
