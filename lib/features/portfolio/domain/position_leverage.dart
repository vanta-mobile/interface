import 'dart:math' as math;

import 'package:decimal/decimal.dart';

import 'account_snapshot.dart';

class LeverageBracket {
  const LeverageBracket({required this.maximum, required this.floor, required this.cap});
  final int maximum;
  final Decimal floor, cap;
}

class PositionLeverageContext {
  PositionLeverageContext({
    required this.address,
    required this.symbol,
    required this.current,
    required this.receivedAt,
    required Iterable<LeverageBracket> brackets,
    this.positionNotional,
  }) : brackets = List.unmodifiable(brackets);
  final String address, symbol;
  final int current;
  final DateTime receivedAt;
  final List<LeverageBracket> brackets;

  /// Absolute notional of this symbol's positions (all sides) from the same
  /// signed positionRisk read; null when the response omits it.
  final Decimal? positionNotional;

  /// The same read with the leverage a signed query verified after a change.
  PositionLeverageContext withCurrent(int leverage) => PositionLeverageContext(
    address: address,
    symbol: symbol,
    current: leverage,
    receivedAt: receivedAt,
    brackets: brackets,
    positionNotional: positionNotional,
  );

  /// Notional still openable at [leverage]: the largest bracket cap that
  /// allows it, less the existing position notional, never below zero.
  Decimal? remainingNotional(int leverage) {
    final held = positionNotional;
    Decimal? cap;
    for (final bracket in brackets) {
      if (bracket.maximum >= leverage && (cap == null || bracket.cap > cap)) cap = bracket.cap;
    }
    if (cap == null || held == null) return null;
    return cap > held ? cap - held : Decimal.zero;
  }

  // The documented mutation range is 1..125 even if a website badge or a
  // bracket advertises a higher maximum. Tighter exposure limits stay server-side.
  int get maximum => math.min(125, brackets.fold(0, (n, b) => math.max(n, b.maximum)));
  int? target(String input) {
    if (!RegExp(r'^[1-9]\d{0,2}$').hasMatch(input)) return null;
    final value = int.parse(input);
    return value <= maximum && value != current ? value : null;
  }
}

enum LeverageStep {
  idle,
  preparing,
  signingContext,
  loadingContext,
  signing,
  submitting,
  checkSigning,
  checking,
}

class LeverageIntent {
  const LeverageIntent({required this.context, required this.target, required this.revision});
  final PositionLeverageContext context;
  final int target, revision;
}

class LeverageResult {
  const LeverageResult({this.observed, this.failure, this.checkedAt});
  final int? observed;
  final DateTime? checkedAt;
  final AccountReadFailure? failure;
}

class PositionLeverageState {
  const PositionLeverageState({
    this.context,
    this.intent,
    this.result,
    this.failure,
    this.step = LeverageStep.idle,
    this.stale = false,
  });
  final PositionLeverageContext? context;
  final LeverageIntent? intent;
  final LeverageResult? result;
  final AccountReadFailure? failure;
  final LeverageStep step;
  final bool stale;
  bool get busy => step != LeverageStep.idle;
}

abstract interface class PositionLeverageRepository {
  Future<PositionLeverageContext> read({
    required String address,
    required String symbol,
    required bool Function() isCurrent,
    required void Function(LeverageStep) onStep,
  });
  Future<LeverageResult> change({
    required LeverageIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(LeverageStep) onStep,
  });
  Future<LeverageResult> recheck({
    required LeverageIntent intent,
    required bool Function() isCurrent,
    required void Function(LeverageStep) onStep,
  });
}
