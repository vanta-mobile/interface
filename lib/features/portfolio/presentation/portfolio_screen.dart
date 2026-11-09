import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../funding/domain/funding_catalog.dart';
import '../../funding/domain/transfer_history.dart';
import '../../funding/presentation/funding_info_screen.dart';
import '../../funding/presentation/internal_transfer_screen.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/portfolio_overview_provider.dart';
import 'portfolio_assets.dart';
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
  bool assets = false, hidden = false, hideOther = false, hideSmall = false, expanded = false;
  String period = '7D';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final active = ref.watch(authProvider.select((s) => !s.needsWalletConnection));
    final preview = ref.watch(portfolioPreviewProvider);
    final overview = ref.watch(portfolioOverviewProvider);
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
                  return ListView(
                    key: const Key('portfolio-page'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
                    children: [
                      if (preview)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(l.portfolioPreviewNotice, style: PortfolioTypography.caption),
                        ),
                      PortfolioAccountValue(
                        overview: overview,
                        visible: !hidden,
                        active: active || preview,
                        historyExpanded: expanded,
                        period: period,
                        onToggleVisibility: () => setState(() => hidden = !hidden),
                        onToggleHistory: () => setState(() => expanded = !expanded),
                      ),
                      if (expanded && !hidden) ...[
                        const SizedBox(height: 12),
                        PortfolioValueHistory(
                          overview: overview,
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(l.portfolioPerformance, style: PortfolioTypography.section),
                          ),
                          if (active || preview)
                            TextButton(
                              key: const Key('portfolio-pnl-entry'),
                              onPressed: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(builder: (_) => const PortfolioPnlScreen()),
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
                        overview: overview,
                        preview: preview,
                        hidden: hidden,
                      ),
                      const SizedBox(height: 16),
                      Text(l.portfolioFuturesAssets, style: PortfolioTypography.section),
                      if (active || preview) ...[
                        PortfolioAssetTabs(
                          assets: assets,
                          count: overview.positions.length,
                          preview: preview,
                          onChanged: (value) => setState(() => assets = value),
                        ),
                        if (assets)
                          PortfolioAssetList(
                            overview: overview,
                            preview: preview,
                            hidden: hidden,
                            hideSmall: hideSmall,
                            onHideSmall: (value) => setState(() => hideSmall = value),
                          )
                        else
                          PortfolioPositionList(
                            overview: overview,
                            preview: preview,
                            hidden: hidden,
                            hideOther: hideOther,
                            onHideOther: (value) => setState(() => hideOther = value),
                          ),
                      ] else
                        PortfolioEmpty(l.portfolioLoginBalances),
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

class _MoneyActions extends StatelessWidget {
  const _MoneyActions({required this.preview});
  final bool preview;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    void open(FundingOperation operation) => preview
        ? portfolioPreviewNotice(context)
        : Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => FundingInfoScreen(
                initialMarket: TransferMarket.perp,
                initialOperation: operation,
              ),
            ),
          );
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
                label: l.fundingWithdraw,
                onPressed: () => open(FundingOperation.withdraw),
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
                    .push<void>(MaterialPageRoute(builder: (_) => const InternalTransferScreen())),
          child: Text(
            l.portfolioTransfer,
            style: PortfolioTypography.caption.copyWith(color: PortfolioColors.accent),
          ),
        ),
      ],
    );
  }
}
