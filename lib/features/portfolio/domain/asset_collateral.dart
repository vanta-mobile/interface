import 'package:decimal/decimal.dart';

import '../../market/domain/mark_prices.dart';
import 'aster_account.dart';
import 'asset_valuation.dart';

enum AssetCollateralIssue { eligibilityUnknown, ineligible, equityUnknown, events, ratesUnknown }

/// A reference contribution from two independently dated snapshots. Never an
/// order budget, a withdrawal allowance, or evidence of the active margin mode.
class AssetCollateralValue {
  const AssetCollateralValue._({
    this.usd,
    this.equity,
    this.quote,
    this.issue,
    this.fresh = false,
    this.livePnl = false,
    this.markTime,
  });
  factory AssetCollateralValue({
    required AsterAssetBalance asset,
    required AssetIndexState prices,
    required DateTime accountReceivedAt,
    bool accountStale = false,
    bool hasAccountEvents = false,
    AssetCrossPnl? liveCrossPnl,
  }) {
    if (asset.marginAvailable == null) {
      return const AssetCollateralValue._(issue: AssetCollateralIssue.eligibilityUnknown);
    }
    if (!asset.marginAvailable!) {
      return const AssetCollateralValue._(issue: AssetCollateralIssue.ineligible);
    }
    // ACCOUNT_UPDATE does not provide aggregate crossed PnL. Never mix an old
    // REST aggregate with new wallet/position data or infer zero for a missing field.
    if (hasAccountEvents || asset.eventTime != null) {
      return const AssetCollateralValue._(issue: AssetCollateralIssue.events);
    }
    final wallet = asset.crossWalletBalance;
    final pnl = liveCrossPnl?.pnl ?? asset.crossUnrealizedProfit;
    if (wallet == null || pnl == null) {
      return const AssetCollateralValue._(issue: AssetCollateralIssue.equityUnknown);
    }
    final equity = wallet + pnl, quote = prices.snapshot?.forAsset(asset.asset);
    final bid = quote?.bidRate, ask = quote?.askRate;
    if (bid == null || ask == null || bid < Decimal.zero || bid > ask) {
      return AssetCollateralValue._(equity: equity, issue: AssetCollateralIssue.ratesUnknown);
    }
    final bidValue = equity * bid, askValue = equity * ask;
    final age = prices.checkedAt.difference(accountReceivedAt.toUtc());
    return AssetCollateralValue._(
      usd: bidValue < askValue ? bidValue : askValue,
      equity: equity,
      quote: quote,
      livePnl: liveCrossPnl?.pnl != null,
      markTime: liveCrossPnl?.oldestMark,
      fresh:
          !accountStale &&
          !age.isNegative &&
          age < const Duration(seconds: 60) &&
          prices.fresh(quote!) &&
          (liveCrossPnl?.pnl == null || liveCrossPnl!.fresh),
    );
  }
  final Decimal? usd, equity;
  final AssetUsdIndex? quote;
  final AssetCollateralIssue? issue;
  final bool fresh, livePnl;
  final DateTime? markTime;
}

/// All relevant crossed positions must have complete linear-contract units,
/// explicit crossed mode, entry price and mark. Otherwise retain the distinctly
/// labelled signed snapshot rather than mixing live and old position PnL.
class AssetCrossPnl {
  const AssetCrossPnl._({this.pnl, this.fresh = false, this.oldestMark});
  factory AssetCrossPnl(Iterable<AsterPosition> positions, MarkPrices marks) {
    final rows = positions.toList();
    if (rows.isEmpty) return const AssetCrossPnl._();
    var total = Decimal.zero;
    var allFresh = true;
    DateTime? oldest;
    for (final position in rows) {
      final entry = position.entryPrice;
      final quote = marks.quotes[position.symbol];
      if (!supportsCollateralMarkPnl(position) ||
          quote == null ||
          quote.price <= Decimal.zero ||
          marks.invalid.contains(position.symbol)) {
        return const AssetCrossPnl._();
      }
      total += position.quantity * (quote.price - entry!);
      allFresh =
          allFresh &&
          marks.fresh.contains(position.symbol) &&
          marks.connection == MarkPriceConnection.online;
      if (oldest == null || quote.eventTime.isBefore(oldest)) oldest = quote.eventTime;
    }
    return AssetCrossPnl._(pnl: total, fresh: allFresh, oldestMark: oldest);
  }
  final Decimal? pnl;
  final bool fresh;
  final DateTime? oldestMark;
}

bool supportsCollateralMarkPnl(AsterPosition position) =>
    position.isolated == false &&
    position.units != null &&
    position.units!.margin == position.units!.quote &&
    position.entryPrice != null &&
    position.entryPrice! > Decimal.zero;

/// Preserve unknown units/modes so they prevent a misleading partial live sum.
List<AsterPosition> collateralPositions(Iterable<AsterPosition> positions, String asset) =>
    List.unmodifiable(
      positions.where(
        (p) =>
            p.quantity != Decimal.zero &&
            p.isolated != true &&
            (p.units == null || p.units!.margin == asset),
      ),
    );
