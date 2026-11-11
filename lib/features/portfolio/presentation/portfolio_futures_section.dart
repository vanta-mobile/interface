import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/portfolio_loading_provider.dart';
import '../application/portfolio_overview_provider.dart';
import 'portfolio_account_feedback.dart';
import 'portfolio_assets.dart';
import 'portfolio_loading.dart';

/// Tab/filter intent stays local; changing it never rebuilds the page summary
/// or waits for account transport. Slivers build only visible position and asset rows.
class PortfolioFuturesSection extends ConsumerStatefulWidget {
  const PortfolioFuturesSection({super.key, required this.hidden});
  final bool hidden;

  @override
  ConsumerState<PortfolioFuturesSection> createState() => _PortfolioFuturesSectionState();
}

class _PortfolioFuturesSectionState extends ConsumerState<PortfolioFuturesSection> {
  bool assets = false, hideOther = false, hideSmall = false;

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(portfolioOverviewProvider);
    final preview = ref.watch(portfolioPreviewProvider);
    final loading = ref.watch(portfolioLoadingProvider);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: PortfolioAssetTabs(
            assets: assets,
            count: overview.positions.length,
            onChanged: (value) => setState(() => assets = value),
          ),
        ),
        if (loading.account)
          SliverToBoxAdapter(
            child: PortfolioListSkeleton(
              key: Key(assets ? 'portfolio-assets-loading' : 'portfolio-positions-loading'),
              assets: assets,
            ),
          )
        else if (assets)
          PortfolioAssetList(
            sliver: true,
            overview: overview,
            preview: preview,
            hidden: widget.hidden,
            hideSmall: hideSmall,
            valuationLoading: loading.valuation,
            onHideSmall: (value) => setState(() => hideSmall = value),
          )
        else
          PortfolioPositionList(
            overview: overview,
            preview: preview,
            hidden: widget.hidden,
            hideOther: hideOther,
            onHideOther: (value) => setState(() => hideOther = value),
          ),
        if (!preview) const SliverToBoxAdapter(child: PortfolioAccountFeedback()),
      ],
    );
  }
}
