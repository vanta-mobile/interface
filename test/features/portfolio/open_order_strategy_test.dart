import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/aster_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/data/open_order_strategy_mapper.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_open_order_strategy_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/domain/open_order_strategy.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/live_order.dart';
import '../../support/wallet_connection.dart';

AsterOpenOrder _order(Map<String, Object?> extra) => mapAsterOpenOrders(
  [
    {...openOrder(), ...extra},
  ],
  address: accountAddress,
  receivedAt: liveOrderClock,
).orders.single;

Map<String, Object?> _leg(int sub, Object orderId, String type, String stop) => {
  'strategyId': 77,
  'orderId': orderId,
  'strategySubId': sub,
  'symbol': 'BTCUSDT',
  'type': type,
  'stopPrice': stop,
};

Map<String, Object?> _strategy({String type = 'OTOCO', Object entryId = 1917641}) => {
  'strategyId': 77,
  'clientStrategyId': 'vanta-abc-def',
  'strategyType': type,
  'strategyStatus': 'WORKING',
  'subOrders': [
    _leg(1, entryId, 'LIMIT', '0'),
    _leg(2, 0, 'TAKE_PROFIT_MARKET', '372.86'),
    if (type == 'OTOCO') _leg(3, 0, 'STOP_MARKET', '41.43'),
  ],
};

void main() {
  group('query rules', () {
    test('app entry and exit legs derive the client strategy id', () {
      for (final leg in ['1', '2', '3']) {
        final query = openOrderStrategyQuery(_order({'clientOrderId': 'vanta-abc-def-$leg'}))!;
        expect(query.parameters, {'clientStrategyId': 'vanta-abc-def'});
        expect(query.types, ['OTOCO', 'OTO']);
      }
    });

    test('orders without linkage, and complete row linkage, need no read', () {
      expect(openOrderStrategyQuery(_order({'clientOrderId': 'web_123'})), isNull);
      expect(openOrderStrategyQuery(_order({})), isNull);
      final complete = _order({
        'strategyId': 77,
        'strategyType': 'OTOCO',
        'strategySubId': 1,
        'tp': '372.86',
        'sl': '41.43',
      });
      expect(complete.strategy!.takeProfit, Decimal.parse('372.86'));
      expect(openOrderStrategyQuery(complete), isNull);
      final partial = _order({'strategyId': '77', 'strategyType': 'OTOCO', 'tp': '372.86'});
      expect(openOrderStrategyQuery(partial)!.parameters, {'strategyId': '77'});
      expect(openOrderStrategyQuery(partial)!.types, ['OTOCO']);
    });

    test('malformed optional linkage is ignored without failing the read', () {
      final order = _order({'strategyId': 'x', 'clientOrderId': 42, 'tp': 'bad'});
      expect(order.strategy, isNull);
      expect(order.clientOrderId, isNull);
    });
  });

  group('mapper', () {
    test('entry gets TP/SL from exit legs; exit leg reports its strategy', () {
      final entry = mapOpenOrderStrategy(_strategy(), _order({}));
      expect(entry.strategyId, '77');
      expect(entry.entry, isTrue);
      expect(entry.takeProfit, Decimal.parse('372.86'));
      expect(entry.stopLoss, Decimal.parse('41.43'));
      final exit = mapOpenOrderStrategy({
        ..._strategy(),
        'subOrders': [_leg(1, 1, 'LIMIT', '0'), _leg(2, 1917641, 'TAKE_PROFIT_MARKET', '372.86')],
      }, _order({}));
      expect(exit.sequence, 2);
      expect(exit.entry, isFalse);
    });

    test('a strategy that does not contain the order is rejected', () {
      expect(() => mapOpenOrderStrategy(_strategy(entryId: 5), _order({})), throwsFormatException);
    });
  });

  group('repository', () {
    late List<String> types;
    late Map<String, int> errors;
    late SignedOpenOrderStrategyRepository repository;
    setUp(() {
      types = [];
      errors = {};
      final service = AsterAccountService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/time')) {
            return http.Response(
              jsonEncode({'serverTime': liveOrderClock.millisecondsSinceEpoch}),
              200,
            );
          }
          expect(request.url.path, endsWith('/fapi/v3/strategyOpenOrder'));
          final type = request.url.queryParameters['strategyType']!;
          types.add(type);
          if (errors[type] case final code?) {
            return http.Response(jsonEncode({'code': code, 'msg': 'x'}), 400);
          }
          return http.Response(jsonEncode(_strategy(type: type)), 200);
        }),
      );
      addTearDown(service.close);
      repository = SignedOpenOrderStrategyRepository(
        service,
        ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
        nonces: AsterReadNonces(),
      );
    });
    final query = const OpenOrderStrategyQuery(
      parameters: {'clientStrategyId': 'vanta-abc-def'},
      types: ['OTOCO', 'OTO'],
    );

    Future<OpenOrderStrategy?> read() => repository.read(
      address: accountAddress,
      order: _order({'clientOrderId': 'vanta-abc-def-1'}),
      query: query,
      isCurrent: () => true,
    );

    test('OTOCO first; OTO only after not-found', () async {
      expect((await read())!.stopLoss, Decimal.parse('41.43'));
      expect(types, ['OTOCO']);
      types.clear();
      errors['OTOCO'] = -2013;
      final oto = (await read())!;
      expect(types, ['OTOCO', 'OTO']);
      expect(oto.takeProfit, Decimal.parse('372.86'));
      expect(oto.stopLoss, isNull);
    });

    test('not found under every type is no strategy; other errors propagate', () async {
      errors['OTOCO'] = errors['OTO'] = -2013;
      expect(await read(), isNull);
      errors['OTOCO'] = -1021;
      await expectLater(read(), throwsA(isA<AccountReadFailure>()));
      expect(types.last, 'OTOCO');
    });
  });
}
