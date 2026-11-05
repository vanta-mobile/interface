import 'account_snapshot.dart';

enum PositionMarginMode {
  cross('CROSSED'),
  isolated('ISOLATED');

  const PositionMarginMode(this.parameter);
  final String parameter;
}

class PositionMarginModeContext {
  const PositionMarginModeContext({
    required this.address,
    required this.symbol,
    required this.current,
    required this.hasPosition,
    required this.openOrderCount,
    required this.receivedAt,
  });
  final String address, symbol;
  final PositionMarginMode current;
  final bool hasPosition;
  final int openOrderCount;
  final DateTime receivedAt;
  bool get blocked => hasPosition || openOrderCount > 0;
}

enum MarginModeStep {
  idle,
  preparing,
  signingContext,
  loadingContext,
  signing,
  submitting,
  checkSigning,
  checking,
}

class MarginModeIntent {
  const MarginModeIntent({required this.context, required this.target, required this.revision});
  final PositionMarginModeContext context;
  final PositionMarginMode target;
  final int revision;
}

class MarginModeResult {
  const MarginModeResult({this.observed, this.failure, this.checkedAt});
  final PositionMarginMode? observed;
  final DateTime? checkedAt;
  final AccountReadFailure? failure;
  bool get needsRecheck => observed == null;
}

class PositionMarginModeState {
  const PositionMarginModeState({
    this.context,
    this.intent,
    this.result,
    this.failure,
    this.step = MarginModeStep.idle,
    this.stale = false,
  });
  final PositionMarginModeContext? context;
  final MarginModeIntent? intent;
  final MarginModeResult? result;
  final AccountReadFailure? failure;
  final MarginModeStep step;
  final bool stale;
  bool get busy => step != MarginModeStep.idle;
  bool get needsRecheck => result?.needsRecheck == true;
}

abstract interface class PositionMarginModeRepository {
  Future<PositionMarginModeContext> read({
    required String address,
    required String symbol,
    required bool Function() isCurrent,
    required void Function(MarginModeStep) onStep,
  });
  Future<MarginModeResult> change({
    required MarginModeIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(MarginModeStep) onStep,
  });
  Future<MarginModeResult> recheck({
    required MarginModeIntent intent,
    required bool Function() isCurrent,
    required void Function(MarginModeStep) onStep,
  });
}
