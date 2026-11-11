import 'package:decimal/decimal.dart';

/// Display-ready immutable domain data. Null means unavailable, never zero.
class PortfolioPerformance {
  PortfolioPerformance({
    this.pnl,
    this.returnPercent,
    this.volume,
    this.todayPnl,
    this.todayPercent,
    Iterable<Decimal> history = const [],
    Map<DateTime, Decimal> dailyPnl = const {},
    this.start,
    this.end,
  }) : history = List.unmodifiable(history),
       dailyPnl = Map.unmodifiable(dailyPnl);
  final Decimal? pnl, returnPercent, volume, todayPnl, todayPercent;
  final List<Decimal> history;
  final Map<DateTime, Decimal> dailyPnl;
  final DateTime? start, end;
}

class PortfolioAsset {
  const PortfolioAsset({
    required this.symbol,
    required this.balance,
    this.available,
    this.margin,
    this.pnl,
    this.usd,
    this.pnlUsd,
  });
  final String symbol;
  final Decimal balance;
  final Decimal? available, margin, pnl, usd;

  /// USD valuation of [pnl]; [pnl] retains the asset's native units.
  final Decimal? pnlUsd;
}

class PortfolioPosition {
  const PortfolioPosition({
    required this.symbol,
    required this.side,
    required this.long,
    required this.quantity,
    this.base,
    this.quote,
    this.marginAsset,
    this.entry,
    this.mark,
    this.liquidation,
    this.pnl,
    this.margin,
    this.notional,
    this.leverage,
    this.isolated,
    this.returnPercent,
    this.riskPercent,
  });
  final String symbol, side;
  final String? base, quote, marginAsset;
  final bool long;
  final bool? isolated;
  final int? leverage;
  final Decimal quantity;
  final Decimal? entry, mark, liquidation, pnl, margin, notional, returnPercent, riskPercent;
}

class PortfolioOverview {
  PortfolioOverview({
    required this.performance,
    this.totalUsd,
    Iterable<PortfolioAsset> assets = const [],
    Iterable<PortfolioPosition> positions = const [],
    this.partialValue = false,
    this.staleValue = false,
  }) : assets = List.unmodifiable(_assetsByUsd(assets)),
       positions = List.unmodifiable(positions);
  final Decimal? totalUsd;
  final PortfolioPerformance performance;
  final List<PortfolioAsset> assets;
  final List<PortfolioPosition> positions;
  final bool partialValue, staleValue;
}

/// Highest USD balance first; missing estimates follow known values. Keep the
/// source order for ties so equal/unknown balances do not shuffle on refresh.
Iterable<PortfolioAsset> _assetsByUsd(Iterable<PortfolioAsset> assets) {
  final indexed = assets.indexed.toList()
    ..sort((a, b) {
      final left = a.$2.usd, right = b.$2.usd;
      final order = left == null
          ? right == null
                ? 0
                : 1
          : right == null
          ? -1
          : right.compareTo(left);
      return order == 0 ? a.$1.compareTo(b.$1) : order;
    });
  return indexed.map((entry) => entry.$2);
}
