import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/app_toast.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/application/market_providers.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_option_sheet.dart';
import '../application/live_order_provider.dart';
import '../application/position_order_submission.dart';
import '../application/position_risk_provider.dart';
import '../domain/attached_entry_peg.dart';
import '../domain/live_order.dart';
import '../domain/live_order_peg.dart';
import '../domain/live_order_size.dart';
import '../domain/live_order_time_in_force.dart';
import '../domain/live_order_trigger.dart';
import '../domain/position_risk.dart';
import '../domain/percent_share.dart';
import '../domain/position_valuation.dart';
import 'portfolio_components.dart';
import 'position_order_inputs.dart';
import 'position_tpsl_summary.dart';
import 'position_valuation_rows.dart';
import 'trade_check_option.dart';

/// Opens the Close Position sheet on its Market close or Limit close tab.
Future<void> showPositionCloseSheet(
  BuildContext context,
  PositionRisk position, {
  bool limit = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: false,
  backgroundColor: TradeColors.sheet,
  barrierColor: TradeColors.scrim,
  shape: const RoundedRectangleBorder(
    side: BorderSide(color: TradeColors.card),
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => PositionCloseSheet(position: position, limit: limit),
);

/// Market or limit close of one position (Futures PRD «仓位操作：Market／Limit»):
/// a reverse order of the chosen quantity, reduce-only in one-way mode and on
/// the position side in hedge mode. Confirm submits once; no automatic retry.
class PositionCloseSheet extends ConsumerStatefulWidget {
  const PositionCloseSheet({super.key, required this.position, this.limit = false});
  final PositionRisk position;
  final bool limit;
  @override
  ConsumerState<PositionCloseSheet> createState() => _PositionCloseSheetState();
}

class _PositionCloseSheetState extends ConsumerState<PositionCloseSheet> {
  late bool limit = widget.limit;
  final amount = TextEditingController(), price = TextEditingController();
  OrderSizeUnit unit = OrderSizeUnit.quote;

  /// Slider stop of the amount; null once the amount is typed.
  int? percent;
  LiveOrderPeg? peg;
  bool hidden = false;

  /// Reference the order price was last filled from (Last or Mark price).
  LiveOrderTriggerBasis priceType = LiveOrderTriggerBasis.last;
  String? issue;

  String get symbol => widget.position.symbol;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(liveOrderProvider.notifier).load(symbol, includeFunds: false);
    });
  }

  @override
  void dispose() {
    amount.dispose();
    price.dispose();
    super.dispose();
  }

  void _render([VoidCallback? change]) => setState(() {
    change?.call();
    issue = null;
  });

  /// The newest snapshot of this position, or the one the sheet opened with.
  PositionRisk _position() {
    final p = widget.position;
    for (final row
        in ref.watch(positionRiskProvider.select((s) => s.account?.positions)) ??
            const <PositionRisk>[]) {
      if (row.symbol == p.symbol && row.side == p.side && !row.balanceOnly) return row;
    }
    return p;
  }

  /// Close quantity: the slider share of the position, or the typed amount in
  /// base units or quote value (at the limit price, else the mark), floored to
  /// the exchange step of this order type.
  Decimal? _quantity(PositionRisk p, Decimal? mark, LiveOrderContext? data) {
    if (percent case final share?) {
      if (data != null) {
        final value = data.closeFraction(p.side, share, market: !limit);
        return value > Decimal.zero ? value : null;
      }
      return share == 0 ? null : p.quantity.abs() * Decimal.fromInt(share) * Decimal.parse('0.01');
    }
    final typed = Decimal.tryParse(amount.text.trim());
    if (typed == null || typed <= Decimal.zero) return null;
    var raw = typed;
    if (unit == OrderSizeUnit.quote) {
      final reference = limit && peg == null ? parseOrderDecimal(price.text.trim()) : mark;
      if (reference == null || reference <= Decimal.zero) return null;
      raw = (typed / reference).toDecimal(scaleOnInfinitePrecision: 24);
    }
    if (data == null) return raw;
    final value = (limit ? data.rules.limitQuantity : data.rules.marketQuantity).floor(raw);
    return value > Decimal.zero ? value : null;
  }

  LiveOrderDraft _draft(PositionRisk p, Decimal? quantity) => LiveOrderDraft(
    buy: !p.long,
    market: !limit,
    quantity: quantity?.toString() ?? '',
    price: limit && peg == null ? price.text.trim() : '',
    closingSide: p.side,
    timeInForce: limit && hidden ? LiveOrderTimeInForce.hidden : LiveOrderTimeInForce.gtc,
    peg: limit ? peg : null,
  );

  /// Slider range in the shown unit: the position quantity, or its value at
  /// the mark. Null while the mark is unknown.
  Decimal? _maximum(PositionRisk p, Decimal? mark) {
    final total = p.quantity.abs();
    final value = unit == OrderSizeUnit.base ? total : (mark == null ? null : total * mark);
    return value == null || value <= Decimal.zero ? null : value;
  }

  /// Trade-workspace slider rules ([sliderChoice]). Base amounts move in the
  /// exchange step of this order type; without it the slider keeps its stops.
  ({Decimal? maximum, Decimal fine}) _sliderScale(
    PositionRisk p,
    Decimal? mark,
    LiveOrderContext? data,
  ) {
    if (unit == OrderSizeUnit.quote) {
      return (maximum: _maximum(p, mark), fine: Decimal.parse('0.01'));
    }
    final rule = data == null
        ? null
        : (limit ? data.rules.limitQuantity : data.rules.marketQuantity);
    return (maximum: rule == null ? null : _maximum(p, mark), fine: rule?.step ?? Decimal.one);
  }

  void _selectPosition(double position, PositionRisk p, Decimal? mark, LiveOrderContext? data) {
    final scale = _sliderScale(p, mark, data);
    final choice = sliderChoice(position, maximum: scale.maximum, fine: scale.fine);
    if (choice.percent case final share?) return _selectPercent(share, p, mark);
    _render(() {
      percent = null;
      amount.text = marketInput(choice.amount!);
    });
  }

  void _selectPercent(int value, PositionRisk p, Decimal? mark) => _render(() {
    percent = value;
    final maximum = _maximum(p, mark);
    final shown = maximum == null ? null : percentShare(maximum, value);
    amount.text = shown == null
        ? ''
        : marketInput(shown.round(scale: unit == OrderSizeUnit.base ? 8 : 2));
  });

  Future<void> _chooseUnit(PositionRisk p) async {
    final l10n = AppLocalizations.of(context);
    String label(OrderSizeUnit value) => value == OrderSizeUnit.quote
        ? p.units?.quote ?? l10n.accountUnitUnavailable
        : p.units?.base ?? l10n.accountUnitUnavailable;
    final value = await showTradeOptionSheet(
      context,
      title: l10n.tradeSelectUnitType,
      selected: unit,
      options: [
        for (final option in OrderSizeUnit.values.reversed)
          (value: option, label: label(option), description: null),
      ],
    );
    if (value == null || value == unit || !mounted) return;
    _render(() {
      unit = value;
      percent = null;
      amount.clear();
    });
  }

  Future<void> _chooseLevel() async {
    final l10n = AppLocalizations.of(context), current = peg;
    if (current == null) return;
    final value = await showTradeOptionSheet(
      context,
      key: const Key('position-close-bbo-levels'),
      title: l10n.liveOrderBboModeTitle,
      selected: current,
      footer: l10n.liveOrderBboModeHint,
      options: [
        for (final level in const [LiveOrderPeg.counterparty, LiveOrderPeg.queue])
          (value: level, label: _levelLabel(l10n, level), description: null),
      ],
    );
    if (value != null && peg != null && mounted) _render(() => peg = value);
  }

  static String _levelLabel(AppLocalizations l10n, LiveOrderPeg peg) => peg == LiveOrderPeg.queue
      ? l10n.liveOrderBboQueue(AttachedEntryPeg.queue1.depth)
      : l10n.liveOrderBboCounterparty(AttachedEntryPeg.counterparty1.depth);

  /// Fills the order price from the chosen reference. The last price falls back
  /// to the public ticker and the mark to the live mark stream, so this works
  /// before the signed order context has been read.
  Future<void> _choosePriceType({required Decimal? last, required Decimal? mark}) async {
    final l10n = AppLocalizations.of(context);
    final value = await showTradeOptionSheet(
      context,
      key: const Key('position-close-price-types'),
      title: l10n.tradeSelectPriceType,
      selected: priceType,
      options: [
        (value: LiveOrderTriggerBasis.last, label: l10n.openOrdersLastPrice, description: null),
        (value: LiveOrderTriggerBasis.mark, label: l10n.openOrdersMarkPrice, description: null),
      ],
    );
    if (value == null || !mounted) return;
    final reference = value == LiveOrderTriggerBasis.last ? last : mark;
    setState(() {
      priceType = value;
      issue = reference == null
          ? l10n.positionClosePriceUnavailable(
              value == LiveOrderTriggerBasis.last
                  ? l10n.openOrdersLastPrice
                  : l10n.openOrdersMarkPrice,
            )
          : null;
      if (reference != null) {
        peg = null;
        price.text = marketInput(reference);
      }
    });
  }

  Future<void> _confirm(PositionRisk p, Decimal? mark) async {
    final l10n = AppLocalizations.of(context);
    String? problem;
    if (limit && peg == null && parseOrderDecimal(price.text.trim()) == null) {
      problem = l10n.positionTpslMissingLimit;
    } else if (_quantity(p, mark, null) == null) {
      problem = l10n.positionTpslMissingAmount;
    }
    if (problem != null) {
      setState(() => issue = problem);
      return;
    }
    FocusScope.of(context).unfocus();
    final wasLimit = limit;
    await ref
        .read(positionCloseProvider.notifier)
        .submit(symbol, (data) => _draft(p, _quantity(p, data.markPrice, data)));
    if (!mounted) return;
    final attempt = ref.read(positionCloseProvider).attempt;
    switch (attempt?.outcome) {
      case PositionOrderOutcome.placed:
        AppToast.showSuccess(
          context,
          wasLimit ? l10n.positionCloseLimitPlaced : l10n.positionClosePlaced,
        );
        Navigator.of(context).maybePop();
      case PositionOrderOutcome.unknown:
        // An unconfirmed close must not be sent again by another tap.
        _render(() {
          percent = null;
          amount.clear();
        });
        AppToast.showFailure(context, l10n.positionCloseUnknown);
      case PositionOrderOutcome.failed:
      case null:
        AppToast.showFailure(
          context,
          l10n.positionCloseFailed(
            attempt?.failure == null ? '' : accountErrorText(context, attempt!.failure!),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = _position();
    final (quote, _) = watchPositionMark(ref, p);
    final mark = PositionValuation(position: p, quote: quote).mark;
    final live = ref.watch(liveOrderProvider);
    final data = live.context?.symbol == symbol ? live.context : null;
    final submitting = ref.watch(positionCloseProvider.select((s) => s.busy));
    final enabled = !submitting;
    final quantity = _quantity(p, mark, data);
    final pnl = data?.estimatedClosePnl(_draft(p, quantity));
    final quoteUnit = p.units?.quote ?? l10n.accountUnitUnavailable;
    // Public last price of this symbol, watched only on the Limit close tab.
    final lastQuote = limit
        ? ref.watch(
            liveMarketQuotesProvider.select(
              (s) => s.value?.quotes.where((q) => q.symbol == symbol).firstOrNull?.price,
            ),
          )
        : null;
    final loadFailure = live.intent == null && data == null ? live.failure : null;
    final message = issue ?? (loadFailure == null ? null : accountErrorText(context, loadFailure));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          key: const Key('position-close-sheet'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.positionCloseTitle, style: TradeTypography.heading)),
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
              const SizedBox(height: 16),
              PositionTabs<bool>(
                tabs: [(false, l10n.positionCloseMarket), (true, l10n.positionCloseLimit)],
                selected: limit,
                onSelect: enabled ? (value) => _render(() => limit = value) : null,
              ),
              const SizedBox(height: 16),
              if (limit) ...[
                PositionPriceRow(
                  controller: price,
                  caption: l10n.positionOrderPrice,
                  enabled: enabled,
                  onChanged: _render,
                  suffix: Semantics(
                    button: true,
                    label: l10n.tradeSelectPriceType,
                    child: PositionTapTarget(
                      key: const Key('position-close-price-type'),
                      onTap: enabled
                          ? () => _choosePriceType(
                              last: data?.lastPrice ?? lastQuote,
                              mark: mark ?? data?.markPrice,
                            )
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            priceType == LiveOrderTriggerBasis.last
                                ? l10n.openOrdersLastPrice
                                : l10n.openOrdersMarkPrice,
                            style: TradeTypography.body.copyWith(color: TradeColors.accent),
                          ),
                          const SizedBox(width: 4),
                          PositionSuffix(label: quoteUnit),
                        ],
                      ),
                    ),
                  ),
                  onBbo: () => _render(() => peg = peg == null ? LiveOrderPeg.queue : null),
                  bboLevel: peg == null ? null : _levelLabel(l10n, peg!),
                  onBboLevel: _chooseLevel,
                ),
                const SizedBox(height: 8),
              ],
              PositionField(
                label: l10n.positionTpslAmount,
                child: PositionValueInput(
                  fieldKey: const Key('position-close-amount'),
                  controller: amount,
                  enabled: enabled,
                  onChanged: () => _render(() => percent = null),
                  suffix: PositionSuffix(
                    key: const Key('position-close-unit'),
                    label: unit == OrderSizeUnit.quote
                        ? quoteUnit
                        : p.units?.base ?? l10n.accountUnitUnavailable,
                    tooltip: l10n.tradeSelectUnitType,
                    onTap: enabled ? () => _chooseUnit(p) : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PositionAmountSlider(
                sliderKey: const Key('position-close-percent'),
                position: sliderPosition(
                  percent: percent,
                  amount: Decimal.tryParse(amount.text.trim()),
                  maximum: _maximum(p, mark),
                ),
                continuous: _sliderScale(p, mark, data).maximum != null,
                onCommit: enabled ? (value) => _selectPosition(value, p, mark, data) : null,
              ),
              if (limit) ...[
                const SizedBox(height: 8),
                TradeCheckOption(
                  tapKey: const Key('position-close-hidden'),
                  label: l10n.tradeHiddenOrder,
                  value: hidden,
                  minHeight: 20,
                  onChanged: (value) {
                    if (enabled) _render(() => hidden = value);
                  },
                ),
              ],
              const SizedBox(height: 16),
              PositionOrderSummary(
                position: p,
                limit: limit,
                bordered: true,
                rows: [
                  (l10n.positionTpslEntryPrice, Text(summaryPrice(context, p, p.entryPrice))),
                  (l10n.positionTpslMarkPrice, Text(summaryPrice(context, p, mark))),
                  (
                    l10n.positionClosePositionAmount,
                    Text(summaryPrice(context, p, mark == null ? null : (p.quantity * mark).abs())),
                  ),
                  (l10n.positionTpslEstimatedPnl, summaryPnlText(context, p, pnl)),
                ],
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  key: const Key('position-close-issue'),
                  style: TradeTypography.body.copyWith(color: TradeColors.negative),
                ),
              ],
              const SizedBox(height: 36),
              Row(
                children: [
                  Expanded(
                    child: PositionActionButton(
                      key: const Key('position-close-cancel'),
                      label: l10n.cancel,
                      primary: false,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PositionActionButton(
                      key: const Key('position-close-confirm'),
                      label: l10n.positionTpslConfirm,
                      pending: submitting,
                      onPressed: enabled ? () => _confirm(p, mark) : null,
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
