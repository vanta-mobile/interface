import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/live_order_opening_cost.dart';

import '../../support/live_order_capacity.dart';

void main() {
  test('fresh signed notional is retained instead of rebuilding it from an older mark', () {
    final exposure = LiveOrderOpeningExposure.oneWay(
      markPrice: Decimal.fromInt(100),
      leverage: 10,
      positionQuantity: Decimal.fromInt(2),
      positionNotional: Decimal.fromInt(202),
      buyOrderNotional: Decimal.zero,
      sellOrderNotional: Decimal.zero,
    );
    expect(exposure.signedNotional, Decimal.fromInt(202));
    final cost = exposure.cost(
      buy: false,
      quantity: Decimal.fromInt(5),
      marginPrice: Decimal.fromInt(100),
      lossPrice: Decimal.fromInt(100),
    );
    expect(cost.reservedNotionalAfter, Decimal.fromInt(298));
    expect(cost.initialMargin, Decimal.parse('9.6').toRational());
    expect(cost.openingQuantity, Decimal.fromInt(3));
  });
  for (final (quantity, notional) in [
    ('0', '1'),
    ('0', '-1'),
    ('1', '0'),
    ('-1', '0'),
    ('1', '-1'),
    ('-1', '1'),
  ]) {
    test('rejects conflicting signed quantity/notional $quantity $notional', () {
      expect(
        () => LiveOrderOpeningExposure.oneWay(
          markPrice: Decimal.fromInt(100),
          leverage: 10,
          positionQuantity: Decimal.parse(quantity),
          positionNotional: Decimal.parse(notional),
          buyOrderNotional: Decimal.zero,
          sellOrderNotional: Decimal.zero,
        ),
        throwsArgumentError,
      );
    });
  }
  for (final (buy, price, margin, loss) in [
    (true, '110', '22', '20'),
    (false, '110', '22', '0'),
    (true, '90', '18', '0'),
    (false, '90', '18', '20'),
    (true, '100', '20', '0'),
    (false, '100', '20', '0'),
  ]) {
    test('flat account official linear cost $buy $price', () {
      final result = openingExposure().cost(
        buy: buy,
        quantity: Decimal.fromInt(2),
        marginPrice: Decimal.parse(price),
        lossPrice: Decimal.parse(price),
      );
      expect(result.initialMargin, Decimal.parse(margin).toRational());
      expect(result.openingLoss, Decimal.parse(loss));
      expect(result.total, (Decimal.parse(margin) + Decimal.parse(loss)).toRational());
      expect(result.openingQuantity, Decimal.fromInt(2));
    });
  }
  for (final buy in [true, false]) {
    test('opposite position closing leg has zero opening cost $buy', () {
      final result = openingExposure(position: buy ? '-5' : '5').cost(
        buy: buy,
        quantity: Decimal.fromInt(3),
        marginPrice: Decimal.fromInt(110),
        lossPrice: Decimal.fromInt(buy ? 110 : 90),
      );
      expect(result.openingQuantity, Decimal.zero);
      expect(result.initialMargin, Decimal.zero.toRational());
      expect(result.openingLoss, Decimal.zero);
      // The order is pending: the original opposite-side reservation remains.
      expect(result.reservedNotionalAfter, Decimal.fromInt(500));
    });
    test('reversal reserves only incremental exposure and new-leg loss $buy', () {
      final result = openingExposure(position: buy ? '-5' : '5').cost(
        buy: buy,
        quantity: Decimal.fromInt(8),
        marginPrice: Decimal.fromInt(110),
        lossPrice: Decimal.fromInt(buy ? 110 : 90),
      );
      expect(result.reservedNotionalAfter, Decimal.fromInt(500));
      expect(result.initialMargin, Decimal.zero.toRational());
      expect(result.openingQuantity, Decimal.fromInt(3));
      expect(result.openingLoss, Decimal.fromInt(30));
      expect(result.total, Decimal.fromInt(30).toRational());
    });
    test('larger reversal budgets excess over existing reservation $buy', () {
      final result = openingExposure(position: buy ? '-5' : '5').cost(
        buy: buy,
        quantity: Decimal.fromInt(12),
        marginPrice: Decimal.fromInt(110),
        lossPrice: Decimal.fromInt(buy ? 110 : 90),
      );
      expect(result.reservedNotionalAfter, Decimal.fromInt(820));
      expect(result.initialMargin, Decimal.fromInt(32).toRational());
      expect(result.openingLoss, Decimal.fromInt(70));
      expect(result.total, Decimal.fromInt(102).toRational());
    });
    test('hedge opening never consumes other-side closing capacity $buy', () {
      final result = openingExposure(hedgeGross: '500').cost(
        buy: buy,
        quantity: Decimal.fromInt(3),
        marginPrice: Decimal.fromInt(110),
        lossPrice: Decimal.fromInt(buy ? 110 : 90),
      );
      expect(result.initialMargin, Decimal.fromInt(33).toRational());
      expect(result.openingQuantity, Decimal.fromInt(3));
      expect(result.openingLoss, Decimal.fromInt(30));
      expect(result.reservedNotionalAfter, Decimal.fromInt(830));
    });
  }
  test('existing opposing orders share a larger one-way reservation', () {
    final data = openingExposure(position: '2', bids: '100', asks: '700');
    expect(data.currentNotional, Decimal.fromInt(500));
    final buy = data.cost(
      buy: true,
      quantity: Decimal.one,
      marginPrice: Decimal.fromInt(100),
      lossPrice: Decimal.fromInt(100),
    );
    final sell = data.cost(
      buy: false,
      quantity: Decimal.one,
      marginPrice: Decimal.fromInt(100),
      lossPrice: Decimal.fromInt(100),
    );
    expect(buy.reservedNotionalAfter, Decimal.fromInt(500));
    expect(buy.initialMargin, Decimal.zero.toRational());
    expect(sell.reservedNotionalAfter, Decimal.fromInt(600));
    expect(sell.initialMargin, Decimal.fromInt(10).toRational());
  });
  test('entered limit loss and assumed execution margin are separate references', () {
    final result = openingExposure().cost(
      buy: true,
      quantity: Decimal.fromInt(2),
      marginPrice: Decimal.fromInt(112),
      lossPrice: Decimal.fromInt(110),
    );
    expect(result.initialMargin, Decimal.parse('22.4').toRational());
    expect(result.openingLoss, Decimal.fromInt(20));
    expect(result.total, Decimal.parse('42.4').toRational());
  });
  test('repeating leverage division is exact and not rounded to five places', () {
    final result = openingExposure(leverage: 3).cost(
      buy: true,
      quantity: Decimal.parse('0.01'),
      marginPrice: Decimal.one,
      lossPrice: Decimal.one,
    );
    expect(
      result.initialMargin * Decimal.fromInt(3).toRational(),
      Decimal.parse('0.01').toRational(),
    );
  });
  test('zero quantity has zero cost even with open orders', () {
    final result = openingExposure(position: '-2', bids: '600', asks: '200').cost(
      buy: true,
      quantity: Decimal.zero,
      marginPrice: Decimal.fromInt(110),
      lossPrice: Decimal.fromInt(110),
    );
    expect(result.total, Decimal.zero.toRational());
    expect(result.openingQuantity, Decimal.zero);
  });
  for (final args in [
    () => openingExposure(mark: '0'),
    () => openingExposure(mark: '-1'),
    () => openingExposure(leverage: 0),
    () => openingExposure(bids: '-1'),
    () => openingExposure(asks: '-1'),
    () => openingExposure(hedgeGross: '-1'),
  ]) {
    test(
      'invalid exposure fails explicitly ${args.hashCode}',
      () => expect(args, throwsArgumentError),
    );
  }
  test('negative quantity and missing positive prices never produce a cost', () {
    final data = openingExposure();
    for (final (quantity, margin, loss) in [
      ('-1', '100', '100'),
      ('1', '0', '100'),
      ('1', '100', '0'),
    ]) {
      expect(
        () => data.cost(
          buy: true,
          quantity: Decimal.parse(quantity),
          marginPrice: Decimal.parse(margin),
          lossPrice: Decimal.parse(loss),
        ),
        throwsArgumentError,
      );
    }
  });
}
