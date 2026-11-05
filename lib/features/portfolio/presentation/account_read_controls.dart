import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../domain/account_snapshot.dart';
import '../application/account_change_provider.dart';

class AccountReadControls extends ConsumerWidget {
  const AccountReadControls({
    super.key,
    required this.state,
    required this.onRead,
    this.buttonKey = const Key('read-aster-account'),
    this.initialLabel,
    this.refreshLabel,
    this.enabled = true,
  });
  final AccountSnapshotState<WalletAccountSnapshot> state;
  final VoidCallback onRead;
  final Key buttonKey;
  final String? initialLabel, refreshLabel;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);
    final identity = session.identity;
    final address = identity?.walletAddress;
    final canSign = identity?.signingAvailable == true;
    final streamSigning = ref.watch(
      accountChangeProvider.select((s) => s.step != AccountReadStep.idle),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: buttonKey,
          onPressed: !enabled || state.busy || session.busy || streamSigning
              ? null
              : identity == null || address == null || !canSign
              ? () => showAccountSheet(context)
              : onRead,
          icon: Icon(
            address == null || !canSign ? Icons.account_balance_wallet_outlined : Icons.refresh,
          ),
          label: Text(
            identity == null
                ? l10n.accountSignInToRead
                : address == null
                ? tr(context, 'createWallet')
                : !canSign
                ? tr(context, 'reconnectExternalWallet')
                : state.account == null
                ? initialLabel ?? l10n.accountReadWithWallet
                : refreshLabel ?? l10n.accountRefreshWithWallet,
          ),
        ),
        if (state.busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(switch (state.step) {
            AccountReadStep.signing => l10n.accountReadSigning,
            AccountReadStep.loading => l10n.accountReadLoading,
            _ => l10n.accountReadPreparing,
          }, key: const Key('account-read-progress')),
        ],
        if (state.failure case final failure?) ...[
          const SizedBox(height: 12),
          Text(
            '${tr(context, failure.key)}${failure.code == null ? '' : '\n${l10n.accountErrorCode(failure.code!)}'}',
            key: const Key('account-read-error'),
            style: const TextStyle(color: AppColors.negative),
          ),
        ],
        const SizedBox(height: 12),
        Text(l10n.accountReadNotice, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
