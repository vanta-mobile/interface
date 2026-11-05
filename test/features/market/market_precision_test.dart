import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/utils/number_util.dart';
import 'package:vanta/features/market/domain/market_precision.dart';
import 'package:vanta/features/trade/domain/demo_order.dart';

void main() {
  test('depth price tooltips never repeat the integer as a fractional suffix', () {
    expect(NumberUtil.format(80000, 5), '80,000');
    expect(NumberUtil.format(0.0000010203, 10), '0.0000010203');
  });
  test('fractions retain the second nonzero digit and all supplied precision', () {
    for (final entry in {
      '0': '0',
      '1234': '1,234',
      '1234.1': '1,234.10',
      '0.0000010203': '0.0000010203',
      '0.01002': '0.01002',
      '-0.00000012': '-0.00000012',
      '1e-10': '0.0000000001',
      '0.000001': '0.000001',
      'NaN': '—',
    }.entries) {
      expect(marketNumber(entry.key), entry.value, reason: entry.key);
    }
    expect(marketNumber('0.12', minimumDecimals: 5), '0.12000');
    expect(marketNumber(Decimal.parse('0.1234567890123456789')), '0.1234567890123456789');
    expect(marketInput('1234.0000010203'), '1234.0000010203');
    expect(marketDrawingDecimals([0.0000010203], minimum: 2), 10);
  });

  test('exchange increments preserve tiny ticks and non-power-of-ten steps', () {
    final rules = MarketPrecision.fromExchange({
      'filters': [
        {'filterType': 'PRICE_FILTER', 'tickSize': '0.0000000100'},
        {'filterType': 'LOT_SIZE', 'stepSize': '0.0500'},
      ],
    });
    expect(rules.priceDecimals, 8);
    expect(rules.quantityDecimals, 2);
    expect(rules.acceptsPrice(Decimal.parse('0.00000012')), isTrue);
    expect(rules.acceptsPrice(Decimal.parse('0.000000125')), isFalse);
    expect(rules.acceptsQuantity(Decimal.parse('1.15')), isTrue);
    expect(rules.acceptsQuantity(Decimal.parse('1.16')), isFalse);
    expect(rules.floorQuantity(Decimal.parse('1.1999')), Decimal.parse('1.15'));
    final missing = MarketPrecision.fromExchange({
      'filters': [
        {'filterType': 'PRICE_FILTER', 'tickSize': '0'},
        {'filterType': 'LOT_SIZE', 'stepSize': 'NaN'},
      ],
    });
    expect(missing.priceTick, isNull);
    expect(missing.quantityStep, isNull);
  });

  test('tiny limit orders validate exact increments; market quotes may be finer', () {
    OrderDraft order(String price, {bool market = false, String quantity = '1.15'}) => OrderDraft(
      symbol: 'TINYUSDT',
      buy: true,
      market: market,
      quantity: quantity,
      price: price,
      leverage: 7,
      precision: const MarketPrecision(priceTick: '0.00000001', quantityStep: '0.05'),
    );
    final available = Decimal.fromInt(100);
    expect(order('0.00000012').validate(available), isNull);
    expect(order('0.0000001200').validate(available), isNull);
    expect(order('0.000000125').validate(available), 'invalidPrice');
    expect(order('0.000000125', market: true).validate(available), isNull);
    expect(order('0.00000012', quantity: '1.16').validate(available), 'invalidQuantity');
  });

  test('allocation floors to actual quantity step without overcommitting margin', () {
    for (final price in ['0.0000010203', '81234.56']) {
      for (final step in ['0.05', '0.00000001', '1']) {
        final rules = MarketPrecision(quantityStep: step);
        final available = Decimal.parse('99.12345678');
        final quantity = marketAllocation(
          available: available,
          fraction: Decimal.one,
          price: Decimal.parse(price),
          leverage: 7,
          feeRate: demoFeeRate,
          precision: rules,
        );
        final unitCost =
            Decimal.parse(price).toRational() / Decimal.fromInt(7).toRational() +
            (Decimal.parse(price) * demoFeeRate).toRational();
        expect(rules.acceptsQuantity(quantity), isTrue);
        expect(quantity.toRational() * unitCost <= available.toRational(), isTrue);
        expect(
          (quantity + Decimal.parse(step)).toRational() * unitCost > available.toRational(),
          isTrue,
        );
      }
    }
  });
}
