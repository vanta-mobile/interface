import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/app_toast.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_option_sheet.dart';
import '../../auth/application/auth_provider.dart';
import '../application/live_order_provider.dart';
import '../application/open_orders_auto_read_provider.dart';
import '../application/open_orders_provider.dart';
import '../application/order_cancellation_provider.dart';
import '../application/position_risk_provider.dart';
import '../application/position_tpsl_provider.dart';
import '../domain/aster_open_orders.dart';
import '../domain/attached_entry_peg.dart';
import '../domain/live_order.dart';
import '../domain/live_order_peg.dart';
import '../domain/live_order_trigger.dart';
import '../domain/position_exit_groups.dart';
import '../domain/position_risk.dart';
import '../domain/position_tpsl.dart';
import '../domain/position_trigger_calculation.dart';
import '../domain/percent_share.dart';
import '../domain/position_valuation.dart';
import 'aster_open_order_card.dart';
import 'open_order_cancel_prompts.dart';
import 'open_order_labels.dart';
import 'order_cancellation_controls.dart';
import 'portfolio_components.dart';
import 'position_order_inputs.dart';
import 'position_tpsl_fields.dart';
import 'position_tpsl_summary.dart';
import 'position_valuation_rows.dart';
import 'trade_check_option.dart';

part 'position_tpsl_chrome.dart';
part 'position_tpsl_leg.dart';
part 'position_tpsl_list.dart';

/// Set TP/SL for one position: a take-profit and/or stop-loss conditional
/// order closing part of it (reduce quantity) or all of it (closePosition).
class PositionTpSlScreen extends ConsumerStatefulWidget {
  const PositionTpSlScreen({super.key, required this.position});
  final PositionRisk position;
  @override
  ConsumerState<PositionTpSlScreen> createState() => _PositionTpSlScreenState();
}

class _PositionTpSlScreenState extends ConsumerState<PositionTpSlScreen> {
  PositionTpSlScope scope = PositionTpSlScope.partial;
  PositionTriggerInput input = PositionTriggerInput.pnl;
  final takeProfit = _LegInput(LiveOrderTriggerKind.takeProfit, LiveOrderTriggerBasis.last);
  final stopLoss = _LegInput(LiveOrderTriggerKind.stop, LiveOrderTriggerBasis.last);
  final amount = TextEditingController();

  /// Slider stop of the partial amount; null once the amount is typed.
  int? percent;
  String? issue;

  /// Position, mark and context of the latest build, for input callbacks.
  ({PositionRisk position, Decimal? mark, LiveOrderContext? data})? _view;

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
    takeProfit.dispose();
    stopLoss.dispose();
    amount.dispose();
    super.dispose();
  }

  /// Display quantity: the slider share of the position or the typed amount at
  /// the current mark. Submission recomputes it on the exchange step.
  Decimal? _quantity(PositionRisk p, Decimal? mark, LiveOrderContext? data) {
    if (scope == PositionTpSlScope.entire) return p.quantity.abs();
    if (percent case final share?) {
      if (data != null) {
        final value = data.closeFraction(p.side, share, market: false, conditional: true);
        return value > Decimal.zero ? value : null;
      }
      return share == 0 ? null : p.quantity.abs() * Decimal.fromInt(share) * Decimal.parse('0.01');
    }
    final typed = Decimal.tryParse(amount.text.trim());
    if (data != null) return closeQuantityForQuote(data, typed, mark);
    if (typed == null || mark == null || mark <= Decimal.zero || typed <= Decimal.zero) return null;
    return (typed / mark).toDecimal(scaleOnInfinitePrecision: 24);
  }

  void _render([VoidCallback? change]) => setState(() {
    change?.call();
    issue = null;
  });

  _LegEstimate _estimate(PositionRisk p, Decimal? mark, LiveOrderContext? data) => _LegEstimate(
    position: p,
    quantity: _quantity(p, mark, data),
    leverage: p.leverage ?? data?.leverage ?? 0,
    mode: input,
  );

  /// Re-derives both estimate boxes after the quantity or input mode changed.
  void _resync() {
    final view = _view;
    if (view == null) return;
    final estimate = _estimate(view.position, view.mark, view.data);
    takeProfit.syncEstimate(estimate);
    stopLoss.syncEstimate(estimate);
  }

  /// Position value at the current mark: the slider's range.
  Decimal? _positionValue(PositionRisk p, Decimal? mark) {
    if (mark == null) return null;
    final value = (p.quantity * mark).abs();
    return value > Decimal.zero ? value : null;
  }

  /// A slider stop fills the amount with that share of the position value.
  void _selectPercent(int value, PositionRisk p, Decimal? mark) => _render(() {
    percent = value;
    final total = _positionValue(p, mark);
    amount.text = total == null ? '' : marketInput(percentShare(total, value).round(scale: 2));
    _resync();
  });

  /// Trade-workspace slider rules over the position value ([sliderChoice]).
  void _selectPosition(double position, PositionRisk p, Decimal? mark) {
    final choice = sliderChoice(
      position,
      maximum: _positionValue(p, mark),
      fine: Decimal.parse('0.01'),
    );
    if (choice.percent case final share?) return _selectPercent(share, p, mark);
    _render(() {
      percent = null;
      amount.text = marketInput(choice.amount!);
      _resync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = _latestPosition(ref, widget.position);
    final (quote, _) = watchPositionMark(ref, p);
    final mark = PositionValuation(position: p, quote: quote).mark;
    final live = ref.watch(liveOrderProvider);
    final data = live.context?.symbol == symbol ? live.context : null;
    final submitting = ref.watch(positionTpSlProvider.select((s) => s.busy));
    _view = (position: p, mark: mark, data: data);
    final estimate = _estimate(p, mark, data);
    final enabled = !submitting;
    final quoteAsset = p.units?.quote ?? data?.rules.quoteAsset ?? '';
    final loadFailure = live.intent == null && data == null ? live.failure : null;
    return Scaffold(
      backgroundColor: TradeColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Header(title: l10n.positionTpslTitle),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('position-tpsl-page'),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PositionTabs<PositionTpSlScope>(
                      tabs: [
                        (PositionTpSlScope.partial, l10n.positionTpslPartial),
                        (PositionTpSlScope.entire, l10n.positionTpslEntire),
                      ],
                      selected: scope,
                      onSelect: enabled
                          ? (value) => _render(() {
                              scope = value;
                              _resync();
                            })
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _LegSection(
                      leg: takeProfit,
                      title: l10n.positionTpslTakeProfit,
                      scope: scope,
                      data: data,
                      estimate: estimate,
                      quoteAsset: quoteAsset,
                      enabled: enabled,
                      onChanged: _render,
                      onMode: _chooseMode,
                    ),
                    const SizedBox(height: 16),
                    _LegSection(
                      leg: stopLoss,
                      title: l10n.positionTpslStopLoss,
                      scope: scope,
                      data: data,
                      estimate: estimate,
                      quoteAsset: quoteAsset,
                      enabled: enabled,
                      onChanged: _render,
                      onMode: _chooseMode,
                    ),
                    if (scope == PositionTpSlScope.partial) ...[
                      const SizedBox(height: 16),
                      _AmountSection(
                        controller: amount,
                        unit: quoteAsset,
                        position: sliderPosition(
                          percent: percent,
                          amount: Decimal.tryParse(amount.text.trim()),
                          maximum: _positionValue(p, mark),
                        ),
                        positionValue: _positionValue(p, mark),
                        enabled: enabled,
                        onTyped: () => _render(() {
                          percent = null;
                          _resync();
                        }),
                        onPosition: (value) => _selectPosition(value, p, mark),
                      ),
                    ],
                    const SizedBox(height: 16),
                    PositionOrderSummary(
                      position: p,
                      limit:
                          scope == PositionTpSlScope.partial &&
                          (takeProfit.active && takeProfit.limit ||
                              stopLoss.active && stopLoss.limit),
                      rows: [
                        (l10n.positionTpslEntryPrice, Text(summaryPrice(context, p, p.entryPrice))),
                        (l10n.positionTpslMarkPrice, Text(summaryPrice(context, p, mark))),
                        (
                          l10n.positionTpslLiqPrice,
                          Text(summaryPrice(context, p, p.liquidationPrice)),
                        ),
                        (
                          l10n.positionTpslEstimatedPnl,
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: summaryPnl(
                                    context,
                                    p,
                                    estimate.pnl(takeProfit.triggerPrice),
                                  ),
                                  style: summaryEstimateStyle.copyWith(color: TradeColors.positive),
                                ),
                                const TextSpan(text: ' / ', style: summaryEstimateStyle),
                                TextSpan(
                                  text: summaryPnl(context, p, estimate.pnl(stopLoss.triggerPrice)),
                                  style: summaryEstimateStyle.copyWith(color: TradeColors.negative),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (issue ??
                            (loadFailure == null ? null : accountErrorText(context, loadFailure))
                        case final text?)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          text,
                          key: const Key('position-tpsl-issue'),
                          style: TradeTypography.body.copyWith(color: TradeColors.negative),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: PositionActionButton(
                key: const Key('position-tpsl-confirm'),
                label: l10n.positionTpslConfirm,
                pending: submitting,
                onPressed: enabled ? () => _confirm(p) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseMode() async {
    final asset =
        widget.position.units?.margin ?? AppLocalizations.of(context).accountUnitUnavailable;
    final value = await showPositionTpSlSettingsSheet(context, input, asset);
    if (value == null || value == input || !mounted) return;
    _render(() {
      input = value;
      _resync();
    });
  }

  Future<void> _confirm(PositionRisk p) async {
    final l10n = AppLocalizations.of(context);
    final legs = [takeProfit, stopLoss].where((leg) => leg.active).toList();
    final partial = scope == PositionTpSlScope.partial;
    String? problem;
    if (legs.isEmpty || legs.any((leg) => parseOrderDecimal(leg.trigger.text.trim()) == null)) {
      problem = l10n.positionTpslMissingTrigger;
    } else if (partial &&
        legs.any((leg) => leg.limit && leg.limitPrice == null && leg.peg == null)) {
      problem = l10n.positionTpslMissingLimit;
    } else if (partial && (percent ?? 1) == 0 ||
        partial &&
            percent == null &&
            (Decimal.tryParse(amount.text.trim()) ?? Decimal.zero) <= Decimal.zero) {
      problem = l10n.positionTpslMissingAmount;
    }
    if (problem != null) {
      setState(() => issue = problem);
      return;
    }
    FocusScope.of(context).unfocus();
    final share = percent, typed = Decimal.tryParse(amount.text.trim()), currentScope = scope;
    String quantity(LiveOrderContext data) {
      if (currentScope == PositionTpSlScope.entire) return '';
      final value = share != null
          ? data.closeFraction(p.side, share, market: false, conditional: true)
          : closeQuantityForQuote(data, typed, data.markPrice);
      return value == null || value <= Decimal.zero ? '' : value.toString();
    }

    final builders = [
      for (final leg in legs)
        (
          kind: leg.kind,
          draft: (LiveOrderContext data) => leg
              .snapshot(partial: partial)
              .draft(side: p.side, long: p.long, scope: currentScope, quantity: quantity(data)),
        ),
    ];
    await ref.read(positionTpSlProvider.notifier).submit(symbol, builders);
    if (!mounted) return;
    _report(ref.read(positionTpSlProvider).results, legs);
  }

  void _report(List<PositionTpSlLegResult> results, List<_LegInput> legs) {
    final l10n = AppLocalizations.of(context);
    String name(LiveOrderTriggerKind kind) =>
        kind == LiveOrderTriggerKind.takeProfit ? l10n.tradeTakeProfit : l10n.tradeStopLoss;
    if (results.length == legs.length &&
        results.every((r) => r.outcome == PositionOrderOutcome.placed)) {
      AppToast.showSuccess(context, l10n.positionTpslPlaced);
      Navigator.of(context).maybePop();
      return;
    }
    final lines = <String>[];
    for (final leg in legs) {
      final result = results.where((r) => r.kind == leg.kind).firstOrNull;
      lines.add(switch (result?.outcome) {
        PositionOrderOutcome.placed => l10n.positionTpslLegPlaced(name(leg.kind)),
        PositionOrderOutcome.unknown => l10n.positionTpslLegUnknown(name(leg.kind)),
        PositionOrderOutcome.failed => l10n.positionTpslLegFailed(
          name(leg.kind),
          result!.failure == null ? '' : accountErrorText(context, result.failure!),
        ),
        null => l10n.positionTpslNotSubmitted(name(leg.kind)),
      });
      // A placed or unconfirmed order must not be sent again by another tap;
      // failed and unsent legs keep their input for correction.
      if (result != null && result.outcome != PositionOrderOutcome.failed) {
        setState(leg.clear);
      }
    }
    AppToast.showFailure(context, lines.join('\n'));
  }
}
