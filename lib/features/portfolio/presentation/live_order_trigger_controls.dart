import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/live_order.dart';
import '../domain/live_order_trigger.dart';
import 'live_order_trailing_controls.dart';

String liveOrderTypeLabel(AppLocalizations l10n, LiveOrderDraft draft) => draft.trailing != null
    ? l10n.openOrdersTrailingStop
    : switch ((draft.trigger?.kind, draft.market)) {
        (null, true) => l10n.market,
        (null, false) => l10n.limit,
        (LiveOrderTriggerKind.stop, true) => l10n.openOrdersStopMarket,
        (LiveOrderTriggerKind.stop, false) => l10n.openOrdersStopLimit,
        (LiveOrderTriggerKind.takeProfit, true) => l10n.openOrdersTakeProfitMarket,
        (LiveOrderTriggerKind.takeProfit, false) => l10n.openOrdersTakeProfitLimit,
      };

String _basisLabel(AppLocalizations l10n, LiveOrderTriggerBasis basis) =>
    basis == LiveOrderTriggerBasis.mark ? l10n.openOrdersMarkPrice : l10n.openOrdersLastPrice;

class LiveOrderTriggerSummary extends StatelessWidget {
  const LiveOrderTriggerSummary({super.key, required this.data, required this.draft});
  final LiveOrderContext data;
  final LiveOrderDraft draft;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), trigger = draft.trigger;
    if (draft.trailing != null) return LiveOrderTrailingSummary(data: data, draft: draft);
    if (trigger == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.liveOrderTriggerBasis, _basisLabel(l10n, trigger.basis)),
        ValueRow(
          l10n.openOrdersTriggerPrice,
          '${trigger.rises(draft.buy) ? '≥' : '≤'} ${trigger.price} ${data.rules.quoteAsset}',
        ),
        ValueRow(
          l10n.liveOrderTriggerProtect,
          trigger.protect ? l10n.liveOrderProtectOn : l10n.liveOrderProtectOff,
        ),
        Text(draft.entireClose ? l10n.liveEntireHint : l10n.liveOrderConditionalHint),
      ],
    );
  }
}
