import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

import 'account_snapshot.dart';
import 'futures_asset_mode.dart';
import 'live_order.dart';
import 'live_order_opening_cost.dart';
import 'main_order_capacity.dart';
import 'main_order_liquidation_solver.dart';
import 'main_order_margin_budget.dart';
import 'main_order_post_trade.dart';
import 'main_order_revaluation.dart';

/// Independent post-fill estimate, never the pre-order liquidationPrice field.
/// Missing facts, no residual position or no valid positive boundary return null.
Rational? mainOrderLiquidation({
  required MainOrderCapacitySnapshot snapshot,
  required MainOrderRevaluation? valuation,
  required LiveOrderContext context,
  required LiveOrderDraft draft,
  required Decimal quantity,
  required LiveOrderOpeningCost cost,
}) {
  if (valuation == null ||
      valuation.anchor != snapshot ||
      !context.sameAccountAnchor(snapshot.context)) {
    return null;
  }
  final age = valuation.checkedAt.difference(context.receivedAt);
  if (age.isNegative || age >= const Duration(seconds: 30)) return null;
  final facts = snapshot.marketFacts, zero = Rational.zero;
  final tiers = facts?.riskTiers[context.symbol];
  if (facts == null || tiers == null) return null;
  final post = mainOrderPostTrade(
    snapshot: snapshot,
    context: context,
    draft: draft,
    quantity: quantity,
    cost: cost,
  );
  if (post == null || post.quantity == Decimal.zero) return null;
  final target = post.original, margin = target.units.margin;
  final legs = <LiquidationLeg>[
    LiquidationLeg(quantity: post.quantity.toRational(), entryValue: post.entryValue),
  ];
  var wallet = post.isolatedWallet, otherPnl = zero, otherMaintenance = zero;
  var otherEquityLessMaintenance = zero, bid = Rational.one, ask = Rational.one;
  if (!target.isolated) {
    final asset = snapshot.account.assets.where((a) => a.asset == margin).singleOrNull;
    final values = valuation.assets[margin];
    if (asset == null || values?.crossMarkPnl == null) return null;
    wallet = asset.crossWallet.toRational() + post.crossWalletChange;
    otherPnl = values!.crossMarkPnl!.toRational();
    otherMaintenance = values.crossMaintenance.toRational();
    for (final p in snapshot.account.positions.where(
      (p) => p.symbol == context.symbol && !p.isolated,
    )) {
      final beforePnl = p.quantity * (context.markPrice - p.entryPrice);
      otherPnl -= beforePnl.toRational();
      if (p.quantity != Decimal.zero) {
        final n = (p.quantity * context.markPrice).abs();
        final tier = tiers.where((t) => t.contains(n)).singleOrNull;
        if (tier == null) return null;
        otherMaintenance -= (n * tier.rate - tier.cumulative).toRational();
      }
      if (p.side != target.side && p.quantity != Decimal.zero) {
        legs.add(
          LiquidationLeg(
            quantity: p.quantity.toRational(),
            entryValue: (p.quantity * p.entryPrice).toRational(),
          ),
        );
      }
    }
    if (otherMaintenance < zero) return null;
    if (snapshot.assetMode == FuturesAssetMode.multi) {
      if (!asset.marginAvailable) return null;
      try {
        final rate = mainOrderAssetRate(valuation.indices, margin, valuation.checkedAt);
        bid = rate.bidRate!.toRational();
        ask = rate.askRate!.toRational();
        for (final a in snapshot.account.assets.where(
          (a) => a.marginAvailable && a.asset != margin,
        )) {
          final value = valuation.assets[a.asset];
          if (value?.crossMarkPnl == null) return null;
          final amount = a.crossWallet + value!.crossMarkPnl!;
          if (amount == Decimal.zero && value.crossMaintenance == Decimal.zero) continue;
          final r = mainOrderAssetRate(valuation.indices, a.asset, valuation.checkedAt);
          final equityRate = amount < Decimal.zero ? r.askRate! : r.bidRate!;
          otherEquityLessMaintenance += (amount * equityRate - value.crossMaintenance * r.askRate!)
              .toRational();
        }
      } on AccountReadFailure {
        return null;
      }
    }
  }
  return solveMainOrderLiquidation(
    legs: legs,
    tiers: tiers,
    wallet: wallet + otherPnl,
    otherEquityLessMaintenance: otherEquityLessMaintenance,
    otherMaintenance: otherMaintenance,
    bidRate: bid,
    askRate: ask,
    mark: context.markPrice.toRational(),
  );
}
