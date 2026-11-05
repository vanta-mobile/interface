import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';

import '../../support/live_order.dart';

void main() {
  for (final kind in LiveOrderTriggerKind.values) {
    for (final buy in [false, true]) {
      for (final market in [false, true]) {
        for (final basis in LiveOrderTriggerBasis.values) {
          test('single trigger terms and query: $kind buy=$buy market=$market $basis', () {
            final rising = (kind == LiveOrderTriggerKind.stop) == buy;
            final trigger = LiveOrderTrigger(
              kind: kind,
              price: rising ? '81000' : '79000',
              basis: basis,
              protect: true,
            );
            final intent = liveIntent(
              buy: buy,
              market: market,
              trigger: trigger,
              timeInForce: LiveOrderTimeInForce.hidden,
            );
            expect(intent.context.validate(intent.draft), null);
            expect(intent.parameters['stopPrice'], trigger.price);
            expect(intent.parameters['workingType'], basis.wire);
            expect(intent.parameters['priceProtect'], 'TRUE');
            expect(
              intent.parameters['type'],
              '${kind == LiveOrderTriggerKind.stop ? 'STOP' : 'TAKE_PROFIT'}${market ? '_MARKET' : ''}',
            );
            expect(intent.parameters['price'], market ? null : '80000');
            expect(intent.parameters['timeInForce'], market ? null : 'HIDDEN');
            expect(intent.parameters.containsKey('closePosition'), false);
            expect(mapLiveOrderQuery(liveQueryPayload(intent), intent).status, 'NEW');
            final executed = {
              ...liveQueryPayload(intent, status: 'FILLED'),
              'type': market ? 'MARKET' : 'LIMIT',
            };
            expect(mapLiveOrderQuery(executed, intent).executedQuantity, Decimal.parse('0.001'));
          });
        }
      }
    }
  }

  test('trigger basis uses distinct signed-read-context public references; no substitution', () {
    const last = LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '80000.5');
    const mark = LiveOrderTrigger(
      kind: LiveOrderTriggerKind.stop,
      price: '80000.5',
      basis: LiveOrderTriggerBasis.mark,
    );
    final context = liveContext();
    expect(context.validate(liveDraft(buy: false, trigger: last)), null);
    expect(context.validate(liveDraft(buy: false, trigger: mark)), 'liveOrderTriggerImmediate');
    final missing = liveContext(lastPrice: null);
    expect(
      missing.validate(liveDraft(buy: false, trigger: last)),
      'liveOrderTriggerReferenceUnavailable',
    );
    expect(missing.validate(liveDraft(buy: true, trigger: mark)), null);
    expect(missing.validate(liveDraft()), null);
  });

  test('stop and take-profit reject already-met and equality boundaries for both sides', () {
    for (final kind in LiveOrderTriggerKind.values) {
      for (final buy in [false, true]) {
        final rising = (kind == LiveOrderTriggerKind.stop) == buy;
        for (final price in ['80000', rising ? '79000' : '81000']) {
          final trigger = LiveOrderTrigger(
            kind: kind,
            price: price,
            basis: LiveOrderTriggerBasis.mark,
          );
          expect(
            liveContext().validate(liveDraft(buy: buy, trigger: trigger)),
            'liveOrderTriggerImmediate',
          );
        }
      }
    }
  });

  test('trigger price uses decimal bounds/ticks, not display precision or a float', () {
    for (final price in ['0', '-1', 'NaN', '1e3', '81000.01', '1000000.1']) {
      final trigger = LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: price);
      expect(
        liveContext().validate(liveDraft(trigger: trigger)),
        ['81000.01', '1000000.1'].contains(price)
            ? 'liveOrderTriggerFilter'
            : 'liveOrderInvalidTrigger',
      );
    }
  });

  test('conditional limit does not apply current mark percent to a future execution price', () {
    const stop = LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '75000');
    final draft = liveDraft(buy: false, price: '74999', trigger: stop);
    expect(liveContext().validate(draft), null);
    expect(liveContext().validate(liveDraft(buy: false, price: '74999')), 'liveOrderPercentFilter');
    expect(
      liveContext().validate(liveDraft(buy: false, price: '74999.01', trigger: stop)),
      'liveOrderPriceFilter',
    );
  });

  test(
    'conditional quantity uses general LOT_SIZE; MARKET_LOT_SIZE applies to ordinary MARKET',
    () {
      const stop = LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '81000');
      final context = liveContext();
      expect(context.validate(liveDraft(market: true, quantity: '150', trigger: stop)), null);
      expect(context.validate(liveDraft(market: true, quantity: '150')), 'liveOrderQuantityFilter');
      expect(
        context.validate(liveDraft(market: true, quantity: '150.0001', trigger: stop)),
        'liveOrderQuantityFilter',
      );
    },
  );

  for (final short in [false, true]) {
    for (final hedge in [false, true]) {
      test(
        'position TP/SL preserves side, reducing scope and quantity: short=$short hedge=$hedge',
        () {
          for (final kind in LiveOrderTriggerKind.values) {
            final rising = (kind == LiveOrderTriggerKind.stop) == short;
            final trigger = LiveOrderTrigger(kind: kind, price: rising ? '81000' : '78000');
            final intent = liveCloseIntent(short: short, hedge: hedge, trigger: trigger);
            expect(intent.context.validate(intent.draft), null);
            expect(intent.parameters['reduceOnly'], hedge ? null : 'true');
            expect(intent.parameters['positionSide'], hedge ? (short ? 'SHORT' : 'LONG') : 'BOTH');
            expect(intent.side, short ? 'BUY' : 'SELL');
            expect(
              intent.context.validate(
                liveDraft(
                  buy: short,
                  closingSide: intent.positionSide,
                  quantity: '0.011',
                  market: true,
                  trigger: trigger,
                ),
              ),
              'liveCloseTooLarge',
            );
          }
        },
      );
    }
  }

  test('conditional estimates use trigger/limit prices rather than current best bid or mark', () {
    const stop = LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '81000');
    final opening = liveIntent(market: true, trigger: stop);
    expect(opening.context.estimatedOpeningMargin(opening.draft), Decimal.parse('8.1'));
    final closing = liveCloseIntent(
      trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '78000'),
    );
    expect(closing.context.estimatedClosePnl(closing.draft), Decimal.parse('-5'));
    final limit = liveCloseIntent(
      market: false,
      trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '78000'),
    );
    expect(limit.context.estimatedClosePnl(limit.draft), Decimal.parse('5'));
  });

  test('unsupported conditional types and unknown protection threshold fail before review', () {
    const stop = LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '81000', protect: true);
    final limited = liveContext(orderTypes: {'LIMIT', 'MARKET'});
    expect(limited.validate(liveDraft(trigger: stop)), 'liveOrderTypeUnavailable');
    final payload = liveExchangePayload();
    final row = (payload['symbols'] as List).single as Map;
    row.remove('triggerProtect');
    final rules = mapLiveOrderRules(payload, 'BTCUSDT');
    expect(
      rules.validate(liveDraft(trigger: stop), Decimal.parse('80000')),
      'liveOrderProtectUnavailable',
    );
    expect(rules.triggerProtectPercent, null);
    expect(liveContext().rules.triggerProtectPercent, Decimal.fromInt(5));
  });

  test('capability and protection payloads reject duplicates, malformed decimals and floats', () {
    for (final invalid in <Object?>[-1, '-0.1', 'NaN', 0.05]) {
      final payload = liveExchangePayload();
      (payload['symbols'] as List).single['triggerProtect'] = invalid;
      expect(() => mapLiveOrderRules(payload, 'BTCUSDT'), throwsFormatException);
    }
    final payload = liveExchangePayload();
    (payload['symbols'] as List).single['orderTypes'] = ['LIMIT', 'MARKET', 'STOP', 'STOP'];
    expect(() => mapLiveOrderRules(payload, 'BTCUSDT'), throwsFormatException);
  });

  test('query verifies original conditional identity, trigger, basis, protection and quantity', () {
    final intent = liveIntent(
      trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '81000'),
    );
    final payload = liveQueryPayload(intent);
    for (final bad in <String, Object?>{
      'origType': 'TAKE_PROFIT',
      'type': 'STOP_MARKET',
      'stopPrice': '81000.1',
      'workingType': 'MARK_PRICE',
      'priceProtect': true,
      'closePosition': true,
      'origQty': '0',
      'reduceOnly': true,
      'timeInForce': 'IOC',
    }.entries) {
      expect(
        () => mapLiveOrderQuery({...payload, bad.key: bad.value}, intent),
        throwsFormatException,
        reason: bad.key,
      );
    }
    final market = liveIntent(market: true, trigger: intent.draft.trigger);
    expect(
      () => mapLiveOrderQuery({...liveQueryPayload(market), 'timeInForce': 'IOC'}, market),
      throwsFormatException,
    );
  });

  test(
    'Last ticker validates symbol and exact price, permits a quiet market and rejects future time',
    () {
      final payload = {'symbol': 'BTCUSDT', 'price': '80000.000000000000000001', 'time': 1};
      expect(mapLiveLastPrice(payload, 'BTCUSDT', 100000).toString(), '80000.000000000000000001');
      expect(() => mapLiveLastPrice(payload, 'ETHUSDT', 100000), throwsFormatException);
      expect(
        () => mapLiveLastPrice({...payload, 'price': 80000.1}, 'BTCUSDT', 100000),
        throwsFormatException,
      );
      expect(
        () => mapLiveLastPrice({...payload, 'time': 110001}, 'BTCUSDT', 100000),
        throwsFormatException,
      );
    },
  );
}
