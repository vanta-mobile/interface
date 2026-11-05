import 'package:decimal/decimal.dart';

import 'aster_account.dart';
export 'account_snapshot.dart';

class PositionRiskSnapshot implements WalletAccountSnapshot {
  PositionRiskSnapshot({
    required this.address,
    required this.receivedAt,
    required Iterable<PositionRisk> positions,
    this.lastEventAt,
    Map<String, DateTime> positionUpdatedAt = const {},
    Map<String, DateTime> positionEventAt = const {},
    Map<String, AsterContractUnits> units = const {},
  }) : positions = List.unmodifiable(positions),
       positionUpdatedAt = Map.unmodifiable(positionUpdatedAt),
       positionEventAt = Map.unmodifiable(positionEventAt),
       units = Map.unmodifiable(units);
  @override
  final String address;
  @override
  final DateTime receivedAt;
  final List<PositionRisk> positions;
  final DateTime? lastEventAt;
  final Map<String, DateTime> positionUpdatedAt;
  final Map<String, DateTime> positionEventAt;
  final Map<String, AsterContractUnits> units;
}

/// Event patches clear risk fields that the event does not provide. An event
/// PnL and its timestamp are distinct from REST and public mark estimates.
class PositionRisk {
  const PositionRisk({
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.entryPrice,
    required this.markPrice,
    required this.isolated,
    required this.isolatedWallet,
    required this.leverage,
    this.liquidationPrice,
    this.unrealizedProfit,
    this.notional,
    this.isolatedMargin,
    this.updatedAt,
    this.units,
    this.eventTime,
  });
  final String symbol, side;
  final Decimal quantity, entryPrice, isolatedWallet;
  final Decimal? markPrice, liquidationPrice, unrealizedProfit, notional, isolatedMargin;
  final bool isolated;
  final int? leverage;
  final DateTime? updatedAt, eventTime;
  final AsterContractUnits? units;
  bool get balanceOnly => quantity == Decimal.zero;
  bool get long => side == 'LONG' || (side == 'BOTH' && quantity > Decimal.zero);
}

typedef PositionRiskRepository = WalletAccountRepository<PositionRiskSnapshot>;
