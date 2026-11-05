import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/attached_order_mapper.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/attached_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';

import '../../support/attached_order.dart';
import '../../support/live_order.dart';

void main() {
  for (final buy in [true, false]) {
    for (final hedge in [true, false]) {
      for (final exits in ['tp', 'sl', 'both']) {
        test('entry and protection scope, linkage and independent query $buy $hedge $exits', () {
          final intent = attachedIntent(
            buy: buy,
            hedge: hedge,
            tp: exits != 'sl',
            sl: exits != 'tp',
          );
          expect(intent.context.validate(intent.draft), null);
          expect(() => intent.parameters, throwsStateError);
          final p = intent.strategyParameters;
          expect(p.keys.toSet(), {'clientStrategyId', 'strategyType', 'subOrderList'});
          expect(p['strategyType'], exits == 'both' ? 'OTOCO' : 'OTO');
          final legs = jsonDecode(p['subOrderList']!) as List;
          expect(legs.length, exits == 'both' ? 3 : 2);
          expect((legs.first as Map)['type'], 'LIMIT');
          expect((legs.first as Map)['timeInForce'], 'GTC');
          for (var i = 1; i < legs.length; i++) {
            final leg = legs[i] as Map;
            expect(leg['quantity'], '0.001');
            expect(leg['side'], buy ? 'SELL' : 'BUY');
            expect(leg['positionSide'], hedge ? (buy ? 'LONG' : 'SHORT') : 'BOTH');
            expect(leg['reduceOnly'], hedge ? null : 'true');
            expect(leg.containsKey('closePosition'), false);
            expect(leg.containsKey('price'), false);
            expect(leg['firstDrivenId'], '1');
            expect(leg['firstDrivenOn'], 'PARTIALLY_FILLED_OR_FILLED');
            expect(leg['firstTrigger'], 'PLACE_ORDER');
            expect(leg['secondDrivenId'], exits == 'both' ? (i == 1 ? '3' : '2') : null);
            expect(leg['secondTrigger'], exits == 'both' ? 'CANCEL_ORDER' : null);
          }
          final result = mapAttachedOrderQuery(attachedQuery(intent), intent, liveOrderClock);
          expect(result.needsRecheck, false);
          expect(result.orderId, null);
          expect(result.executedQuantity, null);
          expect(result.strategy!.strategyId, '9876');
          expect(result.strategy!.legs.first.orderId, '100');
          expect(result.strategy!.legs.last.orderId, null);
        });
      }
    }
  }
  for (final policy in LiveOrderTimeInForce.values) {
    test('strategy entry policy $policy', () {
      final intent = attachedIntent(policy: policy);
      expect(
        intent.context.validate(intent.draft),
        policy == LiveOrderTimeInForce.ioc ? 'attachedOrderIocUnavailable' : null,
      );
    });
  }
  test('ordinary market and triggered entries use distinct future reference and terms', () {
    final market = attachedIntent(market: true);
    expect(market.context.validate(market.draft), null);
    expect(market.strategyLegs.first.keys, isNot(contains('price')));
    expect(market.strategyLegs.first.keys, isNot(contains('timeInForce')));
    for (final isMarket in [true, false]) {
      final intent = attachedIntent(
        market: isMarket,
        trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '80500'),
      );
      expect(intent.context.validate(intent.draft), null);
      expect(intent.strategyLegs.first['stopPrice'], '80500');
      expect(intent.strategyLegs.first['type'], isMarket ? 'STOP_MARKET' : 'STOP');
    }
  });
  test(
    'reverse entry protects full main quantity while opening margin still nets old position',
    () {
      final context = liveCloseContext(short: true, quantity: '0.002');
      final intent = attachedIntent(context: context, quantity: '0.003');
      expect(context.validate(intent.draft), null);
      expect(intent.strategyLegs[1]['quantity'], '0.003');
      expect(context.estimatedOpeningQuantity(intent.draft), Decimal.parse('0.001'));
      final noExposure = attachedIntent(context: context, quantity: '0.001');
      expect(context.validate(noExposure.draft), null);
      expect(noExposure.strategyLegs[1]['quantity'], '0.001');
      expect(context.estimatedOpeningQuantity(noExposure.draft), Decimal.zero);
      final same = attachedIntent(context: liveCloseContext(quantity: '0.002'));
      expect(same.strategyLegs[1]['quantity'], '0.001');
    },
  );
  test('empty, wrong-kind, reduction, trailing and quick attachments rejected', () {
    final data = liveContext(bid: '80000', ask: '80000');
    expect(
      data.validate(liveDraft(attachment: const LiveOrderAttachment())),
      'attachedOrderInvalid',
    );
    expect(
      data.validate(
        liveDraft(
          attachment: const LiveOrderAttachment(
            takeProfit: AttachedExit(kind: LiveOrderTriggerKind.stop, price: '81000'),
          ),
        ),
      ),
      'attachedOrderInvalid',
    );
    expect(
      liveCloseContext().validate(
        liveDraft(buy: false, reduceOnly: true, attachment: attachedProtection(buy: false)),
      ),
      'attachedOrderInvalid',
    );
    expect(
      data.validate(
        liveDraft(
          market: true,
          price: '',
          trailing: const LiveOrderTrailing(callbackRate: '1'),
          attachment: attachedProtection(),
        ),
      ),
      'attachedOrderInvalid',
    );
    expect(
      data.validate(
        liveDraft(market: true, price: '', quickEntry: true, attachment: attachedProtection()),
      ),
      'quickOrderInvalid',
    );
  });
  test('decimal tick, direction, missing Last and capabilities are not silently repaired', () {
    final data = liveContext(bid: '80000', ask: '80000');
    for (final item in <(String, String)>[
      ('0', 'liveOrderInvalidTrigger'),
      ('81000.01', 'liveOrderTriggerFilter'),
      ('79999', 'attachedOrderPriceDirection'),
      ('80000', 'attachedOrderPriceDirection'),
    ]) {
      final draft = liveDraft(
        market: true,
        attachment: LiveOrderAttachment(
          takeProfit: AttachedExit(
            kind: LiveOrderTriggerKind.takeProfit,
            price: item.$1,
            basis: LiveOrderTriggerBasis.mark,
          ),
        ),
      );
      expect(data.validate(draft), item.$2);
    }
    final draft = liveDraft(
      market: true,
      attachment: LiveOrderAttachment(
        takeProfit: const AttachedExit(
          kind: LiveOrderTriggerKind.takeProfit,
          price: '81000',
          basis: LiveOrderTriggerBasis.last,
        ),
      ),
    );
    expect(liveContext(lastPrice: null, bid: '80000', ask: '80000').validate(draft), null);
    expect(
      liveContext(orderTypes: {'LIMIT', 'MARKET'}).validate(draft),
      'liveOrderTypeUnavailable',
    );
    expect(
      liveContext(protection: null)
          .validate(liveDraft(attachment: attachedProtection(protect: true))),
      'liveOrderProtectUnavailable',
    );
  });
  test('full main-order protection does not inherit a net residual lot minimum', () {
    final intent = attachedIntent(
      context: liveCloseContext(short: true, quantity: '0.0025'),
      quantity: '0.003',
    );
    expect(intent.context.validate(intent.draft), null);
    expect(Decimal.parse(intent.strategyLegs[1]['quantity']!), Decimal.parse('0.003'));
    expect(intent.context.estimatedOpeningQuantity(intent.draft), Decimal.parse('0.0005'));
  });
  test('ordinary order mapper can never treat strategy ID as an order ID', () {
    final intent = attachedIntent();
    expect(() => mapLiveOrderQuery(liveQueryPayload(intent), intent), throwsFormatException);
  });
  test('HTTP 200 failureCode is checked and raw reason discarded', () {
    expect(
      () =>
          checkAttachedOrderAcknowledgement({'failureCode': -4142, 'failureReason': 'raw secret'}),
      throwsA(
        isA<AccountReadFailure>()
            .having((e) => e.code, 'code', -4142)
            .having((e) => e.key, 'key', 'attachedOrderRejected'),
      ),
    );
    expect(
      () => checkAttachedOrderAcknowledgement({'strategyId': 9876}),
      throwsA(isA<AccountReadFailure>()),
    );
    checkAttachedOrderAcknowledgement({'failureCode': 0});
  });
  final mutations = <String, Object?>{
    'symbol': 'ETHUSDT',
    'side': 'BUY',
    'positionSide': 'LONG',
    'clientOrderId': 'wrong',
    'strategyId': 1,
    'strategySubId': 1,
    'quantity': '0.002',
    'stopPrice': '81000.1',
    'reduceOnly': false,
    'closePosition': true,
    'workingType': 'CONTRACT_PRICE',
    'priceProtect': true,
    'timeInForce': 'IOC',
    'type': 'STOP_MARKET',
    'securityType': 'OPTIONS',
    'firstDrivenId': 3,
    'firstDrivenOn': 'FILLED',
    'firstTrigger': 'CANCEL_ORDER',
    'secondDrivenId': 1,
    'secondTrigger': 'PLACE_ORDER',
    'secondDrivenOn': 'NEW',
    'status': 'raw sensitive response',
    'orderId': 1.5,
  };
  for (final change in mutations.entries) {
    test('query cannot resolve mismatched linked exit ${change.key}', () {
      final intent = attachedIntent(), payload = attachedQuery(attachedIntent());
      ((payload['subOrders'] as List)[1] as Map)[change.key] = change.value;
      expect(() => mapAttachedOrderQuery(payload, intent, liveOrderClock), throwsFormatException);
    });
  }
  test('out of order rows are matched by sequence; duplicate IDs and missing legs rejected', () {
    final intent = attachedIntent(), payload = attachedQuery(attachedIntent());
    final legs = payload['subOrders'] as List;
    payload['subOrders'] = legs.reversed.toList();
    expect(mapAttachedOrderQuery(payload, intent, liveOrderClock).strategy!.legs.first.sequence, 1);
    (legs[1] as Map)['orderId'] = 100;
    expect(() => mapAttachedOrderQuery(payload, intent, liveOrderClock), throwsFormatException);
    payload['subOrders'] = [legs.first];
    expect(() => mapAttachedOrderQuery(payload, intent, liveOrderClock), throwsFormatException);
  });
}
