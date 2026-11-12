import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/refresh_batch.dart';
import '../../auth/application/auth_provider.dart';
import '../../funding/application/funding_activity_poll_provider.dart';
import '../data/portfolio_preview.dart';
import '../domain/portfolio_overview.dart';
import '../domain/asset_valuation.dart';
import 'account_read_provider.dart';
import 'asset_index_provider.dart';
import 'asset_metadata_refresh_provider.dart';
import 'open_orders_provider.dart';
import 'position_risk_provider.dart';
import '../domain/position_risk.dart';
import 'portfolio_stats_provider.dart';

final portfolioPreviewProvider = NotifierProvider<PortfolioPreviewController, bool>(
  PortfolioPreviewController.new,
);

class PortfolioPreviewController extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authProvider.select((s) => s.identity?.id), (_, _) => state = false);
    return false;
  }

  void select(bool preview) => state = preview;
}

final portfolioOverviewProvider = Provider<PortfolioOverview>((ref) {
  if (ref.watch(portfolioPreviewProvider)) return portfolioPreview();
  final accountState = ref.watch(accountReadProvider);
  final account = accountState.account;
  if (ref.watch(authProvider.select((s) => s.identity)) == null) {
    return PortfolioOverview(performance: PortfolioPerformance());
  }
  final prices = ref.watch(assetIndexProvider);
  if (account == null) return PortfolioOverview(performance: PortfolioPerformance());
  final assets = [
    for (final a in account.assets)
      PortfolioAsset(
        symbol: a.asset,
        balance: a.walletBalance,
        available: a.availableBalance,
        pnl: a.unrealizedProfit,
        pnlUsd: a.unrealizedProfit == null
            ? null
            : AssetAmountValue(a.unrealizedProfit!, a.asset, prices).usd,
        margin: a.unrealizedProfit == null ? null : a.walletBalance + a.unrealizedProfit!,
        usd: AssetAmountValue(a.walletBalance, a.asset, prices).usd,
      ),
  ];
  final wallet = AssetWalletValue(
    account.assets.map((a) => AssetAmountValue(a.walletBalance, a.asset, prices)),
    prices,
  );
  return PortfolioOverview(
    totalUsd: wallet.missing == 0 ? wallet.usd : null,
    partialValue: wallet.missing > 0,
    staleValue: accountState.stale || wallet.stale > 0,
    performance: PortfolioPerformance(),
    assets: assets,
  );
});

/// Open positions on the Portfolio page come from the same position-risk read
/// as the Futures Positions tab, so both pages render one card. Null while the
/// first read is pending or failed.
final portfolioPositionsProvider = Provider<List<PositionRisk>?>((ref) {
  if (ref.watch(portfolioPreviewProvider)) return portfolioPreviewPositions();
  if (ref.watch(authProvider.select((s) => s.identity)) == null) return const [];
  return ref
      .watch(positionRiskProvider.select((s) => s.account?.positions))
      ?.where((p) => !p.balanceOnly)
      .toList();
});

/// [calendarMonth] is the PnL calendar month currently shown, if any.
final portfolioRefreshProvider = Provider<Future<void> Function({DateTime? calendarMonth})>((ref) {
  final batch = RefreshBatch();
  return ({calendarMonth}) async {
    if (ref.read(portfolioPreviewProvider)) return;
    await batch.run([
      () => refreshPortfolioStats(ref, calendarMonth: calendarMonth),
      if (!ref.read(authProvider).needsWalletConnection)
        () async {
          await ref.read(accountReadProvider.notifier).refresh();
          if (ref.mounted) await ref.read(refreshFundingActivityProvider)();
          // Position cards also show open-order TP/SL; refresh reads already made.
          if (ref.mounted && ref.read(openOrdersReadProvider).account != null) {
            await ref.read(openOrdersReadProvider.notifier).refresh();
          }
          if (ref.mounted &&
              (ref.read(positionRiskProvider).account != null ||
                  ref.read(positionRiskProvider).failure != null)) {
            await ref.read(positionRiskProvider.notifier).refresh();
          }
        },
      if (!ref.read(authProvider).needsWalletConnection)
        ref.read(assetIndexProvider.notifier).refresh,
      ref.read(assetMetadataRefreshProvider),
    ]);
  };
});
