import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/core/network/request_scope.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/application/trading_history_provider.dart';
import 'package:vanta/features/portfolio/data/trading_history_mapper.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/trading_history.dart';
import 'package:vanta/features/portfolio/presentation/futures_history_screen.dart';
import 'package:vanta/features/trade/application/providers.dart' show symbolProvider;
import 'package:vanta/l10n/generated/app_localizations.dart';

const historyAddress = '0x1111111111111111111111111111111111111111';
const historyUnits = {'AAPLUSDT': AsterContractUnits(base: 'AAPL', quote: 'USDT', margin: 'USDT')};
Map<String, Object?> historyOrder({
  int id = 123,
  String status = 'PARTIALLY_FILLED',
  String symbol = 'AAPLUSDT',
}) => {
  'order_id': id,
  'symbol': symbol,
  'side': 'SELL',
  'position_side': 'SHORT',
  'type': 'LIMIT',
  'status': status,
  'executed_qty': '3',
  'orig_qty': '6',
  'price': '190.000000',
  'avg_price': '190.100000',
  'reduce_only': false,
  'order_time': '2026-11-05T10:28:00Z',
  'update_time': '2026-11-05T10:29:41Z',
  'source': 'live',
};
Map<String, Object?> historyFill({int id = 50, String feeAsset = 'USDT', String quantity = '3'}) =>
    {
      'trade_id': id,
      'order_id': 123,
      'symbol': 'AAPLUSDT',
      'side': 'SELL',
      'position_side': 'SHORT',
      'price': '190.100000',
      'qty': quantity,
      'notional': '570.30',
      'fee': '-0.071288',
      'fee_asset': feeAsset,
      'realized_profit': '0',
      'active_buy': false,
      'trade_time': '2026-11-05T10:29:41Z',
      'source': 'live',
    };
Map<String, Object?> historyPosition({
  int id = 7,
  String side = 'LONG',
  String pnl = '0.27',
  bool inferred = false,
}) => {
  'id': id,
  'symbol': 'AAPLUSDT',
  'side': side,
  'opened_at': '2026-11-05T09:18:06Z',
  'closed_at': '2026-11-05T10:42:18Z',
  'entry_price': '189.200000',
  'exit_price': '194.600000',
  'max_qty': '0.05',
  'realized_pnl': pnl,
  'fees': '-0.003892',
  'status': 'closed',
  'inferred': inferred,
  'liquidated': false,
};
Map<String, Object?> historyIncome({String amount = '-0.00000043'}) => {
  'occurred_at': '2026-11-04T23:58:09Z',
  'kind': 'funding',
  'symbol': 'AAPLUSDT',
  'asset': 'USDT',
  'amount': amount,
  'source': 'app_report',
  'data_source': 'app_report',
  'source_tier': 'live',
};
Map<String, Object?> historyTransfer({int id = 9}) => {
  'id': id,
  'occurred_at': '2026-11-05T12:18:44Z',
  'kind': 'internal_transfer',
  'symbol': null,
  'asset': 'USDT',
  'amount': '500.00',
  'data_source': 'app_report',
  'source_tier': 'live',
};
Map<String, Object?> historyPage(List<Object?> rows, {String? next, bool partial = false}) => {
  'items': rows,
  'next_cursor': next,
  'partial': partial,
  'symbol_filter_ignored': false,
  'filters': {'from': null, 'to': null},
};

class HistorySession extends VantaApiSessionController {
  int signInCalls = 0;
  @override
  VantaApiSessionState build() =>
      const VantaApiSessionState(VantaApiSessionStatus.ready, address: historyAddress);
  void set(VantaApiSessionState value) => state = value;
  @override
  Future<void> ensure() async {
    signInCalls++;
    state = const VantaApiSessionState(VantaApiSessionStatus.ready, address: historyAddress);
  }
}

class HistoryAuth extends AuthController {
  void set(AuthSession value) => state = value;
  @override
  AuthSession build() => const AuthSession(
    phase: AuthPhase.signedIn,
    identity: AuthIdentity(
      id: 'history-user',
      walletAddress: historyAddress,
      signingAvailable: true,
    ),
  );
}

final historyGrant = TradingAgent(
  identityId: 'history-user',
  owner: historyAddress,
  address: '0x2222222222222222222222222222222222222222',
  expiresAt: DateTime.utc(2030),
  status: TradingAgentStatus.active,
);

class HistoryRepository implements TradingHistoryRepository, TradingOrderFillsRepository {
  final orderFillCalls = <HistoryOrder>[];
  @override
  Future<TradingHistoryPage> readOrderFills(
    HistoryOrder order, {
    required String address,
    TradingHistoryCursor? cursor,
  }) {
    orderFillCalls.add(order);
    return read(TradingHistoryTab.trades, address: address, cursor: cursor);
  }

  final calls = <(TradingHistoryTab, TradingHistoryCursor?)>[];
  final scopes = <bool Function()>[];
  final rows = <TradingHistoryTab, List<TradingHistoryRecord>>{
    TradingHistoryTab.orders: mapTradingHistory([
      historyOrder(),
      historyOrder(id: 124, status: 'CANCELED'),
    ], TradingHistoryTab.orders),
    TradingHistoryTab.positions: mapTradingHistory([
      historyPosition(),
    ], TradingHistoryTab.positions),
    TradingHistoryTab.trades: mapTradingHistory([historyFill()], TradingHistoryTab.trades),
    TradingHistoryTab.transactions: mapTradingHistory([
      historyIncome(),
    ], TradingHistoryTab.transactions),
  };
  Completer<void>? gate;
  Object? failure;
  TradingHistoryCursor? next;
  bool partial = false;
  @override
  Future<TradingHistoryPage> read(
    TradingHistoryTab tab, {
    required String address,
    TradingHistoryCursor? cursor,
  }) async {
    calls.add((tab, cursor));
    final scope = RequestScope.current;
    scopes.add(() => scope?.active ?? false);
    await gate?.future;
    if (failure case final error?) throw error;
    return TradingHistoryPage(address: address, records: rows[tab]!, next: next, partial: partial);
  }
}

Future<ProviderContainer> launchTradingHistory(
  WidgetTester tester,
  HistoryRepository repository, {
  double width = 393,
  double height = 852,
  double scale = 1,
  String locale = 'en',
  Future<Map<String, AsterContractUnits>> Function()? loadUnits,
  Future<TradingAgent?> Function()? loadGrant,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(HistoryAuth.new),
      vantaApiSessionProvider.overrideWith(HistorySession.new),
      tradingAgentProvider.overrideWith(
        (ref) async => loadGrant == null ? historyGrant : await loadGrant(),
      ),
      tradingHistorySourceProvider.overrideWith((ref, tab) => repository),
      tradingOrderFillsRepositoryProvider.overrideWithValue(repository),
      tradingHistoryUnitsProvider.overrideWith(
        (ref) async => loadUnits == null ? historyUnits : await loadUnits(),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(symbolProvider.notifier).select('AAPLUSDT');
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: vantaTheme(),
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openFuturesHistory(context),
              child: const Text('History entry'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('History entry'));
  await tester.pumpAndSettle();
  return container;
}

Future<void> historyTap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
