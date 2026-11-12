import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/animated_number_text.dart';
import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../funding/domain/funding_catalog.dart';
import '../../funding/presentation/funding_screen.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/portfolio_account_load_provider.dart';
import '../application/portfolio_loading_provider.dart';
import '../application/portfolio_overview_provider.dart';
import '../domain/portfolio_overview.dart';
import 'portfolio_account_feedback.dart';
import 'portfolio_assets.dart';
import 'portfolio_components.dart';
import 'portfolio_header.dart';
import 'portfolio_loading.dart';

/// Shares account reads, valuation, sorting and lazy rows with the asset page.
class TradeAssetsSection extends ConsumerStatefulWidget {
  const TradeAssetsSection({super.key});

  @override
  ConsumerState<TradeAssetsSection> createState() => _TradeAssetsSectionState();
}

class _TradeAssetsSectionState extends ConsumerState<TradeAssetsSection> {
  bool hideSmall = false;

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(portfolioPreviewProvider);
    final active = !ref.watch(authProvider.select((s) => s.needsWalletConnection));
    final overview = ref.watch(portfolioOverviewProvider);
    final loading = ref.watch(portfolioLoadingProvider);
    ref.watch(portfolioAccountLoadProvider);
    final l = AppLocalizations.of(context);
    return SliverMainAxisGroup(
      slivers: [
        if (preview)
          SliverToBoxAdapter(
            child: Text(l.portfolioPreviewNotice, style: PortfolioTypography.caption),
          ),
        if (!active && !preview)
          SliverToBoxAdapter(
            child: TextButton(
              key: const Key('trade-assets-login'),
              onPressed: () => showAccountSheet(context),
              child: Text(l.authWalletContinue),
            ),
          )
        else if (loading.account)
          const SliverToBoxAdapter(
            child: PortfolioListSkeleton(key: Key('trade-assets-loading'), assets: true),
          )
        else
          PortfolioAssetList(
            sliver: true,
            overview: overview,
            preview: preview,
            hidden: false,
            hideSmall: hideSmall,
            valuationLoading: loading.valuation,
            onHideSmall: (value) => setState(() => hideSmall = value),
            header: _TotalBalance(overview: overview, preview: preview, loading: loading.value),
          ),
        if (active && !preview) const SliverToBoxAdapter(child: PortfolioAccountFeedback()),
      ],
    );
  }
}

class _TotalBalance extends StatelessWidget {
  const _TotalBalance({required this.overview, required this.preview, required this.loading});
  final PortfolioOverview overview;
  final bool preview, loading;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.centerRight,
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).spotTotalBalance,
                  style: PortfolioTypography.assetSymbol,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: loading
                      ? const SkeletonBox(width: 80, height: 24)
                      : AnimatedNumberText(
                          portfolioUsd(overview.totalUsd),
                          key: const Key('trade-assets-total'),
                          comparisonValue: overview.totalUsd?.toString(),
                          softWrap: true,
                          textAlign: TextAlign.right,
                          style: PortfolioTypography.assetSymbol.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      // The 44px hit target overlaps non-interactive space; only the 16px
      // icon and its 8px gap reserve horizontal space beside the amount.
      Positioned(
        right: 0,
        child: SizedBox.square(
          dimension: 44,
          child: IconButton(
            key: const Key('trade-assets-deposit'),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerRight,
            iconSize: 16,
            tooltip: AppLocalizations.of(context).fundingDeposit,
            onPressed: () => preview
                ? portfolioPreviewNotice(context)
                : openFunding(context, FundingOperation.deposit),
            icon: const PortfolioIcon('asset-deposit.svg', size: 16),
          ),
        ),
      ),
    ],
  );
}
