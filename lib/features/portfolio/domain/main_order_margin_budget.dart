import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

import 'account_snapshot.dart';
import 'asset_valuation.dart';
import 'futures_asset_mode.dart';
import 'main_order_capacity.dart';
import 'position_margin_mode.dart';

Rational mainOrderMarginBudget({
  required CapacityAccount account,
  required String marginAsset,
  required FuturesAssetMode assetMode,
  required PositionMarginMode marginMode,
  required AssetIndexSnapshot? indices,
  required DateTime now,
}) {
  final asset = account.assets.where((a) => a.asset == marginAsset).singleOrNull;
  if (asset == null) throw const AccountReadFailure('accountDataInvalid');
  if (assetMode == FuturesAssetMode.single) {
    if (marginMode == PositionMarginMode.cross) return asset.available.toRational();
    var crossMaintenance = Decimal.zero, isolatedOrderMargin = Decimal.zero;
    for (final p in account.positions.where((p) => p.units.margin == marginAsset)) {
      if (p.isolated) {
        isolatedOrderMargin += p.orderMargin;
      } else {
        crossMaintenance += p.maintenance;
      }
    }
    final isolatedBudget = asset.crossWallet - crossMaintenance - isolatedOrderMargin;
    return (isolatedBudget < asset.available ? isolatedBudget : asset.available).toRational();
  }
  if (marginMode != PositionMarginMode.cross ||
      account.positions.any(
        (p) =>
            p.isolated &&
            (p.quantity != Decimal.zero ||
                p.orderMargin != Decimal.zero ||
                p.isolatedWallet != Decimal.zero),
      )) {
    throw const AccountReadFailure('liveCapacityChanged');
  }

  final denominator = mainOrderAssetRate(indices, marginAsset, now).askRate!;
  var equity = Decimal.zero, initialMargin = Decimal.zero;
  for (final a in account.assets.where((a) => a.marginAvailable)) {
    if (a.crossWallet + a.crossPnl == Decimal.zero && a.initialMargin == Decimal.zero) continue;
    final q = mainOrderAssetRate(indices, a.asset, now), amount = a.crossWallet + a.crossPnl;
    final bidValue = amount * q.bidRate!, askValue = amount * q.askRate!;
    equity += bidValue < askValue ? bidValue : askValue;
    initialMargin += a.initialMargin * q.askRate!;
  }
  // Keep the USD-to-margin-asset division rational; rounding a repeating ratio
  // here can move the final maximum order by an entire quantity step.
  return (equity - initialMargin) / denominator;
}

AssetUsdIndex mainOrderAssetRate(AssetIndexSnapshot? indices, String name, DateTime now) {
  final value = indices?.forAsset(name);
  if (indices == null ||
      value == null ||
      value.bidRate == null ||
      value.askRate == null ||
      value.bidRate! < Decimal.zero ||
      value.askRate! <= Decimal.zero ||
      value.bidRate! > value.askRate! ||
      indices.receivedAt.isAfter(now) ||
      now.difference(indices.receivedAt) >= const Duration(seconds: 60) ||
      value.time.isAfter(now.add(const Duration(seconds: 30))) ||
      now.difference(value.time) >= const Duration(seconds: 90)) {
    throw const AccountReadFailure('liveCapacityRatesUnavailable');
  }
  return value;
}
