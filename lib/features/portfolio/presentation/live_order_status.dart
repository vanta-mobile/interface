import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/live_order_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../domain/live_order.dart';
import 'live_close_result.dart';
import 'live_order_policy.dart';
import 'live_order_trigger_controls.dart';
import 'live_order_attachment_summary.dart';
import 'attached_order_status.dart';
import 'live_order_pricing.dart';

class LiveOrderStatus extends ConsumerWidget {
  const LiveOrderStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), state = ref.watch(liveOrderProvider);
    final auth = ref.watch(authProvider);
    final controller = ref.read(liveOrderProvider.notifier);
    final result = state.result, failure = state.failure ?? result?.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.busy)
          Text(switch (state.step) {
            LiveOrderStep.signingContext ||
            LiveOrderStep.signingPosition ||
            LiveOrderStep.signing ||
            LiveOrderStep.checkSigning => l10n.accountReadSigning,
            LiveOrderStep.loadingContext ||
            LiveOrderStep.checkingPosition ||
            LiveOrderStep.checking => l10n.accountReadLoading,
            LiveOrderStep.submitting => l10n.liveOrderSubmitting,
            _ => l10n.accountReadPreparing,
          }),
        if (state.intent case final attempted?) ...[
          const SizedBox(height: 16),
          SelectableText(attempted.context.symbol),
          SelectableText(attempted.context.address),
          Text(
            attempted.draft.attachment != null
                ? l10n.attachedOrderClientId
                : l10n.liveOrderClientId,
          ),
          SelectableText(attempted.clientOrderId),
          LiveOrderAttachmentSummary(intent: attempted),
          if (attempted.draft.peg case final peg?) LiveOrderPegSummary(peg: peg),
          if (attempted.draft.trigger != null || attempted.draft.trailing != null) ...[
            Text(liveOrderTypeLabel(l10n, attempted.draft)),
            LiveOrderTriggerSummary(data: attempted.context, draft: attempted.draft),
          ],
          if (!attempted.draft.market) LiveOrderPolicySummary(policy: attempted.draft.timeInForce),
        ],
        if (result != null && result.orderId != null) ...[
          Text(
            l10n.liveOrderVerifiedResult(
              result.status!,
              result.executedQuantity!.toString(),
              result.orderId!,
            ),
          ),
          SelectableText(result.orderId!),
          Text(
            state.intent?.draft.entireClose == true
                ? l10n.liveEntireQueryScope
                : l10n.liveOrderQueryScope,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (state.intent?.draft.reducing == true)
            LiveCloseResult(intent: state.intent!, result: result),
        ],
        const AttachedOrderStatus(),
        if (state.needsRecheck) ...[
          Text(l10n.liveOrderOutcomeUnknown),
          OutlinedButton(
            key: const Key('live-order-recheck'),
            onPressed: state.busy || auth.busy ? null : controller.recheck,
            child: Text(l10n.liveOrderRecheck),
          ),
        ],
        if (failure != null)
          Text(
            '${tr(context, failure.key)}${failure.code == null ? '' : ' ${l10n.accountErrorCode(failure.code!)}'}',
            key: const Key('live-order-error'),
            style: const TextStyle(color: AppColors.negative),
          ),
      ],
    );
  }
}
