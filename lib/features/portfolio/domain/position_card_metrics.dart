import 'dart:math' as math;

import 'package:decimal/decimal.dart';

import 'aster_account.dart';
import 'aster_open_orders.dart';
import 'asset_valuation.dart';
import 'futures_asset_mode.dart';
import 'isolated_margin_ratio.dart';
import 'position_risk.dart';

/// Margin Ratio (Futures PRD, Positions «margin ratio»): maintenance margin
/// over margin balance in the same risk scope, in percent at full precision.
/// - Isolated: that position's `maintMargin` / (`isolatedWallet` +
///   `unrealizedProfit`), from the same signed account row.
/// - Single-asset cross: cross `maintMargin` of the margin asset's positions /
///   that asset's `crossWalletBalance` + `crossUnPnl`.
/// - Multi-asset cross: Σ(cross `maintMargin` × askRate) / Σ min(E × askRate,
///   E × bidRate) over margin-eligible assets, E = wallet + PnL, using fresh
///   public USD index rates.
/// Null when the account read is another wallet's, the asset mode is unknown,
/// a term is missing or event-patched, a rate is stale, or the balance ≤ 0.
Decimal? positionMarginRatio(
  PositionRisk position,
  AsterAccount? account,
  String address, {
  FuturesAssetMode? assetMode,
  AssetIndexState? rates,
}) {
  if (account == null ||
      position.balanceOnly ||
      account.address.toLowerCase() != address.toLowerCase()) {
    return null;
  }
  if (position.isolated) {
    for (final row in account.positions) {
      if (row.symbol == position.symbol && row.side == position.side) {
        return isolatedMarginRatio(row).percent;
      }
    }
    return null;
  }
  final maintenance = _crossMaintenance(account.positions);
  if (maintenance == null) return null;
  Decimal? equity(AsterAssetBalance asset) {
    final wallet = asset.crossWalletBalance, pnl = asset.crossUnrealizedProfit;
    // Events carry no crossed PnL; never mix them with an older REST aggregate.
    if (asset.eventTime != null || wallet == null || pnl == null) return null;
    return wallet + pnl;
  }

  Decimal numerator = Decimal.zero, denominator = Decimal.zero;
  switch (assetMode) {
    case FuturesAssetMode.single:
      final margin = position.units?.margin;
      final asset = account.assets.where((a) => a.asset == margin).firstOrNull;
      final value = asset == null ? null : equity(asset);
      if (value == null) return null;
      numerator = maintenance[margin] ?? Decimal.zero;
      denominator = value;
    case FuturesAssetMode.multi:
      // Every asset with cross requirements must be margin-eligible.
      for (final asset in maintenance.keys) {
        if (account.assets.where((a) => a.asset == asset && a.marginAvailable == true).isEmpty) {
          return null;
        }
      }
      for (final asset in account.assets) {
        if (asset.marginAvailable == null) return null;
        if (!asset.marginAvailable!) continue;
        final value = equity(asset);
        final quote = rates?.snapshot?.forAsset(asset.asset);
        final bid = quote?.bidRate, ask = quote?.askRate;
        if (value == null || bid == null || ask == null || !rates!.fresh(quote!)) return null;
        final bidValue = value * bid, askValue = value * ask;
        denominator += bidValue < askValue ? bidValue : askValue;
        numerator += (maintenance[asset.asset] ?? Decimal.zero) * ask;
      }
    case null:
      return null;
  }
  if (denominator <= Decimal.zero || numerator < Decimal.zero) return null;
  return (numerator * Decimal.fromInt(100) / denominator).toDecimal(scaleOnInfinitePrecision: 24);
}

/// Cross maintenance margin per margin asset, or null when an open position's
/// mode, units or requirement is unknown.
Map<String, Decimal>? _crossMaintenance(Iterable<AsterPosition> positions) {
  final totals = <String, Decimal>{};
  for (final row in positions) {
    if (row.quantity == Decimal.zero || row.isolated == true) continue;
    final asset = row.units?.margin, value = row.maintenanceMargin;
    if (row.isolated == null || asset == null || value == null || value < Decimal.zero) {
      return null;
    }
    totals[asset] = (totals[asset] ?? Decimal.zero) + value;
  }
  return totals;
}

/// Needle rotation of the margin-ratio gauge, clockwise in radians from the
/// design's left-pointing needle. The arc sweeps 270° clockwise from its
/// lower-left end (0%) over the top to its lower-right end (100%, the
/// liquidation boundary), so the left direction sits at 45° (≈16.7%).
double marginGaugeRotation(Decimal ratio) {
  final share = (ratio / Decimal.fromInt(100)).toDouble().clamp(0, 1).toDouble();
  return (share * 270 - 45) * math.pi / 180;
}

/// Share of the entry-to-liquidation distance the mark has already moved,
/// clamped to 0–1 (0 while the position is at or beyond its entry in profit).
/// A drawing ratio only; null without a positive entry and liquidation price.
double? liquidationProgress({Decimal? entry, Decimal? mark, Decimal? liquidation}) {
  if (entry == null ||
      mark == null ||
      liquidation == null ||
      entry <= Decimal.zero ||
      liquidation <= Decimal.zero ||
      liquidation == entry) {
    return null;
  }
  return ((mark - entry) / (liquidation - entry)).toDouble().clamp(0, 1).toDouble();
}

/// Open take-profit / stop-loss orders that close one position. Entire orders
/// close the whole position (`closePosition`); partial orders carry their own
/// reduce quantity. The newest order of each kind is shown.
class PositionExitOrders {
  const PositionExitOrders({
    this.entireTakeProfit,
    this.entireStopLoss,
    this.partialTakeProfit,
    this.partialStopLoss,
    this.partialCount = 0,
  });
  final AsterOpenOrder? entireTakeProfit, entireStopLoss, partialTakeProfit, partialStopLoss;
  final int partialCount;
}

const _takeProfitTypes = {'TAKE_PROFIT', 'TAKE_PROFIT_MARKET'};
const _stopLossTypes = {'STOP', 'STOP_MARKET'};

PositionExitOrders positionExitOrders(PositionRisk position, Iterable<AsterOpenOrder> orders) {
  AsterOpenOrder? entireTp, entireSl, partialTp, partialSl;
  var partialCount = 0;
  AsterOpenOrder newer(AsterOpenOrder? current, AsterOpenOrder next) =>
      current == null || (next.time?.isAfter(current.time ?? next.time!) ?? false) ? next : current;
  for (final order in orders) {
    final takeProfit = _takeProfitTypes.contains(order.type);
    if (order.symbol != position.symbol ||
        order.positionSide != position.side ||
        order.side != (position.long ? 'SELL' : 'BUY') ||
        !takeProfit && !_stopLossTypes.contains(order.type) ||
        // One-way rows close only when marked; hedge rows close their side.
        position.side == 'BOTH' && !order.reduceOnly && !order.closePosition) {
      continue;
    }
    if (order.closePosition) {
      takeProfit ? entireTp = newer(entireTp, order) : entireSl = newer(entireSl, order);
    } else {
      partialCount++;
      takeProfit ? partialTp = newer(partialTp, order) : partialSl = newer(partialSl, order);
    }
  }
  return PositionExitOrders(
    entireTakeProfit: entireTp,
    entireStopLoss: entireSl,
    partialTakeProfit: partialTp,
    partialStopLoss: partialSl,
    partialCount: partialCount,
  );
}
