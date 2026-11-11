import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/refresh_batch.dart';
import '../../auth/application/auth_provider.dart';
import '../data/portfolio_preview.dart';
import '../domain/portfolio_overview.dart';
import '../domain/asset_valuation.dart';
import 'account_read_provider.dart';
import 'asset_index_provider.dart';
import 'asset_metadata_refresh_provider.dart';

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
    positions: [
      for (final p in account.positions.where((p) => p.quantity != Decimal.zero))
        PortfolioPosition(
          symbol: p.symbol,
          side: p.side,
          long: p.long,
          quantity: p.quantity.abs(),
          base: p.units?.base,
          quote: p.units?.quote,
          marginAsset: p.units?.margin,
          entry: p.entryPrice,
          pnl: p.unrealizedProfit,
          margin: p.initialMargin,
          leverage: p.leverage,
          isolated: p.isolated,
        ),
    ],
  );
});

final portfolioRefreshProvider = Provider<Future<void> Function()>((ref) {
  final batch = RefreshBatch();
  return () async {
    if (ref.read(portfolioPreviewProvider)) return;
    await batch.run([
      if (!ref.read(authProvider).needsWalletConnection)
        ref.read(accountReadProvider.notifier).refresh,
      if (!ref.read(authProvider).needsWalletConnection)
        ref.read(assetIndexProvider.notifier).refresh,
      ref.read(assetMetadataRefreshProvider),
    ]);
  };
});
