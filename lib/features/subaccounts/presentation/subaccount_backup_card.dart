import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../domain/generated_subaccount.dart';
import 'account_components.dart';

/// Rendering only: key retrieval and visibility lifetime stay in the screen.
class SubaccountBackupCard extends StatelessWidget {
  const SubaccountBackupCard({
    super.key,
    required this.wallet,
    required this.accepted,
    required this.privateKey,
    required this.onReveal,
  });
  final GeneratedSubaccount wallet;
  final bool accepted;
  final String? privateKey;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PortfolioCard(
      border: false,
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (accepted) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(minWidth: 70, minHeight: 24),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: PortfolioColors.onAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  l.accountsCreatedBadge,
                  textAlign: TextAlign.center,
                  style: AccountTypography.caption.copyWith(color: PortfolioColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(wallet.name, style: AccountTypography.heading),
          const SizedBox(height: 6),
          AccountAddressRow(l.accountsAddress, wallet.address, showCopyButton: true),
          const SizedBox(height: 6),
          const Divider(color: PortfolioColors.line, height: 1),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(child: Text(l.accountsPrivateKey, style: AccountTypography.caption)),
              SizedBox.square(
                dimension: 44,
                child: IconButton(
                  key: const Key('subaccount-reveal-key'),
                  tooltip: privateKey == null ? l.accountsRevealKey : l.accountsHideKey,
                  onPressed: onReveal,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: const PortfolioIcon('eye.svg'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          if (privateKey == null)
            const ExcludeSemantics(child: _HiddenKey())
          else
            SelectableText(
              privateKey!,
              key: const Key('subaccount-revealed-key'),
              style: AccountTypography.secondary,
            ),
          const SizedBox(height: 12),
          Text(l.accountsHiddenKey, style: AccountTypography.caption),
        ],
      ),
    );
  }
}

class _HiddenKey extends StatelessWidget {
  const _HiddenKey();
  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      2,
      (_) => Padding(
        padding: const EdgeInsets.only(left: 6, right: 24),
        child: SizedBox(
          height: 26,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              16,
              (_) => Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '•',
                    style: AccountTypography.heading.copyWith(color: PortfolioColors.secondary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class BackupAcknowledgement extends StatelessWidget {
  const BackupAcknowledgement({super.key, required this.saved, required this.onChanged});
  final bool saved;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!saved),
      borderRadius: BorderRadius.circular(6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 24,
              child: Semantics(
                checked: saved,
                enabled: onChanged != null,
                child: Center(
                  child: saved
                      ? const PortfolioIcon(
                          'check-circle.svg',
                          size: 16,
                          color: PortfolioColors.accent,
                        )
                      : Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: PortfolioColors.muted, width: 1.5),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).accountsSavedKey,
                style: AccountTypography.body,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
