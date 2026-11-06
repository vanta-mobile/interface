import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/domain/decimal_value.dart';

void main() {
  group('DecimalValue', () {
    test('preserves the supplied decimal text and scale', () {
      final value = DecimalValue('100.2300', asset: 'USDC', unit: 'token');
      expect(value.value, '100.2300');
      expect(value.scale, 4);
    });

    test('rejects exponent, non-finite, and malformed values', () {
      for (final input in ['1e3', 'NaN', 'Infinity', '', '.', '01.2']) {
        expect(() => DecimalValue(input), throwsFormatException);
      }
    });

    test('only compares values with matching asset and unit', () {
      final left = DecimalValue('1.0', asset: 'USDC', unit: 'token');
      final same = DecimalValue('1.0', asset: 'USDC', unit: 'token');
      final other = DecimalValue('1.0', asset: 'USD', unit: 'fiat');
      expect(left, same);
      expect(left, isNot(other));
    });
  });
}
