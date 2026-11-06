import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/live_order_provider.dart';
import '../application/main_order_allocation_provider.dart';
import '../application/main_order_capacity_provider.dart';
import '../application/main_order_refresh_provider.dart';
import '../application/main_order_capacity_preview_provider.dart';
import '../application/main_order_pricing_provider.dart';
import '../domain/account_snapshot.dart';
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
import 'main_order_capacity_panel.dart';
import 'main_order_percentage_control.dart';
import '../domain/main_order_capacity_preview.dart';
import '../domain/main_order_allocation.dart';

part 'live_order_allocation_binding.dart';

class LiveOrderForm extends ConsumerStatefulWidget {
  const LiveOrderForm({
    super.key,
    required this.data,
    this.closingSide,
    this.initialConditional = false,
    this.initialCloseMarket = true,
    this.mode,
    this.onModeChanged,
  });
  final LiveOrderContext data;
  final String? closingSide;
  final bool initialConditional;
  final bool initialCloseMarket;
  final LiveOrderEntryMode? mode;
  final ValueChanged<LiveOrderEntryMode>? onModeChanged;
  @override
  ConsumerState<LiveOrderForm> createState() => _LiveOrderFormState();
}

class _LiveOrderFormState extends ConsumerState<LiveOrderForm> with AutomaticKeepAliveClientMixin {
  final quantity = TextEditingController(), price = TextEditingController();
  final quoteAmount = TextEditingController();
  final _ratioInput = TextEditingController();
  OrderSizeUnit sizeUnit = OrderSizeUnit.quote;
  bool _limitSeeded = false, _limitEdited = false;
  LiveOrderSize get sizeInput => LiveOrderSize(
    unit: sizeUnit,
    text: _allocationPercent == null ? _manualSizeInput.text : _ratioInput.text,
  );
  OrderSizeResolution get sizing => _resolveSize(
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
          takeProfit: attachment!.takeProfit
              ?.resolve(_pricingContext ?? widget.data, attachmentEntry)
              .exit,
          stopLoss: attachment!.stopLoss
              ?.resolve(_pricingContext ?? widget.data, attachmentEntry)
              .exit,
          entryPeg: market ? null : entryPeg,
        );
  String? get attachmentFailure {
    if (!attaching) return null;
    for (final input in [?attachment!.takeProfit, ?attachment!.stopLoss]) {
      if (input.resolve(_pricingContext ?? widget.data, attachmentEntry).failure != null) {
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
    market = widget.closingSide != null && widget.initialCloseMarket;
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
    _ratioInput.dispose();
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
    return entry.withQuantity(_resolveSize(entry).quantity);
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
          _ratioInput.clear();
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
    final allocation = ref.watch(mainOrderAllocationProvider);
    ref.watch(mainOrderCapacityProvider);
    if (!reducing) ref.watch(mainOrderPricingProvider);
    ref.watch(symbolSettingsActivityProvider);
    final controller = ref.read(liveOrderProvider.notifier);
    final enabled =
        !ref.watch(mainOrderRefreshProvider).loading &&
        !state.busy &&
        !state.needsRecheck &&
        !allocation.preparing;
    final contextData = _pricingContext ?? widget.data;
    _syncRatioInput();
    final size = sizing;
    final invalid =
        size.failure ??
        (!reducing && _pricingContext == null ? 'liveCapacityPriceUnavailable' : null) ??
        attachmentFailure ??
        contextData.validate(draft);
    final intent = invalid == null
        ? controller.prepare(contextData.symbol, draft, pricingContext: _pricingContext)
        : null;
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
            onSelectionChanged: !enabled ? null : (value) => setState(() => buy = value.first),
          ),
        LiveOrderReductionControls(
          data: contextData,
          draft: draft,
          enabled: enabled,
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
            enabled: enabled,
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
            enabled: enabled,
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
            onSelectionChanged: !enabled || entireClose || trailing
                ? null
                : (value) => setState(() => market = value.first),
          ),
        if (widget.initialConditional && widget.closingSide != null)
          LiveOrderEntireControls(
            selected: entireClose,
            market: market,
            enabled: enabled,
            onChanged: (value) => setState(() => entireClose = value),
          ),
        const SizedBox(height: 12),
        if (!reducing)
          MainOrderPercentageControl(
            unit: sizeUnit,
            manualCheck: draft.attachment?.entryPeg == null,
          ),
        if (!entireClose)
          LiveOrderSizeField(
            data: contextData,
            draft: draft,
            unit: sizeUnit,
            controller: _allocationPercent != null
                ? _ratioInput
                : sizeUnit == OrderSizeUnit.base
                ? quantity
                : quoteAmount,
            enabled: enabled,
            onUnit: _onSizeUnit,
            onInput: _onSizeInput,
          ),
        LiveOrderPriceInputs(
          data: contextData,
          draft: draft,
          price: price,
          policy: timeInForce,
          fixedPolicy: widget.mode == LiveOrderEntryMode.postOnly,
          peg: peg,
          entryPeg: entryPeg,
          enabled: enabled,
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
          enabled: enabled,
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
        if (!reducing)
          MainOrderCapacityPanel(
            data: widget.data,
            draft: draft,
            unit: sizeUnit,
            input: sizeInput.text,
            percent: _allocationPercent,
            showReview: true,
            onReview: enabled && (_allocationPercent == null || _allocationPercent! > 0)
                ? (direction) => _reviewAllocated(direction: direction)
                : null,
          ),
        LiveOrderSubmitControls(
          draft: draft,
          enabled: enabled,
          pending: allocation.preparing || state.busy,
          onSubmit: intent == null
              ? null
              : !reducing && draft.attachment?.entryPeg == null
              ? _reviewAllocated
              : () => reviewLiveOrder(context, ref, intent, sizing: size),
        ),
      ],
    );
  }

  void _render(VoidCallback change) => setState(change);
}
