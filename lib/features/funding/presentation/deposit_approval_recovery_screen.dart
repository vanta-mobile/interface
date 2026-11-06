import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/deposit_approval_provider.dart';
import '../domain/deposit_approval.dart';
import '../domain/deposit_transaction.dart';
import '../domain/deposit_wallet.dart';
import 'deposit_messages.dart';

class DepositApprovalRecoveryNotice extends ConsumerWidget {
  const DepositApprovalRecoveryNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(depositApprovalJournalSnapshotProvider);
    final pending = ref.watch(pendingDepositApprovalsProvider), l10n = AppLocalizations.of(context);
    if (storage.failure != null || !storage.ready) {
      return Column(
        children: [
          Text(l10n.depositApprovalStorage, style: const TextStyle(color: AppColors.warning)),
          TextButton(
            key: const Key('deposit-approval-storage-retry'),
            onPressed: ref.read(depositApprovalJournalSnapshotProvider.notifier).reload,
            child: Text(l10n.notificationRetry),
          ),
        ],
      );
    }
    if (pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.depositApprovalPending),
        OutlinedButton(
          key: const Key('deposit-approval-recovery-entry'),
          onPressed: () => Navigator.of(context)
              .push<void>(MaterialPageRoute(builder: (_) => const DepositApprovalRecoveryScreen())),
          child: Text(l10n.depositApprovalOpenRecovery),
        ),
      ],
    );
  }
}

class DepositApprovalRecoveryScreen extends ConsumerWidget {
  const DepositApprovalRecoveryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), records = ref.watch(pendingDepositApprovalsProvider);
    final state = ref.watch(depositApprovalProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.depositApprovalRecovery)),
      body: SafeArea(
        child: ListView(
          key: const Key('deposit-approval-recovery-scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.depositApprovalRecoveryScope),
            if (ref.watch(depositApprovalJournalSnapshotProvider).failure != null)
              const DepositApprovalRecoveryNotice(),
            if (records.isEmpty) Text(l10n.depositApprovalNoPending),
            for (final record in records)
              DepositApprovalRecoveryCard(key: ValueKey(record.key), record: record),
            if (state.failure case final key?)
              Text(
                apiErrorText(
                  context,
                  key,
                  state.errorDetails,
                  fallbackText: depositMessage(context, key),
                ),
                style: const TextStyle(color: AppColors.warning),
              ),
            if (state.busy) ...[
              const LinearProgressIndicator(),
              TextButton(
                key: const Key('deposit-approval-check-stop'),
                onPressed: ref.read(depositApprovalProvider.notifier).stop,
                child: Text(l10n.subaccountStopWaiting),
              ),
            ],
            if (state.receipt != null && state.record != null)
              DepositApprovalReceiptPanel(record: state.record!, receipt: state.receipt!),
          ],
        ),
      ),
    );
  }
}

class DepositApprovalRecoveryCard extends ConsumerStatefulWidget {
  const DepositApprovalRecoveryCard({super.key, required this.record});
  final DepositApprovalRecord record;
  @override
  ConsumerState<DepositApprovalRecoveryCard> createState() => _DepositApprovalRecoveryCardState();
}

class _DepositApprovalRecoveryCardState extends ConsumerState<DepositApprovalRecoveryCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final hash = TextEditingController();
  @override
  void dispose() {
    hash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final r = widget.record, l10n = AppLocalizations.of(context);
    final tx = r.transaction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(
          r.kind == DepositTransactionKind.resetApproval
              ? l10n.depositGasReset
              : l10n.depositGasApprove,
        ),
        ValueRow(l10n.fundingNetwork, '${tx.chainId}'),
        SelectableText(
          '${depositQuantity(r.amountUnits, r.query.asset.decimals)} ${r.query.asset.asset}',
        ),
        SelectableText(tx.from),
        Text(l10n.depositGasTarget),
        SelectableText(tx.to),
        Text(l10n.depositSpenderScope),
        SelectableText(depositVaults[tx.chainId]!),
        Text(l10n.depositApprovalNonce),
        SelectableText('${tx.nonce}'),
        Text(l10n.depositApprovalPreparedAt),
        Text(r.preparedAt.toUtc().toIso8601String()),
        Text(l10n.depositApprovalHash),
        if (r.hash case final value?) SelectableText(value),
        ...[
          Text(l10n.depositApprovalHashHint),
          TextField(
            key: const Key('deposit-approval-original-hash'),
            controller: hash,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 66,
            onChanged: (_) => setState(() {}),
          ),
        ],
        OutlinedButton(
          key: const Key('deposit-approval-check'),
          onPressed:
              ref.watch(depositApprovalProvider).busy ||
                  (hash.text.trim().isNotEmpty || r.hash == null) &&
                      !validFundingHash(hash.text.trim())
              ? null
              : () => ref.read(depositApprovalProvider.notifier).check(r.key, hash.text),
          child: Text(l10n.depositApprovalCheck),
        ),
      ],
    );
  }
}

class DepositApprovalReceiptPanel extends StatelessWidget {
  const DepositApprovalReceiptPanel({super.key, required this.record, required this.receipt});
  final DepositApprovalRecord record;
  final DepositApprovalReceipt receipt;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context),
        native = record.transaction.chainId == 56 ? 'BNB' : 'ETH';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(switch (receipt.status) {
          DepositReceiptStatus.pending => l10n.depositApprovalReceiptPending,
          DepositReceiptStatus.succeeded => l10n.depositApprovalReceiptSucceeded,
          DepositReceiptStatus.reverted => l10n.depositApprovalReceiptReverted,
          DepositReceiptStatus.replaced => l10n.depositApprovalReceiptReplaced,
        }),
        SelectableText(receipt.hash),
        ValueRow(l10n.depositApprovalConfirmations, '${receipt.confirmations}'),
        if (receipt.gasFee case final fee?) ...[
          ValueRow(l10n.depositApprovalGasFee, '${depositQuantity(fee, 18)} $native'),
          Text(l10n.depositApprovalFeeScope),
        ],
      ],
    );
  }
}
