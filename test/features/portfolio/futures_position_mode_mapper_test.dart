import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/futures_position_mode_mapper.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';

import '../../support/futures_position_mode.dart';

void main() {
  test('actual boolean maps to distinct read mode and string write parameter', () {
    expect(mapFuturesPositionMode({'dualSidePosition': false}), FuturesPositionMode.oneWay);
    expect(mapFuturesPositionMode({'dualSidePosition': true}), FuturesPositionMode.hedge);
    expect(FuturesPositionMode.oneWay.parameter, 'false');
    expect(FuturesPositionMode.hedge.parameter, 'true');
    for (final value in [
      null,
      <Object?>[],
      <String, Object?>{},
      {'dualSidePosition': 'false'},
      {'dualSidePosition': 0},
    ]) {
      expect(() => mapFuturesPositionMode(value), throwsFormatException);
    }
  });
  test('all symbols included and tiny position amounts are never rounded to zero', () {
    expect(hasPositionModeBlocker([], FuturesPositionMode.oneWay), false);
    expect(hasPositionModeBlocker(positionModeRows(), FuturesPositionMode.oneWay), false);
    expect(
      hasPositionModeBlocker([
        ...positionModeRows(),
        ...positionModeRows(symbol: 'ETHUSDT', quantity: '0.00000000000000000000001'),
      ], FuturesPositionMode.oneWay),
      true,
    );
    expect(
      hasPositionModeBlocker(
        positionModeRows(hedge: true, quantity: '1'),
        FuturesPositionMode.hedge,
      ),
      true,
    );
  });
  test('malformed quantities, modes and duplicate rows fail even with no exposure', () {
    final row = positionModeRows().first;
    for (final payload in <Object?>[
      {},
      null,
      [null],
      [row, row],
      [
        {...row, 'symbol': 'BTC&symbol=ETH'},
      ],
      [
        {...row, 'positionAmt': 0.0},
      ],
      [
        {...row, 'positionAmt': '1e-9'},
      ],
      [
        {...row, 'positionAmt': null},
      ],
      [
        {...row, 'positionSide': 'LONG'},
      ],
      [
        {...row, 'positionSide': 'UNKNOWN'},
      ],
    ]) {
      expect(
        () => hasPositionModeBlocker(payload, FuturesPositionMode.oneWay),
        throwsFormatException,
      );
    }
    expect(() => hasPositionModeBlocker([row], FuturesPositionMode.hedge), throwsFormatException);
  });
  test('hedge signs validated while net short BOTH and negative zero remain valid', () {
    for (final row in [
      {'symbol': 'BTCUSDT', 'positionSide': 'LONG', 'positionAmt': '-0.01'},
      {'symbol': 'ETHUSDT', 'positionSide': 'SHORT', 'positionAmt': '0.01'},
    ]) {
      expect(() => hasPositionModeBlocker([row], FuturesPositionMode.hedge), throwsFormatException);
    }
    expect(
      hasPositionModeBlocker(positionModeRows(quantity: '-0.01'), FuturesPositionMode.oneWay),
      true,
    );
    expect(
      hasPositionModeBlocker(positionModeRows(quantity: '-0.000'), FuturesPositionMode.oneWay),
      false,
    );
  });
}
