import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/application/rebalance_provider.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../../subaccounts/application/account_entries_provider.dart';
import '../../subaccounts/presentation/account_components.dart';
import 'funding_components.dart';

String rebalanceMessage(BuildContext context, String key) {
  final l = AppLocalizations.of(context);
  return switch (key) {
    'rebalanceStorage' => l.rebalanceStorage,
    'rebalancePending' => l.rebalancePending,
    'rebalanceChanged' => l.rebalanceChanged,
    _ => tr(context, key),
  };
}

/// Negative USDT notice above the Rebalance entry of the withdraw form.
class RebalanceAlert extends StatelessWidget {
  const RebalanceAlert({super.key, required this.usdt});
  final String usdt;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      key: const Key('funding-rebalance-alert'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PortfolioColors.negativeSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const PortfolioIcon('funding-warning.svg', size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.fundingRebalanceRequired,
                  style: PortfolioTypography.section.copyWith(color: PortfolioColors.negative),
                ),
                const SizedBox(height: 2),
                Text(
                  l.fundingUsdtBalanceValue(usdt),
                  style: PortfolioTypography.caption.copyWith(color: PortfolioColors.negative),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showRebalanceSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: false,
  backgroundColor: PortfolioColors.inset,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    side: BorderSide(color: PortfolioColors.line),
  ),
  builder: (_) => const RebalanceSheet(),
);

/// Confirms Rebalance with a fresh account check. While the request runs the
/// sheet cannot be dismissed; it closes once USDT is no longer negative.
class RebalanceSheet extends ConsumerStatefulWidget {
  const RebalanceSheet({super.key});
  @override
  ConsumerState<RebalanceSheet> createState() => _RebalanceSheetState();
}

class _RebalanceSheetState extends ConsumerState<RebalanceSheet> {
  bool started = false;
  String? error;
  Future<void> _confirm() async {
    setState(() {
      started = true;
      error = null;
    });
    final controller = ref.read(rebalanceProvider.notifier);
    var review = controller.prepare();
    if (review == null) {
      await controller.load();
      if (!mounted) return;
      review = controller.prepare();
    }
    if (review != null) await controller.confirm(review);
    if (!mounted) return;
    final after = ref.read(rebalanceProvider);
    if (review != null && after.failure == null && after.context?.needed == false) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      started = false;
      error = after.failure ?? 'rebalanceChanged';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), state = ref.watch(rebalanceProvider);
    final processing = started || state.busy;
    final usdt = state.context?.usdt;
    final entry = ref.watch(activeAccountEntryProvider);
    return PopScope(
      canPop: !processing,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        processing ? l.fundingRebalancing : l.fundingRebalance,
                        style: AccountTypography.name,
                      ),
                    ),
                    if (!processing)
                      IconButton(
                        key: const Key('funding-rebalance-close'),
                        tooltip: tr(context, 'close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const PortfolioIcon('close.svg', size: 24),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                processing ? l.fundingRebalancingHint : l.fundingRebalanceHint,
                style: AccountTypography.secondary,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PortfolioColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    AccountValueRow(l.account, entry == null ? l.account : accountLabel(l, entry)),
                    const SizedBox(height: 12),
                    AccountValueRow(
                      l.fundingUsdtBalance,
                      usdt == null ? '—' : fundingAmountText(usdt.toString(), 'USDT'),
                      color: PortfolioColors.negative,
                    ),
                  ],
                ),
              ),
              if (error case final key?) ...[
                const SizedBox(height: 12),
                FundingError(rebalanceMessage(context, key)),
              ],
              const SizedBox(height: 12),
              AccountAction(
                fadeDisabled: true,
                key: const Key('funding-rebalance-confirm'),
                label: processing ? l.fundingRebalancing : l.fundingRebalanceConfirm,
                busy: processing,
                onPressed: _confirm,
              ),
              if (!processing) ...[
                const SizedBox(height: 12),
                AccountAction(
                  label: tr(context, 'cancel'),
                  primary: false,
                  outlined: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
