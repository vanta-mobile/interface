import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/app_toast.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/trade_theme.dart';
import '../application/order_modification_provider.dart';
import '../domain/aster_open_orders.dart';
import '../domain/order_modification.dart';
import 'portfolio_components.dart';
import 'position_order_inputs.dart';

/// Opens the "Edit Price/Amount" sheet of one LIMIT open order.
Future<void> showOpenOrderEditSheet(BuildContext context, AsterOpenOrder order) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: TradeColors.sheet,
      barrierColor: TradeColors.scrim,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: TradeColors.card),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => OpenOrderEditSheet(order: order),
    );

/// New absolute price and total amount (base units) for `PUT /fapi/v3/order`.
/// Confirm submits once; an unconfirmed result closes the sheet so the same
/// change cannot be sent again before the order is checked.
class OpenOrderEditSheet extends ConsumerStatefulWidget {
  const OpenOrderEditSheet({super.key, required this.order});
  final AsterOpenOrder order;
  @override
  ConsumerState<OpenOrderEditSheet> createState() => _OpenOrderEditSheetState();
}

class _OpenOrderEditSheetState extends ConsumerState<OpenOrderEditSheet> {
  late final price = TextEditingController(text: marketInput(widget.order.price));
  late final amount = TextEditingController(text: marketInput(widget.order.origQty));
  String? issue;

  @override
  void dispose() {
    price.dispose();
    amount.dispose();
    super.dispose();
  }

  String? _validate(AppLocalizations l10n, Decimal? newPrice, Decimal? newAmount) {
    final order = widget.order;
    if (newPrice == null || newPrice <= Decimal.zero) return l10n.openOrdersEditInvalidPrice;
    if (newAmount == null || newAmount <= order.executedQty) {
      return l10n.openOrdersEditInvalidAmount(marketNumber(order.executedQty));
    }
    if (newPrice == order.price && newAmount == order.origQty) {
      return l10n.openOrdersEditUnchanged;
    }
    return null;
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final newPrice = Decimal.tryParse(price.text.trim());
    final newAmount = Decimal.tryParse(amount.text.trim());
    final problem = _validate(l10n, newPrice, newAmount);
    if (problem != null) {
      setState(() => issue = problem);
      return;
    }
    FocusScope.of(context).unfocus();
    final result = await ref
        .read(orderModificationProvider.notifier)
        .modify(OrderModification(order: widget.order, price: newPrice!, quantity: newAmount!));
    if (!mounted) return;
    final navigator = Navigator.of(context);
    switch (result) {
      case null:
        navigator.maybePop();
      case OrderModificationResult(outcome: OrderModifyOutcome.modified):
        AppToast.showSuccess(context, l10n.openOrdersEditModified);
        navigator.maybePop();
      case OrderModificationResult(outcome: OrderModifyOutcome.unknown):
        AppToast.showFailure(context, l10n.openOrdersEditUnknown);
        navigator.maybePop();
      case OrderModificationResult(closed: true):
        AppToast.showFailure(context, l10n.openOrdersEditClosed);
        navigator.maybePop();
      case OrderModificationResult(:final failure):
        // The original order stays; keep the typed values for another try.
        AppToast.showFailure(
          context,
          l10n.openOrdersEditFailed(failure == null ? '' : accountErrorText(context, failure)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pending = ref.watch(orderModificationProvider.select((s) => s.busy));
    final units = widget.order.units;
    Widget field(String label, Key key, TextEditingController controller, String? unit) =>
        PositionField(
          label: label,
          child: PositionValueInput(
            fieldKey: key,
            controller: controller,
            enabled: !pending,
            bold: false,
            onChanged: () => setState(() => issue = null),
            suffix: PositionSuffix(label: unit ?? l10n.accountUnitUnavailable, caret: false),
          ),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          key: const Key('open-order-edit-sheet'),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.openOrdersEditTitle, style: TradeTypography.heading)),
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const PortfolioIcon('close.svg', size: 24),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1, color: TradeColors.line),
              const SizedBox(height: 8),
              field(
                l10n.openOrdersEditPrice,
                const Key('open-order-edit-price'),
                price,
                units?.quote,
              ),
              const SizedBox(height: 8),
              field(
                l10n.openOrdersEditAmount,
                const Key('open-order-edit-amount'),
                amount,
                units?.base,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.openOrdersEditNote,
                style: TradeTypography.body.copyWith(color: TradeColors.muted),
              ),
              if (issue case final text?) ...[
                const SizedBox(height: 8),
                Text(
                  text,
                  key: const Key('open-order-edit-issue'),
                  style: TradeTypography.body.copyWith(color: TradeColors.negative),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: PositionActionButton(
                      label: l10n.cancel,
                      primary: false,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PositionActionButton(
                      key: const Key('open-order-edit-confirm'),
                      label: l10n.openOrdersConfirm,
                      pending: pending,
                      onPressed: pending ? null : _confirm,
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
