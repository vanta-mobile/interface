import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../funding/presentation/transfer_history_screen.dart';
import '../../subaccounts/presentation/account_selector_sheet.dart';
import '../../subaccounts/presentation/account_components.dart';
import '../../subaccounts/application/account_entries_provider.dart';
import '../application/portfolio_overview_provider.dart';
import 'portfolio_account_details.dart';
import 'portfolio_components.dart';

class PortfolioHeader extends ConsumerWidget {
  const PortfolioHeader({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), session = ref.watch(authProvider);
    final preview = ref.watch(portfolioPreviewProvider);
    final active = preview || !session.needsWalletConnection;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: active
                ? InkWell(
                    key: const Key('portfolio-account-selector'),
                    onTap: () => preview
                        ? _selectAccount(context, ref, preview)
                        : showAccountSelector(context),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        children: [
                          const PortfolioIcon('account.svg', color: PortfolioColors.secondary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              preview
                                  ? l.portfolioPreviewAccount
                                  : ref.watch(activeAccountEntryProvider) == null
                                  ? l.account
                                  : accountLabel(l, ref.watch(activeAccountEntryProvider)!),
                              style: PortfolioTypography.heading,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const PortfolioIcon(
                            'chevron-down.svg',
                            size: 16,
                            color: PortfolioColors.secondary,
                          ),
                        ],
                      ),
                    ),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(l.portfolio, style: PortfolioTypography.heading),
                    ),
                  ),
          ),
          if (active)
            IconButton(
              key: const Key('portfolio-history-entry'),
              tooltip: l.assetHistoryTitle,
              onPressed: preview
                  ? () => portfolioPreviewNotice(context)
                  : () => openTransferHistory(context),
              icon: const PortfolioIcon('history.svg', size: 24, color: PortfolioColors.secondary),
            ),
        ],
      ),
    );
  }

  Future<void> _selectAccount(BuildContext context, WidgetRef ref, bool preview) async {
    final l = AppLocalizations.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: PortfolioColors.card,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.portfolioAccountSelector, style: PortfolioTypography.heading),
                const SizedBox(height: 12),
                ListTile(
                  key: const Key('portfolio-select-main'),
                  title: Text(l.portfolioMainAccount),
                  trailing: !preview
                      ? const Icon(Icons.check, color: PortfolioColors.accent)
                      : null,
                  onTap: () => Navigator.pop(context, 'main'),
                ),
                ListTile(
                  key: const Key('portfolio-select-preview'),
                  title: Text(l.portfolioPreviewAccount),
                  trailing: preview ? const Icon(Icons.check, color: PortfolioColors.accent) : null,
                  onTap: () => Navigator.pop(context, 'preview'),
                ),
                ListTile(
                  key: const Key('portfolio-account-details'),
                  title: Text(l.account),
                  onTap: () => Navigator.pop(context, 'details'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (result) {
      case 'preview':
        ref.read(portfolioPreviewProvider.notifier).select(true);
      case 'main':
        ref.read(portfolioPreviewProvider.notifier).select(false);
      case 'details':
        Navigator.of(context)
            .push<void>(MaterialPageRoute(builder: (_) => const PortfolioAccountDetails()));
    }
  }
}

void portfolioPreviewNotice(BuildContext context) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).portfolioPreviewAction)));
