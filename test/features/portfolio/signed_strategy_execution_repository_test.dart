import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_strategy_execution_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/strategy_execution.dart';

import '../../support/aster_account.dart';
import '../../support/attached_order.dart';
import '../../support/live_order.dart';
import '../../support/strategy_execution.dart';
import '../../support/wallet_connection.dart';

void main() {
  late StrategyExecutionFixture fixture;
  late AsterAccountService service;
  late SignedStrategyExecutionRepository repository;
  late List<http.Request> requests;
  late List<String> signatures;
  late bool current, unitsFail;
  late int openError, historyError, refusedAt, orderErrorAt;
  late Map<String, dynamic> strategy;
  late Map<String, dynamic> Function(int) order;
  void Function(int)? afterSign;
  void Function(http.Request)? afterRequest;
  setUp(() {
    fixture = StrategyExecutionFixture();
    requests = [];
    signatures = [];
    current = true;
    unitsFail = false;
    openError = historyError = refusedAt = orderErrorAt = 0;
    strategy = fixture.strategy();
    order = fixture.order;
    afterSign = null;
    afterRequest = null;
    service = AsterAccountService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.followRedirects, false);
        afterRequest?.call(request);
        final path = request.url.path;
        if (path.endsWith('/time')) {
          return http.Response(
            jsonEncode({'serverTime': liveOrderClock.millisecondsSinceEpoch}),
            200,
          );
        }
        if (path.endsWith('/exchangeInfo')) {
          return unitsFail
              ? http.Response('unavailable', 503)
              : http.Response(jsonEncode(contractPayload()), 200);
        }
        if (path.endsWith('/strategyOpenOrder') || path.endsWith('/strategyHistoryOrder')) {
          final error = path.endsWith('/strategyOpenOrder') ? openError : historyError;
          if (error != 0) {
            return http.Response(jsonEncode({'code': error, 'msg': 'PRIVATE RAW'}), 400);
          }
          return http.Response(jsonEncode(strategy), 200);
        }
        if (path.endsWith('/order')) {
          final sequence = int.parse(request.url.queryParameters['orderId']!) - 99;
          if (sequence == orderErrorAt) {
            return http.Response('{"code":-2013,"msg":"PRIVATE RAW"}', 400);
          }
          return http.Response(jsonEncode(order(sequence)), 200);
        }
        fail('Unexpected endpoint $path');
      }),
    );
    repository = SignedStrategyExecutionRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        expect((typedData['domain'] as Map)['chainId'], 1666);
        signatures.add((typedData['message'] as Map)['msg'] as String);
        if (signatures.length == refusedAt) throw const AuthFailure('authWalletRejected');
        afterSign?.call(signatures.length);
        return TestWalletConnection.signature;
      },
      AsterReadNonces(),
      () => liveOrderClock,
    );
  });
  tearDown(() => service.close());
  Future<StrategyExecutionSnapshot> read({StrategyExecutionQuery? query}) =>
      repository.read(query ?? fixture.query, isCurrent: () => current, onStep: (_, _) {});
  List<http.Request> privateRequests() =>
      requests.where((r) => r.url.queryParameters.containsKey('signature')).toList();
  Matcher failure(String key) =>
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'safe key', key));

  test(
    'same EOA, fresh unique microsecond nonces, exact signed bytes, GET-only actual fills',
    () async {
      final result = await read();
      expect(signatures.length, 4);
      final private = privateRequests();
      expect(private.length, 4);
      for (var i = 0; i < private.length; i++) {
        expect(
          private[i].url.query,
          '${signatures[i]}&signature=${TestWalletConnection.signature}',
        );
        final params = Uri.splitQueryString(signatures[i]);
        expect(params['user'], accountAddress);
        expect(params['signer'], accountAddress);
        expect(params['nonce'], '${liveOrderClock.millisecondsSinceEpoch * 1000 + i}');
      }
      expect(private.first.url.queryParameters['clientStrategyId'], fixture.intent.clientOrderId);
      expect(private.skip(1).map((r) => r.url.queryParameters['orderId']), ['100', '101', '102']);
      expect(private.skip(1).every((r) => r.url.queryParameters['symbol'] == 'BTCUSDT'), true);
      expect(result.legs.first.execution!.executed, Decimal.parse('0.0004'));
      expect(result.legs.first.execution!.status, 'CANCELED');
      expect(result.legs.first.execution!.quoteAmount, Decimal.parse('32.000000000000000001'));
      expect(result.units!.base, 'BTC');
      expect(identical(result.query, fixture.query), true);
    },
  );
  test('zero/missing exchange ID stays unknown, never queried as order0 or filled0', () async {
    strategy = fixture.strategy(allIds: false);
    final result = await read();
    expect(signatures.length, 2);
    expect(result.legs.skip(1).every((r) => r.execution == null && r.failure == null), true);
    expect(privateRequests().where((r) => r.url.path.endsWith('/order')).length, 1);
  });
  test('strategy -2013 alone permits history lookup, still original identifiers', () async {
    openError = -2013;
    final result = await read();
    expect(result.strategy.strategyId, '9876');
    expect(signatures.length, 5);
    expect(privateRequests()[1].url.path, '/fapi/v3/strategyHistoryOrder');
    expect(
      privateRequests()[1].url.queryParameters['clientStrategyId'],
      fixture.intent.clientOrderId,
    );
  });
  test('permission failure never falls back to another strategy source', () async {
    openError = -2015;
    await expectLater(
      read(),
      throwsA(isA<AccountReadFailure>().having((f) => f.code, 'code', -2015)),
    );
    expect(signatures.length, 1);
    expect(requests.any((r) => r.url.path.endsWith('/strategyHistoryOrder')), false);
  });
  test('missing retained history does not create an empty successful snapshot', () async {
    openError = historyError = -2013;
    await expectLater(read(), throwsA(isA<AccountReadFailure>()));
    expect(signatures.length, 2);
  });
  for (final field in ['strategyId', 'clientStrategyId']) {
    test('different $field cannot lead to ordinary order signatures', () async {
      strategy[field] = field == 'strategyId' ? 8888 : 'different-strategy';
      await expectLater(read(), failure('accountDataInvalid'));
      expect(signatures.length, 1);
    });
  }
  test('changed strategy linkage is rejected before querying ordinary orders', () async {
    ((strategy['subOrders'] as List)[1] as Map)['firstDrivenId'] = 3;
    await expectLater(read(), failure('accountDataInvalid'));
    expect(signatures.length, 1);
  });
  test('second leg missing from retention retains first fill and stops later prompts', () async {
    orderErrorAt = 2;
    final result = await read();
    expect(signatures.length, 3);
    expect(result.legs[0].execution, isNotNull);
    expect(result.legs[1].failure!.code, -2013);
    expect(result.legs[2].failure!.key, 'strategyExecutionSkipped');
    expect(result.legs[1].execution, null);
  });
  test('refusal stops subsequent signatures and preserves earlier successful leg', () async {
    refusedAt = 3;
    final result = await read();
    expect(signatures.length, 3);
    expect(privateRequests().length, 2);
    expect(result.legs[0].execution, isNotNull);
    expect(result.legs[1].failure!.key, 'authWalletRejected');
    expect(result.legs[2].failure!.key, 'strategyExecutionSkipped');
  });
  test('malformed child cannot contaminate actual values or cause more prompts', () async {
    order = (sequence) => fixture.order(sequence)..['clientOrderId'] = 'different-order';
    final result = await read();
    expect(signatures.length, 2);
    expect(result.legs[0].failure!.key, 'accountDataInvalid');
    expect(result.legs[0].execution, null);
    expect(result.legs.skip(1).every((r) => r.failure!.key == 'strategyExecutionSkipped'), true);
  });
  test('resized actual quantity does not overwrite frozen protected quantity', () async {
    order = (sequence) {
      final row = fixture.order(sequence);
      if (sequence > 1) row['origQty'] = '0.0004';
      return row;
    };
    final result = await read();
    expect(result.legs[1].execution!.quantity, Decimal.parse('0.0004'));
    expect(result.legs[1].execution!.termsChanged, true);
    expect(result.query.order.protectedQuantity, '0.001');
  });
  test('public units failure preserves exact amounts without invented units', () async {
    unitsFail = true;
    final result = await read();
    expect(result.units, null);
    expect(result.legs[0].execution!.quoteAmount, Decimal.parse('32.000000000000000001'));
  });
  test('switching identity after wallet confirmation sends no signed request', () async {
    afterSign = (_) => current = false;
    await expectLater(read(), failure('authWalletChanged'));
    expect(privateRequests(), isEmpty);
    expect(signatures.length, 1);
  });
  test('switching while public units loads invalidates whole late snapshot', () async {
    afterRequest = (r) {
      if (r.url.path.endsWith('/exchangeInfo')) current = false;
    };
    await expectLater(read(), failure('authWalletChanged'));
  });
  test('invalid frozen query is rejected before any wallet prompt or network', () async {
    final q = fixture.query.order;
    final invalid = StrategyExecutionQuery(
      order: OrderQuery(
        address: q.address,
        symbol: q.symbol,
        clientOrderId: 'bad?client',
        mode: q.mode,
        draft: q.draft,
        protectedQuantity: q.protectedQuantity,
      ),
      strategyId: '9876',
    );
    await expectLater(read(query: invalid), failure('accountDataInvalid'));
    expect(signatures, isEmpty);
    expect(requests, isEmpty);
  });
  test('ordinary order query cannot be passed as an attached strategy', () async {
    final invalid = StrategyExecutionQuery(
      order: OrderQuery.capture(liveIntent()),
      strategyId: '9876',
    );
    await expectLater(read(query: invalid), failure('accountDataInvalid'));
    expect(signatures, isEmpty);
  });
  test('single SL strategy uses actual sequence2 and only two ordinary lookups', () async {
    fixture = StrategyExecutionFixture(intent: attachedIntent(tp: false));
    strategy = fixture.strategy();
    order = fixture.order;
    final result = await read();
    expect(signatures.length, 3);
    expect(result.legs.length, 2);
    expect(result.legs[1].execution!.originalType, 'STOP_MARKET');
  });
}
