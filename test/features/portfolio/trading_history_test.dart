import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/auth/data/vanta_api_session_store.dart';
import 'package:vanta/features/portfolio/application/trading_history_provider.dart';
import 'package:vanta/features/portfolio/application/trading_history_details_provider.dart';
import 'package:vanta/features/portfolio/data/trading_history_mapper.dart';
import 'package:vanta/features/portfolio/data/trading_history_repository.dart';
import 'package:vanta/features/portfolio/domain/trading_history.dart';

import '../../support/trading_history.dart';
import '../../support/vanta_api.dart';

Decimal d(String value) => Decimal.parse(value);

void main() {
  test('contract amounts stay decimal; null data is not zero', () {
    final order =
        mapTradingHistory([
              {...historyOrder(), 'avg_price': null},
            ], TradingHistoryTab.orders).single
            as HistoryOrder;
    expect(order.filledValue, isNull);
    expect(order.orderValue, d('1140'));
    final income =
        mapTradingHistory([
              historyIncome(amount: '0.000000000000000001'),
            ], TradingHistoryTab.transactions).single
            as HistoryTransaction;
    expect(income.amount, d('0.000000000000000001'));
    expect(
      () => mapTradingHistory([
        {...historyFill(), 'fee': 0.07},
      ], TradingHistoryTab.trades),
      throwsFormatException,
    );
    expect(
      () => mapTradingHistory([
        {...historyPosition(), 'inferred': 'false'},
      ], TradingHistoryTab.positions),
      throwsFormatException,
    );
    expect(
      () => mapTradingHistory([
        {...historyFill(), 'trade_time': 'yesterday'},
      ], TradingHistoryTab.trades),
      throwsFormatException,
    );
  });

  test('income without an ID keeps distinct identical reported ledger rows', () {
    final rows = mapTradingHistory([
      historyIncome(),
      historyIncome(),
    ], TradingHistoryTab.transactions);
    expect(rows.map((r) => r.key).toSet(), hasLength(2));
  });

  test('position preserves inferred and liquidated flags; open has no fabricated close', () {
    final r =
        mapTradingHistory([
              {
                ...historyPosition(inferred: true),
                'status': 'open',
                'closed_at': null,
                'exit_price': null,
              },
            ], TradingHistoryTab.positions).single
            as HistoryPosition;
    expect(r.inferred, isTrue);
    expect(r.closedAt, isNull);
    expect(r.exitPrice, isNull);
    expect(
      () => mapTradingHistory([
        {...historyPosition(), 'closed_at': null},
      ], TradingHistoryTab.positions),
      throwsFormatException,
    );
  });

  group('contract repository', () {
    late Backend backend;
    late ApiTradingHistoryRepository repository;
    setUp(() async {
      backend = Backend();
      final store = MemoryStore()
        ..value = VantaApiCredentials.fromIssued(
          issued('a', 'r'),
          address: vantaTestAddress,
          receivedAt: vantaTestNow,
        );
      final session = vantaTestRepository(
        backend,
        store: store,
        signer: KeySigner(),
        now: () => vantaTestNow,
      );
      addTearDown(session.close);
      await session.restore(vantaTestAddress);
      repository = ApiTradingHistoryRepository(session);
    });
    test('transactions merge independent ledgers and never restart an exhausted cursor', () async {
      backend.routes['GET /v1/history/income'] = (_) =>
          json(historyPage([historyIncome()], next: 'income-2', partial: true));
      backend.routes['GET /v1/history/transfers'] = (_) => json(historyPage([historyTransfer()]));
      final first = await repository.read(
        TradingHistoryTab.transactions,
        address: vantaTestAddress,
      );
      expect(first.records, hasLength(2));
      expect(first.partial, isTrue);
      expect(first.next?.main, 'income-2');
      expect(first.next?.transfers, isNull);
      backend.routes['GET /v1/history/income'] = (request) {
        expect(request.url.queryParameters['cursor'], 'income-2');
        expect(request.headers['Authorization'], 'Bearer a');
        return json(historyPage([]));
      };
      final next = await repository.read(
        TradingHistoryTab.transactions,
        address: vantaTestAddress,
        cursor: first.next,
      );
      expect(next.next, isNull);
      expect(backend.paths.where((p) => p.endsWith('/transfers')), hasLength(1));
      expect(backend.requests.every((r) => !r.url.queryParameters.containsKey('symbol')), isTrue);
    });
    test('malformed payload carries typed safe failure with endpoint', () async {
      backend.routes['GET /v1/history/orders'] = (_) => json(
        historyPage([
          {...historyOrder(), 'executed_qty': 'NaN'},
        ]),
      );
      await expectLater(
        repository.read(TradingHistoryTab.orders, address: vantaTestAddress),
        throwsA(
          isA<VantaApiFailure>()
              .having((e) => e.key, 'key', vantaApiDataInvalid)
              .having((e) => e.details?.endpoint, 'endpoint', '/v1/history/orders'),
        ),
      );
    });
    test('HTTP 200 business errors retain the server message and code', () async {
      backend.routes['GET /v1/history/orders'] = (_) => json({
        'code': 'HISTORY_UNAVAILABLE',
        'message': 'History archive is temporarily unavailable',
      });
      await expectLater(
        repository.read(TradingHistoryTab.orders, address: vantaTestAddress),
        throwsA(
          isA<VantaApiFailure>()
              .having((e) => e.code, 'code', 'HISTORY_UNAVAILABLE')
              .having(
                (e) => e.details?.message,
                'message',
                'History archive is temporarily unavailable',
              ),
        ),
      );
    });
  });

  group('provider lifetime', () {
    late HistoryRepository repository;
    late ProviderContainer container;
    final provider = tradingHistoryProvider(TradingHistoryTab.orders);
    setUp(() async {
      repository = HistoryRepository();
      container = ProviderContainer(
        overrides: [
          vantaApiSessionProvider.overrideWith(HistorySession.new),
          authProvider.overrideWith(HistoryAuth.new),
          tradingAgentProvider.overrideWith((ref) async => historyGrant),
          tradingHistorySourceProvider.overrideWith((ref, tab) => repository),
          tradingOrderFillsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(tradingAgentProvider.future);
    });
    Future<void> settle() async {
      await Future<void>.delayed(Duration.zero);
      await container.pump();
    }

    test('duplicate refreshes share one request and failed refresh retains page', () async {
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await settle();
      final page = container.read(provider).page;
      expect(page, isNotNull);
      repository.gate = Completer<void>();
      final first = container.read(provider.notifier).refresh();
      final second = container.read(provider.notifier).refresh();
      expect(container.read(provider).page, same(page));
      expect(repository.calls, hasLength(2));
      repository.failure = const VantaApiFailure(vantaApiRateLimited);
      repository.gate!.complete();
      await Future.wait([first, second]);
      expect(container.read(provider).page, same(page));
      expect(container.read(provider).busy, isFalse);
      expect(container.read(provider).error, isA<VantaApiFailure>());
    });
    test('pagination deduplicates records and a failed page can be retried', () async {
      repository.next = const TradingHistoryCursor('page-2');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await settle();
      final old = container.read(provider).page;
      repository.failure = const VantaApiFailure(vantaApiRequestFailed);
      await container.read(provider.notifier).loadMore();
      expect(container.read(provider).page, same(old));
      repository.failure = null;
      repository.next = null;
      repository.rows[TradingHistoryTab.orders] = mapTradingHistory([
        historyOrder(),
        historyOrder(id: 125, status: 'FILLED'),
      ], TradingHistoryTab.orders);
      await container.read(provider.notifier).loadMore();
      expect(repository.calls.last.$2?.main, 'page-2');
      expect(container.read(provider).page!.records, hasLength(3));
      expect(container.read(provider).page!.next, isNull);
      expect(container.read(provider).error, isNull);
    });
    test('a repeated pagination cursor becomes a recoverable error', () async {
      repository.next = const TradingHistoryCursor('page-2');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await settle();
      final old = container.read(provider).page;
      await container.read(provider.notifier).loadMore();
      expect(container.read(provider).page, same(old));
      expect(container.read(provider).error, isA<VantaApiFailure>());
      expect(container.read(provider).busy, isFalse);
    });
    test('wallet changes discard late reads and clear private records', () async {
      repository.gate = Completer<void>();
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await settle();
      expect(repository.scopes.single(), isTrue);
      (container.read(authProvider.notifier) as HistoryAuth).set(const AuthSession());
      await settle();
      expect(repository.scopes.single(), isFalse);
      repository.gate!.complete();
      await settle();
      expect(container.read(provider).page, isNull);
      expect(container.read(provider).busy, isFalse);
    });
    test('disposal invalidates the transport scope before a late result', () async {
      repository.gate = Completer<void>();
      final subscription = container.listen(provider, (_, _) {});
      await settle();
      expect(repository.scopes.single(), isTrue);
      subscription.close();
      await settle();
      expect(repository.scopes.single(), isFalse);
      repository.gate!.complete();
      await settle();
    });
    test('order details match symbol and ID and sum charges in one currency', () async {
      final order = repository.rows[TradingHistoryTab.orders]!.first as HistoryOrder;
      final details = tradingOrderDetailsProvider(order);
      final subscription = container.listen(details, (_, _) {});
      addTearDown(subscription.close);
      final result = await container.read(details.future);
      expect(result!.complete, isTrue);
      expect(result.fee, d('0.071288'));
      expect(result.realizedPnl, Decimal.zero);
    });
    test('missing fills and mixed fee currencies never become a complete total', () async {
      final order = repository.rows[TradingHistoryTab.orders]!.first as HistoryOrder;
      repository.rows[TradingHistoryTab.trades] = mapTradingHistory([
        historyFill(quantity: '1', feeAsset: 'BNB'),
        historyFill(id: 51, quantity: '1'),
      ], TradingHistoryTab.trades);
      final details = tradingOrderDetailsProvider(order);
      final subscription = container.listen(details, (_, _) {});
      addTearDown(subscription.close);
      final result = await container.read(details.future);
      expect(result!.complete, isFalse);
      expect(result.fills, hasLength(2));
      expect(result.fee, isNull);
      expect(result.realizedPnl, isNull);
    });
  });
}
