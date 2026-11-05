import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/position_leverage.dart';
import 'package:vanta/features/portfolio/domain/quick_order.dart';

import '../../support/live_order.dart';
import '../../support/quick_order.dart';

void main() {
  test('percentage quantity reserves taker fee and floors exact rational division', () {
    final sizing = quickSizing();
    for (final buy in [false, true]) {
      for (final entry in {25: '0.002', 50: '0.005', 75: '0.008', 100: '0.011'}.entries) {
        expect(sizing.quantity(buy, entry.key), Decimal.parse(entry.value));
      }
    }
    final data = liveContext(bid: '80000', ask: '80000', available: '80');
    expect(quickSizing(context: data, fee: '0').quantity(true, 100), Decimal.parse('0.01'));
    expect(quickSizing(context: data).quantity(true, 100), Decimal.parse('0.009'));
  });
  test('risk cap, existing exposure and remaining orders limit reference budget', () {
    final data = liveContext(bid: '79999', ask: '80001', available: '1000');
    final order = AsterOpenOrder(
      symbol: 'BTCUSDT',
      orderId: '1',
      side: 'BUY',
      positionSide: 'BOTH',
      type: 'LIMIT',
      status: 'PARTIALLY_FILLED',
      time: liveOrderClock,
      origQty: Decimal.parse('0.003'),
      executedQty: Decimal.parse('0.001'),
      price: Decimal.parse('80000'),
    );
    expect(quickSizing(context: data, cap: '400').quantity(true, 100), Decimal.parse('0.004'));
    expect(
      quickSizing(context: data, cap: '400', orders: [order]).quantity(true, 100),
      Decimal.parse('0.002'),
    );
    expect(
      quickSizing(context: data, cap: '400', orders: [order]).quantity(false, 100),
      Decimal.parse('0.005'),
    );
    final long = liveContext(
      bid: '80000',
      ask: '80000',
      available: '1000',
      positions: {
        'BOTH': LiveOrderPosition(
          side: 'BOTH',
          quantity: Decimal.parse('0.003'),
          entryPrice: Decimal.parse('79000'),
        ),
      },
    );
    expect(quickSizing(context: long, cap: '400').quantity(true, 100), Decimal.parse('0.002'));
    expect(quickSizing(context: long, cap: '400').quantity(false, 100), Decimal.parse('0.008'));
    expect(quickSizing(context: long, cap: '100').quantity(true, 100), Decimal.zero);
    final reduction = AsterOpenOrder(
      symbol: 'BTCUSDT',
      orderId: '2',
      side: 'SELL',
      positionSide: 'BOTH',
      type: 'LIMIT',
      status: 'NEW',
      time: liveOrderClock,
      origQty: Decimal.parse('0.002'),
      executedQty: Decimal.zero,
      price: Decimal.parse('80000'),
      reduceOnly: true,
    );
    expect(
      quickSizing(context: long, cap: '400', orders: [reduction]).quantity(false, 100),
      Decimal.parse('0.006'),
    );
    final entire = AsterOpenOrder(
      symbol: 'BTCUSDT',
      orderId: '3',
      side: 'SELL',
      positionSide: 'BOTH',
      type: 'STOP_MARKET',
      status: 'NEW',
      time: liveOrderClock,
      origQty: Decimal.zero,
      executedQty: Decimal.zero,
      price: Decimal.zero,
      closePosition: true,
    );
    expect(
      quickSizing(context: long, cap: '400', orders: [entire]).quantity(false, 100),
      Decimal.parse('0.005'),
    );
  });
  test(
    'market max and minimum/step apply after percentage; zero is not min-quantity inflation',
    () {
      final large = liveContext(bid: '80000', ask: '80000', available: '1000000000');
      expect(
        quickSizing(context: large, cap: '1000000000').quantity(true, 100),
        Decimal.fromInt(120),
      );
      expect(
        quickSizing(context: large, cap: '1000000000').quantity(true, 25),
        Decimal.fromInt(30),
      );
      final tiny = liveContext(bid: '80000', ask: '80000', available: '0.000000001');
      expect(quickSizing(context: tiny).quantity(true, 100), Decimal.zero);
      expect(quickSizing().quantity(true, 0), null);
      expect(quickSizing().quantity(true, 101), null);
      expect(quickSizing(context: liveContext()).quantity(true, 100), null);
      expect(
        quickSizing(
          context: liveContext(bid: '80000', ask: '80000', available: null),
        ).quantity(true, 100),
        null,
      );
    },
  );
  test('brackets must support current leverage; hedge exposure and direction remain separate', () {
    final data = liveCloseContext(hedge: true);
    expect(quickSizing(context: data, cap: '800').quantity(true, 100), Decimal.zero);
    final unsupported = QuickOrderSizing(
      context: data,
      takerFee: Decimal.zero,
      brackets: [LeverageBracket(maximum: 5, floor: Decimal.zero, cap: Decimal.fromInt(100000))],
      orders: quickSizing(context: data).orders,
    );
    expect(unsupported.quantity(true, 100), null);
  });
  for (final hedge in [false, true]) {
    for (final buy in [false, true]) {
      test('quick entry has fixed MARKET/open shape and exact flags $hedge $buy', () {
        final context = liveContext(
          mode: hedge ? FuturesPositionMode.hedge : FuturesPositionMode.oneWay,
        );
        final draft = liveDraft(market: true, buy: buy, price: '', quickEntry: true);
        final intent = LiveOrderIntent(
          context: context,
          draft: draft,
          clientOrderId: 'vanta-quick-1',
          revision: 0,
        );
        expect(context.validate(draft), null);
        expect(intent.parameters['type'], 'MARKET');
        expect(intent.parameters['reduceOnly'], hedge ? null : 'false');
        expect(intent.positionSide, hedge ? (buy ? 'LONG' : 'SHORT') : 'BOTH');
        for (final key in ['price', 'stopPrice', 'timeInForce', 'callbackRate', 'closePosition']) {
          expect(intent.parameters.containsKey(key), false);
        }
        expect(mapLiveOrderQuery(liveQueryPayload(intent), intent).status, 'NEW');
        expect(
          () => mapLiveOrderQuery({...liveQueryPayload(intent), 'reduceOnly': true}, intent),
          throwsFormatException,
        );
        expect(
          () => mapLiveOrderQuery({...liveQueryPayload(intent), 'closePosition': true}, intent),
          throwsFormatException,
        );
      });
    }
  }
  test('quick shape cannot inherit price, reduction or conditional state', () {
    for (final invalid in [
      liveDraft(quickEntry: true),
      liveDraft(market: true, price: '1', quickEntry: true),
      liveDraft(market: true, price: '', reduceOnly: true, quickEntry: true),
      liveDraft(market: true, price: '', closingSide: 'BOTH', quickEntry: true),
      liveDraft(
        market: true,
        price: '',
        quickEntry: true,
        trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '81000'),
      ),
      liveDraft(
        market: true,
        price: '',
        quickEntry: true,
        trailing: const LiveOrderTrailing(callbackRate: '1'),
      ),
    ]) {
      expect(liveContext().validate(invalid), 'quickOrderInvalid');
    }
  });
}
