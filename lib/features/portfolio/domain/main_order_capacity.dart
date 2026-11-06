import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

import 'aster_account.dart';
import 'futures_asset_mode.dart';
import 'live_order.dart';
import 'live_order_capacity.dart';
import 'live_order_opening_cost.dart';
import 'main_order_account_facts.dart';

/// Complete account rows for sizing. Unlike Portfolio, zero positions and
/// their open-order margin/configuration must be retained.
class CapacityAccount {
  CapacityAccount({
    required this.address,
    required this.receivedAt,
    required this.canTrade,
    required Iterable<CapacityAsset> assets,
    required Iterable<CapacityPosition> positions,
  }) : assets = List.unmodifiable(assets),
       positions = List.unmodifiable(positions);
  final String address;
  final DateTime receivedAt;
  final bool canTrade;
  final List<CapacityAsset> assets;
  final List<CapacityPosition> positions;
}

class CapacityAsset {
  const CapacityAsset({
    required this.asset,
    required this.available,
    required this.crossWallet,
    required this.crossPnl,
    required this.initialMargin,
    required this.marginAvailable,
  });
  final String asset;
  final Decimal available, crossWallet, crossPnl, initialMargin;
  final bool marginAvailable;
}

class CapacityPosition {
  const CapacityPosition({
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.entryPrice,
    required this.notional,
    required this.leverage,
    required this.isolated,
    required this.orderMargin,
    required this.maintenance,
    required this.maxNotional,
    required this.units,
    required this.isolatedWallet,
  });
  final String symbol, side;
  final Decimal quantity, entryPrice, notional, orderMargin, maintenance, maxNotional;
  final Decimal isolatedWallet;
  final int leverage;
  final bool isolated;
  final AsterContractUnits units;
}

class MainOrderCapacitySnapshot {
  const MainOrderCapacitySnapshot({
    required this.context,
    required this.account,
    required this.assetMode,
    required this.availableMargin,
    required this.exposure,
    required this.notionalCap,
    required this.contractCap,
    required this.receivedAt,
    this.marketFacts,
  });
  final LiveOrderContext context;
  final CapacityAccount account;
  final FuturesAssetMode assetMode;
  final Rational availableMargin;
  final LiveOrderOpeningExposure exposure;
  final Decimal notionalCap;
  final SymbolOpenableNotional contractCap;
  final DateTime receivedAt;
  final MainOrderAccountFacts? marketFacts;

  /// This snapshot supplies common facts, never a cached maximum from a
  /// different side, execution mode, quantity filter, or current price input.
  LiveOrderCapacity calculator(LiveOrderDraft draft) => LiveOrderCapacity(
    exposure: exposure,
    availableMargin: availableMargin,
    notionalCap: notionalCap,
    remainingOpenableNotional: contractCap.remaining,
    rule: context.rules.quantityRule(draft),
    minimumNotional: context.rules.minimumNotional,
  );
}

abstract interface class MainOrderCapacityRepository {
  Future<MainOrderCapacitySnapshot> read({
    required LiveOrderContext context,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  });
}

class MainOrderCapacityState {
  const MainOrderCapacityState({
    this.snapshot,
    this.loading = false,
    this.stale = false,
    this.failure,
  });
  final MainOrderCapacitySnapshot? snapshot;
  final bool loading, stale;
  final AccountReadFailure? failure;
}
