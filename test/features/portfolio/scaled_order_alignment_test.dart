import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/scaled_order.dart';

import '../../support/live_order.dart';
import '../../support/scaled_order.dart';

void main() {
  Matcher failure(String key) =>
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', key));
  LiveOrderContext data({String step = '0.001', String minimum = '0.001', int leverage = 10}) =>
      scaledContext(
        leverage: leverage,
        available: '999999999999999999999999999999999999999999999999',
        rules: scaledRules(
          lot: OrderQuantityRule(
            minimum: Decimal.parse(minimum),
            maximum: Decimal.parse('1000'),
            step: Decimal.parse(step),
          ),
        ),
      );

  for (final buy in [true, false]) {
    for (final unit in ScaledSizeUnit.values) {
      for (final pattern in [
        (ScaledDistribution.equal, ScaledConstant.difference, ['0.004', '0.004', '0.004']),
        (ScaledDistribution.increasing, ScaledConstant.difference, ['0.002', '0.004', '0.006']),
        (ScaledDistribution.decreasing, ScaledConstant.difference, ['0.006', '0.004', '0.002']),
        (ScaledDistribution.increasing, ScaledConstant.ratio, ['0.002', '0.004', '0.008']),
        (ScaledDistribution.decreasing, ScaledConstant.ratio, ['0.008', '0.004', '0.002']),
      ]) {
        test(
          'exact public weights, price-weighted quote conversion: $buy $unit ${pattern.$1} ${pattern.$2}',
          () {
            final quantities = pattern.$3.map(Decimal.parse).toList();
            final total = quantities.fold(Decimal.zero, (a, b) => a + b);
            final notional = List.generate(
              3,
              (i) => quantities[i] * Decimal.fromInt(79000 + i * 1000),
            ).fold(Decimal.zero, (a, b) => a + b);
            final plan = planScaledOrder(
              data(),
              scaledDraft(
                buy: buy,
                unit: unit,
                distribution: pattern.$1,
                constant: pattern.$2,
                quantity: '${unit == ScaledSizeUnit.base ? total : notional}',
              ),
            );
            expect(plan.orders.map((o) => o.quantity), pattern.$3);
            expect(plan.orders.map((o) => o.price), ['79000', '80000', '81000']);
            expect(plan.orders.every((o) => o.buy == buy), true);
            expect(plan.totalQuantity, total);
            expect(plan.notional, notional);
            expect(plan.unallocatedQuote, unit == ScaledSizeUnit.quote ? Decimal.zero : null);
          },
        );
      }
    }
  }
  for (final unit in ScaledSizeUnit.values) {
    test('110 distinct children, immutable exact totals and independently bounded IDs: $unit', () {
      final context = data();
      final plan = planScaledOrder(
        context,
        scaledDraft(
          count: 110,
          quantity: unit == ScaledSizeUnit.base ? '0.22' : '17600',
          unit: unit,
        ),
      );
      expect(plan.orders.length, 110);
      expect(plan.orders.map((o) => o.price).toSet().length, 110);
      expect(plan.orders.first.price, '79000');
      expect(plan.orders.last.price, '81000');
      if (unit == ScaledSizeUnit.base) expect(plan.totalQuantity, Decimal.parse('0.22'));
      if (unit == ScaledSizeUnit.quote) {
        expect(plan.notional <= Decimal.fromInt(17600), true);
        expect(plan.unallocatedQuote, Decimal.fromInt(17600) - plan.notional);
      }
      expect(
        ScaledOrderIntent(
          context: context,
          plan: plan,
          clientIds: List.generate(110, (i) => 'vs-test-${i + 1}'),
          revision: 0,
          epoch: 0,
        ).valid,
        true,
      );
      expect(() => plan.orders.clear(), throwsUnsupportedError);
    });
  }
  test('quote remainder is exact; no rounding up or leverage multiplication', () {
    final draft = scaledDraft(unit: ScaledSizeUnit.quote, quantity: '1000.000000000000000001');
    final plan = planScaledOrder(data(), draft);
    expect(plan.orders.map((o) => o.quantity), ['0.004', '0.004', '0.004']);
    expect(plan.notional, Decimal.parse('960'));
    expect(plan.unallocatedQuote, Decimal.parse('40.000000000000000001'));
    final changedLeverage = planScaledOrder(data(leverage: 50), draft);
    expect(changedLeverage.totalQuantity, plan.totalQuantity);
    expect(changedLeverage.notional, plan.notional);
  });
  test('base largest remainders conserve total and monotonic weights after rounding', () {
    for (final distribution in [ScaledDistribution.increasing, ScaledDistribution.decreasing]) {
      final plan = planScaledOrder(
        data(),
        scaledDraft(quantity: '0.011', distribution: distribution),
      );
      expect(plan.totalQuantity, Decimal.parse('0.011'));
      expect(
        plan.orders.map((o) => o.quantity),
        distribution == ScaledDistribution.increasing
            ? ['0.002', '0.004', '0.005']
            : ['0.005', '0.004', '0.002'],
      );
    }
  });
  for (final unit in ScaledSizeUnit.values) {
    test('offset LOT minimum is respected without exceeding input: $unit', () {
      final context = data(minimum: '0.0025', step: '0.001');
      final plan = planScaledOrder(
        context,
        scaledDraft(unit: unit, quantity: unit == ScaledSizeUnit.base ? '0.0085' : '700'),
      );
      for (final order in plan.orders) {
        expect(context.rules.limitQuantity.accepts(Decimal.parse(order.quantity)), true);
      }
      if (unit == ScaledSizeUnit.base) expect(plan.totalQuantity, Decimal.parse('0.0085'));
      if (unit == ScaledSizeUnit.quote) {
        expect(plan.orders.map((o) => o.quantity), ['0.0025', '0.0025', '0.0025']);
        expect(plan.unallocatedQuote, Decimal.fromInt(100));
      }
    });
  }
  for (final size in ['', '0', '-1', 'NaN', '1e3', ' ']) {
    test('invalid quote size $size never falls back to base or a default', () {
      expect(
        () => planScaledOrder(data(), scaledDraft(unit: ScaledSizeUnit.quote, quantity: size)),
        failure('scaledAmountInvalid'),
      );
    });
  }
  test('quote budget below per-child minimum rejects rather than inflates budget', () {
    expect(
      () => planScaledOrder(data(), scaledDraft(unit: ScaledSizeUnit.quote, quantity: '239.99')),
      failure('scaledQuantityTooSmall'),
    );
    expect(
      () => planScaledOrder(
        data(),
        scaledDraft(
          unit: ScaledSizeUnit.quote,
          quantity: '240',
          distribution: ScaledDistribution.increasing,
        ),
      ),
      failure('scaledQuantityTooSmall'),
    );
  });
  test('large ratio counts cannot silently clamp small quantities or overflow', () {
    expect(
      () => planScaledOrder(
        data(),
        scaledDraft(
          count: 110,
          quantity: '1',
          distribution: ScaledDistribution.increasing,
          constant: ScaledConstant.ratio,
        ),
      ),
      failure('scaledQuantityTooSmall'),
    );
    expect(
      () => planScaledOrder(
        data(),
        scaledDraft(
          count: 110,
          quantity: '99999999999999999999999999999999999999999',
          distribution: ScaledDistribution.increasing,
          constant: ScaledConstant.ratio,
        ),
      ),
      failure('liveOrderQuantityFilter'),
    );
  });
  for (final variance in ['', '-1', '10.000000000000000001', 'NaN', '1e1']) {
    test('invalid random variance $variance is rejected', () {
      expect(
        () => planScaledOrder(
          data(),
          scaledDraft(
            quantity: '0.03',
            distribution: ScaledDistribution.random,
            variance: variance,
            seed: 42,
          ),
        ),
        failure('scaledVarianceInvalid'),
      );
    });
  }
  for (final seed in [null, -1, 0x100000000]) {
    test('missing or invalid seed $seed never triggers hidden random resampling', () {
      expect(
        () => planScaledOrder(
          data(),
          scaledDraft(quantity: '0.03', distribution: ScaledDistribution.random, seed: seed),
        ),
        failure('scaledRandomRequired'),
      );
    });
  }
  for (final unit in ScaledSizeUnit.values) {
    for (final count in [2, 3, 110]) {
      test('frozen random weights, actual variance bounded, count=$count unit=$unit', () {
        final context = data(minimum: '0.000000001', step: '0.000000001');
        final draft = scaledDraft(
          count: count,
          quantity: unit == ScaledSizeUnit.base
              ? '${Decimal.fromInt(count) * Decimal.parse('0.001')}'
              : '${80 * count}',
          distribution: ScaledDistribution.random,
          seed: 42,
          variance: '10',
          unit: unit,
        );
        final plan = planScaledOrder(context, draft);
        final again = planScaledOrder(context, draft);
        expect(again.orders.map((o) => o.quantity), plan.orders.map((o) => o.quantity));
        expect(plan.orders.map((o) => o.quantity).toSet().length, greaterThan(1));
        final total = plan.totalQuantity;
        for (final order in plan.orders) {
          final deviation = (Decimal.parse(order.quantity) * Decimal.fromInt(count) - total).abs();
          expect(deviation * Decimal.fromInt(100) <= total * Decimal.fromInt(10), true);
        }
        if (unit == ScaledSizeUnit.base) expect(total, Decimal.parse(draft.quantity));
        if (unit == ScaledSizeUnit.quote) {
          expect(plan.notional <= Decimal.parse(draft.quantity), true);
        }
        final intent = ScaledOrderIntent(
          context: context,
          plan: plan,
          clientIds: List.generate(count, (i) => 'vs-random-$i'),
          revision: 0,
          epoch: 0,
        );
        expect(intent.valid, true);
        expect(intent.valid, true); // validation must not regenerate randomness
      });
    }
  }
  test('zero random variance is equal and reproducible', () {
    final plan = planScaledOrder(
      data(),
      scaledDraft(
        quantity: '0.03',
        variance: '0',
        distribution: ScaledDistribution.random,
        seed: 0,
      ),
    );
    expect(plan.orders.map((o) => o.quantity), ['0.01', '0.01', '0.01']);
  });
  test('random rounding outside requested variance is rejected explicitly', () {
    expect(
      () => planScaledOrder(
        data(),
        scaledDraft(
          quantity: '0.008',
          variance: '10',
          distribution: ScaledDistribution.random,
          seed: 42,
        ),
      ),
      failure('scaledVarianceStep'),
    );
  });
  test('quote precision below floating point is preserved for all distributions', () {
    for (final distribution in ScaledDistribution.values) {
      final plan = planScaledOrder(
        data(minimum: '0.000000000000000001', step: '0.000000000000000001'),
        scaledDraft(
          unit: ScaledSizeUnit.quote,
          quantity: '1000.000000000000000001',
          distribution: distribution,
          seed: 42,
        ),
      );
      expect(plan.notional <= Decimal.parse('1000.000000000000000001'), true);
      expect(plan.notional + plan.unallocatedQuote!, Decimal.parse('1000.000000000000000001'));
    }
  });
  test('tampered peg is rejected even if fixed quantity and price match plan', () {
    final context = data(), draft = scaledDraft();
    final plan = planScaledOrder(context, draft),
        first = planScaledOrder(context, draft).orders.first;
    final tampered = ScaledOrderPlan(
      draft: draft,
      orders: [
        liveDraft(quantity: first.quantity, price: first.price, peg: LiveOrderPeg.counterparty),
        ...plan.orders.skip(1),
      ],
    );
    expect(
      ScaledOrderIntent(
        context: context,
        plan: tampered,
        clientIds: ['a', 'b', 'c'],
        revision: 0,
        epoch: 0,
      ).valid,
      false,
    );
  });
}
