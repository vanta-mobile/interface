import '../../../core/errors/error_text.dart';
import 'deposit_messages.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/deposit_submission_provider.dart';
import '../application/deposit_approval_provider.dart';
import '../domain/deposit_wallet.dart';
import 'deposit_gas_details.dart';

class DepositSubmissionPanel extends ConsumerStatefulWidget {
  const DepositSubmissionPanel({
    super.key,
    required this.query,
    required this.amount,
    required this.canPrepare,
  });
  final DepositWalletQuery query;
  final String amount;
  final bool canPrepare;
  @override
  ConsumerState<DepositSubmissionPanel> createState() => _DepositSubmissionPanelState();
}

class _DepositSubmissionPanelState extends ConsumerState<DepositSubmissionPanel>
    with AutomaticKeepAliveClientMixin {
  bool acknowledged = false;
  @override
  bool get wantKeepAlive => true;
  @override
  void didUpdateWidget(DepositSubmissionPanel old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query || old.amount != widget.amount) acknowledged = false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context),
        s = ref.watch(depositSubmissionProvider),
        storage = ref.watch(depositSubmissionJournalSnapshotProvider);
    final controller = ref.read(depositSubmissionProvider.notifier);
    ref.listen(
      authProvider.select(
        (s) => (s.identity?.id, s.identity?.walletAddress, s.identity?.walletKind),
      ),
      (a, b) {
        if (a != b) setState(() => acknowledged = false);
      },
    );
    final blocked =
        ref.watch(pendingDepositSubmissionsProvider).isNotEmpty ||
        ref.watch(pendingDepositApprovalsProvider).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(l.depositSubmissionScope),
        Text(l.depositPlatformLimitsUnknown),
        CheckboxListTile(
          key: const Key('deposit-limits-acknowledgement'),
          contentPadding: EdgeInsets.zero,
          value: acknowledged,
          onChanged: s.busy ? null : (v) => setState(() => acknowledged = v ?? false),
          title: Text(l.depositLimitsAcknowledgement),
        ),
        FilledButton(
          key: const Key('deposit-submit-prepare'),
          onPressed:
              !widget.canPrepare ||
                  !acknowledged ||
                  s.busy ||
                  blocked ||
                  !storage.ready ||
                  storage.failure != null
              ? null
              : () async {
                  final review = await controller.prepare(
                    widget.query,
                    widget.amount,
                    acknowledgeUnknownLimits: acknowledged,
                  );
                  if (review == null || !context.mounted) return;
                  final accepted = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => DepositSubmissionReviewScreen(review: review),
                    ),
                  );
                  if (accepted == true) {
                    await controller.confirm(review);
                  } else {
                    controller.cancel(review);
                  }
                },
          child: Text(l.depositSubmissionPrepare),
        ),
        if (s.busy) ...[
          const LinearProgressIndicator(),
          TextButton(onPressed: controller.stop, child: Text(l.subaccountStopWaiting)),
        ],
        if (s.failure case final key?)
          Text(
            apiErrorText(context, key, s.errorDetails, fallbackText: depositMessage(context, key)),
            style: const TextStyle(color: AppColors.warning),
          ),
        if (s.record != null && !s.busy && s.failure == null) Text(l.depositSubmissionSent),
      ],
    );
  }
}

class DepositSubmissionReviewScreen extends ConsumerWidget {
  const DepositSubmissionReviewScreen({super.key, required this.review});
  final DepositSubmissionReview review;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        valid = identical(ref.watch(depositSubmissionProvider).review, review);
    return Scaffold(
      appBar: AppBar(title: Text(l.depositSubmissionReview)),
      body: SafeArea(
        child: ListView(
          key: const Key('deposit-submit-review'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.depositSubmissionScope),
            Text(l.depositPlatformLimitsUnknown),
            DepositGasDetails(quote: review.quote),
            Text(l.withdrawalReceiver),
            SelectableText(review.transaction.from),
            Text(l.depositGasTarget),
            SelectableText(review.transaction.to),
            Text(l.depositApprovalNonce),
            SelectableText('${review.transaction.nonce}'),
            Text(l.depositSubmissionRecoveryScope),
            FilledButton(
              key: const Key('deposit-submit-confirm'),
              onPressed: valid ? () => Navigator.pop(context, true) : null,
              child: Text(l.depositSubmissionConfirm),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'cancel')),
            ),
          ],
        ),
      ),
    );
  }
}
