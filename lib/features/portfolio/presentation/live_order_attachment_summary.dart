import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/live_order.dart';
import '../domain/live_order_trigger.dart';
import '../domain/live_order_attachment.dart';
import 'attached_exit_preview.dart';

class LiveOrderAttachmentSummary extends StatelessWidget {
  const LiveOrderAttachmentSummary({super.key, required this.intent});
  final LiveOrderIntent intent;
  @override
  Widget build(BuildContext context) {
    final attachment = intent.draft.attachment;
    if (attachment == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.attachedOrderTitle, style: Theme.of(context).textTheme.titleSmall),
        ValueRow(l10n.attachedOrderStrategyType, attachment.strategyType),
        for (final exit in attachment.exits) ...[
          ValueRow(
            exit.kind == LiveOrderTriggerKind.takeProfit
                ? l10n.attachedOrderTakeProfit
                : l10n.attachedOrderStopLoss,
            '${exit.basis == LiveOrderTriggerBasis.last ? l10n.openOrdersLastPrice : l10n.openOrdersMarkPrice} '
            '${exit.rises(!intent.draft.buy) ? '≥' : '≤'} ${exit.price} ${intent.context.rules.quoteAsset}'
            '${exit.protect ? ' · ${l10n.attachedOrderPriceProtect}' : ''}',
          ),
          ValueRow(
            l10n.attachedOrderExecution,
            '${intent.draft.buy ? l10n.sell : l10n.buy} · ${attachedExecutionLabel(l10n, exit.execution)}'
            '${!exit.market ? ' · ${exit.executionPrice} ${intent.context.rules.quoteAsset}' : ''}',
          ),
        ],
        ValueRow(
          l10n.attachedOrderExitQuantity,
          '${intent.draft.quantity} ${intent.context.rules.baseAsset}',
        ),
        Text(
          attachment.drivenOn == AttachedOrderDrivenOn.filled
              ? l10n.attachedOrderLegacyLifecycle
              : l10n.attachedOrderLifecycle,
        ),
        Text(l10n.attachedOrderEstimateScope),
        Text(l10n.attachedOrderManageScope),
      ],
    );
  }
}
