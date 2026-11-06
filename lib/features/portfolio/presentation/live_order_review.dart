import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/live_order_provider.dart';
import '../domain/live_order.dart';
import '../domain/futures_position_mode.dart';
import '../domain/position_margin_mode.dart';
import 'live_order_funds_panel.dart';
import 'live_order_policy.dart';
import 'live_order_trigger_controls.dart';
import '../application/order_confirmation_provider.dart';
import '../domain/order_confirmation.dart';
import '../../auth/application/auth_provider.dart';
import 'live_order_attachment_summary.dart';
import 'attached_entry_pricing.dart';
import 'live_order_pricing.dart';
import '../domain/live_order_size.dart';
import 'live_order_size_field.dart';

Future<void> reviewLiveOrder(
  BuildContext context,
  WidgetRef ref,
  LiveOrderIntent intent, {
  OrderSizeResolution? sizing,
  Future<void> Function()? onSubmit,
  Widget? extraTerms,
}) async {
  final controller = ref.read(liveOrderProvider.notifier);
  final kind = orderConfirmationKind(intent.draft);
  final preference = ref.read(orderConfirmationProvider(kind));
  final identity = ref.read(authProvider).identity;
  // Reducing and entire-position close flows keep their dedicated review.
  if (!intent.draft.reducing && preference.canSkip) {
    await (onSubmit?.call() ?? controller.submit(intent));
    return;
  }
  var skipNext = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          scrollable: true,
          title: Text(
            intent.draft.reducing ? l10n.liveCloseConfirmTitle : l10n.liveOrderConfirmTitle,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                intent.draft.attachment != null
                    ? l10n.attachedOrderConfirmHint
                    : intent.draft.reducing
                    ? l10n.liveCloseConfirmHint
                    : l10n.liveOrderConfirmHint,
              ),
              SelectableText(intent.context.address),
              SelectableText(intent.context.symbol),
              if (!intent.draft.reducing) LiveOrderFundsPanel(data: intent.context),
              _LiveOrderAccountTerms(intent: intent),
              _LiveOrderFinancialTerms(intent: intent, sizing: sizing),
              ?extraTerms,
              if (!intent.draft.reducing)
                CheckboxListTile(
                  key: const Key('live-order-skip-confirmation'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.orderConfirmDoNotShow),
                  value: skipNext,
                  onChanged: (value) => setState(() => skipNext = value ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(
              key: const Key('live-order-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.liveOrderSignSubmit),
            ),
          ],
        );
      },
    ),
  );
  if (confirmed != true ||
      !context.mounted ||
      !identical(identity, ref.read(authProvider).identity)) {
    return;
  }
  if (skipNext) await ref.read(orderConfirmationProvider(kind).notifier).select(false);
  if (context.mounted) await (onSubmit?.call() ?? controller.submit(intent));
}

class _LiveOrderAccountTerms extends StatelessWidget {
  const _LiveOrderAccountTerms({required this.intent});
  final LiveOrderIntent intent;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(
          l10n.liveOrderSide,
          intent.draft.reducing
              ? (intent.draft.buy ? l10n.liveCloseShort : l10n.liveCloseLong)
              : (intent.draft.buy ? l10n.long : l10n.short),
        ),
        if (intent.draft.reducing) ...[
          SelectableText(intent.positionSide),
          ValueRow(
            l10n.liveClosePositionAmount,
            '${intent.context.reductionPosition(intent.draft)!.quantity.abs()} ${intent.context.rules.baseAsset}',
          ),
          if (!intent.draft.entireClose) Text(l10n.liveOrderReduceHint),
        ],
        ValueRow(
          l10n.positionModeSettings,
          intent.mode == FuturesPositionMode.oneWay
              ? l10n.positionModeOneWay
              : l10n.positionModeHedge,
        ),
        ValueRow(
          l10n.accountMarginMode,
          intent.context.marginMode == PositionMarginMode.cross
              ? l10n.cross
              : l10n.accountIsolatedMode,
        ),
        ValueRow(l10n.leverageCurrentSetting, '${intent.context.leverage}×'),
      ],
    );
  }
}

class _LiveOrderFinancialTerms extends StatelessWidget {
  const _LiveOrderFinancialTerms({required this.intent, this.sizing});
  final LiveOrderIntent intent;
  final OrderSizeResolution? sizing;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notional = intent.draft.entireClose
        ? null
        : parseOrderDecimal(intent.draft.quantity)! *
              intent.context.referenceExecutionPrice(intent.draft)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.liveOrderType, liveOrderTypeLabel(l10n, intent.draft)),
        LiveOrderTriggerSummary(data: intent.context, draft: intent.draft),
        LiveOrderAttachmentSummary(intent: intent),
        if (!intent.draft.market) LiveOrderPolicySummary(policy: intent.draft.timeInForce),
        ValueRow(
          l10n.liveOrderQuantity(intent.context.rules.baseAsset),
          intent.draft.entireClose ? l10n.liveEntireQuantity : intent.draft.quantity,
        ),
        if (intent.draft.attachment?.entryPeg case final peg?)
          AttachedEntryPegSummary(peg: peg)
        else if (intent.draft.peg case final peg?)
          LiveOrderPegSummary(peg: peg)
        else if (!intent.draft.market)
          ValueRow(l10n.liveOrderPrice(intent.context.rules.quoteAsset), intent.draft.price),
        if (sizing?.converted == true) LiveOrderSizePreview(value: sizing!, data: intent.context),
        if (notional != null && sizing?.converted != true)
          ValueRow(l10n.liveOrderEstimatedNotional, '$notional ${intent.context.rules.quoteAsset}'),
        Text(intent.draft.attachment != null ? l10n.attachedOrderClientId : l10n.liveOrderClientId),
        if (!intent.draft.reducing) LiveOrderCostPreview(data: intent.context, draft: intent.draft),
        SelectableText(intent.clientOrderId),
      ],
    );
  }
}
