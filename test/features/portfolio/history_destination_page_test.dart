import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/trading_history.dart';

import '../../support/trading_history.dart';

void main() {
  for (final locale in ['en', 'zh']) {
    testWidgets('primary History page switches all four record tabs: $locale', (t) async {
      await launchTradingHistory(t, HistoryRepository(), primary: true, locale: locale);
      expect(find.text(locale == 'en' ? 'History' : '历史记录'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing, reason: 'a destination, not a pushed route');
      for (final tab in TradingHistoryTab.values) {
        await historyTap(t, 'history-tab-${tab.name}');
        final selected = t.widget<Semantics>(
          find
              .ancestor(
                of: find.byKey(Key('history-tab-${tab.name}')),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(selected.properties.selected, isTrue, reason: tab.name);
      }
      expect(find.byKey(const Key('futures-history-page')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('orders tab shows records and fits narrow enlarged text', (t) async {
    await launchTradingHistory(t, HistoryRepository(), primary: true, width: 320, scale: 2);
    expect(find.byKey(const Key('history-filter')), findsOneWidget);
    expect(find.byKey(const Key('history-expand-order:AAPLUSDT:123')), findsOneWidget);
    await historyTap(t, 'history-tab-transactions');
    expect(find.byKey(const Key('history-filter')), findsNothing);
    expect(t.takeException(), isNull);
  });
}
