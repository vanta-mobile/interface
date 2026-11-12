import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/network/request_scope.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/portfolio/application/trading_history_provider.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/aster_trading_history_repository.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_history.dart';
import 'package:vanta/features/portfolio/domain/trading_history.dart';

import '../../support/futures_history.dart';
import '../../support/live_order.dart';
import '../../support/trading_history.dart';
import '../../support/wallet_connection.dart';

const _owner = historyAddress;
const _signer = '0x2222222222222222222222222222222222222222';
final _order = HistoryRepository().rows[TradingHistoryTab.orders]!.first as HistoryOrder;

void main() {
  late AsterAccountService service;
  late AsterTradingHistoryRepository repository;
  late List<http.Request> requests;
  late List<Map<String, Object?>> signatures;
  late Object? response;
  late bool reject;
  late DateTime now;
  Future<String> sign({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) async {
    expect(expectedAddress, _signer);
    signatures.add(typedData);
    return TestWalletConnection.signature;
  }

  Future<AccountRequestIdentity> authorize(String address) async {
    expect(address, _owner);
    return AccountRequestIdentity(address: _signer, sign: sign);
  }

  setUp(() {
    requests = [];
    signatures = [];
    response = null;
    reject = false;
    now = futuresHistoryNow;
    service = AsterAccountService(
      client: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/time')) {
          return http.Response(jsonEncode({'serverTime': now.millisecondsSinceEpoch}), 200);
        }
        if (r.url.path.endsWith('/exchangeInfo')) {
          return http.Response(jsonEncode(liveExchangePayload()), 200);
        }
        final payload =
            response ??
            switch (r.url.path) {
              '/fapi/v3/allOrders' => [futuresOrderRow()],
              '/fapi/v3/income' => [futuresIncomeRow()],
              '/fapi/v3/userTrades' => [
                {...futuresTradeRow(), 'symbol': _order.symbol, 'orderId': _order.id},
              ],
              _ => throw StateError('Unexpected endpoint'),
            };
        return http.Response(
          jsonEncode(reject ? {'code': -2015, 'msg': 'Account access revoked'} : payload),
          200,
        );
      }),
    );
    final nonces = AsterReadNonces();
    repository = AsterTradingHistoryRepository(
      service: service,
      sign: sign,
      authorization: authorize,
      nonces: nonces,
      now: () => now,
    );
    addTearDown(service.close);
  });

  test(
    'orders and transactions use all-symbol Aster reads and exact agent-signed query bytes',
    () async {
      final orders = await repository.read(TradingHistoryTab.orders, address: _owner);
      final income = await repository.read(TradingHistoryTab.transactions, address: _owner);
      final row = orders.records.single as HistoryOrder;
      expect(row.filledValue, Decimal.parse('80.000000000000000001'));
      expect(row.stopPrice, Decimal.zero);
      expect(orders.recentDays, 7);
      expect(orders.next, isNull);
      expect(
        (income.records.single as HistoryTransaction).amount,
        Decimal.parse('-0.000000000000000001'),
      );
      final signed = requests.where((r) => r.url.queryParameters.containsKey('signature')).toList();
      expect(signed.map((r) => r.url.path), ['/fapi/v3/allOrders', '/fapi/v3/income']);
      for (var i = 0; i < signed.length; i++) {
        final p = signed[i].url.queryParameters;
        expect(p['user'], _owner);
        expect(p['signer'], _signer);
        expect(p.containsKey('symbol'), isFalse);
        expect(p.containsKey('incomeType'), isFalse);
        expect(p['limit'], '1000');
        expect(p['nonce'], '${now.millisecondsSinceEpoch * 1000 + i}');
        expect(
          (signatures[i]['message'] as Map)['msg'],
          signed[i].url.query.split('&signature=').first,
        );
        expect(signed[i].method, 'GET');
      }
    },
  );

  test(
    'saturated windows split without losing a boundary or moving the original end time',
    () async {
      response = List.generate(1000, (i) => futuresOrderRow(id: '$i'));
      final first = await repository.read(TradingHistoryTab.orders, address: _owner);
      final cursor = jsonDecode(first.next!.main!) as List;
      final recent = HistoryWindow.recent(now, const Duration(days: 7));
      final newer = cursor[0] as List, older = cursor[1] as List;
      expect(newer[1], recent.end);
      expect(older[0], recent.start);
      expect((older[1] as int) + 1, newer[0]);
      now = now.add(const Duration(hours: 1));
      response = [futuresOrderRow(time: newer[1] as int)];
      final next = await repository.read(
        TradingHistoryTab.orders,
        address: _owner,
        cursor: first.next,
      );
      expect(jsonDecode(next.next!.main!), [older]);
      expect(
        requests.lastWhere((r) => r.url.path.endsWith('allOrders')).url.queryParameters['endTime'],
        '${newer[1]}',
      );
    },
  );

  test('allOrders keeps a filled order whose exchange update time precedes creation', () async {
    final created = futuresHistoryNow.millisecondsSinceEpoch;
    response = [
      {
        ...futuresOrderRow(),
        'status': 'FILLED',
        'executedQty': '0.002',
        'cumQuote': '160',
        'updateTime': created - 27,
      },
      {
        ...futuresOrderRow(id: '12346'),
        'status': 'NEW',
        'executedQty': '0',
        'cumQuote': '0',
        'avgPrice': '0',
      },
    ];
    final page = await repository.read(TradingHistoryTab.orders, address: _owner);
    expect(page.records, hasLength(2));
    final order = page.records.cast<HistoryOrder>().singleWhere((r) => r.id == '12345');
    expect(order.time.millisecondsSinceEpoch, created);
    expect(order.updatedAt!.millisecondsSinceEpoch, created - 27);
    expect(order.status, 'FILLED');
    expect(order.filledValue, Decimal.parse('160'));
  });

  test('a saturated single millisecond reports partial data', () async {
    final time = now.millisecondsSinceEpoch;
    response = List.generate(1000, (i) => futuresIncomeRow(id: '$i', time: time));
    final page = await repository.read(
      TradingHistoryTab.transactions,
      address: _owner,
      cursor: TradingHistoryCursor(
        jsonEncode([
          [time, time],
        ]),
      ),
    );
    expect(page.partial, isTrue);
    expect(page.next, isNull);
  });

  test('income IDs are scoped by incomeType and all reported flow kinds are retained', () async {
    response = [
      futuresIncomeRow(id: '42'),
      {...futuresIncomeRow(id: '42'), 'incomeType': 'COMMISSION'},
      {...futuresIncomeRow(id: '43'), 'incomeType': 'AUTO_EXCHANGE', 'symbol': ''},
    ];
    final page = await repository.read(TradingHistoryTab.transactions, address: _owner);
    expect(page.records.map((r) => r.key).toSet(), hasLength(3));
    expect(
      page.records.cast<HistoryTransaction>().map((r) => r.type),
      containsAll(['FUNDING_FEE', 'COMMISSION', 'AUTO_EXCHANGE']),
    );
  });

  test('invalid tabs and cursors cannot dispatch or sign requests', () async {
    for (final tab in [TradingHistoryTab.trades, TradingHistoryTab.positions]) {
      await expectLater(repository.read(tab, address: _owner), throwsA(isA<AccountReadFailure>()));
    }
    await expectLater(
      repository.read(
        TradingHistoryTab.orders,
        address: _owner,
        cursor: const TradingHistoryCursor('bad cursor'),
      ),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(requests, isEmpty);
    expect(signatures, isEmpty);
  });

  test('HTTP 200 rejection retains Aster error message and code without replay', () async {
    reject = true;
    await expectLater(
      repository.read(TradingHistoryTab.orders, address: _owner),
      throwsA(
        isA<AccountReadFailure>()
            .having((e) => e.code, 'code', -2015)
            .having((e) => e.details?.message, 'message', 'Account access revoked'),
      ),
    );
    expect(requests.where((r) => r.url.path.endsWith('allOrders')), hasLength(1));
  });

  test('order details filter exact symbol and order without time filters and retain Maker and signed fees', () async {
    final page = await repository.readOrderFills(_order, address: _owner);
    final fill = page.records.single as HistoryFill;
    expect(fill.maker, isTrue);
    expect(fill.fee, Decimal.parse('-0.008000000000000001'));
    final request = requests.last;
    expect(request.url.path, '/fapi/v3/userTrades');
    expect(request.url.queryParameters['symbol'], _order.symbol);
    expect(request.url.queryParameters['orderId'], _order.id);
    expect(request.url.queryParameters.containsKey('startTime'), isFalse);
    expect(request.url.queryParameters.containsKey('endTime'), isFalse);
    expect(requests.any((r) => r.url.path.endsWith('exchangeInfo')), isFalse);
  });

  test('order fills page by numeric fromId and reject ignored or mismatched filters', () async {
    response = List.generate(
      1000,
      (i) => {...futuresTradeRow(id: '$i'), 'symbol': _order.symbol, 'orderId': _order.id},
    );
    final first = await repository.readOrderFills(_order, address: _owner);
    expect(first.next!.main, '1000');
    response = [
      {...futuresTradeRow(id: '1000'), 'symbol': _order.symbol, 'orderId': _order.id},
    ];
    final next = await repository.readOrderFills(_order, address: _owner, cursor: first.next);
    expect(next.next, isNull);
    expect(requests.last.url.queryParameters['fromId'], '1000');
    response = [
      {...futuresTradeRow(id: '999'), 'symbol': _order.symbol, 'orderId': _order.id},
    ];
    await expectLater(
      repository.readOrderFills(_order, address: _owner, cursor: first.next),
      throwsA(isA<AccountReadFailure>()),
    );
    response = [futuresTradeRow()];
    await expectLater(
      repository.readOrderFills(_order, address: _owner),
      throwsA(isA<AccountReadFailure>()),
    );
  });

  test('tab source wiring keeps Trade and Position on OpenAPI only', () {
    final api = HistoryRepository();
    final c = ProviderContainer(
      overrides: [
        asterTradingHistoryRepositoryProvider.overrideWithValue(repository),
        tradingHistoryRepositoryProvider.overrideWithValue(api),
        vantaApiSessionProvider.overrideWith(HistorySession.new),
      ],
    );
    addTearDown(c.dispose);
    for (final tab in TradingHistoryTab.values) {
      expect(
        c.read(tradingHistorySourceProvider(tab)),
        same(historyUsesAster(tab) ? repository : api),
      );
    }
    expect(c.read(tradingOrderFillsRepositoryProvider), same(repository));
  });

  for (final bodyStarted in [false, true]) {
    test(
      'Aster history cancellation aborts ${bodyStarted ? 'body' : 'headers'} and isolates another reader',
      () async {
        final transport = _PendingTransport();
        final a = AsterAccountService(client: transport);
        final b = AsterAccountService(client: transport);
        addTearDown(a.close);
        addTearDown(b.close);
        final nonces = AsterReadNonces();
        AsterTradingHistoryRepository reader(AsterAccountService s) =>
            AsterTradingHistoryRepository(
              service: s,
              sign: sign,
              authorization: authorize,
              nonces: nonces,
              now: () => now,
            );
        var current = true;
        final result = RequestScope.run(
          () => current,
          () => reader(a).read(TradingHistoryTab.transactions, address: _owner),
        );
        final failure = expectLater(
          result,
          throwsA(
            isA<AccountReadFailure>().having(
              (e) => e.details?.cause,
              'cause',
              ApiErrorCause.cancelled,
            ),
          ),
        );
        await transport.started.future;
        var cancelled = false;
        final body = StreamController<List<int>>(onCancel: () => cancelled = true);
        if (bodyStarted) {
          transport.reply.complete(http.StreamedResponse(body.stream, 200));
          body.add(utf8.encode('['));
          await Future<void>.delayed(Duration.zero);
        }
        current = false;
        await failure;
        await (transport.privateRequest! as http.Abortable).abortTrigger;
        if (!bodyStarted) transport.reply.complete(http.StreamedResponse(body.stream, 200));
        await Future<void>.delayed(Duration.zero);
        expect(cancelled, isTrue);
        await body.close();
        final second = await reader(b).read(TradingHistoryTab.transactions, address: _owner);
        expect(second.records, hasLength(1));
      },
    );
  }
}

class _PendingTransport extends http.BaseClient {
  final started = Completer<void>();
  final reply = Completer<http.StreamedResponse>();
  http.BaseRequest? privateRequest;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await request.finalize().drain<void>();
    if (request.url.path.endsWith('/time')) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(jsonEncode({'serverTime': futuresHistoryNow.millisecondsSinceEpoch})),
        ),
        200,
      );
    }
    if (privateRequest == null) {
      privateRequest = request;
      started.complete();
      return reply.future;
    }
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode([futuresIncomeRow()]))), 200);
  }
}
