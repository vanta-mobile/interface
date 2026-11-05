import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';

import '../../support/live_order.dart';

void main() {
  test('capabilities preserve known policies without enabling undocumented values', () {
    final payload = liveExchangePayload();
    final row = (payload['symbols'] as List).single as Map;
    row['timeInForce'] = ['IOC', 'HIDDEN', 'FOK', 'FUTURE_POLICY'];
    final rules = mapLiveOrderRules(payload, 'BTCUSDT');
    expect(rules.timeInForce, {LiveOrderTimeInForce.ioc, LiveOrderTimeInForce.hidden});
    expect(rules.validate(liveDraft(), Decimal.parse('80000')), 'liveOrderTimeInForceUnavailable');
    expect(rules.validate(liveDraft(market: true), Decimal.parse('80000')), null);
    expect(() => rules.timeInForce.clear(), throwsUnsupportedError);
  });

  test('missing, empty, duplicate or malformed capability lists fail closed', () {
    for (final invalid in <Object?>[
      null,
      <String>[],
      ['GTC', 'GTC'],
      ['GTC', 1],
      ['gtc'],
      'GTC',
      ['GTC', ''],
    ]) {
      final payload = liveExchangePayload();
      (payload['symbols'] as List).single['timeInForce'] = invalid;
      expect(
        () => mapLiveOrderRules(payload, 'BTCUSDT'),
        throwsFormatException,
        reason: '$invalid',
      );
    }
  });

  test('unknown-only capabilities do not prevent market orders or invent a default policy', () {
    final payload = liveExchangePayload();
    (payload['symbols'] as List).single['timeInForce'] = ['FUTURE_POLICY'];
    final rules = mapLiveOrderRules(payload, 'BTCUSDT');
    expect(rules.timeInForce, isEmpty);
    expect(rules.validate(liveDraft(), Decimal.parse('80000')), 'liveOrderTimeInForceUnavailable');
    expect(rules.validate(liveDraft(market: true), Decimal.parse('80000')), null);
  });

  for (final policy in LiveOrderTimeInForce.values) {
    test('${policy.wire}: opening and close intents freeze policy and preserve exact filters', () {
      final intent = liveIntent(timeInForce: policy);
      expect(intent.context.validate(intent.draft), null);
      expect(intent.parameters['timeInForce'], policy.wire);
      expect(intent.parameters['price'], '80000');
      expect(
        intent.context.validate(liveDraft(timeInForce: policy, price: '80000.01')),
        'liveOrderPriceFilter',
      );
      final close = liveCloseIntent(market: false, timeInForce: policy);
      expect(close.parameters['timeInForce'], policy.wire);
      expect(close.parameters['reduceOnly'], 'true');
      expect(close.context.validate(close.draft), null);
      final hedge = liveCloseIntent(market: false, hedge: true, timeInForce: policy);
      expect(hedge.parameters['timeInForce'], policy.wire);
      expect(hedge.parameters['positionSide'], 'LONG');
      expect(hedge.parameters.containsKey('reduceOnly'), false);
    });

    test('${policy.wire}: market orders exclude dormant limit price and policy', () {
      final market = liveIntent(market: true, timeInForce: policy);
      expect(market.context.validate(market.draft), null);
      expect(market.parameters.containsKey('timeInForce'), false);
      expect(market.parameters.containsKey('price'), false);
    });

    test('${policy.wire}: query rejects a different policy for the same order reference', () {
      final intent = liveIntent(timeInForce: policy);
      final payload = liveQueryPayload(intent);
      expect(mapLiveOrderQuery(payload, intent).status, 'NEW');
      payload['timeInForce'] = policy == LiveOrderTimeInForce.gtc ? 'IOC' : 'GTC';
      expect(() => mapLiveOrderQuery(payload, intent), throwsFormatException);
    });
  }

  test('IOC expiry can confirm a partial fill without implying the whole order filled', () {
    final intent = liveIntent(timeInForce: LiveOrderTimeInForce.ioc);
    final result = mapLiveOrderQuery({
      ...liveQueryPayload(intent, status: 'EXPIRED'),
      'executedQty': '0.0004',
    }, intent);
    expect(result.status, 'EXPIRED');
    expect(result.executedQuantity, Decimal.parse('0.0004'));
    expect(result.needsRecheck, false);
    expect(
      () => mapLiveOrderQuery({
        ...liveQueryPayload(intent, status: 'FILLED'),
        'executedQty': '0.0004',
      }, intent),
      throwsFormatException,
    );
  });

  test('Post Only rejection is a verified zero-fill result', () {
    final intent = liveIntent(timeInForce: LiveOrderTimeInForce.postOnly);
    final result = mapLiveOrderQuery(liveQueryPayload(intent, status: 'REJECTED'), intent);
    expect(result.status, 'REJECTED');
    expect(result.executedQuantity, Decimal.zero);
    expect(result.needsRecheck, false);
  });
}
