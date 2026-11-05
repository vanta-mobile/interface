import 'package:decimal/decimal.dart';

import 'account_snapshot.dart';
export 'account_snapshot.dart';

/// Values retain their asset units. USDT summary fields are not a valuation
/// of every deposited asset, nor an aggregate of Spot and other accounts.
class AsterAccount implements WalletAccountSnapshot {
  AsterAccount({
    required this.address,
    required this.receivedAt,
    required Iterable<AsterAssetBalance> assets,
    required Iterable<AsterPosition> positions,
    this.walletBalance,
    this.marginBalance,
    this.availableBalance,
    this.unrealizedProfit,
    this.initialMargin,
    this.canTrade,
    this.lastEventAt,
    Map<String, DateTime> assetUpdatedAt = const {},
    Map<String, DateTime> positionUpdatedAt = const {},
    Map<String, DateTime> assetEventAt = const {},
    Map<String, DateTime> positionEventAt = const {},
    Map<String, AsterContractUnits> units = const {},
  }) : assets = List.unmodifiable(assets),
       positions = List.unmodifiable(positions),
       assetUpdatedAt = Map.unmodifiable(assetUpdatedAt),
       positionUpdatedAt = Map.unmodifiable(positionUpdatedAt),
       assetEventAt = Map.unmodifiable(assetEventAt),
       positionEventAt = Map.unmodifiable(positionEventAt),
       units = Map.unmodifiable(units);

  @override
  final String address;
  @override
  final DateTime receivedAt;
  final Decimal? walletBalance, marginBalance, availableBalance, unrealizedProfit, initialMargin;
  final bool? canTrade;
  final List<AsterAssetBalance> assets;
  final List<AsterPosition> positions;
  final DateTime? lastEventAt;
  // Include zero/hidden REST rows so delayed events cannot reopen them.
  final Map<String, DateTime> assetUpdatedAt, positionUpdatedAt;
  final Map<String, DateTime> assetEventAt, positionEventAt;
  final Map<String, AsterContractUnits> units;
}

class AsterAssetBalance {
  const AsterAssetBalance({
    required this.asset,
    required this.walletBalance,
    this.availableBalance,
    this.unrealizedProfit,
    this.marginAvailable,
    this.crossWalletBalance,
    this.crossUnrealizedProfit,
    this.eventTime,
  });
  final String asset;
  final Decimal walletBalance;
  final Decimal? availableBalance, unrealizedProfit;
  final bool? marginAvailable;
  final Decimal? crossWalletBalance, crossUnrealizedProfit;
  final DateTime? eventTime;
}

class AsterPosition {
  const AsterPosition({
    required this.symbol,
    required this.side,
    required this.quantity,
    this.entryPrice,
    this.unrealizedProfit,
    this.initialMargin,
    this.maintenanceMargin,
    this.leverage,
    this.isolated,
    this.units,
    this.eventTime,
    this.isolatedWallet,
  });
  final String symbol, side;
  final Decimal quantity;
  final Decimal? entryPrice, unrealizedProfit, initialMargin, maintenanceMargin;
  final int? leverage;
  final bool? isolated;
  final AsterContractUnits? units;
  final DateTime? eventTime;
  final Decimal? isolatedWallet;
  bool get long => side == 'LONG' || (side == 'BOTH' && quantity > Decimal.zero);
}

class AsterContractUnits {
  const AsterContractUnits({required this.base, required this.quote, required this.margin});
  final String base, quote, margin;
}

typedef AccountReadState = AccountSnapshotState<AsterAccount>;
typedef AsterAccountRepository = WalletAccountRepository<AsterAccount>;
