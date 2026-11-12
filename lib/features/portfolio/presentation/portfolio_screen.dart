import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../funding/domain/funding_catalog.dart';
import '../../funding/presentation/funding_screen.dart';
import '../../funding/presentation/portfolio_funding_activity.dart';
import '../../subaccounts/presentation/account_transfer_screen.dart';
import '../../subaccounts/application/account_entries_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/portfolio_overview_provider.dart';
import '../application/portfolio_account_load_provider.dart';
import '../application/portfolio_stats_provider.dart';
import 'portfolio_futures_section.dart';
import '../application/portfolio_loading_provider.dart';
import 'portfolio_pnl_screen.dart';
import 'portfolio_components.dart';
import 'portfolio_header.dart';
import 'portfolio_summary.dart';

class PortfolioPage extends ConsumerStatefulWidget {
  const PortfolioPage({super.key});
  @override
  ConsumerState<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends ConsumerState<PortfolioPage> {
  bool hidden = false, expanded = false;
  String period = '7D';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final active = ref.watch(authProvider.select((s) => !s.needsWalletConnection));
    final preview = ref.watch(portfolioPreviewProvider);
    final overview = ref.watch(portfolioOverviewProvider);
    final stats = ref.watch(portfolioPerformanceProvider(portfolioStatsPeriod(period)));
    ref.watch(portfolioAccountLoadProvider);
    final valueLoading = ref.watch(portfolioLoadingProvider.select((s) => s.value));
    return Material(
      color: PortfolioColors.background,
      child: Column(
        children: [
          const PortfolioHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ref.watch(portfolioRefreshProvider),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal = constraints.maxWidth > 820
                      ? (constraints.maxWidth - 788) / 2
                      : 16.0;
                  return CustomScrollView(
                    key: const Key('portfolio-page'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: horizontal),
                        sliver: SliverMainAxisGroup(
                          slivers: [
                            SliverList.list(
                              children: [
                                if (preview)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      l.portfolioPreviewNotice,
                                      style: PortfolioTypography.caption,
                                    ),
                                  ),
                                PortfolioAccountValue(
                                  overview: overview,
                                  stats: stats,
                                  loading: valueLoading,
                                  visible: !hidden,
                                  active: active || preview,
                                  historyExpanded: expanded,
                                  onToggleVisibility: () => setState(() => hidden = !hidden),
                                  onToggleHistory: () => setState(() => expanded = !expanded),
                                ),
                                if (expanded && !hidden) ...[
                                  const SizedBox(height: 12),
                                  PortfolioValueHistory(
                                    stats: stats,
                                    period: period,
                                    onPeriod: (value) => setState(() => period = value),
                                    onCollapse: () => setState(() => expanded = false),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                if (active || preview)
                                  _MoneyActions(preview: preview)
                                else ...[
                                  Text(l.portfolioLoginHint, style: PortfolioTypography.body),
                                  const SizedBox(height: 16),
                                  PortfolioAction(
                                    key: const Key('portfolio-login'),
                                    label: l.authWalletContinue,
                                    primary: true,
                                    onPressed: () => showAccountSheet(context),
                                  ),
                                ],
                                if (active && !preview) PortfolioFundingActivity(hidden: hidden),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l.portfolioPerformance,
                                        style: PortfolioTypography.section,
                                      ),
                                    ),
                                    if (active || preview)
                                      TextButton(
                                        key: const Key('portfolio-pnl-entry'),
                                        onPressed: () => Navigator.of(context).push<void>(
                                          MaterialPageRoute(
                                            builder: (_) => const PortfolioPnlScreen(),
                                          ),
                                        ),
                                        child: Text(
                                          l.portfolioPnlDetails,
                                          style: PortfolioTypography.caption.copyWith(
                                            color: PortfolioColors.accent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                PortfolioPerformanceCard(
                                  stats: stats,
                                  hidden: hidden,
                                  active: active || preview,
                                ),
                                const SizedBox(height: 16),
                                Text(l.portfolioFuturesAssets, style: PortfolioTypography.section),
                              ],
                            ),
                            if (active || preview)
                              PortfolioFuturesSection(hidden: hidden)
                            else
                              SliverToBoxAdapter(child: PortfolioEmpty(l.portfolioLoginBalances)),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyActions extends ConsumerWidget {
  const _MoneyActions({required this.preview});
  final bool preview;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final entry = ref.watch(activeAccountEntryProvider);
    final child = entry != null && entry.roleKnown && !entry.main;
    void open(FundingOperation operation) =>
        preview ? portfolioPreviewNotice(context) : openFunding(context, operation);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PortfolioAction(
                key: const Key('portfolio-deposit'),
                label: l.fundingDeposit,
                primary: true,
                onPressed: () => open(FundingOperation.deposit),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: PortfolioAction(
                key: const Key('portfolio-withdraw'),
                label: preview || !child ? l.fundingWithdraw : l.accountsWithdrawMainOnly,
                onPressed: preview || !child ? () => open(FundingOperation.withdraw) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextButton(
          key: const Key('portfolio-transfer'),
          onPressed: preview
              ? () => portfolioPreviewNotice(context)
              : () => Navigator.of(context)
                    .push<void>(MaterialPageRoute(builder: (_) => const AccountTransferScreen())),
          child: Text(
            l.portfolioTransfer,
            style: PortfolioTypography.caption.copyWith(color: PortfolioColors.accent),
          ),
        ),
      ],
    );
  }
}
