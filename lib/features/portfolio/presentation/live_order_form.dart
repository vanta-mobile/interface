import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/live_order_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/live_order.dart';
import '../domain/futures_position_mode.dart';
import '../domain/live_order_time_in_force.dart';
import 'live_order_review.dart';
import 'order_confirmation_control.dart';
import 'live_order_reduction_controls.dart';
import 'live_order_funds_panel.dart';
import '../domain/live_order_trigger.dart';
import 'live_order_trigger_controls.dart';
import 'live_order_entire_controls.dart';
import '../domain/live_order_trailing.dart';
import 'live_order_trailing_controls.dart';
import '../domain/live_order_attachment.dart';
import '../domain/attached_exit_input.dart';
import 'live_order_attachment_controls.dart';
import '../domain/attached_entry_peg.dart';
import '../domain/live_order_peg.dart';
import 'live_order_price_inputs.dart';
import '../domain/live_order_size.dart';
import '../domain/live_order_entry_mode.dart';
import 'live_order_size_field.dart';

class LiveOrderForm extends ConsumerStatefulWidget {
  const LiveOrderForm({
    super.key,
    required this.data,
    this.closingSide,
    this.initialConditional = false,
    this.mode,
    this.onModeChanged,
  });
  final LiveOrderContext data;
  final String? closingSide;
  final bool initialConditional;
  final LiveOrderEntryMode? mode;
  final ValueChanged<LiveOrderEntryMode>? onModeChanged;
  @override
  ConsumerState<LiveOrderForm> createState() => _LiveOrderFormState();
}

class _LiveOrderFormState extends ConsumerState<LiveOrderForm> with AutomaticKeepAliveClientMixin {
  final quantity = TextEditingController(), price = TextEditingController();
  final quoteAmount = TextEditingController();
  OrderSizeUnit sizeUnit = OrderSizeUnit.quote;
  bool _limitSeeded = false, _limitEdited = false;
  LiveOrderSize get sizeInput => LiveOrderSize(
    unit: sizeUnit,
    text: sizeUnit == OrderSizeUnit.base ? quantity.text : quoteAmount.text,
  );
  OrderSizeResolution get sizing => sizeInput.resolve(
    widget.data,
    rawDraft(attaching ? LiveOrderAttachment(entryPeg: market ? null : entryPeg) : null),
  );
  final triggerPrice = TextEditingController();
  bool buy = true, market = false, reduceOnly = false;
  bool conditional = false, protect = false;
  bool entireClose = false, trailing = false;
  final trailingRate = TextEditingController(), trailingActivation = TextEditingController();
  LiveOrderTriggerBasis trailingBasis = LiveOrderTriggerBasis.mark;
  LiveOrderTriggerKind triggerKind = LiveOrderTriggerKind.stop;
  LiveOrderTriggerBasis triggerBasis = LiveOrderTriggerBasis.mark;
  LiveOrderTimeInForce timeInForce = LiveOrderTimeInForce.gtc;
  AttachedOrderInput? attachment;
  AttachedEntryPeg? entryPeg;
  LiveOrderPeg? peg;
  bool get attaching => attachment != null && !trailing && !reducing;
  LiveOrderPeg? get effectivePeg => !market && !trailing && !attaching ? peg : null;
  LiveOrderDraft get attachmentEntry =>
      buildDraft(attaching ? LiveOrderAttachment(entryPeg: market ? null : entryPeg) : null);
  LiveOrderAttachment? get effectiveAttachment => !attaching
      ? null
      : LiveOrderAttachment(
          takeProfit: attachment!.takeProfit?.resolve(widget.data, attachmentEntry).exit,
          stopLoss: attachment!.stopLoss?.resolve(widget.data, attachmentEntry).exit,
          entryPeg: market ? null : entryPeg,
        );
  String? get attachmentFailure {
    if (!attaching) return null;
    for (final input in [?attachment!.takeProfit, ?attachment!.stopLoss]) {
      if (input.resolve(widget.data, attachmentEntry).failure != null) {
        return 'attachedOrderCheckExits';
      }
    }
    return null;
  }

  int attachmentGeneration = 0;
  // Scrolling the rule/funds section into view must not reset an order intent.
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    market = widget.closingSide != null;
    conditional = widget.initialConditional;
    sizeUnit = widget.closingSide == null ? OrderSizeUnit.quote : OrderSizeUnit.base;
    if (widget.mode case final mode?) _applyMode(mode);
    _seedLimit();
  }

  void _seedLimit() {
    if (_limitSeeded || _limitEdited) return;
    final value = initialLiveLimitPrice(widget.data);
    if (value != null) {
      price.text = value;
      _limitSeeded = true;
    }
  }

  @override
  void didUpdateWidget(covariant LiveOrderForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode case final mode? when mode != liveOrderEntryMode(draft)) _applyMode(mode);
    _seedLimit();
  }

  void _applyMode(LiveOrderEntryMode mode) {
    if (!mode.inline) return;
    final previous = liveOrderEntryMode(draft);
    market = mode.marketExecution;
    conditional = mode.conditional;
    trailing = mode == LiveOrderEntryMode.trailing;
    if (mode == LiveOrderEntryMode.postOnly || previous == LiveOrderEntryMode.postOnly) {
      timeInForce = mode.defaultPolicy;
    }
    entireClose = false;
  }

  @override
  void dispose() {
    quantity.dispose();
    quoteAmount.dispose();
    price.dispose();
    triggerPrice.dispose();
    trailingRate.dispose();
    trailingActivation.dispose();
    super.dispose();
  }

  bool get reducing =>
      widget.closingSide != null || reduceOnly && widget.data.mode == FuturesPositionMode.oneWay;

  LiveOrderDraft get draft => buildDraft(effectiveAttachment);
  LiveOrderDraft buildDraft(LiveOrderAttachment? protection) {
    final entry = rawDraft(protection);
    return entry.withQuantity(sizeInput.resolve(widget.data, entry).quantity);
  }

  LiveOrderDraft rawDraft(LiveOrderAttachment? protection) => LiveOrderDraft(
    buy: widget.closingSide == null
        ? buy
        : !(widget.data.positions[widget.closingSide]?.long ?? true),
    market: market,
    quantity: entireClose ? '' : quantity.text.trim(),
    price: market || entireClose || trailing || effectivePeg != null || protection?.entryPeg != null
        ? ''
        : price.text.trim(),
    entireClose: entireClose,
    reduceOnly: reduceOnly && widget.data.mode == FuturesPositionMode.oneWay,
    closingSide: widget.closingSide,
    timeInForce: timeInForce,
    attachment: protection,
    peg: effectivePeg,
    trailing: trailing
        ? LiveOrderTrailing(
            callbackRate: trailingRate.text.trim(),
            activationPrice: trailingActivation.text.trim().isEmpty
                ? null
                : trailingActivation.text.trim(),
            basis: trailingBasis,
          )
        : null,
    trigger: conditional
        ? LiveOrderTrigger(
            kind: triggerKind,
            price: triggerPrice.text.trim(),
            basis: triggerBasis,
            protect: protect,
          )
        : null,
  );
  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (previous, next) {
        if (previous != next) {
          quantity.clear();
          quoteAmount.clear();
          sizeUnit = widget.closingSide == null ? OrderSizeUnit.quote : OrderSizeUnit.base;
          price.clear();
          _limitSeeded = _limitEdited = false;
          triggerPrice.clear();
          entireClose = false;
          trailing = false;
          trailingRate.clear();
          trailingActivation.clear();
          trailingBasis = LiveOrderTriggerBasis.mark;
          triggerBasis = LiveOrderTriggerBasis.mark;
          attachment = null;
          entryPeg = null;
          peg = null;
          attachmentGeneration++;
          timeInForce = LiveOrderTimeInForce.gtc;
        }
      },
    );
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(liveOrderProvider);
    ref.watch(symbolSettingsActivityProvider);
    final controller = ref.read(liveOrderProvider.notifier);
    final contextData = widget.data;
    final size = sizing;
    final invalid = size.failure ?? attachmentFailure ?? contextData.validate(draft);
    final intent = invalid == null ? controller.prepare(contextData.symbol, draft) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        if (widget.closingSide == null)
          LiveOrderFundsPanel(data: contextData, historical: state.stale),
        if (widget.closingSide == null)
          SegmentedButton<bool>(
            key: const Key('live-order-direction'),
            segments: [
              ButtonSegment(value: true, label: Text(l10n.long)),
              ButtonSegment(value: false, label: Text(l10n.short)),
            ],
            selected: {buy},
            onSelectionChanged: state.busy || state.needsRecheck
                ? null
                : (value) => setState(() => buy = value.first),
          ),
        LiveOrderReductionControls(
          data: contextData,
          draft: draft,
          enabled: !state.busy && !state.needsRecheck,
          onReduce: (value) => setState(() => reduceOnly = value),
          onFraction: (percent) => setState(() {
            sizeUnit = OrderSizeUnit.base;
            quantity.text = contextData
                .closeFraction(
                  widget.closingSide!,
                  percent,
                  market: market,
                  conditional: conditional || trailing,
                )
                .toString();
          }),
        ),
        if (!widget.initialConditional && (widget.mode == null || trailing))
          LiveOrderTrailingControls(
            showToggle: widget.mode == null,
            data: contextData,
            selected: trailing,
            enabled: !state.busy && !state.needsRecheck,
            rate: trailingRate,
            activation: trailingActivation,
            basis: trailingBasis,
            onEnabled: (value) => setState(() {
              trailing = value;
              if (value) {
                market = true;
                conditional = false;
                entireClose = false;
              }
            }),
            onBasis: (value) => setState(() => trailingBasis = value),
            onInput: () => setState(() {}),
          ),
        if (!trailing && (widget.mode == null || conditional))
          LiveOrderTriggerControls(
            showToggle: widget.mode == null,
            fixedConditional: widget.initialConditional,
            data: contextData,
            draft: draft,
            price: triggerPrice,
            enabled: !state.busy && !state.needsRecheck,
            onEnabled: (value) => setState(() => conditional = value),
            onKind: (value) => setState(() => triggerKind = value),
            onBasis: (value) => setState(() => triggerBasis = value),
            onProtect: (value) => setState(() => protect = value),
            onPrice: () => setState(() {}),
          ),
        const SizedBox(height: 12),
        if (widget.mode == null)
          SegmentedButton<bool>(
            key: const Key('live-order-type'),
            segments: [
              ButtonSegment(value: false, label: Text(l10n.limit)),
              ButtonSegment(value: true, label: Text(l10n.market)),
            ],
            selected: {market},
            onSelectionChanged: state.busy || state.needsRecheck || entireClose || trailing
                ? null
                : (value) => setState(() => market = value.first),
          ),
        if (widget.initialConditional && widget.closingSide != null)
          LiveOrderEntireControls(
            selected: entireClose,
            market: market,
            enabled: !state.busy && !state.needsRecheck,
            onChanged: (value) => setState(() => entireClose = value),
          ),
        const SizedBox(height: 12),
        if (!entireClose)
          LiveOrderSizeField(
            data: contextData,
            draft: draft,
            unit: sizeUnit,
            controller: sizeUnit == OrderSizeUnit.base ? quantity : quoteAmount,
            enabled: !state.busy && !state.needsRecheck,
            onUnit: (value) => setState(() => sizeUnit = value),
            onInput: () => setState(() {}),
          ),
        LiveOrderPriceInputs(
          data: contextData,
          draft: draft,
          price: price,
          policy: timeInForce,
          fixedPolicy: widget.mode == LiveOrderEntryMode.postOnly,
          peg: peg,
          entryPeg: entryPeg,
          enabled: !state.busy && !state.needsRecheck,
          onPolicy: (value) {
            setState(() => timeInForce = value);
            widget.onModeChanged?.call(liveOrderEntryMode(draft));
          },
          onPeg: (value) => setState(() => peg = value),
          onEntryPeg: (value) => setState(() => entryPeg = value),
          onPrice: () => setState(() => _limitEdited = true),
        ),
        LiveOrderAttachmentControls(
          key: ValueKey((contextData.address, attachmentGeneration, 'attachment')),
          allowed: !reducing && !trailing,
          enabled: !state.busy && !state.needsRecheck,
          data: contextData,
          entry: attachmentEntry,
          onChanged: (value) => setState(() => attachment = value),
        ),
        const SizedBox(height: 8),
        if (invalid != null &&
            (sizeInput.text.isNotEmpty ||
                triggerPrice.text.isNotEmpty ||
                trailingRate.text.isNotEmpty ||
                trailingActivation.text.isNotEmpty))
          Text(tr(context, invalid), style: const TextStyle(color: AppColors.negative)),
        if (widget.closingSide != null && contextData.reductionPosition(draft)?.quantity == null)
          Text(l10n.liveClosePositionChanged, style: const TextStyle(color: AppColors.warning)),
        LiveOrderSizePreview(value: size, data: contextData),
        if (!size.converted)
          if (parseOrderDecimal(draft.quantity) case final amount?)
            if (contextData.referenceExecutionPrice(draft) case final executionPrice?)
              ValueRow(
                l10n.liveOrderEstimatedNotional,
                '${amount * executionPrice} ${contextData.rules.quoteAsset}',
              ),
        const SizedBox(height: 12),
        if (widget.closingSide == null) LiveOrderCostPreview(data: contextData, draft: draft),
        LiveOrderSubmitControls(
          draft: draft,
          enabled: !state.busy && !state.needsRecheck,
          onSubmit: intent == null
              ? null
              : () => reviewLiveOrder(context, ref, intent, sizing: size),
        ),
      ],
    );
  }
}
