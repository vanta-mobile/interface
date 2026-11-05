import 'dart:async';

import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';

import 'aster_account.dart';

final marginModeClock = DateTime.utc(2026, 11, 3, 12);
List<Map<String, Object?>> marginModeRows({
  String symbol = 'BTCUSDT',
  String mode = 'cross',
  bool hedge = false,
  String quantity = '0',
}) => [
  for (final side in hedge ? ['LONG', 'SHORT'] : ['BOTH'])
    {
      'symbol': symbol,
      'marginType': mode,
      'positionSide': side,
      'positionAmt': side == 'SHORT' && quantity != '0' ? '-$quantity' : quantity,
    },
];
PositionMarginModeContext marginModeContext({
  String symbol = 'BTCUSDT',
  String address = accountAddress,
  PositionMarginMode current = PositionMarginMode.cross,
  bool hasPosition = false,
  int orders = 0,
  DateTime? time,
}) => PositionMarginModeContext(
  address: address,
  symbol: symbol,
  current: current,
  hasPosition: hasPosition,
  openOrderCount: orders,
  receivedAt: time ?? marginModeClock,
);

class TestPositionMarginModeRepository implements PositionMarginModeRepository {
  int reads = 0, changes = 0, checks = 0;
  Completer<void>? readGate, changeGate, checkGate;
  AccountReadFailure? readFailure, changeFailure;
  bool submit = true;
  PositionMarginModeContext? context;
  MarginModeResult result = MarginModeResult(
    observed: PositionMarginMode.isolated,
    checkedAt: marginModeClock,
  );
  bool Function()? latestCurrent;
  @override
  Future<PositionMarginModeContext> read({
    required String address,
    required String symbol,
    required bool Function() isCurrent,
    required void Function(MarginModeStep) onStep,
  }) async {
    reads++;
    latestCurrent = isCurrent;
    await readGate?.future;
    if (readFailure case final failure?) throw failure;
    return context ?? marginModeContext(symbol: symbol, address: address);
  }

  @override
  Future<MarginModeResult> change({
    required MarginModeIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(MarginModeStep) onStep,
  }) async {
    changes++;
    latestCurrent = isCurrent;
    onStep(MarginModeStep.signing);
    await changeGate?.future;
    if (submit && canSubmit()) onStep(MarginModeStep.submitting);
    if (changeFailure case final failure?) throw failure;
    return result;
  }

  @override
  Future<MarginModeResult> recheck({
    required MarginModeIntent intent,
    required bool Function() isCurrent,
    required void Function(MarginModeStep) onStep,
  }) async {
    checks++;
    latestCurrent = isCurrent;
    onStep(MarginModeStep.checkSigning);
    await checkGate?.future;
    return result;
  }
}
