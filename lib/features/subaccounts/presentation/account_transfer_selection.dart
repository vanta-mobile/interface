import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'account_components.dart';

class AccountTransferSelection extends StatelessWidget {
  const AccountTransferSelection({super.key, required this.values, this.source});
  final Map<String, String> values;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AccountsPage(
      title: l.accountsSelect,
      children: [
        for (final entry in values.entries) ...[
          _SelectionOption(
            key: ValueKey('accounts-select-${entry.key}'),
            label: entry.value,
            disabled: entry.key.toLowerCase() == source?.toLowerCase(),
            onPressed: () => Navigator.pop(context, entry.key),
          ),
          const SizedBox(height: 8),
        ],
        if (source != null) ...[
          const SizedBox(height: 8),
          Text(l.accountsDifferentSource, style: AccountTypography.caption),
        ],
      ],
    );
  }
}

class _SelectionOption extends StatelessWidget {
  const _SelectionOption({
    super.key,
    required this.label,
    required this.disabled,
    required this.onPressed,
  });
  final String label;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: disabled ? null : onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      backgroundColor: PortfolioColors.card,
      disabledBackgroundColor: PortfolioColors.card.withValues(alpha: .38),
      foregroundColor: PortfolioColors.text,
      disabledForegroundColor: PortfolioColors.secondary.withValues(alpha: .38),
      side: BorderSide(
        color: disabled
            ? PortfolioColors.line.withValues(alpha: PortfolioColors.line.a * .38)
            : PortfolioColors.line,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: Theme.of(context).textTheme.labelLarge?.merge(AccountTypography.section),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
}

class AccountTransferUnavailable extends StatelessWidget {
  const AccountTransferUnavailable({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AccountsPage(
      title: l.accountsTransferUnavailable,
      onBack: onBack,
      footer: [AccountAction(label: l.accountsBackTransfer, onPressed: onBack)],
      children: [
        Text(l.accountsTransferFreezeHeading, style: AccountTypography.heading),
        const SizedBox(height: 16),
        Text(l.accountsFrozenNotice, style: AccountTypography.secondary),
      ],
    );
  }
}
