import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';

import '../../support/live_order.dart';

void main() {
  for (final buy in [true, false]) {
    for (final basis in LiveOrderTriggerBasis.values) {
      for (final explicit in [false, true]) {
        test('trailing fixed quantity and terms: buy=$buy $basis activation=$explicit', () {
          final trailing = LiveOrderTrailing(
            callbackRate: '1.25',
            basis: basis,
            activationPrice: explicit ? (buy ? '79000' : '81000') : null,
          );
          final intent = liveIntent(market: true, buy: buy, trailing: trailing);
          expect(intent.context.validate(intent.draft), null);
          expect(intent.parameters['type'], 'TRAILING_STOP_MARKET');
          expect(intent.parameters['quantity'], '0.001');
          expect(intent.parameters['callbackRate'], '1.25');
          expect(intent.parameters['workingType'], basis.wire);
          expect(intent.parameters['activationPrice'], trailing.activationPrice);
          for (final field in [
            'price',
            'timeInForce',
            'stopPrice',
            'priceProtect',
            'closePosition',
          ]) {
            expect(intent.parameters.containsKey(field), false, reason: field);
          }
          expect(mapLiveOrderQuery(liveQueryPayload(intent), intent).status, 'NEW');
          expect(
            mapLiveOrderQuery({
              ...liveQueryPayload(intent, status: 'FILLED'),
              'type': 'MARKET',
            }, intent).executedQuantity,
            Decimal.parse('0.001'),
          );
        });
      }
    }
  }
  for (final short in [false, true]) {
    for (final hedge in [false, true]) {
      test('trailing closes original position with fixed quantity: short=$short hedge=$hedge', () {
        final intent = liveCloseIntent(
          short: short,
          hedge: hedge,
          trailing: const LiveOrderTrailing(callbackRate: '0.1'),
        );
        expect(intent.context.validate(intent.draft), null);
        expect(intent.parameters['side'], short ? 'BUY' : 'SELL');
        expect(intent.parameters['positionSide'], hedge ? (short ? 'SHORT' : 'LONG') : 'BOTH');
        expect(intent.parameters['reduceOnly'], hedge ? null : 'true');
        expect(intent.parameters['quantity'], '0.005');
        expect(intent.context.estimatedClosePnl(intent.draft), null);
        expect(mapLiveOrderQuery(liveQueryPayload(intent), intent).status, 'NEW');
      });
    }
  }
  LiveOrderDraft draft({
    String rate = '1',
    String? activation,
    bool buy = true,
    String quantity = '0.001',
  }) => liveDraft(
    market: true,
    price: '',
    buy: buy,
    quantity: quantity,
    trailing: LiveOrderTrailing(callbackRate: rate, activationPrice: activation),
  );

  for (final rate in ['0.1', '5', '1.234567890123456789', '00.10']) {
    test('callback rate preserves exact decimal $rate', () {
      expect(liveContext().validate(draft(rate: rate)), null);
    });
  }
  for (final rate in [
    '',
    '0',
    '0.099999999999999999',
    '5.000000000000000001',
    '-1',
    '1e0',
    'NaN',
    '1' * 81,
  ]) {
    test('invalid callback rate $rate blocked', () {
      expect(liveContext().validate(draft(rate: rate)), 'liveTrailingRateInvalid');
    });
  }
  test('trailing shape excludes ordinary limit, fixed stop and entire close', () {
    const trailing = LiveOrderTrailing(callbackRate: '1');
    for (final invalid in [
      liveDraft(market: false, trailing: trailing),
      liveDraft(market: true, price: '1', trailing: trailing),
      liveDraft(
        market: true,
        price: '',
        trailing: trailing,
        trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '81000'),
      ),
      liveDraft(
        market: true,
        price: '',
        quantity: '',
        trailing: trailing,
        entireClose: true,
        closingSide: 'BOTH',
      ),
    ]) {
      expect(liveContext().validate(invalid), 'liveTrailingInvalid');
      expect(liveContext().rules.validate(invalid, Decimal.parse('80000')), 'liveTrailingInvalid');
    }
  });
  test('activation uses matching reference with strict direction and price tick', () {
    for (final buy in [false, true]) {
      expect(liveContext().validate(draft(buy: buy, activation: '80001')), 'liveTrailingImmediate');
      expect(
        liveContext().validate(draft(buy: buy, activation: buy ? '81000' : '79000')),
        'liveTrailingImmediate',
      );
    }
    for (final activation in ['', '0', '-1', '1e4', 'NaN']) {
      expect(
        liveContext().validate(draft(activation: activation)),
        'liveTrailingActivationInvalid',
      );
    }
    for (final activation in ['79000.01', '1000000.1']) {
      expect(liveContext().validate(draft(activation: activation)), 'liveTrailingActivationFilter');
    }
    expect(liveContext(lastPrice: null).validate(draft()), 'liveOrderTriggerReferenceUnavailable');
    final mark = liveDraft(
      market: true,
      price: '',
      trailing: const LiveOrderTrailing(
        callbackRate: '1',
        activationPrice: '80000.5',
        basis: LiveOrderTriggerBasis.mark,
      ),
    );
    expect(liveContext().validate(mark), 'liveTrailingImmediate');
    final last = draft(activation: '80000.5');
    expect(liveContext().validate(last), null);
    expect(
      liveContext(lastPrice: null).validate(
        liveDraft(
          market: true,
          price: '',
          trailing: const LiveOrderTrailing(callbackRate: '1', basis: LiveOrderTriggerBasis.mark),
        ),
      ),
      null,
    );
  });
  test('general lot, supported type, funds and position limits still apply', () {
    expect(liveContext().validate(draft(quantity: '150')), null);
    expect(liveContext().validate(draft(quantity: '0.0011')), 'liveOrderQuantityFilter');
    expect(
      liveContext(orderTypes: {'LIMIT', 'MARKET'}).validate(draft()),
      'liveOrderTypeUnavailable',
    );
    expect(liveContext(withFunds: false).validate(draft()), 'liveOrderReadFunds');
    expect(
      liveCloseContext().validate(
        liveDraft(
          market: true,
          price: '',
          buy: false,
          quantity: '0.011',
          closingSide: 'BOTH',
          trailing: const LiveOrderTrailing(callbackRate: '1'),
        ),
      ),
      'liveCloseTooLarge',
    );
  });
  test('query requires original trailing type, exact rate, basis, activation and flags', () {
    final intent = liveIntent(
      market: true,
      trailing: const LiveOrderTrailing(callbackRate: '1', activationPrice: '79000'),
    );
    final payload = liveQueryPayload(intent);
    for (final invalid in <String, Object?>{
      'origType': 'STOP_MARKET',
      'type': 'LIMIT',
      'activatePrice': '79000.1',
      'priceRate': '1.01',
      'workingType': 'MARK_PRICE',
      'reduceOnly': true,
      'closePosition': true,
      'timeInForce': 'IOC',
      'origQty': '0',
    }.entries) {
      expect(
        () => mapLiveOrderQuery({...payload, invalid.key: invalid.value}, intent),
        throwsFormatException,
        reason: invalid.key,
      );
    }
    for (final key in [
      'origType',
      'activatePrice',
      'priceRate',
      'workingType',
      'reduceOnly',
      'closePosition',
      'timeInForce',
    ]) {
      expect(
        () => mapLiveOrderQuery({...payload}..remove(key), intent),
        throwsFormatException,
        reason: key,
      );
    }
  });
  test('default activation is validated from exchange without pinning snapshot price', () {
    final intent = liveIntent(market: true, trailing: const LiveOrderTrailing(callbackRate: '1'));
    expect(
      mapLiveOrderQuery({...liveQueryPayload(intent), 'activatePrice': '79995.8'}, intent).status,
      'NEW',
    );
    for (final activation in <Object?>['0', '-1', 'NaN', 79995.8, null]) {
      expect(
        () => mapLiveOrderQuery({...liveQueryPayload(intent), 'activatePrice': activation}, intent),
        throwsFormatException,
      );
    }
    expect(intent.parameters.containsKey('activationPrice'), false);
    expect(intent.context.estimatedOpeningMargin(intent.draft), Decimal.fromInt(8));
  });
}
