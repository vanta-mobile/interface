import 'dart:async';

import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';

import 'aster_account.dart';

Map<String, Object?> positionRiskRow() => {
  'symbol': 'BTCUSDT',
  'positionSide': 'BOTH',
  'positionAmt': '-0.000000000000000001',
  'entryPrice': '80000.000000000000000001',
  'markPrice': '81000.000000000000000001',
  'liquidationPrice': '90000.123456789123456789',
  'marginType': 'isolated',
  'isolatedWallet': '1.000000000000000001',
  'isolatedMargin': '0.999999999999999001',
  'unRealizedProfit': '-0.000000000000001',
  'notional': '-0.000000000000081000000000000000000001',
  'leverage': '5',
  'updateTime': 1793620800123,
};

PositionRiskSnapshot positionRiskFixture({String address = accountAddress}) => mapPositionRisk(
  [
    positionRiskRow(),
    positionRiskRow()
      ..['symbol'] = 'ETHUSDT'
      ..['positionAmt'] = '0'
      ..['notional'] = '0'
      ..['isolatedWallet'] = '-2',
  ],
  address: address,
  receivedAt: DateTime.utc(2026, 11, 2, 12, 30),
  units: mapAsterContractUnits(contractPayload()),
);

class TestPositionRiskRepository implements PositionRiskRepository {
  PositionRiskSnapshot result = positionRiskFixture();
  AccountReadFailure? failure;
  Completer<void>? gate;
  int calls = 0;
  @override
  Future<PositionRiskSnapshot> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    calls++;
    onStep(AccountReadStep.signing);
    await gate?.future;
    onStep(AccountReadStep.loading);
    if (failure case final error?) throw error;
    return result;
  }
}
