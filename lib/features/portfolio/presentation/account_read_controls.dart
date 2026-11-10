import '../../../core/errors/error_text.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/status_view.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../domain/account_snapshot.dart';
import '../application/account_change_provider.dart';

class AccountReadControls extends ConsumerStatefulWidget {
  const AccountReadControls({
    super.key,
    required this.state,
    required this.onRead,
    this.buttonKey = const Key('read-aster-account'),
    this.initialLabel,
    this.refreshLabel,
    this.enabled = true,
    this.failureView = false,
  });
  final AccountSnapshotState<WalletAccountSnapshot> state;
  final FutureOr<void> Function() onRead;
  final Key buttonKey;
  final String? initialLabel, refreshLabel;
  final bool enabled;

  /// Replaces the inline error with the shared load-failure state while no
  /// snapshot exists. Retry runs the same wallet read as the read button.
  final bool failureView;

  @override
  ConsumerState<AccountReadControls> createState() => _AccountReadControlsState();
}

/// Reads the user stopped are not load failures; keep the plain read button.
const _userStops = {'historyReadStopped', 'strategyExecutionStopped'};

class _AccountReadControlsState extends ConsumerState<AccountReadControls> {
  // The controller clears its failure when a read starts; keep the failure
  // state (with a spinning Retry) until that retried read settles.
  bool _retrying = false;

  Future<void> _retry(Future<void> Function() read) async {
    setState(() => _retrying = true);
    try {
      await read();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final session = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);
    final identity = session.identity;
    final address = identity?.walletAddress;
    final canSign = identity?.signingAvailable == true;
    final streamSigning = ref.watch(
      accountChangeProvider.select((s) => s.step != AccountReadStep.idle),
    );
    final blocked = !widget.enabled || state.busy || session.busy || streamSigning;
    final needsAccount = identity == null || address == null || !canSign;
    final read = needsAccount ? () => showAccountSheet(context) : widget.onRead;
    final failure = state.failure;
    final showFailureView =
        widget.failureView &&
        state.account == null &&
        ((failure != null && !_userStops.contains(failure.key)) || _retrying);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFailureView)
          KeyedSubtree(
            key: const Key('account-read-error'),
            child: StatusFailureView(
              message: failure == null ? null : accountErrorText(context, failure),
              // Another read or wallet operation in flight also holds Retry.
              retrying: _retrying || blocked,
              onRetry: () => _retry(() async => read()),
            ),
          )
        else
          FilledButton.icon(
            key: widget.buttonKey,
            onPressed: blocked ? null : read,
            icon: state.busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(needsAccount ? Icons.account_balance_wallet_outlined : Icons.refresh),
            label: Text(
              identity == null
                  ? l10n.accountSignInToRead
                  : address == null
                  ? tr(context, 'createWallet')
                  : !canSign
                  ? tr(context, 'reconnectExternalWallet')
                  : state.account == null
                  ? widget.initialLabel ?? l10n.accountReadWithWallet
                  : widget.refreshLabel ?? l10n.accountRefreshWithWallet,
            ),
          ),
        if (state.busy) ...[
          const SizedBox(height: 12),
          if (!showFailureView) ...[const LinearProgressIndicator(), const SizedBox(height: 8)],
          Text(switch (state.step) {
            AccountReadStep.signing => l10n.accountReadSigning,
            AccountReadStep.loading => l10n.accountReadLoading,
            _ => l10n.accountReadPreparing,
          }, key: const Key('account-read-progress')),
        ],
        if (failure != null && !showFailureView) ...[
          const SizedBox(height: 12),
          Text(
            accountErrorText(context, failure),
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
