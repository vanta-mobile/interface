import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/trading_history_mapper.dart';
import 'package:vanta/features/portfolio/domain/trading_history.dart';
import 'package:vanta/features/portfolio/presentation/trading_history_order_card.dart';

import '../../support/trading_history.dart';

void main() {
  for (final locale in ['en', 'zh']) {
    testWidgets('observed metadata and estimated ROE fit narrow enlarged text: $locale', (t) async {
      final repository = HistoryRepository();
      repository.rows[TradingHistoryTab.positions] = mapTradingHistory([
        {
          ...historyPosition(),
          'leverage': '20',
          'margin_type': 'isolated',
          'closed_qty': '0.04',
          'roe': '0.125',
        },
      ], TradingHistoryTab.positions);
      await launchTradingHistory(t, repository, width: 320, scale: 2, locale: locale);
      await historyTap(t, 'history-tab-positions');
      expect(find.text('12.50%'), findsOneWidget);
      expect(find.textContaining('20x'), findsOneWidget);
      await historyTap(t, 'history-expand-position:7');
      expect(find.text('0.04 AAPL'), findsOneWidget);
      expect(
        find.textContaining(locale == 'en' ? 'first values observed' : '首次观测值'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('linked orders retain data on refresh failure and disappear on wallet change', (
    t,
  ) async {
    final repository = HistoryRepository();
    final container = await launchTradingHistory(t, repository);
    await historyTap(t, 'history-tab-positions');
    await historyTap(t, 'history-expand-position:7');
    await historyTap(t, 'history-position-details-7');
    final sheet = find.byKey(const Key('history-related-orders'));
    expect(
      find.descendant(of: sheet, matching: find.byType(TradingHistoryOrderCard)),
      findsNWidgets(2),
    );
    final refresh = find.ancestor(of: sheet, matching: find.byType(RefreshIndicator));
    repository.gate = Completer<void>();
    var settled = false;
    final pending = t.widget<RefreshIndicator>(refresh).onRefresh().then((_) => settled = true);
    await t.pump();
    expect(settled, isFalse);
    repository.failure = const VantaApiFailure(
      vantaApiRequestFailed,
      details: ApiErrorDetails(message: 'Archive unavailable', status: 503),
    );
    repository.gate!.complete();
    await pending;
    await t.pumpAndSettle();
    expect(find.text('Archive unavailable'), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.byType(TradingHistoryOrderCard)),
      findsNWidgets(2),
    );
    (container.read(authProvider.notifier) as HistoryAuth).set(const AuthSession());
    await t.pumpAndSettle();
    expect(find.byType(TradingHistoryOrderCard), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('unbackfilled cycle remains a recoverable error, empty links are a distinct result', (
    t,
  ) async {
    final repository = HistoryRepository();
    await launchTradingHistory(t, repository);
    await historyTap(t, 'history-tab-positions');
    await historyTap(t, 'history-expand-position:7');
    repository.failure = const VantaApiFailure(
      vantaApiRequestFailed,
      code: 'not_found',
      details: ApiErrorDetails(message: 'Position cycle has not been rebuilt', status: 404),
    );
    await historyTap(t, 'history-position-details-7');
    expect(find.text('Position cycle has not been rebuilt'), findsOneWidget);
    expect(find.byType(TradingHistoryOrderCard), findsNothing);
    repository.failure = null;
    repository.rows[TradingHistoryTab.orders] = [];
    await t.tap(find.byKey(const Key('status-retry')));
    await t.pumpAndSettle();
    expect(find.text('Position cycle has not been rebuilt'), findsNothing);
    expect(find.byType(TradingHistoryOrderCard), findsNothing);
    expect(repository.positionOrderCalls, hasLength(2));
  });
}
