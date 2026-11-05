import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/live_order_provider.dart';
import 'attached_entry_pricing.dart';
import '../domain/order_query.dart';
import 'strategy_execution_screen.dart';

class AttachedOrderStatus extends ConsumerWidget {
  const AttachedOrderStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveOrderProvider), snapshot = state.result?.strategy;
    if (snapshot == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context), auth = ref.watch(authProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.attachedOrderVerified),
        if (state.intent?.draft.attachment?.entryPeg case final peg?)
          AttachedEntryPegSummary(peg: peg, showEstimate: false),
        Text(l10n.attachedOrderStrategyId),
        SelectableText(snapshot.strategyId),
        ValueRow(l10n.attachedOrderStrategyStatus, snapshot.status),
        for (final leg in snapshot.legs) ...[
          ValueRow(l10n.attachedOrderLegStatus(leg.sequence), leg.status),
          if (leg.orderId != null) SelectableText(leg.orderId!),
        ],
        Text(l10n.attachedOrderQueryScope),
        if (state.intent case final intent?)
          OutlinedButton(
            key: const Key('attached-order-execution'),
            onPressed: state.busy || auth.busy
                ? null
                : () => openStrategyExecution(
                    context,
                    OrderQuery.capture(intent),
                    snapshot.strategyId,
                  ),
            child: Text(l10n.strategyExecutionTitle),
          ),
        OutlinedButton(
          key: const Key('attached-order-refresh'),
          onPressed: state.busy || auth.busy || auth.identity?.signingAvailable != true
              ? null
              : ref.read(liveOrderProvider.notifier).recheck,
          child: Text(l10n.attachedOrderRefresh),
        ),
      ],
    );
  }
}
