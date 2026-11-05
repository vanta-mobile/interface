import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/position_leverage_mapper.dart';
import 'package:vanta/features/portfolio/domain/position_leverage.dart';

import '../../support/position_leverage.dart';
import '../../support/aster_account.dart';

void main() {
  test('zero-sized one-way and both hedge sides retain current configuration', () {
    expect(mapCurrentLeverage(leverageRows(), 'BTCUSDT'), 10);
    expect(mapCurrentLeverage(leverageRows(hedge: true), 'BTCUSDT'), 10);
  });
  test(
    'wrong symbol, conflicting or incomplete modes, duplicate sides and malformed leverage fail',
    () {
      for (final data in [
        null,
        <Object?>[],
        leverageRows(symbol: 'ETHUSDT'),
        [leverageRows(hedge: true).first],
        [...leverageRows(), ...leverageRows(hedge: true)],
        [...leverageRows(), ...leverageRows()],
        [leverageRows(hedge: true).first, leverageRows(hedge: true, value: '20').last],
        leverageRows(value: '1.5'),
        leverageRows(value: '0'),
        leverageRows(value: '01'),
        [leverageRows().single..['leverage'] = 10],
      ]) {
        expect(() => mapCurrentLeverage(data, 'BTCUSDT'), throwsFormatException, reason: '$data');
      }
    },
  );
  test('brackets accept exact integer or string notationals, never doubles', () {
    final data = leverageBrackets();
    final rows = data['brackets']! as List;
    rows.last['notionalCap'] = '100000.000000000000000001';
    final mapped = mapLeverageBrackets(data, 'BTCUSDT');
    expect(mapped.last.cap, Decimal.parse('100000.000000000000000001'));
    expect(mapLeverageBrackets([data], 'BTCUSDT').length, 2);
    rows.last['notionalCap'] = 100000.1;
    expect(() => mapLeverageBrackets(data, 'BTCUSDT'), throwsFormatException);
  });
  test('bracket gaps, duplicates, increasing limits and mismatched symbols fail', () {
    for (final change in <void Function(Map<String, Object?>)>[
      (d) => d['symbol'] = 'ETHUSDT',
      (d) => d['brackets'] = [],
      (d) => (d['brackets'] as List).last['notionalFloor'] = 9999,
      (d) => (d['brackets'] as List).last['notionalCap'] = 10000,
      (d) => (d['brackets'] as List).last['bracket'] = 1,
      (d) => (d['brackets'] as List).last['initialLeverage'] = 101,
      (d) => (d['brackets'] as List).first['notionalFloor'] = '-1',
    ]) {
      final data = leverageBrackets();
      change(data);
      expect(() => mapLeverageBrackets(data, 'BTCUSDT'), throwsFormatException);
    }
  });
  test('input is a different whole number bounded by brackets and documented 125 range', () {
    final context = leverageContext();
    for (final input in [
      '',
      '0',
      '-1',
      '10',
      '01',
      '1.0',
      '1e2',
      ' 20',
      '101',
      '999999999999999999999999',
    ]) {
      expect(context.target(input), null, reason: input);
    }
    expect(context.target('100'), 100);
    final high = PositionLeverageContext(
      address: accountAddress,
      symbol: 'BTCUSDT',
      current: 20,
      receivedAt: leverageClock,
      brackets: [LeverageBracket(maximum: 300, floor: Decimal.zero, cap: Decimal.fromInt(1000))],
    );
    expect(high.maximum, 125);
    expect(high.target('126'), null);
    expect(high.target('125'), 125);
  });
  test('malformed symbols cannot become signed scope parameters', () {
    for (final symbol in ['', 'BTCUSDT&leverage=100', 'BTC/USDT', 'BTC USDT']) {
      expect(() => validateLeverageSymbol(symbol), throwsFormatException);
    }
    validateLeverageSymbol('黄金USDT');
  });
}
