import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';

import '../../support/aster_account.dart';
import '../../support/position_risk.dart';

void main() {
  PositionRiskSnapshot map(Object? rows) => mapPositionRisk(
    rows,
    address: accountAddress,
    receivedAt: DateTime.utc(2026),
    units: mapAsterContractUnits(contractPayload()),
  );

  test('signed quantities and snapshot valuations retain all decimal digits and units', () {
    final result = map([positionRiskRow()]);
    final p = result.positions.single;
    expect(p.quantity.toString(), '-0.000000000000000001');
    expect(p.markPrice.toString(), '81000.000000000000000001');
    expect(p.liquidationPrice.toString(), '90000.123456789123456789');
    expect(p.notional.toString(), '-0.000000000000081000000000000000000001');
    expect(p.unrealizedProfit.toString(), '-0.000000000000001');
    expect(p.units?.base, 'BTC');
    expect(p.long, false);
    expect(p.updatedAt, DateTime.fromMillisecondsSinceEpoch(1793620800123, isUtc: true));
    expect(() => result.positions.clear(), throwsUnsupportedError);
  });

  test('hedged long and short coexist; zero positions with isolated debt remain visible', () {
    final result = map([
      positionRiskRow()
        ..['positionSide'] = 'LONG'
        ..['positionAmt'] = '0.5'
        ..['notional'] = '40500',
      positionRiskRow()..['positionSide'] = 'SHORT',
      positionRiskRow()
        ..['symbol'] = 'ETHUSDT'
        ..['positionAmt'] = '0'
        ..['isolatedWallet'] = '-2',
      positionRiskRow()
        ..['symbol'] = 'BNBUSDT'
        ..['positionAmt'] = '0'
        ..['isolatedWallet'] = '0',
    ]);
    expect(result.positions.length, 3);
    expect(result.positions.first.long, true);
    expect(result.positions[1].long, false);
    expect(result.positions.last.balanceOnly, true);
    expect(result.positions.last.isolatedWallet, Decimal.fromInt(-2));
    expect(result.positions.last.units, null);
  });

  test('absent optional values stay unknown; server zero is retained without estimation', () {
    final p = map([
      positionRiskRow()
        ..remove('unRealizedProfit')
        ..remove('isolatedMargin')
        ..remove('notional')
        ..['liquidationPrice'] = '0'
        ..['updateTime'] = 0,
    ]).positions.single;
    expect(p.liquidationPrice, Decimal.zero);
    expect(p.unrealizedProfit, null);
    expect(p.notional, null);
    expect(p.updatedAt, null);
    expect(map([]).positions, isEmpty);
  });

  test('invalid required fields, money, sides and timestamps fail the entire read', () {
    for (final entry in <String, Object?>{
      'positionAmt': null,
      'entryPrice': '-1',
      'markPrice': 1.2,
      'liquidationPrice': '-1',
      'isolatedWallet': 'NaN',
      'notional': '1e5',
      'unRealizedProfit': true,
      'isolatedMargin': {},
      'symbol': 'BTC/USDT',
      'positionSide': 'HEDGE',
      'marginType': 'unknown',
      'leverage': '0',
      'updateTime': -1,
    }.entries) {
      expect(
        () => map([positionRiskRow()..[entry.key] = entry.value]),
        throwsFormatException,
        reason: entry.key,
      );
    }
    for (final field in [
      'entryPrice',
      'markPrice',
      'positionAmt',
      'isolatedWallet',
      'marginType',
      'leverage',
    ]) {
      expect(() => map([positionRiskRow()..remove(field)]), throwsFormatException, reason: field);
    }
    expect(() => map({}), throwsFormatException);
    expect(() => map([null]), throwsFormatException);
  });

  test('duplicate, mixed-mode and inconsistent side records are rejected even when zero', () {
    expect(() => map([positionRiskRow(), positionRiskRow()]), throwsFormatException);
    expect(
      () => map([positionRiskRow(), positionRiskRow()..['positionSide'] = 'SHORT']),
      throwsFormatException,
    );
    expect(() => map([positionRiskRow()..['positionSide'] = 'LONG']), throwsFormatException);
    expect(
      () => map([
        positionRiskRow()
          ..['positionSide'] = 'SHORT'
          ..['positionAmt'] = '1',
      ]),
      throwsFormatException,
    );
    final zero = positionRiskRow()
      ..['positionAmt'] = '0'
      ..['isolatedWallet'] = '0';
    expect(() => map([zero, zero]), throwsFormatException);
  });
}
