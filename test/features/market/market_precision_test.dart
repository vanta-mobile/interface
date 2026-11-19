import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/utils/number_util.dart';
import 'package:vanta/features/market/domain/market_precision.dart';

void main() {
  test('depth price tooltips never repeat the integer as a fractional suffix', () {
    expect(NumberUtil.format(80000, 5), '80,000');
    expect(NumberUtil.format(0.0000010203, 10), '0.0000010203');
  });
  test('indicator axes and legends keep the sign between -1 and 0', () {
    for (final (value, fixed, legend) in [
      (-0.0612, '-0.06', '-0.06'),
      (-0.5, '-0.50', '-0.5'),
      (-1.25, '-1.25', '-1.25'),
      (-1234.567, '-1,234.56', '-1,234.56'),
      (-0.001, '0.00', '0'),
      (0.0612, '0.06', '0.06'),
    ]) {
      expect(NumberUtil.formatFixed(value, 2), fixed, reason: '$value');
      expect(NumberUtil.format(value, 2), legend, reason: '$value');
    }
    expect(NumberUtil.formatFixed(-3.9, 0), '-3');
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
}
