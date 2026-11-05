import 'deposit_messages.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/deposit_submission_provider.dart';
import '../domain/deposit_submission.dart';
import '../domain/deposit_approval.dart';
import '../domain/deposit_wallet.dart';

class DepositSubmissionRecoveryNotice extends ConsumerWidget {
  const DepositSubmissionRecoveryNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        storage = ref.watch(depositSubmissionJournalSnapshotProvider),
        pending = ref.watch(pendingDepositSubmissionsProvider);
    if (!storage.ready || storage.failure != null) {
      return Column(
        children: [
          Text(l.depositSubmissionStorage),
          TextButton(
            onPressed: ref.read(depositSubmissionJournalSnapshotProvider.notifier).reload,
            child: Text(l.notificationRetry),
          ),
        ],
      );
    }
    if (pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.depositSubmissionPending),
        OutlinedButton(
          key: const Key('deposit-submit-recovery-entry'),
          onPressed: () => Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => const DepositSubmissionRecoveryScreen())),
          child: Text(l.depositSubmissionRecovery),
        ),
      ],
    );
  }
}

class DepositSubmissionRecoveryScreen extends ConsumerWidget {
  const DepositSubmissionRecoveryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        s = ref.watch(depositSubmissionProvider),
        pending = ref.watch(pendingDepositSubmissionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.depositSubmissionRecovery)),
      body: SafeArea(
        child: ListView(
          key: const Key('deposit-submit-recovery'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.depositSubmissionRecoveryScope),
            if (ref.watch(depositSubmissionJournalSnapshotProvider).failure != null)
              const DepositSubmissionRecoveryNotice(),
            if (pending.isEmpty) Text(l.depositSubmissionNoPending),
            for (final record in pending) _RecoveryCard(key: ValueKey(record.key), record: record),
            if (s.busy) ...[
              const LinearProgressIndicator(),
              TextButton(
                onPressed: ref.read(depositSubmissionProvider.notifier).stop,
                child: Text(l.subaccountStopWaiting),
              ),
            ],
            if (s.failure case final failure?)
              Text(
                depositMessage(context, failure),
                style: const TextStyle(color: AppColors.warning),
              ),
            if (s.receipt case final receipt?) ...[
              Text(
                s.credited
                    ? l.depositSubmissionCredited
                    : switch (receipt.status) {
                        DepositReceiptStatus.pending => l.depositApprovalReceiptPending,
                        DepositReceiptStatus.succeeded => l.depositSubmissionChainSucceeded,
                        DepositReceiptStatus.reverted => l.depositApprovalReceiptReverted,
                        DepositReceiptStatus.replaced => l.depositApprovalReceiptReplaced,
                      },
              ),
              SelectableText(receipt.hash),
              Text('${l.depositApprovalConfirmations}: ${receipt.confirmations}'),
              if (receipt.gasFee case final fee?)
                SelectableText(
                  '${l.depositApprovalGasFee}: ${depositQuantity(fee, 18)} ${s.record?.transaction.chainId == 56 ? 'BNB' : 'ETH'}',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecoveryCard extends ConsumerStatefulWidget {
  const _RecoveryCard({super.key, required this.record});
  final DepositSubmissionRecord record;
  @override
  ConsumerState<_RecoveryCard> createState() => _RecoveryCardState();
}

class _RecoveryCardState extends ConsumerState<_RecoveryCard> with AutomaticKeepAliveClientMixin {
  final hash = TextEditingController();
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    hash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context),
        r = widget.record,
        s = ref.watch(depositSubmissionProvider),
        controller = ref.read(depositSubmissionProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        SelectableText(
          '${depositQuantity(r.amountUnits, r.query.asset.decimals)} ${r.query.asset.asset} · ${r.query.market.name == 'spot' ? l.transferSpotMarket : l.transferPerpMarket} · ${r.transaction.chainId}',
        ),
        SelectableText(r.transaction.from),
        Text(l.depositGasTarget),
        SelectableText(r.transaction.to),
        Text(l.depositApprovalNonce),
        SelectableText('${r.transaction.nonce}'),
        if (r.hash case final value?) SelectableText(value),
        Text(l.depositApprovalHashHint),
        TextField(
          key: const Key('deposit-submit-recovery-hash'),
          controller: hash,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 66,
          onChanged: (_) => setState(() {}),
        ),
        OutlinedButton(
          key: const Key('deposit-submit-check-chain'),
          onPressed:
              s.busy ||
                  hash.text.trim().isNotEmpty && !validFundingHash(hash.text.trim()) ||
                  r.hash == null && hash.text.trim().isEmpty
              ? null
              : () => controller.check(r.key, hash.text.trim()),
          child: Text(l.depositSubmissionCheckChain),
        ),
        OutlinedButton(
          key: const Key('deposit-submit-check-credit'),
          onPressed: s.busy || (r.hash == null && !validFundingHash(hash.text.trim()))
              ? null
              : () => controller.checkCredit(r.key, candidate: hash.text.trim()),
          child: Text(l.depositSubmissionCheckCredit),
        ),
      ],
    );
  }
}
