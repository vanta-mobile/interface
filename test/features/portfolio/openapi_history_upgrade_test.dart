import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/data/vanta_api_session_store.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/trading_history_details_provider.dart';
import 'package:vanta/features/portfolio/application/trading_history_provider.dart';
import 'package:vanta/features/portfolio/data/trading_history_mapper.dart';
import 'package:vanta/features/portfolio/data/trading_history_repository.dart';
import 'package:vanta/features/portfolio/domain/trading_history.dart';

import '../../support/trading_history.dart';
import '../../support/vanta_api.dart';

HistoryPosition position(Map<String, Object?> fields) =>
    mapTradingHistory([
          {...historyPosition(), ...fields},
        ], TradingHistoryTab.positions).single
        as HistoryPosition;

void main() {
  test('new archive fields retain decimal precision and explicit close intent', () {
    final order =
        mapTradingHistory([
              {
                ...historyOrder(),
                'stop_price': '190.123456789123456789',
                'activate_price': '195',
                'price_rate': '0.25',
                'cum_quote': '570.300000000000000001',
                'close_position': true,
              },
            ], TradingHistoryTab.orders).single
            as HistoryOrder;
    expect(order.stopPrice.toString(), '190.123456789123456789');
    expect(order.activationPrice, Decimal.fromInt(195));
    expect(order.callbackRate, Decimal.parse('0.25'));
    expect(order.filledValue.toString(), '570.300000000000000001');
    expect(order.closePosition, isTrue);
    final p = position({
      'leverage': '20',
      'margin_type': 'isolated',
      'closed_qty': '0.04321',
      'roe': '-0.00123456789',
    });
    expect(p.leverage, Decimal.fromInt(20));
    expect(p.marginType, 'isolated');
    expect(p.closedQuantity, Decimal.parse('0.04321'));
    expect(p.estimatedRoePercent, Decimal.parse('-0.123456789'));
    expect(position({'inferred': true, 'roe': '0.5'}).estimatedRoePercent, isNull);
    expect(position({}).closedQuantity, isNull);
    expect(position({}).leverage, isNull);
    expect(position({}).estimatedRoePercent, isNull);
    expect(position({'roe': '0.5'}).estimatedRoePercent, isNull);
    expect(
      position({'roe': '0.5', 'leverage': '20', 'entry_price': '0'}).estimatedRoePercent,
      isNull,
    );
  });
  for (final field in ['stop_price', 'activate_price', 'price_rate', 'cum_quote']) {
    test('malformed archive $field cannot become a financial fact', () {
      for (final bad in ['NaN', '-1', 0.1, true]) {
        expect(
          () => mapTradingHistory([
            {...historyOrder(), field: bad},
          ], TradingHistoryTab.orders),
          throwsFormatException,
        );
      }
    });
  }
  test('malformed optional position metadata rejects the page', () {
    for (final fields in [
      {'leverage': '0'},
      {'leverage': '-1'},
      {'margin_type': 'crossed'},
      {'closed_qty': '-1'},
      {'roe': double.nan},
    ]) {
      expect(() => position(fields), throwsFormatException);
    }
  });

  group('archive repository', () {
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
    test(
      'order fills send order filter with each cursor and retain exact symbol matching',
      () async {
        final order =
            mapTradingHistory([historyOrder()], TradingHistoryTab.orders).single as HistoryOrder;
        backend.routes['GET /v1/history/fills'] = (_) => json(
          historyPage([
            historyFill(),
            {...historyFill(id: 51), 'symbol': 'BTCUSDT'},
            {...historyFill(id: 52), 'order_id': 124},
          ], next: 'older'),
        );
        final page = await repository.readOrderFills(order, address: vantaTestAddress);
        expect(page.records.map((r) => r.key), ['fill:AAPLUSDT:50']);
        expect(page.next!.main, 'older');
        backend.routes['GET /v1/history/fills'] = (_) => json(historyPage([]));
        await repository.readOrderFills(order, address: vantaTestAddress, cursor: page.next);
        expect(backend.requests.last.url.queryParameters, {
          'limit': '100',
          'cursor': 'older',
          'order_id': '123',
        });
        expect(backend.requests.every((r) => r.url.path == '/v1/history/fills'), isTrue);
      },
    );
    test(
      'linked orders validate the cycle and symbol, preserve empty and old null fields',
      () async {
        final p = position({});
        backend.routes['GET /v1/history/positions/7/orders'] = (_) => json({
          'position_id': 7,
          'items': [historyOrder()],
        });
        final result = await repository.readPositionOrders(p);
        expect(result.single.id, '123');
        expect(result.single.quoteFilled, isNull);
        for (final body in [
          {
            'position_id': 8,
            'items': [historyOrder()],
          },
          {
            'position_id': 7,
            'items': [historyOrder(symbol: 'BTCUSDT')],
          },
          {
            'position_id': 7,
            'items': [historyOrder(), historyOrder()],
          },
        ]) {
          backend.routes['GET /v1/history/positions/7/orders'] = (_) => json(body);
          await expectLater(
            repository.readPositionOrders(p),
            throwsA(isA<VantaApiFailure>().having((e) => e.key, 'key', vantaApiDataInvalid)),
          );
        }
        backend.routes['GET /v1/history/positions/7/orders'] = (_) =>
            json({'position_id': 7, 'items': <Object?>[]});
        expect(await repository.readPositionOrders(p), isEmpty);
      },
    );
    for (final status in [200, 404, 429, 503]) {
      test('linked-order $status failures preserve server cause and never mean empty', () async {
        backend.routes['GET /v1/history/positions/7/orders'] = (_) =>
            json({'code': 'not_found', 'message': 'Position cycle has not been rebuilt'}, status);
        await expectLater(
          repository.readPositionOrders(position({})),
          throwsA(
            isA<VantaApiFailure>()
                .having((e) => e.code, 'code', 'not_found')
                .having(
                  (e) => e.details?.message,
                  'message',
                  'Position cycle has not been rebuilt',
                ),
          ),
        );
      });
    }
  });

  group('related-order ownership', () {
    late HistoryRepository repository;
    late ProviderContainer container;
    setUp(() {
      repository = HistoryRepository();
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(HistoryAuth.new),
          vantaApiSessionProvider.overrideWith(HistorySession.new),
          tradingPositionOrdersRepositoryProvider.overrideWithValue(repository),
          tradingOrderFillsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
    });
    test('wallet change cancels ownership and discards late linked records', () async {
      repository.gate = Completer<void>();
      final provider = tradingPositionOrdersProvider(position({}));
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      expect(repository.scopes.single(), isTrue);
      (container.read(authProvider.notifier) as HistoryAuth).set(const AuthSession());
      (container.read(vantaApiSessionProvider.notifier) as HistorySession).set(
        const VantaApiSessionState(VantaApiSessionStatus.signedOut),
      );
      await container.pump();
      expect(repository.scopes.single(), isFalse);
      repository.gate!.complete();
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(container.read(provider).value, isNull);
    });
    test('leaving details aborts the owning scope', () async {
      repository.gate = Completer<void>();
      final provider = tradingPositionOrdersProvider(position({}));
      final sub = container.listen(provider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(repository.scopes.single(), isTrue);
      sub.close();
      await container.pump();
      expect(repository.scopes.single(), isFalse);
      repository.gate!.complete();
    });
    test('filtered fills can finish beyond the former 20-page scan cap', () async {
      final archive = _PagedFills();
      container.updateOverrides([
        authProvider.overrideWith(HistoryAuth.new),
        vantaApiSessionProvider.overrideWith(HistorySession.new),
        tradingPositionOrdersRepositoryProvider.overrideWithValue(repository),
        tradingOrderFillsRepositoryProvider.overrideWithValue(archive),
      ]);
      final order = repository.rows[TradingHistoryTab.orders]!.first as HistoryOrder;
      final result = await container.read(tradingOrderDetailsProvider(order).future);
      expect(archive.calls, 21);
      expect(result!.complete, isTrue);
      expect(result.fills, hasLength(1));
    });
    test('conflicting duplicate fills cannot alter an aggregated charge silently', () async {
      repository.rows[TradingHistoryTab.trades] = mapTradingHistory([
        historyFill(quantity: '1'),
        {...historyFill(quantity: '1'), 'fee': '-100'},
      ], TradingHistoryTab.trades);
      final order = repository.rows[TradingHistoryTab.orders]!.first as HistoryOrder;
      await expectLater(
        container.read(tradingOrderDetailsProvider(order).future),
        throwsA(isA<VantaApiFailure>().having((e) => e.key, 'key', vantaApiDataInvalid)),
      );
    });
    test('partial archive fills cannot produce a complete financial total', () async {
      repository.partial = true;
      final order = repository.rows[TradingHistoryTab.orders]!.first as HistoryOrder;
      final result = await container.read(tradingOrderDetailsProvider(order).future);
      expect(result!.complete, isFalse);
      expect(result.fee, isNull);
      expect(result.realizedPnl, isNull);
    });
  });
}

class _PagedFills implements TradingOrderFillsRepository {
  int calls = 0;
  @override
  Future<TradingHistoryPage> readOrderFills(
    HistoryOrder order, {
    required String address,
    TradingHistoryCursor? cursor,
  }) async {
    calls++;
    return TradingHistoryPage(
      address: address,
      records: calls == 21
          ? mapTradingHistory([historyFill()], TradingHistoryTab.trades)
          : const [],
      next: calls == 21 ? null : TradingHistoryCursor('page-$calls'),
    );
  }
}
