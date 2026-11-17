import '../../../l10n/generated/app_localizations.dart';
import '../domain/live_order.dart';
import '../domain/live_order_trigger.dart';

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
