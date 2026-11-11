import 'package:decimal/decimal.dart';

import '../domain/account_snapshot.dart';
import '../domain/asset_valuation.dart';
import '../domain/aster_open_orders.dart';
import '../domain/futures_asset_mode.dart';
import '../domain/futures_position_mode.dart';
import '../domain/live_order.dart';
import '../domain/live_order_capacity.dart';
import '../domain/main_order_capacity.dart';
import '../domain/main_order_account_facts.dart';
import '../domain/main_order_margin_budget.dart';
import '../domain/main_order_pending_exposure.dart';
import '../domain/position_leverage.dart';
import '../domain/position_margin_mode.dart';

List<CapacityPosition> validateCapacityAccountContext({
  required LiveOrderContext context,
  required CapacityAccount account,
  required FuturesAssetMode assetMode,
  required FuturesPositionMode positionMode,
  required DateTime now,
}) {
  final age = now.difference(context.receivedAt);
  if (age.isNegative || age >= const Duration(seconds: 30)) {
    throw const AccountReadFailure('liveOrderContextExpired');
  }
  if (account.address.toLowerCase() != context.address.toLowerCase()) {
    throw const AccountReadFailure('authWalletChanged');
  }
  if (context.funds == null ||
      context.fundsFailure != null ||
      context.funds!.account.address.toLowerCase() != context.address.toLowerCase() ||
      context.funds!.account.receivedAt.isBefore(context.receivedAt) ||
      context.funds!.account.receivedAt.isAfter(now) ||
      account.receivedAt.isBefore(context.receivedAt) ||
      account.receivedAt.isAfter(now) ||
      assetMode != context.funds!.assetMode ||
      positionMode != context.mode ||
      account.positions.any(
        (p) => !(positionMode == FuturesPositionMode.oneWay ? {'BOTH'} : {'LONG', 'SHORT'})
            .contains(p.side),
      )) {
    throw const AccountReadFailure('liveCapacityChanged');
  }
  if (!account.canTrade) throw const AccountReadFailure('liveOrderTradingDisabled');
  final rows = account.positions.where((p) => p.symbol == context.symbol).toList();
  final requiredSides = positionMode == FuturesPositionMode.oneWay ? {'BOTH'} : {'LONG', 'SHORT'};
  if (rows.length != requiredSides.length ||
      rows.map((p) => p.side).toSet().difference(requiredSides).isNotEmpty ||
      rows.any((p) {
        final before = context.positions[p.side];
        return before == null ||
            before.quantity != p.quantity ||
            p.quantity != Decimal.zero && before.entryPrice != p.entryPrice ||
            p.leverage != context.leverage ||
            p.isolated != (context.marginMode == PositionMarginMode.isolated) ||
            p.units.base != context.rules.baseAsset ||
            p.units.quote != context.rules.quoteAsset ||
            p.units.margin != context.rules.quoteAsset;
      })) {
    throw const AccountReadFailure('liveCapacityChanged');
  }
  return rows;
}

MainOrderCapacitySnapshot assembleMainOrderCapacity({
  required LiveOrderContext context,
  required CapacityAccount account,
  required FuturesAssetMode assetMode,
  required FuturesPositionMode positionMode,
  required AsterOpenOrders orders,
  required List<LeverageBracket> brackets,
  required SymbolOpenableNotional contractCap,
  required AssetIndexSnapshot? indices,
  required DateTime now,
  MainOrderAccountFacts? marketFacts,
}) {
  final rows = validateCapacityAccountContext(
    context: context,
    account: account,
    assetMode: assetMode,
    positionMode: positionMode,
    now: now,
  );
  if (orders.receivedAt.isBefore(context.receivedAt) ||
      orders.receivedAt.isAfter(now) ||
      contractCap.receivedAt.isBefore(context.receivedAt) ||
      contractCap.receivedAt.isAfter(now) ||
      contractCap.symbol != context.symbol ||
      contractCap.leverage != context.leverage ||
      contractCap.remaining != null && contractCap.remaining! < Decimal.zero) {
    throw const AccountReadFailure('liveCapacityChanged');
  }
  final caps = brackets.where((b) => b.maximum >= context.leverage).map((b) => b.cap).toList();
  if (caps.isEmpty) throw const AccountReadFailure('liveCapacityChanged');
  var cap = caps.reduce((a, b) => a > b ? a : b);
  for (final p in rows) {
    if (p.maxNotional < cap) cap = p.maxNotional;
  }
  final exposure = mainOrderPendingExposure(context: context, positions: rows, orders: orders);
  final budget = mainOrderMarginBudget(
    account: account,
    marginAsset: context.rules.quoteAsset,
    assetMode: assetMode,
    marginMode: context.marginMode,
    indices: indices,
    now: now,
  );
  return MainOrderCapacitySnapshot(
    context: context,
    account: account,
    assetMode: assetMode,
    availableMargin: budget,
    exposure: exposure,
    notionalCap: cap,
    contractCap: contractCap,
    receivedAt: now,
    marketFacts: marketFacts,
    maximumLeverage: brackets.map((b) => b.maximum).reduce((a, b) => a > b ? a : b),
  );
}
