import 'dart:async';

import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';

import 'aster_account.dart';

final positionModeClock = DateTime.utc(2026, 11, 3, 12);
List<Map<String, Object?>> positionModeRows({
  String symbol = 'BTCUSDT',
  bool hedge = false,
  String quantity = '0',
}) => [
  for (final side in hedge ? ['LONG', 'SHORT'] : ['BOTH'])
    {
      'symbol': symbol,
      'positionSide': side,
      'positionAmt': side == 'SHORT' && quantity != '0' ? '-$quantity' : quantity,
    },
];
FuturesPositionModeContext positionModeContext({
  String address = accountAddress,
  FuturesPositionMode current = FuturesPositionMode.oneWay,
  bool hasPosition = false,
  int orders = 0,
  DateTime? time,
}) => FuturesPositionModeContext(
  address: address,
  current: current,
  hasPosition: hasPosition,
  openOrderCount: orders,
  receivedAt: time ?? positionModeClock,
);

class TestFuturesPositionModeRepository implements FuturesPositionModeRepository {
  int reads = 0, changes = 0, checks = 0;
  Completer<void>? readGate, changeGate, checkGate;
  AccountReadFailure? readFailure, changeFailure;
  bool submit = true;
  FuturesPositionModeContext? context;
  PositionModeResult result = PositionModeResult(
    observed: FuturesPositionMode.hedge,
    checkedAt: positionModeClock,
  );
  bool Function()? latestCurrent;
  @override
  Future<FuturesPositionModeContext> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(PositionModeStep) onStep,
  }) async {
    reads++;
    latestCurrent = isCurrent;
    await readGate?.future;
    if (readFailure case final failure?) throw failure;
    return context ?? positionModeContext(address: address);
  }

  @override
  Future<PositionModeResult> change({
    required PositionModeIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(PositionModeStep) onStep,
  }) async {
    changes++;
    latestCurrent = isCurrent;
    onStep(PositionModeStep.signing);
    await changeGate?.future;
    if (submit && canSubmit()) onStep(PositionModeStep.submitting);
    if (changeFailure case final failure?) throw failure;
    return result;
  }

  @override
  Future<PositionModeResult> recheck({
    required PositionModeIntent intent,
    required bool Function() isCurrent,
    required void Function(PositionModeStep) onStep,
  }) async {
    checks++;
    latestCurrent = isCurrent;
    onStep(PositionModeStep.checkSigning);
    await checkGate?.future;
    return result;
  }
}
