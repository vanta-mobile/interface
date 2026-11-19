import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../funding/presentation/transfer_history_screen.dart';
import '../../subaccounts/presentation/account_selector_sheet.dart';
import '../../subaccounts/presentation/account_components.dart';
import '../../subaccounts/application/account_entries_provider.dart';
import 'portfolio_components.dart';

class PortfolioHeader extends ConsumerWidget {
  const PortfolioHeader({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), session = ref.watch(authProvider);
    final active = !session.needsWalletConnection;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: active
                ? InkWell(
                    key: const Key('portfolio-account-selector'),
                    onTap: () => showAccountSelector(context),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        children: [
                          const PortfolioIcon('account.svg', color: PortfolioColors.secondary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              ref.watch(activeAccountEntryProvider) == null
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
              onPressed: () => openTransferHistory(context),
              icon: const PortfolioIcon('history.svg', size: 24, color: PortfolioColors.secondary),
            ),
        ],
      ),
    );
  }
}
