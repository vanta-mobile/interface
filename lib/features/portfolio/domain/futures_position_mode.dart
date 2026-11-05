import 'account_snapshot.dart';

enum FuturesPositionMode {
  oneWay('false'),
  hedge('true');

  const FuturesPositionMode(this.parameter);
  final String parameter;
}

class FuturesPositionModeContext {
  const FuturesPositionModeContext({
    required this.address,
    required this.current,
    required this.hasPosition,
    required this.openOrderCount,
    required this.receivedAt,
  });
  final String address;
  final FuturesPositionMode current;
  final bool hasPosition;
  final int openOrderCount;
  final DateTime receivedAt;
  bool get blocked => hasPosition || openOrderCount > 0;
}

enum PositionModeStep {
  idle,
  preparing,
  signingContext,
  loadingContext,
  signing,
  submitting,
  checkSigning,
  checking,
}

class PositionModeIntent {
  const PositionModeIntent({required this.context, required this.target, required this.revision});
  final FuturesPositionModeContext context;
  final FuturesPositionMode target;
  final int revision;
}

class PositionModeResult {
  const PositionModeResult({this.observed, this.failure, this.checkedAt});
  final FuturesPositionMode? observed;
  final DateTime? checkedAt;
  final AccountReadFailure? failure;
  bool get needsRecheck => observed == null;
}

class FuturesPositionModeState {
  const FuturesPositionModeState({
    this.context,
    this.intent,
    this.result,
    this.failure,
    this.step = PositionModeStep.idle,
    this.stale = false,
  });
  final FuturesPositionModeContext? context;
  final PositionModeIntent? intent;
  final PositionModeResult? result;
  final AccountReadFailure? failure;
  final PositionModeStep step;
  final bool stale;
  bool get busy => step != PositionModeStep.idle;
  bool get needsRecheck => result?.needsRecheck == true;
}

abstract interface class FuturesPositionModeRepository {
  Future<FuturesPositionModeContext> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(PositionModeStep) onStep,
  });
  Future<PositionModeResult> change({
    required PositionModeIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(PositionModeStep) onStep,
  });
  Future<PositionModeResult> recheck({
    required PositionModeIntent intent,
    required bool Function() isCurrent,
    required void Function(PositionModeStep) onStep,
  });
}
