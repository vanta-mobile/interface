import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/application/providers.dart';
import '../domain/portfolio_overview.dart';
import 'portfolio_components.dart';
import 'portfolio_header.dart';
import 'portfolio_position_card.dart';
import 'portfolio_asset_details.dart';
import 'futures_history_screen.dart';
import 'position_risk_screen.dart';
import '../../../core/presentation/status_view.dart';
import '../../funding/domain/funding_catalog.dart';
import '../../funding/presentation/funding_screen.dart';

class PortfolioAssetTabs extends StatelessWidget {
  const PortfolioAssetTabs({
    super.key,
    required this.assets,
    required this.count,
    required this.preview,
    required this.onChanged,
  });
  final bool assets, preview;
  final int count;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PortfolioColors.line)),
      ),
      child: Row(
        children: [
          for (final (value, label) in [
            (false, l.portfolioPositionsCount(count)),
            (true, l.portfolioAssets),
          ])
            Flexible(
              child: Semantics(
                selected: assets == value,
                child: TextButton(
                  key: Key('portfolio-assets-tab-${value ? 'assets' : 'positions'}'),
                  onPressed: () => onChanged(value),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(right: 20, top: 12),
                    minimumSize: const Size(0, 44),
                  ),
                  child: Column(
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: PortfolioTypography.section.copyWith(
                          color: assets == value ? PortfolioColors.text : PortfolioColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 1,
                        width: 48,
                        color: assets == value
                            ? PortfolioColors.accent
                            : PortfolioColors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            key: const Key('portfolio-orders-history'),
            tooltip: l.futuresHistoryTitle,
            onPressed: preview
                ? () => portfolioPreviewNotice(context)
                : () => openFuturesHistory(context),
            icon: const PortfolioIcon('orders.svg', size: 24, color: PortfolioColors.secondary),
          ),
        ],
      ),
    );
  }
}

class PortfolioPositionList extends ConsumerWidget {
  const PortfolioPositionList({
    super.key,
    required this.overview,
    required this.preview,
    required this.hidden,
    required this.hideOther,
    required this.onHideOther,
  });
  final PortfolioOverview overview;
  final bool preview, hidden, hideOther;
  final ValueChanged<bool> onHideOther;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), symbol = ref.watch(symbolProvider);
    final positions = overview.positions.where((p) => !hideOther || p.symbol == symbol);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => onHideOther(!hideOther),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      height: 44,
                      child: Checkbox(
                        value: hideOther,
                        onChanged: (v) => onHideOther(v ?? false),
                        side: const BorderSide(color: PortfolioColors.secondary, width: .7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.6)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(l.portfolioHideOtherSymbols, style: PortfolioTypography.caption),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              key: const Key('portfolio-close-all'),
              onPressed: preview
                  ? () => portfolioPreviewNotice(context)
                  : () => Navigator.of(context)
                        .push<void>(MaterialPageRoute(builder: (_) => const PositionRiskScreen())),
              child: Text(
                l.portfolioCloseAll,
                style: PortfolioTypography.caption.copyWith(color: PortfolioColors.negative),
              ),
            ),
          ],
        ),
        // Before the account loads, keep the compact note so the account
        // feedback below it stays in view.
        if (positions.isEmpty && overview.totalUsd == null)
          PortfolioEmpty(l.portfolioNoPositions)
        else if (positions.isEmpty)
          StatusEmptyView(
            key: const Key('portfolio-positions-empty'),
            message: l.portfolioNoPositions,
          )
        else
          for (final position in positions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PortfolioPositionCard(position: position, preview: preview, hidden: hidden),
            ),
      ],
    );
  }
}

class PortfolioAssetList extends StatelessWidget {
  const PortfolioAssetList({
    super.key,
    required this.overview,
    required this.preview,
    required this.hidden,
    required this.hideSmall,
    required this.onHideSmall,
  });
  final PortfolioOverview overview;
  final bool preview, hidden, hideSmall;
  final ValueChanged<bool> onHideSmall;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final assets = overview.assets.where(
      (a) => !hideSmall || a.usd == null || a.usd!.abs() >= Decimal.one,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          key: const Key('portfolio-hide-small-assets'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: hideSmall,
          onChanged: (v) => onHideSmall(v ?? false),
          title: Text(l.portfolioHideLowBalances, style: PortfolioTypography.caption),
        ),
        if (assets.isEmpty && overview.totalUsd == null)
          PortfolioEmpty(l.portfolioNoAssets)
        else if (assets.isEmpty)
          overview.assets.isEmpty
              ? StatusEmptyView(
                  key: const Key('portfolio-assets-empty'),
                  title: l.statusNoAssetsTitle,
                  message: l.statusNoAssetsMessage,
                  actionLabel: l.fundingDeposit,
                  onAction: () => preview
                      ? portfolioPreviewNotice(context)
                      : openFunding(context, FundingOperation.deposit),
                )
              : StatusEmptyView(
                  key: const Key('portfolio-assets-empty'),
                  title: l.statusNoResultsTitle,
                  message: l.portfolioNoAssets,
                )
        else
          for (final asset in assets) _AssetRow(asset: asset, hidden: hidden, preview: preview),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.asset, required this.hidden, required this.preview});
  final PortfolioAsset asset;
  final bool hidden, preview;
  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('portfolio-asset-${asset.symbol}'),
    onTap: () => showPortfolioAssetDetails(context, asset: asset, hidden: hidden, preview: preview),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          PortfolioAssetBadge(symbol: asset.symbol),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.symbol, style: PortfolioTypography.section),
                Text(
                  hidden ? '••••' : portfolioAmount(asset.pnl),
                  style: PortfolioTypography.caption.copyWith(color: portfolioPnlColor(asset.pnl)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hidden
                      ? '••••'
                      : '${portfolioAmount(asset.balance)} (${portfolioUsd(asset.usd)})',
                  textAlign: TextAlign.right,
                  style: PortfolioTypography.caption,
                ),
                Text(
                  hidden
                      ? '••••'
                      : AppLocalizations.of(context)
                            .portfolioAvailable(portfolioAmount(asset.available)),
                  textAlign: TextAlign.right,
                  style: PortfolioTypography.caption.copyWith(color: PortfolioColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
