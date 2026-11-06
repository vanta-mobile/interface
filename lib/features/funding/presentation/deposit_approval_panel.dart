import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/deposit_approval_provider.dart';
import '../domain/deposit_transaction.dart';
import '../domain/deposit_wallet.dart';
import 'deposit_gas_details.dart';
import 'deposit_messages.dart';

class DepositApprovalPanel extends ConsumerWidget {
  const DepositApprovalPanel({
    super.key,
    required this.query,
    required this.amount,
    required this.canPrepare,
  });
  final DepositWalletQuery query;
  final String amount;
  final bool canPrepare;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), state = ref.watch(depositApprovalProvider);
    final pending = ref.watch(pendingDepositApprovalsProvider);
    final storage = ref.watch(depositApprovalJournalSnapshotProvider);
    final controller = ref.read(depositApprovalProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(l10n.depositApprovalScope),
        OutlinedButton(
          key: const Key('deposit-approval-prepare'),
          onPressed:
              !canPrepare ||
                  state.busy ||
                  pending.isNotEmpty ||
                  !storage.ready ||
                  storage.failure != null
              ? null
              : () async {
                  final review = await controller.prepare(query, amount);
                  if (review == null || !context.mounted) return;
                  final accepted = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => DepositApprovalReviewScreen(review: review)),
                  );
                  if (accepted == true) {
                    await controller.confirm(review);
                  } else {
                    controller.cancel(review);
                  }
                },
          child: Text(l10n.depositApprovalPrepare),
        ),
        if (state.busy) ...[
          const LinearProgressIndicator(),
          TextButton(
            key: const Key('deposit-approval-stop'),
            onPressed: controller.stop,
            child: Text(l10n.subaccountStopWaiting),
          ),
        ],
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
        if (state.record != null && !state.busy && state.failure == null)
          Text(l10n.depositApprovalSent),
      ],
    );
  }
}

class DepositApprovalReviewScreen extends ConsumerWidget {
  const DepositApprovalReviewScreen({super.key, required this.review});
  final DepositApprovalReview review;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final valid = identical(ref.watch(depositApprovalProvider).review, review);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.depositApprovalReview)),
      body: SafeArea(
        child: ListView(
          key: const Key('deposit-approval-review-scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.depositApprovalScope),
            DepositGasDetails(quote: review.quote),
            Text(l10n.depositSpenderScope),
            SelectableText(depositVaults[review.transaction.chainId]!),
            Text(l10n.depositApprovalNonce),
            SelectableText('${review.transaction.nonce}'),
            if (!valid)
              Text(l10n.depositApprovalChanged, style: const TextStyle(color: AppColors.warning)),
            OutlinedButton(
              key: const Key('deposit-approval-confirm'),
              onPressed: valid && review.quote.transaction.kind != DepositTransactionKind.deposit
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(l10n.depositApprovalConfirm),
            ),
            TextButton(
              key: const Key('deposit-approval-cancel'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.depositApprovalCancel),
            ),
          ],
        ),
      ),
    );
  }
}
