import 'package:decimal/decimal.dart';

import '../../../core/domain/wallet_operation.dart';
import 'aster_account.dart';
import 'position_risk.dart';

enum MarginDirection { add, remove }

enum MarginAdjustmentStep { idle, reading, signing, submitting, checking }

class MarginRiskTier {
  const MarginRiskTier({
    required this.floor,
    required this.cap,
    required this.rate,
    required this.cumulative,
  });
  final Decimal floor, cap, rate, cumulative;
  bool contains(Decimal value) => value >= floor && value < cap;
}

/// Signed account and position snapshots are deliberately kept together.
class PositionMarginContext {
  PositionMarginContext({
    required this.account,
    required this.position,
    required this.receivedAt,
    required Iterable<MarginRiskTier> tiers,
  }) : tiers = List.unmodifiable(tiers);
  final AsterAccount account;
  final PositionRisk position;
  final DateTime receivedAt;
  final List<MarginRiskTier> tiers;
  String get asset => position.units!.margin;
  Decimal? get maintenance => account.positions
      .where((p) => p.symbol == position.symbol && p.side == position.side)
      .singleOrNull
      ?.maintenanceMargin;
  Decimal? get addMax {
    final balance = account.assets.where((a) => a.asset == asset).singleOrNull;
    if (balance?.availableBalance == null || balance?.crossWalletBalance == null) return null;
    var isolatedInitial = Decimal.zero, crossedMaintenance = Decimal.zero;
    for (final p in account.positions) {
      if (p.units == null || p.isolated == null) return null;
      if (p.units!.margin != asset) continue;
      final cost = p.isolated! ? p.initialMargin : p.maintenanceMargin;
      if (cost == null || cost < Decimal.zero) return null;
      if (p.isolated!) {
        isolatedInitial += cost;
      } else {
        crossedMaintenance += cost;
      }
    }
    return _positive(
      _min(
        balance!.availableBalance!,
        balance.crossWalletBalance! - isolatedInitial - crossedMaintenance,
      ),
    );
  }

  Decimal? get removeMax {
    final p = position, mm = maintenance;
    if (mm == null ||
        mm < Decimal.zero ||
        p.markPrice == null ||
        p.markPrice! <= Decimal.zero ||
        p.leverage == null ||
        p.leverage! < 1) {
      return null;
    }
    final initial = (p.quantity.abs() * p.markPrice! / Decimal.fromInt(p.leverage!)).toDecimal(
      scaleOnInfinitePrecision: 32,
      toBigInt: (r) => r.ceil(),
    );
    final pnl = p.quantity * (p.markPrice! - p.entryPrice);
    return _positive(_min(p.isolatedWallet - mm, p.isolatedWallet + pnl - initial));
  }

  Decimal? maximum(MarginDirection direction) =>
      direction == MarginDirection.add ? addMax : removeMax;
  Decimal? amount(String input, MarginDirection direction) {
    if (input.length > 100 || !RegExp(r'^(0|[1-9]\d*)(?:\.\d{1,8})?$').hasMatch(input)) return null;
    final n = Decimal.parse(input), max = maximum(direction);
    return n > Decimal.zero && max != null && n <= max ? n : null;
  }

  String? maxInput(MarginDirection direction) {
    final n = maximum(direction);
    if (n == null) return null;
    return n.floor(scale: 2).toStringAsFixed(2);
  }

  /// Solve wallet + q*(P-entry) = abs(q)*P*MMR-cum and require
  /// the candidate notional to belong to the same tier. No mark/last substitution.
  Decimal? liquidation(MarginDirection direction, Decimal adjustment) {
    final p = position, q = p.quantity;
    if (adjustment < Decimal.zero || q == Decimal.zero) return null;
    final wallet = p.isolatedWallet + (direction == MarginDirection.add ? adjustment : -adjustment);
    for (final tier in tiers) {
      final denominator = q - q.abs() * tier.rate;
      if (denominator == Decimal.zero) continue;
      final result = ((q * p.entryPrice - wallet - tier.cumulative) / denominator);
      if (result < Decimal.zero.toRational()) continue;
      // Use rational comparisons at tier boundaries before rounding the display.
      final notional = result * q.abs().toRational();
      if (notional >= tier.floor.toRational() && notional < tier.cap.toRational()) {
        return result.toDecimal(scaleOnInfinitePrecision: 24);
      }
    }
    return null;
  }

  bool samePosition(PositionMarginContext other) {
    final a = position, b = other.position;
    return account.address.toLowerCase() == other.account.address.toLowerCase() &&
        a.symbol == b.symbol &&
        a.side == b.side &&
        a.quantity == b.quantity &&
        a.entryPrice == b.entryPrice &&
        a.isolatedWallet == b.isolatedWallet &&
        a.leverage == b.leverage &&
        asset == other.asset &&
        tiers.length == other.tiers.length &&
        List.generate(
          tiers.length,
          (i) =>
              tiers[i].floor == other.tiers[i].floor &&
              tiers[i].cap == other.tiers[i].cap &&
              tiers[i].rate == other.tiers[i].rate &&
              tiers[i].cumulative == other.tiers[i].cumulative,
        ).every((v) => v);
  }
}

Decimal _min(Decimal a, Decimal b) => a < b ? a : b;
Decimal _positive(Decimal a) => a < Decimal.zero ? Decimal.zero : a;

class PositionMarginIntent {
  const PositionMarginIntent({
    required this.context,
    required this.direction,
    required this.amount,
    required this.reference,
    required this.revision,
  });
  final PositionMarginContext context;
  final MarginDirection direction;
  final Decimal amount;
  final String reference;
  final int revision;
}

class MarginAdjustmentResult {
  const MarginAdjustmentResult({
    required this.record,
    this.verified = false,
    this.position,
    this.failure,
    this.checkedAt,
    this.context,
    this.account,
    this.positions,
  });
  final WalletOperationRecord record;
  final bool verified;
  final PositionRisk? position;
  final AccountReadFailure? failure;
  final DateTime? checkedAt;
  final PositionMarginContext? context;
  final AsterAccount? account;
  final PositionRiskSnapshot? positions;
  bool get rejected => record.reference?.startsWith('rejected:') == true;
}

class PositionMarginState {
  const PositionMarginState({
    this.context,
    this.result,
    this.failure,
    this.step = MarginAdjustmentStep.idle,
    this.stale = false,
  });
  final PositionMarginContext? context;
  final MarginAdjustmentResult? result;
  final AccountReadFailure? failure;
  final MarginAdjustmentStep step;
  final bool stale;
  bool get busy => step != MarginAdjustmentStep.idle;
}

abstract interface class PositionMarginRepository {
  Future<PositionMarginContext> read({
    required String address,
    required String symbol,
    required String side,
    required bool Function() isCurrent,
    required void Function(MarginAdjustmentStep) onStep,
  });
  Future<MarginAdjustmentResult> change({
    required PositionMarginIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(MarginAdjustmentStep) onStep,
  });
  Future<MarginAdjustmentResult> check({
    required WalletOperationRecord record,
    required bool Function() isCurrent,
    required void Function(MarginAdjustmentStep) onStep,
  });
}
