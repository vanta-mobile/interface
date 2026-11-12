import 'dart:async';

import 'package:decimal/decimal.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/presentation/status_view.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/portfolio/data/aster_trading_history_mapper.dart';
import 'package:vanta/features/portfolio/domain/futures_history.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/application/trading_history_provider.dart';
import 'package:vanta/features/portfolio/domain/trading_history.dart';
import 'package:vanta/features/portfolio/presentation/trading_history_order_card.dart';
import 'package:vanta/features/portfolio/presentation/trading_history_position_card.dart';
import 'package:vanta/features/portfolio/presentation/trading_history_fill_card.dart';
import 'package:vanta/features/portfolio/presentation/trading_history_transaction_row.dart';

import '../../support/trading_history.dart';

void main() {
  testWidgets('four tabs read their API and canceled filtering is local', (t) async {
    final repository = HistoryRepository();
    await launchTradingHistory(t, repository);
    expect(find.byType(TradingHistoryOrderCard), findsNWidgets(2));
    expect(repository.calls, hasLength(1));
    await historyTap(t, 'history-filter');
    expect(find.byType(TradingHistoryOrderCard), findsOneWidget);
    expect(repository.calls, hasLength(1));
    for (final (tab, type) in [
      (TradingHistoryTab.positions, TradingHistoryPositionCard),
      (TradingHistoryTab.trades, TradingHistoryFillCard),
      (TradingHistoryTab.transactions, TradingHistoryTransactionRow),
    ]) {
      await historyTap(t, 'history-tab-${tab.name}');
      expect(find.byType(type), findsOneWidget);
      expect(repository.calls.last.$1, tab);
    }
    expect(find.byKey(const Key('history-filter')), findsNothing);
    expect(find.text('-0.00000043 USDT'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('order expansion, exact linked fills, fee sign and close', (t) async {
    final repository = HistoryRepository();
    await launchTradingHistory(t, repository);
    await historyTap(t, 'history-expand-order:AAPLUSDT:123');
    expect(find.text('190.100000 / 190.000000'), findsOneWidget);
    expect(find.text('570.30 / 1,140.00'), findsOneWidget);
    await historyTap(t, 'history-details-123');
    expect(find.byKey(const Key('history-order-details')), findsOneWidget);
    expect(find.text('Order Details'), findsOneWidget);
    expect(find.text('0.071288 USDT'), findsNWidgets(2));
    expect(find.widgetWithText(SelectableText, '123'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, '50'), findsOneWidget);
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(
      () =>
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await t.tap(find.byKey(const ValueKey('history-copy-Order ID')));
    await t.pump();
    expect(copied, '123');
    expect(find.text('Maker'), findsNothing);
    expect(find.text('Taker'), findsNothing);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('history-order-details')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('position details explain unavailable linkage; inferred fields are hidden', (
    t,
  ) async {
    final repository = HistoryRepository();
    await launchTradingHistory(t, repository);
    await historyTap(t, 'history-tab-positions');
    expect(find.text('+0.27 USDT'), findsOneWidget);
    await historyTap(t, 'history-expand-position:7');
    expect(find.text('189.200000'), findsOneWidget);
    expect(find.text('194.600000'), findsOneWidget);
    await historyTap(t, 'history-position-details-7');
    expect(find.text('Related Orders'), findsOneWidget);
    expect(find.textContaining('does not provide position-to-order links'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('pull refresh waits for the request and retains results on server failure', (
    t,
  ) async {
    final repository = HistoryRepository();
    final c = await launchTradingHistory(t, repository);
    repository.gate = Completer<void>();
    final indicator = t.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    var settled = false;
    final refresh = indicator.onRefresh().then((_) => settled = true);
    await t.pump();
    expect(settled, isFalse);
    expect(find.byType(TradingHistoryOrderCard), findsNWidgets(2));
    repository.failure = const VantaApiFailure(
      vantaApiRequestFailed,
      details: ApiErrorDetails(message: 'History archive is temporarily unavailable', status: 503),
    );
    repository.gate!.complete();
    await refresh;
    await t.pumpAndSettle();
    expect(settled, isTrue);
    expect(find.text('History archive is temporarily unavailable'), findsOneWidget);
    expect(find.byType(TradingHistoryOrderCard), findsNWidgets(2));
    expect(c.read(tradingHistoryProvider(TradingHistoryTab.orders)).page, isNotNull);
  });

  testWidgets('initial loading, failure retry, partial and empty are section scoped', (t) async {
    final repository = HistoryRepository()..gate = Completer<void>();
    await launchTradingHistory(t, repository);
    expect(find.byType(SkeletonBox), findsNWidgets(3));
    repository.failure = const VantaApiFailure(
      vantaApiRequestFailed,
      details: ApiErrorDetails(message: 'Read limit reached', status: 429),
    );
    repository.gate!.complete();
    await t.pumpAndSettle();
    expect(find.text('Read limit reached'), findsOneWidget);
    repository.gate = null;
    repository.failure = null;
    repository.partial = true;
    repository.rows[TradingHistoryTab.orders] = [];
    await t.tap(find.byKey(const Key('status-retry')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('futures-history-empty')), findsOneWidget);
    expect(find.text('History is incomplete. Some records may be unavailable.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('refresh waits for contract units as well as history', (t) async {
    final unitsGate = Completer<void>();
    var waitForUnits = false;
    await launchTradingHistory(
      t,
      HistoryRepository(),
      loadUnits: () async {
        if (waitForUnits) await unitsGate.future;
        return historyUnits;
      },
    );
    waitForUnits = true;
    var settled = false;
    final refresh = t
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh()
        .then((_) => settled = true);
    await t.pump();
    expect(settled, isFalse);
    unitsGate.complete();
    await refresh;
    expect(settled, isTrue);
  });

  testWidgets('pull refresh does not request a signature; Sign is explicit', (t) async {
    final c = await launchTradingHistory(t, HistoryRepository());
    await historyTap(t, 'history-tab-trades');
    final session = c.read(vantaApiSessionProvider.notifier) as HistorySession;
    session.set(
      const VantaApiSessionState(VantaApiSessionStatus.signedOut, address: historyAddress),
    );
    await t.pumpAndSettle();
    await t.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    expect(session.signInCalls, 0);
    await t.tap(find.byKey(const Key('status-retry')));
    await t.pumpAndSettle();
    expect(session.signInCalls, 1);
    expect(find.byType(TradingHistoryFillCard), findsOneWidget);
  });

  testWidgets('wallet change clears the list and an already open details sheet', (t) async {
    final c = await launchTradingHistory(t, HistoryRepository());
    await historyTap(t, 'history-expand-order:AAPLUSDT:123');
    await historyTap(t, 'history-details-123');
    (c.read(authProvider.notifier) as HistoryAuth).set(const AuthSession());
    await t.pumpAndSettle();
    expect(find.text('AAPLUSDT'), findsNothing);
    expect(find.widgetWithText(SelectableText, '123'), findsNothing);
    expect(find.text('0.071288 USDT'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Aster tabs and order fills work without an OpenAPI session', (t) async {
    final repository = HistoryRepository();
    final c = await launchTradingHistory(t, repository);
    (c.read(vantaApiSessionProvider.notifier) as HistorySession).set(
      const VantaApiSessionState(VantaApiSessionStatus.unavailable),
    );
    await t.pumpAndSettle();
    expect(find.byType(TradingHistoryOrderCard), findsNWidgets(2));
    await historyTap(t, 'history-expand-order:AAPLUSDT:123');
    await historyTap(t, 'history-details-123');
    expect(repository.orderFillCalls.single.id, '123');
    expect(find.widgetWithText(SelectableText, '50'), findsOneWidget);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    await historyTap(t, 'history-tab-transactions');
    expect(find.byType(TradingHistoryTransactionRow), findsOneWidget);
    await historyTap(t, 'history-tab-trades');
    expect(find.byType(TradingHistoryFillCard), findsNothing);
    expect(find.byKey(const Key('history-failure')), findsOneWidget);
    await historyTap(t, 'history-tab-positions');
    expect(find.byType(TradingHistoryPositionCard), findsNothing);
    expect(find.byKey(const Key('history-failure')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('revoking the Aster grant clears only direct tabs and does not initiate SIWE', (
    t,
  ) async {
    var granted = true;
    final repository = HistoryRepository();
    final c = await launchTradingHistory(
      t,
      repository,
      loadGrant: () async => granted ? historyGrant : null,
    );
    granted = false;
    c.invalidate(tradingAgentProvider);
    await t.pumpAndSettle();
    expect(find.byType(TradingHistoryOrderCard), findsNothing);
    expect(find.byKey(const Key('history-failure')), findsOneWidget);
    await t.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    expect(repository.calls, hasLength(1));
    expect((c.read(vantaApiSessionProvider.notifier) as HistorySession).signInCalls, 0);
    await historyTap(t, 'history-tab-trades');
    expect(find.byType(TradingHistoryFillCard), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Aster trigger terms and actual fill role appear in order details', (t) async {
    final repository = HistoryRepository();
    repository.rows[TradingHistoryTab.orders] = [
      HistoryOrder(
        symbol: 'AAPLUSDT',
        time: DateTime.utc(2026, 11, 5),
        id: '123',
        side: 'SELL',
        positionSide: 'SHORT',
        type: 'STOP_MARKET',
        status: 'FILLED',
        executed: Decimal.parse('3'),
        stopPrice: Decimal.parse('200'),
        workingType: 'MARK_PRICE',
      ),
    ];
    repository.rows[TradingHistoryTab.trades] = [
      mapAsterTradingRecord(
        FuturesTradeRecord(
          symbol: 'AAPLUSDT',
          time: DateTime.utc(2026, 11, 5),
          tradeId: '50',
          orderId: '123',
          side: 'SELL',
          positionSide: 'SHORT',
          price: Decimal.parse('200'),
          quantity: Decimal.parse('3'),
          quoteQuantity: Decimal.parse('600'),
          commission: Decimal.parse('-0.07'),
          commissionAsset: 'USDT',
          realizedPnl: Decimal.zero,
          maker: true,
        ),
      ),
    ];
    await launchTradingHistory(t, repository);
    await historyTap(t, 'history-expand-order:AAPLUSDT:123');
    expect(find.text('200.000000 (Mark)'), findsOneWidget);
    await historyTap(t, 'history-details-123');
    expect(find.text('Maker'), findsOneWidget);
    expect(find.text('0.07 USDT'), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });

  testWidgets('Aster revocation preserves its concrete failure after the grant clears', (t) async {
    var granted = true;
    final repository = HistoryRepository();
    final c = await launchTradingHistory(
      t,
      repository,
      loadGrant: () async => granted ? historyGrant : null,
    );
    repository.gate = Completer<void>();
    repository.failure = const AccountReadFailure(
      'accountPermissionRequired',
      code: -2015,
      details: ApiErrorDetails(message: 'Account access revoked'),
    );
    final refresh = t.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    granted = false;
    c.invalidate(tradingAgentProvider);
    await t.pumpAndSettle();
    repository.gate!.complete();
    await refresh;
    await t.pumpAndSettle();
    expect(find.textContaining('Account access revoked'), findsOneWidget);
    expect(find.byType(TradingHistoryOrderCard), findsNothing);
    expect(t.takeException(), isNull);
  });
}
