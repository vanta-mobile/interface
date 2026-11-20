import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import 'portfolio_components.dart';
import '../application/scaled_order_provider.dart';
import '../domain/account_snapshot.dart';
import '../domain/live_order_time_in_force.dart';
import '../domain/scaled_order.dart';
import 'order_confirmation_dialog.dart';
import 'order_confirmation_terms.dart';
import 'scaled_order_sheets.dart';

/// Order Confirmation sheet (design 10.16/10.17). Confirming submits every
/// child order; the button stays busy until the last one settles, then the
/// outcome is reported and only a full success closes the sheet.
Future<bool> confirmScaledOrder(BuildContext context, ScaledOrderIntent intent) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: TradeColors.sheet,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: TradeColors.card),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ScaledConfirmation(intent: intent),
    ) ??
    false;

class _ScaledConfirmation extends ConsumerStatefulWidget {
  const _ScaledConfirmation({required this.intent});
  final ScaledOrderIntent intent;
  @override
  ConsumerState<_ScaledConfirmation> createState() => _ScaledConfirmationState();
}

class _ScaledConfirmationState extends ConsumerState<_ScaledConfirmation> {
  bool _pending = false;

  Future<void> _confirm() async {
    if (_pending) return;
    setState(() => _pending = true);
    await ref.read(scaledOrderProvider.notifier).submit(widget.intent);
    if (!mounted) return;
    final outcome = _outcome(ref.read(scaledOrderProvider));
    setState(() => _pending = false);
    showOrderSubmissionOutcome(context, outcome);
    if (outcome.kind == OrderSubmissionKind.success) Navigator.pop(context, true);
  }

  /// Success needs every child placed with an exchange order ID.
  OrderSubmissionOutcome _outcome(ScaledOrderState state) {
    if (!identical(state.intent?.plan, widget.intent.plan)) {
      return const OrderSubmissionOutcome(
        OrderSubmissionKind.notSubmitted,
        AccountReadFailure('scaledRefreshRequired'),
      );
    }
    for (final item in state.items) {
      if (item.failure ?? item.result?.failure case final failure?) {
        return OrderSubmissionOutcome(
          item.submitted ? OrderSubmissionKind.failed : OrderSubmissionKind.notSubmitted,
          failure,
        );
      }
      switch (item.result?.status) {
        case 'REJECTED':
          return const OrderSubmissionOutcome(
            OrderSubmissionKind.failed,
            AccountReadFailure('orderCancelRejected'),
          );
        case 'CANCELED' || 'EXPIRED' || 'EXPIRED_IN_MATCH'
            when widget.intent.plan.draft.timeInForce != LiveOrderTimeInForce.ioc:
          return const OrderSubmissionOutcome(
            OrderSubmissionKind.failed,
            AccountReadFailure('orderCancelExpired'),
          );
      }
      if (item.result?.orderId == null) {
        return const OrderSubmissionOutcome(
          OrderSubmissionKind.notSubmitted,
          AccountReadFailure('scaledRefreshRequired'),
        );
      }
    }
    return const OrderSubmissionOutcome(OrderSubmissionKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), intent = widget.intent;
    final data = intent.context, draft = intent.plan.draft;
    final quote = data.rules.quoteAsset, base = data.rules.baseAsset;
    final direction = draft.buy ? l10n.long : l10n.short;
    return PopScope(
      canPop: !_pending,
      child: SafeArea(
        child: SingleChildScrollView(
          key: const Key('scaled-confirmation'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.orderConfirmTitle, style: TradeTypography.heading)),
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: _pending ? null : () => Navigator.pop(context, false),
                      icon: const PortfolioIcon('close.svg', size: 24),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1, color: TradeColors.line),
              const SizedBox(height: 16),
              OrderConfirmationSymbolRow(symbol: data.symbol, direction: direction, buy: draft.buy),
              for (final (label, value) in [
                (l10n.scaledLowestPriceRow, '${intent.plan.orders.first.price} $quote'),
                (l10n.scaledHighestPriceRow, '${intent.plan.orders.last.price} $quote'),
                (l10n.scaledSubOrderCount, '${intent.plan.orders.length}'),
                (l10n.tradeOrderSize, '${intent.plan.totalQuantity} $base'),
              ]) ...[const SizedBox(height: 8), OrderConfirmationTermRow(label, value)],
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1, color: TradeColors.line),
              ScaledDistributionSection(plan: intent.plan, data: data),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OrderConfirmationActionButton(
                      key: const Key('scaled-cancel'),
                      label: l10n.cancel,
                      color: TradeColors.card,
                      textColor: TradeColors.text,
                      onPressed: _pending ? null : () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OrderConfirmationActionButton(
                      key: const Key('scaled-confirm'),
                      label: direction,
                      color: draft.buy ? TradeColors.positive : TradeColors.negative,
                      textColor: TradeColors.onDirection,
                      pending: _pending,
                      onPressed: _pending ? null : _confirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
