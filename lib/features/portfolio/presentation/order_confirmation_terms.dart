import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/live_order.dart';
import '../domain/live_order_attachment.dart';
import '../domain/live_order_size.dart';
import '../domain/live_order_time_in_force.dart';
import '../domain/live_order_trigger.dart';
import 'attached_entry_pricing.dart';
import 'attached_exit_preview.dart';
import 'live_order_policy.dart';
import 'live_order_pricing.dart';
import 'live_order_trigger_controls.dart';

/// Key/value terms of the order being confirmed. Rows beyond the design's
/// price and quantity appear only for options the order actually uses.
class OrderConfirmationTerms extends StatelessWidget {
  const OrderConfirmationTerms({
    super.key,
    required this.intent,
    required this.direction,
    this.sizing,
  });
  final LiveOrderIntent intent;
  final OrderSizeResolution? sizing;
  final String direction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), draft = intent.draft;
    final quote = intent.context.rules.quoteAsset, base = intent.context.rules.baseAsset;
    final converted = !draft.entireClose && sizing?.converted == true;
    final rows = <Widget>[
      _SymbolRow(symbol: intent.context.symbol, direction: direction, buy: draft.buy),
      if (draft.trigger != null || draft.trailing != null)
        _TermRow(l10n.liveOrderType, liveOrderTypeLabel(l10n, draft)),
      _TermRow(l10n.orderConfirmPrice, _price(l10n, draft, quote)),
      _TermRow(
        l10n.orderConfirmQuantity,
        draft.entireClose
            ? l10n.liveEntireQuantity
            : converted
            ? '${sizing!.input} $quote'
            : '${draft.quantity} $base',
        key: const Key('order-confirm-quantity'),
      ),
      if (converted) _TermRow(l10n.liveAmountResolvedQuantity, '${draft.quantity} $base'),
      ..._triggerRows(l10n, draft, quote),
      if (!draft.market && draft.timeInForce != LiveOrderTimeInForce.gtc)
        _TermRow(l10n.liveOrderPolicy, liveOrderPolicyLabel(l10n, draft.timeInForce)),
      if (draft.reduceOnly) _TermRow(l10n.reduceOnly, l10n.liveOrderProtectOn),
      for (final exit in [...?draft.attachment?.exits])
        _TermRow(
          exit.kind == LiveOrderTriggerKind.takeProfit
              ? l10n.orderConfirmTakeProfit
              : l10n.orderConfirmStopLoss,
          _exit(l10n, exit, quote),
          labelColor: exit.kind == LiveOrderTriggerKind.takeProfit
              ? TradeColors.positive
              : TradeColors.negative,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 8), rows[i]],
      ],
    );
  }

  String _price(AppLocalizations l10n, LiveOrderDraft draft, String quote) {
    if (draft.attachment?.entryPeg case final peg?) return attachedEntryPegLabel(l10n, peg);
    if (draft.peg case final peg?) return liveOrderPegLabel(l10n, peg);
    return draft.market ? l10n.orderConfirmMarketPrice : '${draft.price} $quote';
  }

  List<Widget> _triggerRows(AppLocalizations l10n, LiveOrderDraft draft, String quote) {
    if (draft.trailing case final trailing?) {
      return [
        _TermRow(l10n.liveTrailingRate, '${trailing.callbackRate}%'),
        _TermRow(l10n.liveTrailingBasis, _basis(l10n, trailing.basis)),
        if (trailing.activationPrice case final price?)
          _TermRow(l10n.liveTrailingActivation(quote), price),
      ];
    }
    final trigger = draft.trigger;
    if (trigger == null) return const [];
    return [
      _TermRow(
        l10n.openOrdersTriggerPrice,
        '${_basis(l10n, trigger.basis)} ${trigger.rises(draft.buy) ? '≥' : '≤'} '
        '${trigger.price} $quote',
      ),
      if (trigger.protect) _TermRow(l10n.liveOrderTriggerProtect, l10n.liveOrderProtectOn),
    ];
  }

  String _exit(AppLocalizations l10n, AttachedExit exit, String quote) =>
      '${_basis(l10n, exit.basis)} ${exit.rises(!intent.draft.buy) ? '≥' : '≤'} '
      '${exit.price} $quote'
      '${!exit.market ? ' · ${attachedExecutionLabel(l10n, exit.execution)} ${exit.executionPrice} $quote' : ''}'
      '${exit.protect ? ' · ${l10n.attachedOrderPriceProtect}' : ''}';

  String _basis(AppLocalizations l10n, LiveOrderTriggerBasis basis) =>
      basis == LiveOrderTriggerBasis.mark ? l10n.openOrdersMarkPrice : l10n.openOrdersLastPrice;
}

class _SymbolRow extends StatelessWidget {
  const _SymbolRow({required this.symbol, required this.direction, required this.buy});
  final String symbol, direction;
  final bool buy;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: SelectableText(symbol, style: TradeTypography.body)),
      const SizedBox(width: 8),
      // Keep the tag flush with the value column; let long close labels wrap
      // on narrow screens or with enlarged text.
      Flexible(
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            key: const Key('order-confirm-direction'),
            constraints: const BoxConstraints(minWidth: 112),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: buy ? TradeColors.buyLabel : TradeColors.sellLabel,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              direction,
              textAlign: TextAlign.center,
              style: TradeTypography.tag.copyWith(
                color: buy ? TradeColors.positive : TradeColors.negative,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _TermRow extends StatelessWidget {
  const _TermRow(this.label, this.value, {super.key, this.labelColor = TradeColors.secondary});
  final String label, value;
  final Color labelColor;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 22),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: TradeTypography.body.copyWith(color: labelColor)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TradeTypography.body.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}
