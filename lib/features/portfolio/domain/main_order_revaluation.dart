import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

import '../../market/domain/mark_prices.dart';
import '../../market/domain/order_reference_prices.dart';
import 'account_snapshot.dart';
import 'asset_valuation.dart';
import 'futures_asset_mode.dart';
import 'live_order.dart';
import 'live_order_capacity.dart';
import 'live_order_opening_cost.dart';
import 'main_order_capacity.dart';
import 'main_order_margin_budget.dart';
import 'main_order_pending_exposure.dart';
import 'position_margin_mode.dart';

/// A price-derived view of a signed anchor. Never changes the anchor's lifetime,
/// wallet/configuration identity or any user-approved base quantity.
class MainOrderRevaluation {
  MainOrderRevaluation({
    required this.anchor,
    required this.context,
    required this.availableMargin,
    required this.exposure,
    required this.checkedAt,
    required Map<String, CapacityAssetValuation> assets,
    this.indices,
  }) : assets = Map.unmodifiable(assets);
  final MainOrderCapacitySnapshot anchor;
  final LiveOrderContext context;
  final Rational availableMargin;
  final LiveOrderOpeningExposure exposure;
  final DateTime checkedAt;
  final Map<String, CapacityAssetValuation> assets;
  final AssetIndexSnapshot? indices;

  LiveOrderCapacity calculator(LiveOrderDraft draft) => LiveOrderCapacity(
    exposure: exposure,
    availableMargin: availableMargin,
    notionalCap: anchor.notionalCap,
    remainingOpenableNotional: anchor.contractCap.remaining,
    rule: context.rules.quantityRule(draft),
    minimumNotional: context.rules.minimumNotional,
  );
}

class CapacityAssetValuation {
  const CapacityAssetValuation({
    required this.crossPnl,
    required this.crossInitialMargin,
    required this.isolatedOrderMargin,
    required this.crossMaintenance,
    this.crossMarkPnl,
  });
  final Decimal crossPnl, crossMaintenance;

  /// Mark-only PnL for liquidation; sizing deliberately uses min(Mark, Last).
  final Decimal? crossMarkPnl;
  final Rational crossInitialMargin, isolatedOrderMargin;
}

/// PRD step2/step3: recompute all related cross PnL at min(mark,last), pending
/// exposure and initial/maintenance margins from exact public prices. Account
/// events must invalidate the anchor separately; quotes never refresh balances.
MainOrderRevaluation revalueMainOrderCapacity({
  required MainOrderCapacitySnapshot snapshot,
  required MarkPrices marks,
  required Map<String, OrderReferencePrices> references,
  required AssetIndexSnapshot? indices,
  required DateTime now,
}) {
  final context = snapshot.context, account = snapshot.account, facts = snapshot.marketFacts;
  final age = now.difference(context.receivedAt);
  if (age.isNegative || age >= const Duration(seconds: 30)) {
    throw const AccountReadFailure('liveOrderContextExpired');
  }
  if (facts == null ||
      !account.canTrade ||
      account.address.toLowerCase() != context.address.toLowerCase() ||
      facts.orders.address.toLowerCase() != context.address.toLowerCase() ||
      account.receivedAt.isBefore(context.receivedAt) ||
      snapshot.receivedAt.isAfter(now) ||
      account.receivedAt.isAfter(snapshot.receivedAt) ||
      facts.orders.receivedAt.isBefore(context.receivedAt) ||
      facts.orders.receivedAt.isAfter(snapshot.receivedAt)) {
    throw const AccountReadFailure('liveCapacityChanged');
  }
  final multi = snapshot.assetMode == FuturesAssetMode.multi;
  if (multi &&
      (context.marginMode != PositionMarginMode.cross ||
          account.positions.any(
            (p) =>
                p.isolated &&
                (p.quantity != Decimal.zero ||
                    p.orderMargin != Decimal.zero ||
                    p.isolatedWallet != Decimal.zero),
          ))) {
    throw const AccountReadFailure('liveCapacityChanged');
  }
  final eligible = {
    for (final a in account.assets)
      if (multi ? a.marginAvailable : a.asset == context.rules.quoteAsset) a.asset: a,
  };
  if (!eligible.containsKey(context.rules.quoteAsset)) {
    throw const AccountReadFailure('accountDataInvalid');
  }
  final groups = <String, List<CapacityPosition>>{};
  final keys = <String>{};
  for (final p in account.positions) {
    if (!keys.add('${p.symbol}:${p.side}') || p.units.margin != p.units.quote) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    if (eligible.containsKey(p.units.margin) || p.symbol == context.symbol) {
      groups.putIfAbsent(p.symbol, () => []).add(p);
    }
  }
  if (!groups.containsKey(context.symbol)) throw const AccountReadFailure('accountDataInvalid');
  for (final o in facts.orders.orders) {
    if (!keys.contains('${o.symbol}:${o.positionSide}')) {
      throw const AccountReadFailure('liveCapacityChanged');
    }
  }
  final crossPnl = <String, Decimal>{},
      markPnl = <String, Decimal>{},
      maintenance = <String, Decimal>{};
  final crossInitial = <String, Rational>{}, isolatedOrders = <String, Rational>{};
  final zero = Decimal.zero.toRational();
  LiveOrderOpeningExposure? selected;
  for (final group in groups.entries) {
    final symbol = group.key, rows = group.value;
    final needsMark = symbol == context.symbol || rows.any((p) => p.quantity != Decimal.zero);
    final mark = needsMark ? _mark(marks, symbol, now) : context.markPrice;
    final repriced = <CapacityPosition>[];
    for (final p in rows) {
      final notional = p.quantity * mark;
      if (p.quantity != Decimal.zero && p.entryPrice <= Decimal.zero) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      if (!p.isolated && p.quantity != Decimal.zero) {
        final last = _last(references[symbol], symbol, now);
        final currentMarkPnl = p.quantity * (mark - p.entryPrice);
        final lastPnl = p.quantity * (last - p.entryPrice);
        crossPnl.update(
          p.units.margin,
          (n) => n + _min(currentMarkPnl, lastPnl),
          ifAbsent: () => _min(currentMarkPnl, lastPnl),
        );
        markPnl.update(p.units.margin, (n) => n + currentMarkPnl, ifAbsent: () => currentMarkPnl);
        final tier = facts.riskTiers[symbol]?.where((t) => t.contains(notional.abs())).singleOrNull;
        if (tier == null) throw const AccountReadFailure('liveCapacityChanged');
        final mm = notional.abs() * tier.rate - tier.cumulative;
        if (mm < Decimal.zero) throw const AccountReadFailure('accountDataInvalid');
        maintenance.update(p.units.margin, (n) => n + mm, ifAbsent: () => mm);
      }
      repriced.add(
        CapacityPosition(
          symbol: symbol,
          side: p.side,
          quantity: p.quantity,
          entryPrice: p.entryPrice,
          notional: notional,
          leverage: p.leverage,
          isolated: p.isolated,
          orderMargin: p.orderMargin,
          maintenance: p.maintenance,
          maxNotional: p.maxNotional,
          units: p.units,
          isolatedWallet: p.isolatedWallet,
        ),
      );
    }
    final exposure = capacitySymbolExposure(
      symbol: symbol,
      mode: context.mode,
      markPrice: mark,
      positions: repriced,
      orders: facts.orders.orders.where((o) => o.symbol == symbol),
    );
    final marginAsset = rows.first.units.margin;
    if (rows.any((p) => p.units.margin != marginAsset)) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    final gross = repriced.fold(Decimal.zero, (n, p) => n + p.notional.abs());
    final divisor = Decimal.fromInt(rows.first.leverage);
    if (rows.first.isolated) {
      final extra = (exposure.currentNotional - gross) / divisor;
      if (extra < zero) throw const AccountReadFailure('accountDataInvalid');
      isolatedOrders.update(marginAsset, (n) => n + extra, ifAbsent: () => extra);
    } else {
      final initial = exposure.currentNotional / divisor;
      crossInitial.update(marginAsset, (n) => n + initial, ifAbsent: () => initial);
    }
    if (symbol == context.symbol) {
      selected = exposure;
    }
  }
  final assets = {
    for (final name in eligible.keys)
      name: CapacityAssetValuation(
        crossPnl: crossPnl[name] ?? Decimal.zero,
        crossInitialMargin: crossInitial[name] ?? zero,
        isolatedOrderMargin: isolatedOrders[name] ?? zero,
        crossMaintenance: maintenance[name] ?? Decimal.zero,
        crossMarkPnl: markPnl[name] ?? Decimal.zero,
      ),
  };
  final Rational budget;
  if (multi) {
    var equity = Decimal.zero, initial = zero;
    for (final asset in eligible.values) {
      final value = assets[asset.asset]!, amount = asset.crossWallet + value.crossPnl;
      if (amount == Decimal.zero && value.crossInitialMargin == zero) continue;
      final quote = mainOrderAssetRate(indices, asset.asset, now);
      equity += _min(amount * quote.bidRate!, amount * quote.askRate!);
      initial += value.crossInitialMargin * quote.askRate!.toRational();
    }
    budget =
        (equity.toRational() - initial) /
        mainOrderAssetRate(indices, context.rules.quoteAsset, now).askRate!.toRational();
  } else {
    final asset = eligible[context.rules.quoteAsset]!, value = assets[asset.asset]!;
    final available =
        (asset.crossWallet + value.crossPnl).toRational() -
        value.crossInitialMargin -
        value.isolatedOrderMargin;
    final transferable =
        (asset.crossWallet - value.crossMaintenance).toRational() - value.isolatedOrderMargin;
    budget = context.marginMode == PositionMarginMode.isolated && transferable < available
        ? transferable
        : available;
  }

  return MainOrderRevaluation(
    anchor: snapshot,
    context: mainOrderPriceContext(
      context: context,
      marks: marks,
      reference: references[context.symbol],
      now: now,
    ),
    availableMargin: budget,
    exposure: selected!,
    checkedAt: now,
    assets: assets,
    indices: indices,
  );
}

/// Price-only view for manual entry before the explicit signed capacity read.
LiveOrderContext mainOrderPriceContext({
  required LiveOrderContext context,
  required MarkPrices marks,
  required OrderReferencePrices? reference,
  required DateTime now,
}) {
  final book = reference;
  _last(book, context.symbol, now);
  if (book!.bookFailed) {
    throw book.bookFailure ?? _priceFailure('livePriceBookInvalid');
  }
  if (book.book == null) throw _priceFailure('livePriceBookMissing');
  if (book.book!.symbol != context.symbol ||
      book.book!.bid <= Decimal.zero ||
      book.book!.ask < book.book!.bid) {
    throw _priceFailure('livePriceBookInvalid');
  }
  if (!book.bookFresh || !_recent(book.book!.receivedAt, now)) {
    throw _priceFailure('livePriceBookStale');
  }
  return LiveOrderContext(
    address: context.address,
    rules: context.rules,
    mode: context.mode,
    marginMode: context.marginMode,
    leverage: context.leverage,
    markPrice: _mark(marks, context.symbol, now),
    receivedAt: context.receivedAt,
    positions: context.positions,
    bid: book.book!.bid,
    ask: book.book!.ask,
    lastPrice: book.trade!.price,
    markReceivedAt: marks.quotes[context.symbol]!.receivedAt,
    bookReceivedAt: book.book!.receivedAt,
    lastReceivedAt: book.trade!.receivedAt,
    funds: context.funds,
    fundsFailure: context.fundsFailure,
  );
}

AccountReadFailure _priceFailure(String reason) =>
    AccountReadFailure('liveCapacityPriceUnavailable', reasonKey: reason);

Decimal _mark(MarkPrices marks, String symbol, DateTime now) {
  if (marks.connection == MarkPriceConnection.offline) throw _priceFailure('livePriceDisconnected');
  if (marks.connection == MarkPriceConnection.connecting) {
    throw _priceFailure('livePriceConnecting');
  }
  if (marks.invalid.contains(symbol)) throw _priceFailure('livePriceMarkInvalid');
  final value = marks.quotes[symbol];
  if (value == null) throw marks.failure ?? _priceFailure('livePriceMarkMissing');
  if (value.symbol != symbol || value.price <= Decimal.zero) {
    throw _priceFailure('livePriceMarkInvalid');
  }
  if (!marks.fresh.contains(symbol) || !_recent(value.receivedAt, now)) {
    throw marks.failure ?? _priceFailure('livePriceMarkStale');
  }
  return value.price;
}

Decimal _last(OrderReferencePrices? value, String symbol, DateTime now) {
  if (value == null) throw _priceFailure('livePriceConnecting');
  if (value.symbol != symbol) throw _priceFailure('livePriceLastInvalid');
  if (value.connection == OrderPriceConnection.offline) {
    throw _priceFailure('livePriceDisconnected');
  }
  if (value.connection == OrderPriceConnection.connecting) {
    throw _priceFailure('livePriceConnecting');
  }
  if (value.tradeFailed) throw value.tradeFailure ?? _priceFailure('livePriceLastInvalid');
  if (value.trade == null) throw _priceFailure('livePriceLastMissing');
  if (value.trade!.symbol != symbol || value.trade!.price <= Decimal.zero) {
    throw _priceFailure('livePriceLastInvalid');
  }
  if (value.checkedAt.isAfter(now) || !value.tradeFresh || !_recent(value.trade!.receivedAt, now)) {
    throw _priceFailure('livePriceLastStale');
  }
  return value.trade!.price;
}

bool _recent(DateTime received, DateTime now) =>
    !received.isAfter(now) && now.difference(received) < const Duration(seconds: 10);
Decimal _min(Decimal a, Decimal b) => a < b ? a : b;
