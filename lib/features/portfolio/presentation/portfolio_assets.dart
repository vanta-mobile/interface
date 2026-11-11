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
import 'portfolio_asset_row.dart';
import 'position_risk_screen.dart';
import '../../../core/presentation/status_view.dart';
import '../../funding/domain/funding_catalog.dart';
import '../../funding/presentation/funding_screen.dart';

class PortfolioAssetTabs extends StatelessWidget {
  const PortfolioAssetTabs({
    super.key,
    required this.assets,
    required this.count,
    required this.onChanged,
  });
  final bool assets;
  final int count;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PortfolioColors.assetDivider)),
      ),
      child: Wrap(
        spacing: 20,
        children: [
          for (final (value, label) in [
            (false, l.portfolioPositionsCount(count)),
            (true, l.portfolioAssets),
          ])
            IntrinsicWidth(
              child: Semantics(
                selected: assets == value,
                child: TextButton(
                  key: Key('portfolio-assets-tab-${value ? 'assets' : 'positions'}'),
                  onPressed: () => onChanged(value),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(top: 12),
                    minimumSize: const Size(0, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        label,
                        style: PortfolioTypography.tab.copyWith(
                          color: assets == value ? PortfolioColors.text : PortfolioColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 1,
                        color: assets == value
                            ? PortfolioColors.accent
                            : PortfolioColors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
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
    final l = AppLocalizations.of(context);
    final symbol = hideOther ? ref.watch(symbolProvider) : null;
    final positions = overview.positions.where((p) => !hideOther || p.symbol == symbol).toList();
    String rowKey(PortfolioPosition p) => 'portfolio-position-${p.symbol}-${p.side}';
    final indices = {for (var i = 0; i < positions.length; i++) rowKey(positions[i]): i};
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _PositionControls(
            preview: preview,
            hasPositions: overview.positions.isNotEmpty,
            hideOther: hideOther,
            onHideOther: onHideOther,
          ),
        ),
        if (positions.isEmpty)
          SliverToBoxAdapter(
            child: overview.totalUsd == null
                ? PortfolioEmpty(l.portfolioNoPositions)
                : StatusEmptyView(
                    key: const Key('portfolio-positions-empty'),
                    message: l.portfolioNoPositions,
                  ),
          )
        else
          SliverList.builder(
            itemCount: positions.length,
            findChildIndexCallback: (key) => key is ValueKey<String> ? indices[key.value] : null,
            itemBuilder: (_, index) {
              final position = positions[index];
              return Padding(
                key: ValueKey(rowKey(position)),
                padding: const EdgeInsets.only(bottom: 12),
                child: PortfolioPositionCard(position: position, preview: preview, hidden: hidden),
              );
            },
          ),
      ],
    );
  }
}

class _PositionControls extends StatelessWidget {
  const _PositionControls({
    required this.preview,
    required this.hasPositions,
    required this.hideOther,
    required this.onHideOther,
  });
  final bool preview, hasPositions, hideOther;
  final ValueChanged<bool> onHideOther;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            key: const Key('portfolio-hide-other-symbols'),
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
        if (hasPositions)
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
    this.sliver = false,
    this.valuationLoading = false,
  });
  final PortfolioOverview overview;
  final bool preview, hidden, hideSmall, sliver, valuationLoading;
  final ValueChanged<bool> onHideSmall;

  @override
  Widget build(BuildContext context) {
    final assets = overview.assets
        .where((a) => !hideSmall || a.usd == null || a.usd!.abs() >= Decimal.one)
        .toList();
    final filter = _LowBalanceFilter(value: hideSmall, onChanged: onHideSmall);
    String rowKey(PortfolioAsset a) => 'portfolio-asset-${a.symbol}';
    Widget row(int index) => PortfolioAssetRow(
      key: ValueKey(rowKey(assets[index])),
      asset: assets[index],
      hidden: hidden,
      preview: preview,
      valuationLoading: valuationLoading,
    );
    const divider = Divider(height: 1, thickness: 1, color: PortfolioColors.assetDivider);
    if (sliver) {
      final indices = {for (var i = 0; i < assets.length; i++) rowKey(assets[i]): i};
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(child: filter),
          if (assets.isEmpty)
            SliverToBoxAdapter(child: _empty(context))
          else
            SliverList.separated(
              itemCount: assets.length,
              findItemIndexCallback: (key) => key is ValueKey<String> ? indices[key.value] : null,
              itemBuilder: (_, index) => row(index),
              separatorBuilder: (_, _) => divider,
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        filter,
        if (assets.isEmpty) _empty(context),
        for (var i = 0; i < assets.length; i++) ...[if (i > 0) divider, row(i)],
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (overview.totalUsd == null) return PortfolioEmpty(l.portfolioNoAssets);
    if (overview.assets.isNotEmpty) {
      return StatusEmptyView(
        key: const Key('portfolio-assets-empty'),
        title: l.statusNoResultsTitle,
        message: l.portfolioNoAssets,
      );
    }
    return StatusEmptyView(
      key: const Key('portfolio-assets-empty'),
      title: l.statusNoAssetsTitle,
      message: l.statusNoAssetsMessage,
      actionLabel: l.fundingDeposit,
      onAction: () => preview
          ? portfolioPreviewNotice(context)
          : openFunding(context, FundingOperation.deposit),
    );
  }
}

class _LowBalanceFilter extends StatelessWidget {
  const _LowBalanceFilter({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    checked: value,
    child: InkWell(
      key: const Key('portfolio-hide-small-assets'),
      onTap: () => onChanged(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 14,
              child: Transform.scale(
                scale: 14 / 18,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  side: const BorderSide(color: PortfolioColors.secondary, width: .7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.6)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                AppLocalizations.of(context).portfolioHideLowBalances,
                style: PortfolioTypography.caption,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
