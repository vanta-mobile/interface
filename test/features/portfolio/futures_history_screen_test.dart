import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/futures_history_provider.dart';
import 'package:vanta/features/portfolio/data/futures_history_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_history.dart';
import 'package:vanta/features/portfolio/presentation/futures_history_record_card.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/futures_history.dart';
import '../../support/futures_history_widget.dart';
import '../../support/identity_repository.dart';

FuturesHistoryPage mapped(FuturesHistoryQuery q, List<Object?> rows, {bool units = true}) =>
    mapFuturesHistory(
      rows,
      address: accountAddress,
      query: q,
      receivedAt: futuresHistoryNow,
      units: units ? futuresHistoryUnits : const {},
    );

void main() {
  for (final fromOrders in [false, true]) {
    testWidgets('entry opens without reading from ${fromOrders ? 'open orders' : 'portfolio'}', (
      tester,
    ) async {
      final repository = TestFuturesHistoryRepository();
      final container = await launchFuturesHistory(tester, repository, fromOrders: fromOrders);
      expect(find.byKey(const Key('futures-history-page')), findsOneWidget);
      expect(find.widgetWithText(SelectableText, accountAddress), findsOneWidget);
      expect(find.byType(FuturesHistoryRecordCard), findsNothing);
      expect(repository.queries, isEmpty);
      await tapFutures(tester, 'read-futures-history');
      expect(repository.queries, hasLength(1));
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('0.001 BTC'), findsOneWidget);
      expect(find.text('0.002 BTC'), findsOneWidget);
      expect(find.text('80.000000000000000001 USDT'), findsOneWidget);
      expect(find.widgetWithText(SelectableText, '12345'), findsOneWidget);
      expect(find.text('2026-11-05 06:00:00.000'), findsNWidgets(2));
      expect(tester.takeException(), null);
      await closeFuturesHistory(tester, container);
    });
  }

  testWidgets('signed out stays separate from demo; explicit read opens login', (tester) async {
    final repository = TestFuturesHistoryRepository();
    final container = await launchFuturesHistory(
      tester,
      repository,
      identity: TestIdentityRepository(),
    );
    expect(find.byKey(const Key('futures-history-wallet')), findsNothing);
    expect(find.byKey(const Key('futures-history-empty')), findsNothing);
    expect(find.text('10000.00'), findsNothing);
    await tapFutures(tester, 'read-futures-history');
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(repository.queries, isEmpty);
    expect(tester.takeException(), null);
    await closeFuturesHistory(tester, container);
  });

  testWidgets('trades require exact symbol; fills and fee/PnL units stay separate', (tester) async {
    final repository = TestFuturesHistoryRepository()
      ..respond = (q) => mapped(q, [futuresTradeRow(), futuresTradeRow(id: '98766')]);
    final container = await launchFuturesHistory(tester, repository);
    await chooseFuturesKind(tester, FuturesHistoryKind.trades);
    await revealFutures(tester, find.byKey(const Key('read-futures-history')));
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('read-futures-history'))).onPressed,
      null,
    );
    await setFuturesSymbol(tester, ' BTCUSDT ');
    await tapFutures(tester, 'read-futures-history');
    expect(repository.queries.single.symbol, 'BTCUSDT');
    expect(find.byType(FuturesHistoryRecordCard), findsNWidgets(2));
    expect(find.text('-0.008000000000000001 BNB'), findsNWidgets(2));
    expect(find.text('-1.250000000000000001 USDT'), findsNWidgets(2));
    expect(find.widgetWithText(SelectableText, '12345'), findsNWidgets(2));
    expect(find.widgetWithText(SelectableText, '98765'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, '98766'), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(FuturesHistoryRecordCard).first));
    expect(find.text(l10n.futuresHistoryPnlHint), findsNWidgets(2));
    expect(tester.takeException(), null);
    await closeFuturesHistory(tester, container);
  });

  testWidgets('income type plus ID identity and signed amounts; raw info never rendered', (
    tester,
  ) async {
    final repository = TestFuturesHistoryRepository()
      ..respond = (q) => mapped(q, [
        futuresIncomeRow(),
        {...futuresIncomeRow(), 'incomeType': 'REALIZED_PNL', 'income': '1.000000000000000001'},
      ]);
    final container = await launchFuturesHistory(tester, repository);
    await chooseFuturesKind(tester, FuturesHistoryKind.income);
    final dropdown = find.byType(DropdownButtonFormField<String>);
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.descendant(of: dropdown, matching: find.byType(DropdownButton<String>)),
          )
          .items,
      hasLength(18),
    );
    await tapFutures(tester, 'read-futures-history');
    expect(find.byType(FuturesHistoryRecordCard), findsNWidgets(2));
    expect(find.widgetWithText(SelectableText, '45678'), findsNWidgets(2));
    expect(find.text('-0.000000000000000001 USDT'), findsOneWidget);
    expect(find.text('+1.000000000000000001 USDT'), findsOneWidget);
    expect(find.textContaining('Never render this raw payload'), findsNothing);
    await revealFutures(tester, dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Funding fee').last);
    await tester.pumpAndSettle();
    expect(container.read(futuresHistoryProvider).query.incomeType, 'FUNDING_FEE');
    expect(find.byType(FuturesHistoryRecordCard), findsNothing);
    expect(repository.queries, hasLength(1));
    repository.respond = (q) => mapped(q, [futuresIncomeRow()]);
    await tapFutures(tester, 'read-futures-history');
    expect(repository.queries.last.incomeType, 'FUNDING_FEE');
    expect(tester.takeException(), null);
    await closeFuturesHistory(tester, container);
  });

  testWidgets('unknown totals and units never inferred from price times quantity', (tester) async {
    final repository = TestFuturesHistoryRepository()
      ..respond = (q) => mapped(q, [
        {...futuresOrderRow(), 'cumQuote': null, 'avgPrice': null},
      ], units: false);
    final container = await launchFuturesHistory(tester, repository);
    await tapFutures(tester, 'read-futures-history');
    final card = find.byType(FuturesHistoryRecordCard);
    final l10n = AppLocalizations.of(tester.element(card));
    expect(find.descendant(of: card, matching: find.text('—')), findsNWidgets(2));
    expect(find.text('80 USDT'), findsNothing);
    expect(find.text('0.001 ${l10n.accountUnitUnavailable}'), findsOneWidget);
    expect(find.text(l10n.accountUnitUnavailable), findsOneWidget);
    expect(tester.takeException(), null);
    await closeFuturesHistory(tester, container);
  });

  testWidgets('entire close keeps actual fills; trailing uses activation not stop price', (
    tester,
  ) async {
    final repository = TestFuturesHistoryRepository()
      ..respond = (q) => mapped(q, [
        {
          ...futuresOrderRow(),
          'origQty': '0',
          'closePosition': true,
          'type': 'MARKET',
          'origType': 'TRAILING_STOP_MARKET',
          'stopPrice': '123.456',
          'activatePrice': '79000',
          'priceRate': '0.15',
        },
      ]);
    final container = await launchFuturesHistory(tester, repository);
    await tapFutures(tester, 'read-futures-history');
    expect(find.text('Close entire position'), findsOneWidget);
    expect(find.text('0.001 BTC'), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(FuturesHistoryRecordCard)));
    expect(find.text(l10n.notificationOrderType('TRAILING_STOP_MARKET')), findsOneWidget);
    expect(find.text('79,000 USDT'), findsOneWidget);
    expect(find.text('0.15%'), findsOneWidget);
    expect(find.text('123.456 USDT'), findsNothing);
    expect(tester.takeException(), null);
    await closeFuturesHistory(tester, container);
  });

  testWidgets('saturated read remains partial and continuation failure preserves rows and window', (
    tester,
  ) async {
    final repository = TestFuturesHistoryRepository();
    repository.respond = (q) {
      final p = mapped(q, [futuresOrderRow(time: q.window.end, id: '${q.window.end}')]);
      return FuturesHistoryPage(
        address: p.address,
        query: q,
        receivedAt: p.receivedAt,
        records: p.records,
        rawCount: repository.queries.length == 1 ? 1000 : 1,
      );
    };
    final container = await launchFuturesHistory(tester, repository);
    await tapFutures(tester, 'read-futures-history');
    expect(container.read(futuresHistoryProvider).pending, hasLength(2));
    expect(repository.queries, hasLength(1));
    expect(find.textContaining('selected range is not fully checked'), findsOneWidget);
    final snapshot = container.read(futuresHistoryProvider).account;
    repository.failure = const AccountReadFailure('accountNetwork');
    await tapFutures(tester, 'continue-futures-history');
    expect(container.read(futuresHistoryProvider).account, same(snapshot));
    expect(find.byType(FuturesHistoryRecordCard), findsOneWidget);
    expect(find.byKey(const Key('futures-history-snapshot-stale')), findsOneWidget);
    repository.failure = null;
    await tapFutures(tester, 'continue-futures-history');
    expect(repository.queries[1], repository.queries[2]);
    expect(container.read(futuresHistoryProvider).pending, hasLength(1));
    await tapFutures(tester, 'continue-futures-history');
    expect(container.read(futuresHistoryProvider).pending, isEmpty);
    expect(find.byKey(const Key('continue-futures-history')), findsNothing);
    expect(tester.takeException(), null);
    await closeFuturesHistory(tester, container);
  });

  testWidgets('one-millisecond saturated data is explicitly truncated', (tester) async {
    final repository = TestFuturesHistoryRepository()
      ..respond = (q) {
        final p = mapped(q, [futuresOrderRow()]);
        return FuturesHistoryPage(
          address: p.address,
          query: q,
          receivedAt: p.receivedAt,
          records: p.records,
          rawCount: 1000,
        );
      };
    final container = await launchFuturesHistory(tester, repository);
    final now = futuresHistoryNow.millisecondsSinceEpoch;
    container.read(futuresHistoryProvider.notifier).setWindow(HistoryWindow(now, now));
    await tester.pumpAndSettle();
    await tapFutures(tester, 'read-futures-history');
    final l10n = AppLocalizations.of(tester.element(find.byType(FuturesHistoryRecordCard)));
    expect(find.text(l10n.historyTruncated), findsOneWidget);
    expect(find.byKey(const Key('continue-futures-history')), findsNothing);
    expect(repository.queries, hasLength(1));
    expect(tester.takeException(), null);
    await closeFuturesHistory(tester, container);
  });

  testWidgets('refresh error retains input and results; new empty read shows explicit empty', (
    tester,
  ) async {
    final repository = TestFuturesHistoryRepository();
    final container = await launchFuturesHistory(tester, repository);
    await setFuturesSymbol(tester, 'BTCUSDT');
    await tapFutures(tester, 'read-futures-history');
    repository.failure = const AccountReadFailure('accountPermissionRequired', code: -2015);
    await tapFutures(tester, 'read-futures-history');
    expect(find.byType(FuturesHistoryRecordCard), findsOneWidget);
    expect(find.textContaining('Aster error code: -2015'), findsOneWidget);
    expect(container.read(futuresHistoryProvider).query.symbol, 'BTCUSDT');
    repository.failure = null;
    repository.respond = (q) => mapped(q, []);
    await tapFutures(tester, 'read-futures-history');
    expect(find.byType(FuturesHistoryRecordCard), findsNothing);
    expect(find.byKey(const Key('futures-history-empty')), findsOneWidget);
    expect(tester.takeException(), null);
    await closeFuturesHistory(tester, container);
  });

  testWidgets('local ten-row pagination and language switch do not sign', (tester) async {
    final repository = TestFuturesHistoryRepository()
      ..respond = (q) => mapped(q, List.generate(21, (i) => futuresOrderRow(id: '${i + 1}')));
    final container = await launchFuturesHistory(tester, repository);
    await tapFutures(tester, 'read-futures-history');
    expect(find.byType(FuturesHistoryRecordCard), findsNWidgets(10));
    await tapFutures(tester, 'futures-history-next');
    await tapFutures(tester, 'futures-history-next');
    expect(find.byType(FuturesHistoryRecordCard), findsOneWidget);
    expect(find.text('Page 3 of 3 loaded pages'), findsOneWidget);
    final snapshot = container.read(futuresHistoryProvider).account;
    container.read(localeProvider.notifier).select('zh');
    await tester.pumpAndSettle();
    expect(find.text('已加载记录第3／3页'), findsOneWidget);
    expect(container.read(futuresHistoryProvider).account, same(snapshot));
    await tapFutures(tester, 'futures-history-previous');
    expect(find.byType(FuturesHistoryRecordCard), findsNWidgets(10));
    expect(repository.queries, hasLength(1));
    expect(tester.takeException(), null);
    await closeFuturesHistory(tester, container);
  });

  testWidgets('stop and back discard late read without another prompt', (tester) async {
    final repository = TestFuturesHistoryRepository()..gate = Completer<void>();
    final container = await launchFuturesHistory(tester, repository);
    await tapFutures(tester, 'read-futures-history', settle: false);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('read-futures-history'))).onPressed,
      null,
    );
    await tapFutures(tester, 'stop-futures-history');
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(FuturesHistoryRecordCard), findsNothing);
    repository.gate = Completer<void>();
    await tapFutures(tester, 'read-futures-history', settle: false);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(container.read(futuresHistoryProvider).account, null);
    expect(container.read(futuresHistoryProvider).busy, false);
    expect(repository.queries, hasLength(2));
    expect(tester.takeException(), null);
    await closeFuturesHistory(tester, container);
  });

  testWidgets('date picker uses UTC and does not require trade symbol before choosing dates', (
    tester,
  ) async {
    final repository = TestFuturesHistoryRepository();
    final container = await launchFuturesHistory(tester, repository);
    await chooseFuturesKind(tester, FuturesHistoryKind.trades);
    await tapFutures(tester, 'futures-history-dates');
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(DateRangePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '10/01/2026');
    await tester.enterText(fields.at(1), '11/05/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final query = container.read(futuresHistoryProvider).query;
    expect(query.window.start, DateTime.utc(2026, 10, 1).millisecondsSinceEpoch);
    expect(query.window.end, futuresHistoryNow.millisecondsSinceEpoch);
    expect(query.window.fitsRequest, false);
    expect(query.symbol, isEmpty);
    expect(repository.queries, isEmpty);
    await tapFutures(tester, 'futures-history-day');
    expect(
      container.read(futuresHistoryProvider).query.window,
      HistoryWindow.recent(futuresHistoryNow, const Duration(days: 1)),
    );
    await tapFutures(tester, 'futures-history-week');
    expect(container.read(futuresHistoryProvider).query.window, futuresHistoryWindow);
    expect(tester.takeException(), null);
    await closeFuturesHistory(tester, container);
  });
}
