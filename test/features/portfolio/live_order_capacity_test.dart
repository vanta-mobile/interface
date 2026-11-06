import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/live_order_capacity.dart';
import 'package:vanta/features/portfolio/domain/live_order_rules.dart';

import '../../support/live_order_capacity.dart';

void main() {
  test('normalized repeating margin remains exact at a quantity step boundary', () {
    final source = orderCapacity(exposure: openingExposure(mark: '1', leverage: 3));
    final capacity = LiveOrderCapacity(
      exposure: source.exposure,
      availableMargin: Decimal.one / Decimal.fromInt(3),
      notionalCap: source.notionalCap,
      remainingOpenableNotional: null,
      rule: source.rule,
      minimumNotional: Decimal.zero,
    );
    expect(capacitySide(capacity, margin: '1').maximum, Decimal.one);
    expect(capacitySide(capacity, margin: '1').quantityAt(100), Decimal.one);
  });
  test('same account produces separate directional maxima including opening loss', () {
    final data = orderCapacity();
    final buy = capacitySide(data, margin: '110');
    final sell = capacitySide(data, buy: false, margin: '90');
    expect(buy.maximum, Decimal.parse('4.761'));
    expect(sell.maximum, Decimal.parse('5.263'));
    expect(buy.maximumQuote, Decimal.parse('523.71'));
    expect(sell.maximumQuote, Decimal.parse('473.67'));
    expect(buy.quantityAt(20), Decimal.parse('0.952'));
    expect(sell.quantityAt(20), Decimal.parse('1.052'));
  });
  test('one-way position and pending orders change each directional maximum', () {
    final data = orderCapacity(
      exposure: openingExposure(position: '5', bids: '200'),
    );
    expect(capacitySide(data).maximum, Decimal.fromInt(10));
    expect(capacitySide(data, buy: false).maximum, Decimal.fromInt(22));
    final reverse = orderCapacity(
      exposure: openingExposure(position: '-5', asks: '200'),
    );
    expect(capacitySide(reverse).maximum, Decimal.fromInt(22));
    expect(capacitySide(reverse, buy: false).maximum, Decimal.fromInt(10));
  });
  test('personal leverage cap and contract remaining cap constrain different quantities', () {
    final data = orderCapacity(
      exposure: openingExposure(position: '5'),
      cap: '800',
    );
    expect(capacitySide(data).maximum, Decimal.fromInt(3));
    expect(capacitySide(data, buy: false).maximum, Decimal.fromInt(13));
    final limited = orderCapacity(
      exposure: openingExposure(position: '5'),
      cap: '800',
      remaining: '300',
    );
    expect(capacitySide(limited).maximum, Decimal.fromInt(3));
    expect(capacitySide(limited, buy: false).maximum, Decimal.fromInt(8));
  });
  test('no contract capacity still permits an existing opposite closing leg', () {
    final data = orderCapacity(
      exposure: openingExposure(position: '5'),
      remaining: '0',
    );
    expect(capacitySide(data).maximum, Decimal.zero);
    expect(capacitySide(data, buy: false).maximum, Decimal.fromInt(5));
  });
  test('lowered personal cap never permits exposure above its existing excess', () {
    final data = orderCapacity(
      exposure: openingExposure(position: '5'),
      cap: '200',
    );
    expect(capacitySide(data).maximum, Decimal.zero);
    expect(capacitySide(data, buy: false).maximum, Decimal.fromInt(10));
  });
  for (final available in ['0', '-10']) {
    test('known nonpositive free margin preserves zero-cost reductions $available', () {
      expect(capacitySide(orderCapacity(available: available)).maximum, Decimal.zero);
      final data = orderCapacity(
        exposure: openingExposure(position: '5'),
        available: available,
      );
      expect(capacitySide(data).maximum, Decimal.zero);
      expect(capacitySide(data, buy: false).maximum, Decimal.fromInt(10));
    });
  }
  for (final buy in [true, false]) {
    test('hedge uses shared gross risk and no opposite-position credit $buy', () {
      final data = orderCapacity(
        exposure: openingExposure(hedgeGross: '500'),
        cap: '800',
      );
      expect(capacitySide(data, buy: buy).maximum, Decimal.fromInt(3));
      final limited = orderCapacity(
        exposure: openingExposure(hedgeGross: '500'),
        remaining: '100',
      );
      expect(capacitySide(limited, buy: buy).maximum, Decimal.one);
    });
  }
  test('conversion price does not change base capacity or margin cost', () {
    final data = orderCapacity();
    final first = capacitySide(data, conversion: '90');
    final second = capacitySide(data, conversion: '110');
    expect(first.maximum, Decimal.fromInt(10));
    expect(second.maximum, first.maximum);
    expect(first.maximumQuote, Decimal.fromInt(900));
    expect(second.maximumQuote, Decimal.fromInt(1100));
  });
  test('quantity maximum is floored to a nonzero minimum-offset lattice', () {
    final data = orderCapacity(
      exposure: openingExposure(mark: '3'),
      available: '0.1',
      minimum: '0.003',
      step: '0.01',
      maximum: '0.5',
    );
    final side = capacitySide(data, margin: '3');
    expect(side.maximum, Decimal.parse('0.333'));
    expect(side.quantityAt(50), Decimal.parse('0.163'));
    expect(side.quantityAt(1), Decimal.parse('0.003'));
    expect(side.quantityAt(0), Decimal.zero);
    expect(data.rule.accepts(side.maximum), true);
  });
  test('maximum filter clips before ratio without inflating tiny allocations', () {
    final side = capacitySide(orderCapacity(maximum: '0.003'));
    expect(side.maximum, Decimal.parse('0.003'));
    expect(side.quantityAt(1), Decimal.zero);
    expect(side.quantityAt(25), Decimal.zero);
    expect(side.quantityAt(100), side.maximum);
  });
  test('maximum below minimum notional is known zero; small ratios remain for validation', () {
    final data = orderCapacity(available: '1', minimumNotional: '20');
    expect(capacitySide(data).maximum, Decimal.zero);
    final valid = capacitySide(orderCapacity(available: '2', minimumNotional: '20'));
    expect(valid.maximum, Decimal.parse('0.2'));
    expect(valid.quantityAt(25), Decimal.parse('0.05'));
  });
  test('minimum notional uses its explicit price, not quote display conversion', () {
    final data = orderCapacity(available: '1', minimumNotional: '10');
    expect(capacitySide(data, conversion: '50', notional: '100').maximum, Decimal.parse('0.1'));
    expect(capacitySide(data, conversion: '1000', notional: '50').maximum, Decimal.zero);
  });
  test('exact repeating leverage ratio preserves a one-step budget boundary', () {
    final exposure = openingExposure(mark: '1', leverage: 3);
    final below = orderCapacity(exposure: exposure, available: '0.333333333333333333333333333333');
    final above = orderCapacity(exposure: exposure, available: '0.333333333333333333333333333334');
    expect(capacitySide(below, margin: '1').maximum, Decimal.parse('0.999'));
    expect(capacitySide(above, margin: '1').maximum, Decimal.one);
  });
  test('BigInt search preserves lattice indices above IEEE754 exact integer range', () {
    const quantity = '9007199254740993.000000000000000001';
    final data = orderCapacity(
      exposure: openingExposure(mark: '1', leverage: 1),
      available: quantity,
      cap: '1000000000000000000',
      maximum: '1000000000000000000',
      minimum: '0.000000000000000001',
      step: '0.000000000000000001',
    );
    expect(capacitySide(data, margin: '1').maximum, Decimal.parse(quantity));
  });
  test('PRD 20 percent uses independent displayed maxima without synthetic account claims', () {
    final rule = OrderQuantityRule(
      minimum: Decimal.parse('0.00001'),
      maximum: Decimal.fromInt(1000),
      step: Decimal.parse('0.00001'),
    );
    for (final (buy, maximum, expected) in [
      (true, '539.1600', '107.83200'),
      (false, '574.1346', '114.82692'),
    ]) {
      final side = LiveOrderSideCapacity(
        buy: buy,
        maximum: Decimal.parse(maximum),
        conversionPrice: Decimal.one,
        rule: rule,
      );
      expect(side.quantityAt(20), Decimal.parse(expected));
    }
  });
  test('every integer percentage floors exact base quantity and stays within its side', () {
    final side = capacitySide(
      orderCapacity(
        exposure: openingExposure(position: '-3'),
        available: '37',
      ),
    );
    var previous = Decimal.zero;
    for (var percent = 0; percent <= 100; percent++) {
      final quantity = side.quantityAt(percent);
      expect(quantity >= previous && quantity <= side.maximum, true);
      expect(quantity == Decimal.zero || side.rule.accepts(quantity), true);
      expect(
        quantity.toRational() <=
            side.maximum.toRational() *
                Decimal.fromInt(percent).toRational() /
                Decimal.fromInt(100).toRational(),
        true,
      );
      previous = quantity;
    }
    expect(side.quantityAt(100), side.maximum);
    expect(() => side.quantityAt(-1), throwsArgumentError);
    expect(() => side.quantityAt(101), throwsArgumentError);
  });
  test('maximum is feasible and next step fails across directional occupancy regimes', () {
    for (final position in ['-5', '0', '5']) {
      for (final pending in ['0', '300']) {
        for (final buy in [true, false]) {
          for (final price in ['90', '100', '110']) {
            final data = orderCapacity(
              exposure: openingExposure(position: position, bids: pending, asks: pending),
              available: '27',
              cap: '1000',
              remaining: '700',
            );
            final maximum = capacitySide(data, buy: buy, margin: price).maximum;
            bool feasible(Decimal quantity) {
              final cost = data.exposure.cost(
                buy: buy,
                quantity: quantity,
                marginPrice: Decimal.parse(price),
                lossPrice: Decimal.parse(price),
              );
              return cost.total <= Decimal.fromInt(27).toRational() &&
                  cost.reservedNotionalAfter <= Decimal.fromInt(1000) &&
                  cost.openingQuantity * Decimal.parse(price) <= Decimal.fromInt(700);
            }

            expect(feasible(maximum), true, reason: '$position $pending $buy $price');
            expect(
              feasible(maximum + data.rule.step),
              false,
              reason: '$position $pending $buy $price',
            );
          }
        }
      }
    }
  });
  for (final invalid in [
    () => orderCapacity(cap: '0'),
    () => orderCapacity(remaining: '-1'),
    () => orderCapacity(minimum: '0'),
    () => orderCapacity(step: '0'),
    () => orderCapacity(maximum: '0.0001'),
    () => orderCapacity(minimumNotional: '-1'),
  ]) {
    test(
      'invalid capacity fails explicitly ${invalid.hashCode}',
      () => expect(invalid, throwsArgumentError),
    );
  }
  for (final field in ['margin', 'loss', 'conversion', 'notional']) {
    test('nonpositive $field never yields a misleading zero capacity', () {
      expect(
        () => capacitySide(
          orderCapacity(),
          margin: field == 'margin' ? '0' : '100',
          loss: field == 'loss' ? '0' : '100',
          conversion: field == 'conversion' ? '0' : '100',
          notional: field == 'notional' ? '0' : '100',
        ),
        throwsArgumentError,
      );
    });
  }
}
