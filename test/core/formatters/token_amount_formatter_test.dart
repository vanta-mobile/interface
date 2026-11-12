import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/domain/decimal_value.dart';
import 'package:vanta/core/formatters/token_amount_formatter.dart';

void main() {
  group('TokenAmountFormatter', () {
    group('formatDecimal', () {
      final cases = <String, String>{
        '0': '0',
        '0.000000': '0',
        '-0.0000': '0',
        '1': '1',
        '1.000000000': '1',
        '1234.123456789': '1,234.123457',
        '12345678901234567890.1234564': '12,345,678,901,234,567,890.123456',
        '1.1234565': '1.123457',
        '0.1234564': '0.123456',
        '0.0000123456789': '0.0000123457',
        '0.0000100200304': '0.00001002',
        '0.000000000000000001': '0.000000000000000001',
        '0.00120': '0.0012',
        '0.00009999999': '0.0001',
        '0.9999999': '1',
        '999.9999999': '1,000',
        '-0.0000123456789': '-0.0000123457',
        '-12.1234565': '-12.123457',
      };
      for (final entry in cases.entries) {
        test('formats ${entry.key} as ${entry.value}', () {
          expect(TokenAmountFormatter.formatDecimal(DecimalValue(entry.key)), entry.value);
        });
      }
    });

    test('applies adaptive precision to numeric and token display helpers', () {
      final token = DecimalValue('12.123456789', asset: 'ETH', unit: 'token');
      final smallToken = DecimalValue('0.0000123456789', asset: 'ETH', unit: 'token');

      expect(TokenAmountFormatter.formatValue(token), '12.123457');
      expect(TokenAmountFormatter.format(token, symbol: 'ETH', decimals: 18), '12.123457 ETH');
      expect(TokenAmountFormatter.formatValue(smallToken), '0.0000123457');
      expect(
        TokenAmountFormatter.format(smallToken, symbol: 'ETH', decimals: 18),
        '0.0000123457 ETH',
      );
      expect(TokenAmountFormatter.formatText('12.123456789'), '12.123457');
      expect(TokenAmountFormatter.formatText('—'), '—');
    });

    test('preserves an 18-decimal non-zero amount exactly', () {
      final value = DecimalValue('0.000000000000000001', asset: 'ETH', unit: 'token');

      expect(
        TokenAmountFormatter.format(value, symbol: 'ETH', decimals: 18),
        '0.000000000000000001 ETH',
      );
    });

    test('groups integer digits and only trims insignificant zeros', () {
      final value = DecimalValue('1234567.120000', asset: 'USDC', unit: 'token');

      expect(TokenAmountFormatter.format(value, symbol: 'USDC', decimals: 6), '1,234,567.12 USDC');
      expect(
        TokenAmountFormatter.format(
          value,
          symbol: 'USDC',
          decimals: 6,
          display: TokenAmountDisplay.exact,
        ),
        '1,234,567.120000 USDC',
      );
    });

    test('formats fiat and percentage values without binary floating point', () {
      expect(TokenAmountFormatter.formatUsd(DecimalValue('12580.4200')), r'$12,580.42');
      expect(TokenAmountFormatter.formatUsd(DecimalValue('281.622076628')), r'$281.62');
      expect(TokenAmountFormatter.formatUsd(DecimalValue('0.839996378700433967')), r'$0.839996');
      expect(TokenAmountFormatter.formatUsd(DecimalValue('-0.0049')), r'$-0.0049');
      expect(TokenAmountFormatter.formatPercent(DecimalValue('2.01')), '+2.01%');
      expect(TokenAmountFormatter.formatPercent(DecimalValue('-0.8')), '-0.8%');
      expect(TokenAmountFormatter.formatPercent(DecimalValue('-0.473949693625376621')), '-0.47%');
      expect(TokenAmountFormatter.formatPercent(DecimalValue('2.316')), '+2.32%');
      expect(
        TokenAmountFormatter.formatPercent(DecimalValue('83.9988362167685387'), signed: false),
        '84%',
      );
      expect(
        TokenAmountFormatter.formatPercent(DecimalValue('16.0011637832314613'), signed: false),
        '16%',
      );
      expect(
        TokenAmountFormatter.formatPercent(
          DecimalValue('44.64'),
          signed: false,
          maxFractionDigits: 1,
        ),
        '44.6%',
      );
      expect(TokenAmountFormatter.formatPercent(DecimalValue('-0.0049')), '0%');
    });

    test('fixed-formats compact USD labels with decimal rounding', () {
      expect(TokenAmountFormatter.formatUsdFixed(DecimalValue('0.412546030148')), r'$0.41');
      expect(TokenAmountFormatter.formatUsdFixed(DecimalValue('1253.125')), r'$1,253.13');
      expect(TokenAmountFormatter.formatUsdFixed(DecimalValue('0.0049')), r'$0.00');
      expect(
        TokenAmountFormatter.sumUsdFixed([
          DecimalValue('0.206273015074'),
          DecimalValue('0.206273015074'),
        ]),
        r'$0.41',
      );
    });

    test('fixed formats can preserve non-zero values with adaptive precision', () {
      expect(
        TokenAmountFormatter.formatUsdFixed(DecimalValue('16'), preserveSmallValues: true),
        r'$16.00',
      );
      expect(
        TokenAmountFormatter.formatUsdFixed(
          DecimalValue('0.00491234567'),
          preserveSmallValues: true,
        ),
        r'$0.00491235',
      );
      expect(
        TokenAmountFormatter.formatUsdFixed(
          DecimalValue('-0.0000123456789'),
          preserveSmallValues: true,
        ),
        r'$-0.0000123457',
      );
      expect(
        TokenAmountFormatter.formatUsdFixed(DecimalValue('0'), preserveSmallValues: true),
        r'$0.00',
      );
      expect(
        TokenAmountFormatter.formatPercent(
          DecimalValue('-0.0000123456789'),
          trimInsignificantZeros: false,
          preserveSmallValues: true,
        ),
        '-0.0000123457%',
      );
    });

    test('formats large values with compact suffixes', () {
      expect(TokenAmountFormatter.formatCompact(DecimalValue('12580.42'), usd: true), r'$12.58K');
      expect(TokenAmountFormatter.formatCompact(DecimalValue('1234567.89')), '1.23M');
      expect(TokenAmountFormatter.formatCompact(DecimalValue('9876543210')), '9.88B');
      expect(TokenAmountFormatter.formatCompact(DecimalValue('-12580.42'), usd: true), r'-$12.58K');
      expect(TokenAmountFormatter.formatCompact(DecimalValue('12.123456789')), '12.123457');
    });

    test('formats fixed-scale editable values without feature rounding', () {
      expect(TokenAmountFormatter.formatFixed(DecimalValue('188'), decimals: 2), '188.00');
      expect(TokenAmountFormatter.formatFixed(DecimalValue('-0.5'), decimals: 2), '-0.50');
      expect(
        TokenAmountFormatter.formatFixed(DecimalValue('1140.60'), decimals: 2, grouping: true),
        '1,140.60',
      );
      expect(
        () => TokenAmountFormatter.formatFixed(DecimalValue('1.001'), decimals: 2),
        throwsFormatException,
      );
    });

    test('converts atomic units using token decimals without double', () {
      expect(
        TokenAmountFormatter.formatAtomic(BigInt.one, symbol: 'ETH', decimals: 18),
        '0.000000000000000001 ETH',
      );
      expect(
        TokenAmountFormatter.formatAtomic(BigInt.from(-1234567), symbol: 'USDC', decimals: 6),
        '-1.234567 USDC',
      );
    });

    test('rejects non-zero precision beyond token decimals', () {
      final value = DecimalValue('1.0000001', asset: 'USDC', unit: 'token');

      expect(
        () => TokenAmountFormatter.format(value, symbol: 'USDC', decimals: 6),
        throwsFormatException,
      );
    });

    test('allows excess zero scale without changing numeric value', () {
      final value = DecimalValue('1.23000000', asset: 'USDC', unit: 'token');

      expect(
        TokenAmountFormatter.format(
          value,
          symbol: 'USDC',
          decimals: 6,
          display: TokenAmountDisplay.exact,
        ),
        '1.230000 USDC',
      );
    });

    test('rejects invalid decimals and a mismatched token symbol', () {
      final value = DecimalValue('1', asset: 'USDC', unit: 'token');

      expect(
        () => TokenAmountFormatter.format(value, symbol: 'ETH', decimals: 18),
        throwsArgumentError,
      );
      expect(
        () => TokenAmountFormatter.formatAtomic(BigInt.one, symbol: 'ETH', decimals: -1),
        throwsRangeError,
      );
    });

    test('sums USD values at their decimal precision without double', () {
      expect(
        TokenAmountFormatter.sumUsd([
          DecimalValue('12345678901234567890.01', asset: 'USD', unit: 'fiat'),
          DecimalValue('0.009', asset: 'USD', unit: 'fiat'),
          DecimalValue('-0.004', asset: 'USD', unit: 'fiat'),
        ]),
        r'$12,345,678,901,234,567,890.02',
      );
      expect(TokenAmountFormatter.sumUsd(const []), '—');
    });

    test('rounds display values to a fraction limit and trims zeros', () {
      String rounded(String value) =>
          TokenAmountFormatter.formatRounded(DecimalValue(value), maxFractionDigits: 1);
      expect(rounded('643289.9013747723'), '643,289.9');
      expect(rounded('640480.48798292'), '640,480.5');
      expect(rounded('1000000'), '1,000,000');
      expect(rounded('8420.04'), '8,420');
      expect(rounded('0'), '0');
      // Non-zero values do not collapse to zero.
      expect(rounded('0.03'), '0.03');
      expect(
        () => TokenAmountFormatter.formatRounded(DecimalValue('1'), maxFractionDigits: -1),
        throwsRangeError,
      );
    });
  });
}
