import 'dart:async';

import 'package:vanta/features/portfolio/data/position_adl_mapper.dart';
import 'package:vanta/features/portfolio/domain/position_adl.dart';

import 'aster_account.dart';

Map<String, Object?> positionAdlRow() => {
  'symbol': 'BTCUSDT',
  'adlQuantile': {'BOTH': 4, 'LONG': 1, 'SHORT': 2},
};

PositionAdlSnapshot positionAdlFixture({String address = accountAddress}) =>
    mapPositionAdl([positionAdlRow()], address: address, receivedAt: DateTime.utc(2026, 11, 3));

class TestPositionAdlRepository implements PositionAdlRepository {
  PositionAdlSnapshot result = positionAdlFixture();
  AccountReadFailure? failure;
  Completer<void>? gate;
  int calls = 0;
  @override
  Future<PositionAdlSnapshot> read({
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
