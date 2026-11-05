import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';

import '../../support/live_order.dart';

void main() {
  for (final short in [false, true]) {
    for (final hedge in [false, true]) {
      for (final kind in LiveOrderTriggerKind.values) {
        test('entire close: short=$short hedge=$hedge $kind', () {
          final rising = (kind == LiveOrderTriggerKind.stop) == short;
          final intent = liveCloseIntent(
            short: short,
            hedge: hedge,
            entireClose: true,
            trigger: LiveOrderTrigger(kind: kind, price: rising ? '81000' : '78000'),
          );
          expect(intent.context.validate(intent.draft), null);
          expect(intent.parameters['closePosition'], 'true');
          expect(intent.parameters['side'], short ? 'BUY' : 'SELL');
          expect(intent.parameters['positionSide'], hedge ? (short ? 'SHORT' : 'LONG') : 'BOTH');
          for (final key in ['quantity', 'reduceOnly', 'price', 'timeInForce']) {
            expect(intent.parameters.containsKey(key), false, reason: key);
          }
          expect(intent.context.referenceCloseQuantity(intent.draft), Decimal.parse('0.01'));
          expect(intent.context.estimatedOpeningQuantity(intent.draft), Decimal.zero);
          expect(mapLiveOrderQuery(liveQueryPayload(intent), intent).status, 'NEW');
          // Trigger-time size is not bounded by the earlier reviewed snapshot.
          final fill = {
            ...liveQueryPayload(intent, status: 'FILLED', executed: '0.02'),
            'type': 'MARKET',
          };
          expect(mapLiveOrderQuery(fill, intent).executedQuantity, Decimal.parse('0.02'));
        });
      }
    }
  }

  const stop = LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '78000');
  LiveOrderDraft draft({
    bool market = true,
    String quantity = '',
    String price = '',
    bool reduceOnly = false,
    String? side = 'BOTH',
    LiveOrderTrigger? trigger = stop,
    bool buy = false,
  }) => liveDraft(
    buy: buy,
    market: market,
    quantity: quantity,
    price: price,
    reduceOnly: reduceOnly,
    closingSide: side,
    trigger: trigger,
    entireClose: true,
  );

  test('entire close rejects conflicting fields before rules or account access', () {
    for (final invalid in [
      draft(market: false),
      draft(trigger: null),
      draft(side: null),
      draft(quantity: '0.001'),
      draft(price: '80000'),
      draft(reduceOnly: true),
    ]) {
      expect(liveCloseContext().validate(invalid), 'liveEntireInvalid');
      expect(
        liveCloseContext().rules.validate(invalid, Decimal.parse('80000')),
        'liveEntireInvalid',
      );
    }
  });
  test('entire close rejects absent, empty or opposite-side positions', () {
    expect(liveContext().validate(draft()), 'liveClosePositionChanged');
    expect(liveCloseContext(quantity: '0').validate(draft()), 'liveClosePositionChanged');
    expect(liveCloseContext().validate(draft(buy: true)), 'liveClosePositionChanged');
    expect(liveCloseContext().validate(draft(side: 'LONG')), 'liveClosePositionChanged');
    expect(liveCloseContext(hedge: true).validate(draft()), 'liveClosePositionChanged');
    expect(
      liveCloseContext(hedge: true).validate(draft(side: 'SHORT', buy: true)),
      'liveClosePositionChanged',
    );
  });
  test(
    'entire close skips lot and notional for small position, but retains trigger validation',
    () {
      final context = liveCloseContext(hedge: true, quantity: '0.00000001');
      expect(context.validate(draft(side: 'LONG')), null);
      expect(
        context.validate(
          draft(
            side: 'LONG',
            trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '78000.01'),
          ),
        ),
        'liveOrderTriggerFilter',
      );
      expect(
        context.validate(
          draft(
            side: 'LONG',
            trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '81000'),
          ),
        ),
        'liveOrderTriggerImmediate',
      );
    },
  );
  test('entire query checks scope, terms, status and execution without inventing size', () {
    final intent = liveCloseIntent(entireClose: true, trigger: stop);
    final payload = liveQueryPayload(intent);
    for (final invalid in <String, Object?>{
      'closePosition': false,
      'reduceOnly': true,
      'positionSide': 'LONG',
      'origQty': '-1',
      'executedQty': '-1',
      'origType': 'STOP',
      'stopPrice': '77000',
    }.entries) {
      expect(
        () => mapLiveOrderQuery({...payload, invalid.key: invalid.value}, intent),
        throwsFormatException,
      );
    }
    expect(
      () => mapLiveOrderQuery({...payload, 'executedQty': '0.01'}, intent),
      throwsFormatException,
    );
    expect(
      () => mapLiveOrderQuery(liveQueryPayload(intent, status: 'FILLED', executed: '0'), intent),
      throwsFormatException,
    );
    expect(
      () => mapLiveOrderQuery(liveQueryPayload(intent, status: 'PARTIALLY_FILLED'), intent),
      throwsFormatException,
    );
    expect(
      mapLiveOrderQuery(
        liveQueryPayload(intent, status: 'PARTIALLY_FILLED', executed: '0.02'),
        intent,
      ).status,
      'PARTIALLY_FILLED',
    );
    expect(
      () => mapLiveOrderQuery({
        ...liveQueryPayload(intent, status: 'FILLED', executed: '0.02'),
        'origQty': '0.03',
      }, intent),
      throwsFormatException,
    );
    expect(
      mapLiveOrderQuery({
        ...liveQueryPayload(intent, status: 'FILLED', executed: '0.02'),
        'origQty': '0.02',
      }, intent).status,
      'FILLED',
    );
  });
  test('entire estimate is based on reviewed quantity and trigger price', () {
    final intent = liveCloseIntent(entireClose: true, trigger: stop);
    expect(intent.context.estimatedClosePnl(intent.draft), Decimal.parse('-10'));
  });
}
