import 'dart:async';

import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/position_leverage.dart';
import 'package:vanta/features/portfolio/data/position_leverage_mapper.dart';

import 'aster_account.dart';

final leverageClock = DateTime.utc(2026, 11, 3, 12);
Map<String, Object?> leverageBrackets({String symbol = 'BTCUSDT'}) => {
  'symbol': symbol,
  'brackets': <Map<String, Object?>>[
    {'bracket': 1, 'initialLeverage': 100, 'notionalFloor': 0, 'notionalCap': 10000},
    {'bracket': 2, 'initialLeverage': 50, 'notionalFloor': 10000, 'notionalCap': 100000},
  ],
};
List<Map<String, Object?>> leverageRows({
  String symbol = 'BTCUSDT',
  String value = '10',
  bool hedge = false,
}) => [
  for (final side in hedge ? ['LONG', 'SHORT'] : ['BOTH'])
    {'symbol': symbol, 'leverage': value, 'positionSide': side, 'positionAmt': '0'},
];
PositionLeverageContext leverageContext({
  String symbol = 'BTCUSDT',
  String address = accountAddress,
  DateTime? time,
}) => PositionLeverageContext(
  address: address,
  symbol: symbol,
  current: 10,
  receivedAt: time ?? leverageClock,
  brackets: mapLeverageBrackets(leverageBrackets(symbol: symbol), symbol),
);

class TestPositionLeverageRepository implements PositionLeverageRepository {
  int reads = 0, changes = 0, checks = 0;
  Completer<void>? readGate, changeGate, checkGate;
  AccountReadFailure? readFailure, changeFailure;
  bool submit = true;
  PositionLeverageContext? context;
  LeverageResult result = LeverageResult(observed: 20, checkedAt: leverageClock);
  bool Function()? latestCurrent;
  @override
  Future<PositionLeverageContext> read({
    required String address,
    required String symbol,
    required bool Function() isCurrent,
    required void Function(LeverageStep) onStep,
  }) async {
    reads++;
    latestCurrent = isCurrent;
    await readGate?.future;
    if (readFailure case final failure?) throw failure;
    return context ?? leverageContext(symbol: symbol, address: address);
  }

  @override
  Future<LeverageResult> change({
    required LeverageIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(LeverageStep) onStep,
  }) async {
    changes++;
    latestCurrent = isCurrent;
    onStep(LeverageStep.signing);
    await changeGate?.future;
    if (submit && canSubmit()) onStep(LeverageStep.submitting);
    if (changeFailure case final failure?) throw failure;
    return result;
  }

  @override
  Future<LeverageResult> recheck({
    required LeverageIntent intent,
    required bool Function() isCurrent,
    required void Function(LeverageStep) onStep,
  }) async {
    checks++;
    latestCurrent = isCurrent;
    onStep(LeverageStep.checkSigning);
    await checkGate?.future;
    return result;
  }
}
