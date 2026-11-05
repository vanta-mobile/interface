import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/scaled_order.dart';

import '../../support/live_order.dart';
import '../../support/scaled_order.dart';

void main() {
  Matcher failure(String key) =>
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', key));
  for (final buy in [true, false]) {
    for (var count = 2; count <= 5; count++) {
      test('exact endpoints, distinct ticks and conserved quantity: buy=$buy count=$count', () {
        final plan = planScaledOrder(
          liveContext(),
          scaledDraft(buy: buy, count: count, low: '79000.1', high: '79001.1', quantity: '0.017'),
        );
        expect(plan.orders.length, count);
        expect(plan.orders.first.price, '79000.1');
        expect(plan.orders.last.price, '79001.1');
        expect(plan.orders.map((o) => o.price).toSet().length, count);
        expect(plan.totalQuantity, Decimal.parse('0.017'));
        expect(
          plan.orders.every(
            (o) =>
                o.buy == buy &&
                !o.market &&
                !o.reducing &&
                o.timeInForce == LiveOrderTimeInForce.gtc,
          ),
          true,
        );
        for (var i = 1; i < count; i++) {
          expect(
            parseOrderDecimal(plan.orders[i].price)! > parseOrderDecimal(plan.orders[i - 1].price)!,
            true,
          );
          expect(
            parseOrderDecimal(plan.orders[i].quantity)! <=
                parseOrderDecimal(plan.orders[i - 1].quantity)!,
            true,
          );
        }
      });
    }
  }
  test('exact public preview example uses low-price remainder and limit notional', () {
    final plan = planScaledOrder(
      liveContext(),
      scaledDraft(low: '79000', high: '79001', quantity: '0.008', count: 4),
    );
    expect(plan.orders.map((o) => o.price), ['79000', '79000.3', '79000.6', '79001']);
    expect(plan.orders.map((o) => o.quantity), ['0.002', '0.002', '0.002', '0.002']);
    expect(plan.notional, Decimal.parse('632.0038'));
    final remainder = planScaledOrder(liveContext(), scaledDraft());
    expect(remainder.orders.map((o) => o.quantity), ['0.003', '0.003', '0.002']);
    expect(() => remainder.orders.clear(), throwsUnsupportedError);
  });
  for (final count in [0, 1, 111, 100000]) {
    test(
      'unsupported child count $count rejected',
      () => expect(
        () => planScaledOrder(liveContext(), scaledDraft(count: count)),
        failure('scaledCountInvalid'),
      ),
    );
  }
  for (final range in [
    ('0', '80000'),
    ('-1', '80000'),
    ('80000', '80000'),
    ('81000', '79000'),
    ('NaN', '80000'),
    ('1e2', '80000'),
  ]) {
    test(
      'invalid range $range rejected',
      () => expect(
        () => planScaledOrder(liveContext(), scaledDraft(low: range.$1, high: range.$2)),
        failure('scaledRangeInvalid'),
      ),
    );
  }
  test('off-grid endpoints and too few ticks cannot silently change the range', () {
    expect(
      () => planScaledOrder(liveContext(), scaledDraft(low: '79000.01')),
      failure('liveOrderPriceFilter'),
    );
    expect(
      () => planScaledOrder(liveContext(), scaledDraft(low: '79000', high: '79000.1')),
      failure('scaledRangeTooNarrow'),
    );
  });
  test('invalid, insufficient and off-step totals never silently lose quantity', () {
    expect(
      () => planScaledOrder(liveContext(), scaledDraft(quantity: '-1')),
      failure('liveOrderInvalidQuantity'),
    );
    expect(
      () => planScaledOrder(liveContext(), scaledDraft(quantity: '0.002')),
      failure('scaledQuantityTooSmall'),
    );
    expect(
      () => planScaledOrder(liveContext(), scaledDraft(quantity: '0.0081')),
      failure('scaledQuantityStep'),
    );
  });
  test('per-child maximum, percent and notional rules apply', () {
    expect(
      () => planScaledOrder(liveContext(), scaledDraft(quantity: '3001')),
      failure('liveOrderQuantityFilter'),
    );
    expect(
      () => planScaledOrder(liveContext(), scaledDraft(high: '82000')),
      failure('liveOrderPercentFilter'),
    );
    expect(
      () => planScaledOrder(liveContext(), scaledDraft(low: '1', high: '2', quantity: '0.003')),
      failure('liveOrderNotionalFilter'),
    );
  });
  test('fresh funds, trade eligibility and GTC/LIMIT capability are required', () {
    expect(
      () => planScaledOrder(liveContext(withFunds: false), scaledDraft()),
      failure('liveOrderReadFunds'),
    );
    expect(
      () => planScaledOrder(liveContext(canTrade: false), scaledDraft()),
      failure('liveOrderTradingDisabled'),
    );
    expect(
      () => planScaledOrder(liveContext(policies: {LiveOrderTimeInForce.ioc}), scaledDraft()),
      failure('liveOrderTimeInForceUnavailable'),
    );
    expect(
      () => planScaledOrder(scaledContext(rules: scaledRules(types: {'MARKET'})), scaledDraft()),
      failure('liveOrderTypeUnavailable'),
    );
  });
  ScaledOrderIntent intent({List<String>? ids, ScaledOrderPlan? plan}) => ScaledOrderIntent(
    context: liveContext(),
    plan: plan ?? planScaledOrder(liveContext(), scaledDraft()),
    clientIds: ids ?? ['vs-1', 'vs-2', 'vs-3'],
    revision: 0,
    epoch: 0,
  );
  test('confirmation rejects duplicate, missing and invalid IDs and freezes collections', () {
    expect(intent().valid, true);
    for (final ids in [
      ['vs-1'],
      ['a', 'a', 'b'],
      ['a', 'b', 'invalid space'],
      ['a', 'b', 'x' * 37],
    ]) {
      expect(intent(ids: ids).valid, false);
    }
    expect(() => intent().clientIds.clear(), throwsUnsupportedError);
  });
  test('tampered confirmed child quantity, direction, strategy and policy are rejected', () {
    final plan = planScaledOrder(liveContext(), scaledDraft());
    for (final child in [
      liveDraft(quantity: '0.004', price: '79000'),
      liveDraft(buy: false, quantity: '0.003', price: '79000'),
      liveDraft(quantity: '0.003', price: '79000', reduceOnly: true),
      liveDraft(quantity: '0.003', price: '79000', timeInForce: LiveOrderTimeInForce.ioc),
    ]) {
      expect(
        intent(
          plan: ScaledOrderPlan(draft: plan.draft, orders: [child, ...plan.orders.skip(1)]),
        ).valid,
        false,
      );
    }
  });
  test('offset quantity minimum and price ticks preserve exact totals', () {
    final data = scaledContext(
      rules: scaledRules(
        minimumPrice: '0.05',
        tick: '0.1',
        lot: OrderQuantityRule(
          minimum: Decimal.parse('0.0025'),
          maximum: Decimal.one,
          step: Decimal.parse('0.001'),
        ),
      ),
    );
    final plan = planScaledOrder(
      data,
      scaledDraft(low: '79000.05', high: '79000.35', quantity: '0.0085'),
    );
    expect(plan.orders.map((o) => o.price), ['79000.05', '79000.15', '79000.35']);
    expect(plan.orders.map((o) => o.quantity), ['0.0035', '0.0025', '0.0025']);
    expect(plan.totalQuantity, Decimal.parse('0.0085'));
    expect(
      () =>
          planScaledOrder(data, scaledDraft(low: '79000.05', high: '79000.35', quantity: '0.008')),
      failure('scaledQuantityStep'),
    );
  });
  test('tiny totals retain all digits with no floating-point conversion', () {
    final lot = OrderQuantityRule(
      minimum: Decimal.parse('0.000000000000000001'),
      maximum: Decimal.one,
      step: Decimal.parse('0.000000000000000001'),
    );
    final x = scaledRules(lot: lot);
    final rules = LiveOrderRules(
      symbol: x.symbol,
      baseAsset: x.baseAsset,
      quoteAsset: x.quoteAsset,
      priceMinimum: x.priceMinimum,
      priceMaximum: x.priceMaximum,
      priceTick: x.priceTick,
      limitQuantity: lot,
      marketQuantity: lot,
      minimumNotional: Decimal.zero,
      percentUp: x.percentUp,
      percentDown: x.percentDown,
      timeInForce: x.timeInForce,
      orderTypes: x.orderTypes,
    );
    final plan = planScaledOrder(
      scaledContext(rules: rules),
      scaledDraft(quantity: '0.000000000000000008'),
    );
    expect(plan.orders.map((o) => o.quantity), [
      '0.000000000000000003',
      '0.000000000000000003',
      '0.000000000000000002',
    ]);
    expect(plan.totalQuantity, Decimal.parse('0.000000000000000008'));
  });
}
