import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/position_adl_mapper.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/portfolio/domain/position_adl.dart';

import '../../support/aster_account.dart';
import '../../support/position_adl.dart';
import '../../support/position_risk.dart';

void main() {
  PositionAdlSnapshot map(Object? rows) =>
      mapPositionAdl(rows, address: accountAddress, receivedAt: DateTime.utc(2026));
  final position = positionRiskFixture().positions.first;

  test('all five levels are valid and maps are immutable', () {
    for (var level = 0; level <= 4; level++) {
      final payload = [
        positionAdlRow()..['adlQuantile'] = {'BOTH': level},
      ];
      final result = map(payload);
      expect(result.levelFor(position), level);
      expect(() => result.symbols.clear(), throwsUnsupportedError);
      expect(() => result.symbols['BTCUSDT']!.levels.clear(), throwsUnsupportedError);
      (payload.single['adlQuantile'] as Map)['BOTH'] = 1;
      expect(result.levelFor(position), level);
    }
  });

  test('isolated hedge uses exact side, crossed hedge ignores HEDGE marker value', () {
    for (final isolated in [true, false]) {
      final adl = map([
        positionAdlRow()
          ..['adlQuantile'] = isolated
              ? {'BOTH': 0, 'LONG': 1, 'SHORT': 4}
              : {'HEDGE': 99, 'LONG': 3, 'SHORT': 3},
      ]);
      for (final side in ['LONG', 'SHORT']) {
        final p = mapPositionRisk(
          [
            positionRiskRow()
              ..['positionSide'] = side
              ..['positionAmt'] = side == 'LONG' ? '1' : '-1'
              ..['marginType'] = isolated ? 'isolated' : 'cross',
          ],
          address: accountAddress,
          receivedAt: DateTime.utc(2026),
        ).positions.single;
        expect(adl.levelFor(p), isolated ? (side == 'LONG' ? 1 : 4) : 3);
      }
    }
  });

  test(
    'missing records or sides, mode disagreement, and zero quantity never become level zero',
    () {
      final crossed = mapPositionRisk(
        [
          positionRiskRow()
            ..['marginType'] = 'cross'
            ..['positionSide'] = 'SHORT',
        ],
        address: accountAddress,
        receivedAt: DateTime.utc(2026),
      ).positions.single;
      expect(map([]).levelFor(position), null);
      expect(map([positionAdlRow()..['symbol'] = 'ETHUSDT']).levelFor(position), null);
      expect(
        map([
          positionAdlRow()..['adlQuantile'] = {'LONG': 4},
        ]).levelFor(position),
        null,
      );
      expect(
        map([
          positionAdlRow()..['adlQuantile'] = {'HEDGE': 0, 'SHORT': 4},
        ]).levelFor(position),
        null,
      );
      expect(map([positionAdlRow()]).levelFor(crossed), null);
      expect(
        map([positionAdlRow()..['symbol'] = 'ETHUSDT'])
            .levelFor(positionRiskFixture().positions.last),
        null,
      );
      expect(
        map([positionAdlRow()..['adlQuantile'] = <String, Object?>{}]).levelFor(position),
        null,
      );
    },
  );

  test('invalid levels, shapes, conflicting hedge values and duplicate symbols fail the read', () {
    for (final quantiles in <Object?>[
      null,
      [],
      {'BOTH': -1},
      {'BOTH': 5},
      {'BOTH': '1'},
      {'BOTH': 1.0},
      {'BOTH': null},
      {'UNKNOWN': 2},
      {'HEDGE': '0'},
      {'HEDGE': 0, 'BOTH': 1},
      {'HEDGE': 0, 'LONG': 1, 'SHORT': 2},
    ]) {
      expect(
        () => map([positionAdlRow()..['adlQuantile'] = quantiles]),
        throwsFormatException,
        reason: '$quantiles',
      );
    }
    expect(() => map([positionAdlRow(), positionAdlRow()]), throwsFormatException);
    expect(() => map([positionAdlRow()..['symbol'] = '<BTC>']), throwsFormatException);
    expect(() => map({}), throwsFormatException);
    expect(() => map([null]), throwsFormatException);
  });
}
