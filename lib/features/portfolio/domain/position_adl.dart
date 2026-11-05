import 'position_risk.dart';
export 'account_snapshot.dart';

class PositionAdlSnapshot implements WalletAccountSnapshot {
  PositionAdlSnapshot({
    required this.address,
    required this.receivedAt,
    required Map<String, PositionAdlQuantiles> symbols,
  }) : symbols = Map.unmodifiable(symbols);
  @override
  final String address;
  @override
  final DateTime receivedAt;
  final Map<String, PositionAdlQuantiles> symbols;

  /// Never substitute HEDGE's marker value or another side's level.
  /// Positions and quantiles are independent snapshots; mode disagreement
  /// must remain unknown until the user refreshes the relevant snapshot.
  int? levelFor(PositionRisk position) {
    if (position.balanceOnly) return null;
    final row = symbols[position.symbol];
    if (row == null) return null;
    if (position.side == 'BOTH') {
      return row.crossedHedge ? null : row.levels['BOTH'];
    }
    if (row.crossedHedge != !position.isolated) return null;
    return row.levels[position.side];
  }
}

class PositionAdlQuantiles {
  PositionAdlQuantiles({required this.crossedHedge, required Map<String, int> levels})
    : levels = Map.unmodifiable(levels);
  final bool crossedHedge;
  final Map<String, int> levels;
}

typedef PositionAdlRepository = WalletAccountRepository<PositionAdlSnapshot>;
