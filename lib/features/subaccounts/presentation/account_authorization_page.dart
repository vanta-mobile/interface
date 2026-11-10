import 'package:flutter/material.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import 'account_components.dart';

/// Explicit review before opening the owner wallet for a signed account write.
class AccountAuthorizationPage extends StatelessWidget {
  const AccountAuthorizationPage({
    super.key,
    required this.heading,
    required this.summary,
    required this.owner,
    required this.notice,
    required this.onOpen,
    required this.onCancel,
    this.busy = false,
    this.showCancel = false,
    this.failure,
  });
  final String heading, summary, owner, notice;
  final String? failure;
  final VoidCallback? onOpen;
  final VoidCallback onCancel;
  final bool busy, showCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AccountsPage(
      title: l.accountsAccount,
      canPop: false,
      actions: [
        IconButton(
          tooltip: tr(context, 'close'),
          onPressed: busy ? null : onCancel,
          icon: const PortfolioIcon('close.svg', size: 24),
        ),
      ],
      footer: [
        AccountAction(
          key: const Key('accounts-open-wallet'),
          label: l.accountsOpenWallet,
          busy: busy,
          onPressed: onOpen,
        ),
        if (showCancel) ...[
          const SizedBox(height: 12),
          AccountAction(
            label: tr(context, 'cancel'),
            primary: false,
            onPressed: busy ? null : onCancel,
          ),
        ],
      ],
      children: [
        Text(heading, style: AccountTypography.heading),
        const SizedBox(height: 8),
        Text(summary, style: AccountTypography.secondary),
        const SizedBox(height: 12),
        Semantics(
          onLongPress: () => copyAccountAddress(owner),
          child: GestureDetector(
            onLongPress: () => copyAccountAddress(owner),
            child: Text(
              '${l.portfolioMainAccount} · ${shortAccountAddress(owner)}',
              style: AccountTypography.caption,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AccountNotice(notice),
        if (failure != null)
          Semantics(
            liveRegion: true,
            child: Text(
              failure!,
              style: AccountTypography.secondary.copyWith(color: PortfolioColors.negative),
            ),
          ),
      ],
    );
  }
}
