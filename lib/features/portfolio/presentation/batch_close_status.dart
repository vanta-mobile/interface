import '../../../core/errors/error_text.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/batch_close_provider.dart';
import '../application/position_risk_provider.dart';
import '../domain/live_order.dart';
import 'batch_close_controls.dart';

class BatchCloseStatus extends ConsumerWidget {
  const BatchCloseStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(batchCloseProvider), intent = state.intent;
    if (intent == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context), auth = ref.watch(authProvider);
    final risk = ref.watch(positionRiskProvider), snapshot = risk.account;
    final controller = ref.read(batchCloseProvider.notifier);
    final remainingVerified =
        snapshot != null &&
        state.remainingAfter != null &&
        !risk.stale &&
        !risk.busy &&
        risk.failure == null &&
        snapshot.address.toLowerCase() == intent.address.toLowerCase() &&
        !snapshot.receivedAt.isBefore(state.remainingAfter!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(l10n.batchCloseCount(intent.targets.length)),
        SelectableText(intent.address),
        Text(intent.symbol == null ? l10n.batchCloseAll : l10n.batchCloseCurrent),
        if (intent.symbol != null) SelectableText(intent.symbol!),
        Text(l10n.liveCloseResultScope),
        if (state.busy) ...[
          const LinearProgressIndicator(),
          Text(switch (state.step) {
            LiveOrderStep.signingContext ||
            LiveOrderStep.signingPosition ||
            LiveOrderStep.signing ||
            LiveOrderStep.checkSigning => l10n.accountReadSigning,
            LiveOrderStep.submitting => l10n.liveOrderSubmitting,
            _ => l10n.accountReadLoading,
          }),
          OutlinedButton(
            key: const Key('batch-close-stop'),
            onPressed: state.stopRequested ? null : controller.stop,
            child: Text(l10n.batchCancelStop),
          ),
        ],
        if (state.stopRequested) Text(l10n.batchCloseStopped),
        for (final item in state.items.values)
          Padding(
            key: ValueKey('batch-close-result-${item.target.key}'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BatchCloseTargetDetails(target: item.target),
                Text(
                  state.busy && state.currentKey == item.target.key
                      ? l10n.batchCancelInProgress
                      : !item.submitted
                      ? l10n.batchCancelNotSubmitted
                      : item.needsRecheck
                      ? l10n.liveOrderOutcomeUnknown
                      : l10n.liveOrderVerifiedResult(
                          item.result!.status!,
                          item.result!.executedQuantity!.toString(),
                          item.result!.orderId!,
                        ),
                ),
                if (item.result?.orderId case final id?) SelectableText(id),
                if (item.failure ?? item.result?.failure case final failure?)
                  Text(
                    accountErrorText(context, failure),
                    style: const TextStyle(color: AppColors.negative),
                  ),
                if (remainingVerified)
                  ValueRow(
                    l10n.liveCloseRemaining,
                    '${snapshot.positions.where((p) => p.symbol == item.target.position.symbol && p.side == item.target.position.side).firstOrNull?.quantity ?? Decimal.zero} '
                    '${item.order?.context.rules.baseAsset ?? item.target.position.units?.base ?? l10n.accountUnitUnavailable}',
                  ),
              ],
            ),
          ),
        if (state.needsRecheck)
          OutlinedButton(
            key: const Key('batch-close-recheck'),
            onPressed: state.busy || auth.busy || auth.identity?.signingAvailable != true
                ? null
                : controller.recheck,
            child: Text(l10n.batchCloseRecheck),
          ),
        if (state.remainingAfter != null)
          OutlinedButton(
            key: const Key('batch-close-read-remaining'),
            onPressed:
                state.busy ||
                    risk.busy ||
                    auth.busy ||
                    auth.identity?.signingAvailable != true ||
                    auth.identity?.walletAddress?.toLowerCase() != intent.address.toLowerCase()
                ? null
                : () => ref.read(positionRiskProvider.notifier).refresh(),
            child: Text(l10n.liveCloseReadRemaining),
          ),
        if (!state.busy && risk.busy) const LinearProgressIndicator(),
        if (remainingVerified) Text('${snapshot.receivedAt.toUtc().toIso8601String()} UTC'),
        if (!state.busy)
          if (risk.failure case final failure?)
            Text(
              accountErrorText(context, failure),
              style: const TextStyle(color: AppColors.negative),
            ),
      ],
    );
  }
}
