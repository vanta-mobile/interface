import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/position_margin_mode_mapper.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';

import '../../support/position_margin_mode.dart';

void main() {
  test('zero-sized one-way and hedge configuration rows retain margin mode', () {
    expect(mapMarginConfiguration(marginModeRows(), 'BTCUSDT'), (
      mode: PositionMarginMode.cross,
      hasPosition: false,
    ));
    expect(mapMarginConfiguration(marginModeRows(mode: 'isolated', hedge: true), 'BTCUSDT'), (
      mode: PositionMarginMode.isolated,
      hasPosition: false,
    ));
  });
  test('any nonzero quantity, even beyond double precision, blocks switching', () {
    for (final quantity in ['0.000000000000000000000001', '-2.123456789012345678']) {
      expect(
        mapMarginConfiguration(marginModeRows(quantity: quantity), 'BTCUSDT').hasPosition,
        true,
      );
    }
    expect(
      mapMarginConfiguration(marginModeRows(quantity: '2', hedge: true), 'BTCUSDT').hasPosition,
      true,
    );
  });
  test('wrong symbol, incomplete modes, duplicate sides and mixed hedge modes fail', () {
    for (final data in <Object?>[
      null,
      <Object?>[],
      marginModeRows(symbol: 'ETHUSDT'),
      [marginModeRows(hedge: true).first],
      [...marginModeRows(), ...marginModeRows(hedge: true)],
      [...marginModeRows(), ...marginModeRows()],
      [marginModeRows(hedge: true).first, marginModeRows(mode: 'isolated', hedge: true).last],
    ]) {
      expect(() => mapMarginConfiguration(data, 'BTCUSDT'), throwsFormatException);
    }
  });
  test('unknown mode, floating or malformed quantity and contradictory hedge direction fail', () {
    for (final data in <Object?>[
      marginModeRows(mode: 'CROSSED'),
      marginModeRows(mode: 'unknown'),
      [marginModeRows().single..['positionAmt'] = 1.2],
      marginModeRows(quantity: '1e-18'),
      marginModeRows(quantity: 'NaN'),
      marginModeRows(quantity: ' 0'),
      [marginModeRows(hedge: true, quantity: '-1').first, marginModeRows(hedge: true).last],
      [marginModeRows(hedge: true).first, marginModeRows(hedge: true).last..['positionAmt'] = '1'],
    ]) {
      expect(() => mapMarginConfiguration(data, 'BTCUSDT'), throwsFormatException);
    }
  });
  test('read values and wire parameters use explicit mapping', () {
    expect(PositionMarginMode.cross.parameter, 'CROSSED');
    expect(PositionMarginMode.isolated.parameter, 'ISOLATED');
  });
}
