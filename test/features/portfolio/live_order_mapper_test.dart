import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';

import '../../support/live_order.dart';

void main() {
  final mark = Decimal.parse('80000');
  test('static quantity bounds depend on market or limit type', () {
    final rules = liveContext().rules;
    expect(rules.validate(liveDraft(quantity: '120.001'), mark), null);
    expect(
      rules.validate(liveDraft(market: true, quantity: '120.001'), mark),
      'liveOrderQuantityFilter',
    );
    expect(
      rules.validate(liveDraft(quantity: '0.001000000000000001'), mark),
      'liveOrderQuantityFilter',
    );
    expect(rules.validate(liveDraft(quantity: '0.002'), mark), null);
  });
  test('price bounds, ticks, side-specific percent and notional use decimals', () {
    final rules = liveContext().rules;
    expect(rules.validate(liveDraft(price: '80000.01'), mark), 'liveOrderPriceFilter');
    expect(rules.validate(liveDraft(price: '81600.1'), mark), 'liveOrderPercentFilter');
    expect(rules.validate(liveDraft(price: '81600.1', buy: false), mark), null);
    expect(rules.validate(liveDraft(price: '78399.9', buy: false), mark), 'liveOrderPercentFilter');
    expect(rules.validate(liveDraft(price: '100'), mark), 'liveOrderNotionalFilter');
  });
  test('increments follow documented value-minus-minimum rule', () {
    final payload = liveExchangePayload();
    final filters = (payload['symbols'] as List).single['filters'] as List;
    (filters[0] as Map)['minPrice'] = '1.05';
    final rules = mapLiveOrderRules(payload, 'BTCUSDT');
    expect(rules.validate(liveDraft(price: '80000.05'), mark), null);
    expect(rules.validate(liveDraft(price: '80000'), mark), 'liveOrderPriceFilter');
  });
  test('no binary floats, exponent, signs, commas or non-finite input', () {
    for (final text in ['NaN', 'Infinity', '1e-3', '-1', '+1', '1,000', '.1', ' 1']) {
      expect(parseOrderDecimal(text), null, reason: text);
    }
    expect(parseOrderDecimal('0.000000000000000001')!.toString(), '0.000000000000000001');
  });
  test('malformed or inactive rules fail closed', () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (p) => (p['symbols'] as List).single['status'] = 'SETTLING',
      (p) => ((p['symbols'] as List).single['filters'] as List).removeLast(),
      (p) => ((p['symbols'] as List).single['filters'] as List)[1]['stepSize'] = 0.001,
      (p) => (p['symbols'] as List).single['marginAsset'] = 'BTC',
    ]) {
      final payload = liveExchangePayload();
      change(payload);
      expect(() => mapLiveOrderRules(payload, 'BTCUSDT'), throwsFormatException);
    }
  });
  test('mark must belong to symbol and be fresh against exchange server clock', () {
    final payload = {'symbol': 'BTCUSDT', 'markPrice': '80000', 'time': 100000};
    expect(mapLiveMarkPrice(payload, 'BTCUSDT', 100001), mark);
    expect(() => mapLiveMarkPrice(payload, 'ETHUSDT', 100001), throwsFormatException);
    expect(() => mapLiveMarkPrice(payload, 'BTCUSDT', 110001), throwsFormatException);
  });
  test('market payload excludes all limit-only fields; hedge sides have no reduceOnly', () {
    final market = liveIntent(market: true, buy: false, hedge: true);
    expect(market.parameters['positionSide'], 'SHORT');
    expect(market.parameters.keys, isNot(contains('price')));
    expect(market.parameters.keys, isNot(contains('timeInForce')));
    expect(market.parameters.keys, isNot(contains('reduceOnly')));
    expect(liveIntent().parameters['positionSide'], 'BOTH');
    expect(liveIntent().parameters['timeInForce'], 'GTC');
  });
  test('query verifies identity, quantity, limit terms and fill consistency', () {
    final intent = liveIntent();
    final payload = liveQueryPayload(intent, status: 'FILLED');
    expect(mapLiveOrderQuery(payload, intent).executedQuantity, Decimal.parse('0.001'));
    for (final entry in {
      'clientOrderId': 'different',
      'origQty': '1',
      'executedQty': '0',
      'price': '80000.1',
      'timeInForce': 'IOC',
      'positionSide': 'LONG',
    }.entries) {
      final wrong = {...payload, entry.key: entry.value};
      expect(() => mapLiveOrderQuery(wrong, intent), throwsFormatException, reason: entry.key);
    }
  });
}
