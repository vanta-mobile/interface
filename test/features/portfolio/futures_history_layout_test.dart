import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/trading_history.dart';
import 'package:vanta/features/portfolio/data/trading_history_mapper.dart';
import 'package:vanta/features/portfolio/presentation/trading_history_components.dart';
import 'package:vanta/features/portfolio/presentation/trading_history_fill_card.dart';
import 'package:vanta/features/portfolio/presentation/trading_history_order_card.dart';
import 'package:vanta/features/portfolio/presentation/trading_history_position_card.dart';
import 'package:vanta/features/portfolio/presentation/trading_history_transaction_row.dart';

import '../../support/trading_history.dart';

void main() {
  for (final shape in [
    (320.0, 844.0, 2.0),
    (393.0, 852.0, 1.0),
    (844.0, 390.0, 1.5),
    (768.0, 1024.0, 1.0),
  ]) {
    for (final locale in ['en', 'zh']) {
      testWidgets('history tabs and details fit $shape $locale', (t) async {
        await launchTradingHistory(
          t,
          HistoryRepository(),
          width: shape.$1,
          height: shape.$2,
          scale: shape.$3,
          locale: locale,
        );
        // Compact tab rows still start at the page inset on wide layouts.
        expect(t.getTopLeft(find.byKey(const Key('history-tab-orders'))).dx, closeTo(16, 0.01));
        for (final card in find.byType(TradingHistoryOrderCard).evaluate()) {
          final parent = find.byWidget(card.widget);
          final arrow = find.descendant(of: parent, matching: find.byType(HistoryExpand));
          expect(t.getRect(arrow).right, closeTo(shape.$1 - 16, 0.01));
        }
        await historyTap(t, 'history-expand-order:AAPLUSDT:123');
        expectHistoryValuesAtRight(t, right: shape.$1 - 28);
        expect(t.takeException(), isNull);
        await historyTap(t, 'history-details-123');
        expectHistoryValuesAtRight(t, parent: find.byKey(const Key('history-order-details')));
        expect(t.takeException(), isNull);
        await t.tap(find.byTooltip(locale == 'en' ? 'Close' : '关闭'));
        await t.pumpAndSettle();
        for (final tab in TradingHistoryTab.values.skip(1)) {
          await historyTap(t, 'history-tab-${tab.name}');
          if (tab == TradingHistoryTab.positions) {
            await historyTap(t, 'history-expand-position:7');
            final card = find.byType(TradingHistoryPositionCard);
            final right = t.getRect(card).right - 17; // Card padding plus border.
            expectHistoryValuesAtRight(t, parent: card, right: right);
            final roe = find.descendant(
              of: card,
              matching: find.text(locale == 'en' ? 'Realized ROE%' : '已实现收益率'),
            );
            expect(roe, findsOneWidget);
            expect(t.getRect(roe).right, closeTo(right - 8, 0.01));
          } else if (tab == TradingHistoryTab.trades) {
            final card = find.byType(TradingHistoryFillCard);
            final right = t.getRect(card).right - 17;
            expectHistoryValuesAtRight(t, parent: card, right: right);
            expect(t.getRect(find.text('0.00 USDT')).right, closeTo(right, 0.01));
          } else {
            final symbol = find.descendant(
              of: find.byType(TradingHistoryTransactionRow),
              matching: find.text('AAPLUSDT'),
            );
            expect(t.getRect(symbol).right, closeTo(shape.$1 - 16, 0.01));
            expect(t.getRect(find.byType(HistoryTag)).right, closeTo(shape.$1 - 16, 0.01));
          }
          expect(t.takeException(), isNull);
        }
      });
    }
  }
  testWidgets('inferred position never presents snapshot entry or open time as fact', (t) async {
    final repository = HistoryRepository();
    repository.rows[TradingHistoryTab.positions] = mapTradingHistory([
      historyPosition(inferred: true),
    ], TradingHistoryTab.positions);
    await launchTradingHistory(t, repository);
    await historyTap(t, 'history-tab-positions');
    await historyTap(t, 'history-expand-position:7');
    expect(find.text('189.200000'), findsNothing);
    expect(find.textContaining('09:18:06'), findsNothing);
    expect(find.text('194.600000'), findsOneWidget);
  });
}

void expectHistoryValuesAtRight(WidgetTester tester, {Finder? parent, double? right}) {
  final rows = parent == null
      ? find.byType(HistoryRow)
      : find.descendant(of: parent, matching: find.byType(HistoryRow));
  expect(rows, findsWidgets);
  for (final element in rows.evaluate()) {
    final row = element.widget as HistoryRow;
    final finder = find.byWidget(row);
    final edge = tester.getRect(finder).right;
    if (right != null) expect(edge, closeTo(right, 0.01));
    final value = find.descendant(
      of: finder,
      matching: row.copyable ? find.byType(IconButton) : find.text(row.value),
    );
    expect(tester.getRect(value).right, closeTo(edge, 0.01), reason: row.label);
    if (!row.copyable) expect(tester.widget<Text>(value).textAlign, TextAlign.end);
  }
}
