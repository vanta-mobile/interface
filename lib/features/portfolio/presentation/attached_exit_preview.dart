import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/attached_exit_input.dart';
import '../domain/live_order.dart';
import '../domain/live_order_attachment.dart';
import '../domain/live_order_trigger.dart';

String attachedExecutionLabel(AppLocalizations l10n, AttachedExitExecution execution) =>
    switch (execution) {
      AttachedExitExecution.market => l10n.market,
      AttachedExitExecution.manualLimit => l10n.attachedOrderManualLimit,
      AttachedExitExecution.automaticLimit => l10n.attachedOrderAutomaticLimit,
    };

class AttachedExitPreview extends StatelessWidget {
  const AttachedExitPreview({
    super.key,
    required this.data,
    required this.entry,
    required this.resolution,
    required this.derived,
  });
  final LiveOrderContext data;
  final LiveOrderDraft entry;
  final AttachedExitResolution resolution;
  final bool derived;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), exit = resolution.exit;
    final ready = resolution.failure == null;
    final quote = data.rules.quoteAsset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(
          l10n.attachedOrderTriggerPreview,
          !ready
              ? '—'
              : '${exit.basis == LiveOrderTriggerBasis.mark ? l10n.openOrdersMarkPrice : l10n.openOrdersLastPrice} '
                    '${exit.rises(!entry.buy) ? '≥' : '≤'} ${exit.price} $quote',
        ),
        ValueRow(
          l10n.attachedOrderExecution,
          '${entry.buy ? l10n.sell : l10n.buy} · ${attachedExecutionLabel(l10n, exit.execution)}'
          '${!exit.market && ready ? ' · ${exit.executionPrice} $quote' : ''}',
        ),
        ValueRow(
          l10n.attachedOrderGrossPnl,
          ready && resolution.pnl != null ? '${resolution.pnl} $quote' : '—',
        ),
        ValueRow(
          l10n.attachedOrderGrossRoi,
          ready && resolution.roi != null ? '${resolution.roi}%' : '—',
        ),
        if (derived) Text(l10n.attachedOrderRoundedPreview),
        Text(l10n.attachedOrderEstimateScope),
      ],
    );
  }
}
