import 'minimum_order_size_hint.dart';
import 'embedded_time_in_force_selector.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/application/providers.dart' show orderPriceProvider, symbolProvider;
import '../application/live_order_provider.dart';
import '../application/main_order_allocation_provider.dart';
import '../application/main_order_capacity_provider.dart';
import '../application/main_order_refresh_provider.dart';
import '../application/main_order_capacity_preview_provider.dart';
import '../application/main_order_pricing_provider.dart';
import '../application/order_form_prefill_provider.dart';
import '../domain/order_form_prefill.dart';
import '../domain/account_snapshot.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/live_order.dart';
import '../domain/futures_position_mode.dart';
import '../domain/live_order_time_in_force.dart';
import 'live_order_review.dart';
import '../domain/live_order_trigger.dart';
import '../domain/live_order_trailing.dart';
import 'live_order_trailing_controls.dart';
import '../domain/live_order_attachment.dart';
import '../domain/attached_exit_input.dart';
import 'live_order_attachment_controls.dart';
import '../domain/attached_entry_peg.dart';
import '../domain/live_order_peg.dart';
import '../domain/live_order_size.dart';
import '../domain/live_order_entry_mode.dart';
import 'main_order_amount_slider.dart';
import 'main_order_capacity_panel.dart';
import 'main_order_percentage_control.dart';
import '../domain/live_order_capacity.dart';
import '../domain/main_order_capacity_preview.dart';
import '../domain/main_order_allocation.dart';
import '../domain/main_order_review_input.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/presentation/app_toast.dart';
import '../../trade/presentation/trade_theme.dart';
import 'live_order_embedded_controls.dart';
import 'live_order_embedded_inputs.dart';
import 'live_order_embedded_triggers.dart';
import '../../trade/presentation/widgets/trade_option_sheet.dart';

part 'live_order_allocation_binding.dart';
part 'live_order_form_embedded.dart';
part 'live_order_prefill_binding.dart';

class LiveOrderForm extends ConsumerStatefulWidget {
  const LiveOrderForm({
    super.key,
    required this.data,
    this.mode,
    this.onModeChanged,
    this.closing = false,
  });
  final LiveOrderContext data;
  final LiveOrderEntryMode? mode;

  /// Hedge Close segment: orders reduce the position the direction closes.
  final bool closing;
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

  /// Set once deep-link inputs were applied; this form then always confirms.
  bool _prefilled = false, _prefillScheduled = false;
  LiveOrderSize get sizeInput => LiveOrderSize(
    unit: sizeUnit,
    text: _allocationPercent == null ? _manualSizeInput.text : _ratioInput.text,
  );
  OrderSizeResolution get sizing => _resolveSize(rawDraft(_entryAttachment));
  final triggerPrice = TextEditingController();
  bool buy = true, market = false, reduceOnly = false;
  bool? _refreshingReviewDirection;

  /// The direction whose click (read, review and any direct submission) is
  /// still running; both direction buttons wait for it.
  bool? _reviewingDirection;

  /// Embedded layout: a failure from the last direction click, shown only
  /// while the form terms it was found for are unchanged.
  ({AccountReadFailure failure, Object terms})? _reviewFailure;

  /// A trigger price found already reached by the last direction click, shown
  /// under the trigger field until any form term changes.
  Object? _triggerReachedTerms;
  bool conditional = false, protect = false;
  bool trailing = false;
  final trailingRate = TextEditingController(), trailingActivation = TextEditingController();
  LiveOrderTriggerBasis trailingBasis = LiveOrderTriggerBasis.mark;
  LiveOrderTriggerBasis triggerBasis = LiveOrderTriggerBasis.mark;
  LiveOrderTimeInForce timeInForce = LiveOrderTimeInForce.gtc;

  /// The GTC/IOC choice restored when Hidden Order is cleared.
  LiveOrderTimeInForce _policy = LiveOrderTimeInForce.gtc;
  AttachedOrderInput? attachment;
  LiveOrderPeg? peg;

  /// TP/SL is checked. As on Aster's site it excludes BBO, Hidden Order and
  /// Reduce only. Exits left empty are ignored, so a checked but unfilled
  /// TP/SL places the order without TP/SL.
  bool get attaching => attachment != null && !trailing && !reducing;
  AttachedOrderInput? get _filledAttachment {
    bool filled(AttachedExitInput? exit) => exit != null && exit.value.trim().isNotEmpty;
    final input = attachment;
    if (input == null || !filled(input.takeProfit) && !filled(input.stopLoss)) return null;
    return AttachedOrderInput(
      takeProfit: filled(input.takeProfit) ? input.takeProfit : null,
      stopLoss: filled(input.stopLoss) ? input.stopLoss : null,
    );
  }

  /// The order carries filled TP/SL exits.
  bool get _compound => attaching && _filledAttachment != null;
  LiveOrderAttachment? get _entryAttachment => _compound ? const LiveOrderAttachment() : null;
  LiveOrderPeg? get effectivePeg => market || trailing || attaching ? null : peg;
  LiveOrderDraft get attachmentEntry => buildDraft(_entryAttachment);
  LiveOrderAttachment? get effectiveAttachment {
    if (!_compound) return null;
    final filled = _filledAttachment;
    return LiveOrderAttachment(
      takeProfit: filled?.takeProfit?.resolve(_pricingContext ?? widget.data, attachmentEntry).exit,
      stopLoss: filled?.stopLoss?.resolve(_pricingContext ?? widget.data, attachmentEntry).exit,
    );
  }

  String? get attachmentFailure {
    if (!_compound) return null;
    final filled = _filledAttachment;
    for (final input in [?filled?.takeProfit, ?filled?.stopLoss]) {
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
    if (mode == LiveOrderEntryMode.postOnly) {
      timeInForce = LiveOrderTimeInForce.postOnly;
      _constrainPostOnly();
    } else if (previous == LiveOrderEntryMode.postOnly ||
        // Conditional orders offer no Hidden Order.
        conditional && timeInForce == LiveOrderTimeInForce.hidden) {
      timeInForce = _policy;
    }
  }

  void _constrainPostOnly() {
    if (peg != null) peg = LiveOrderPeg.queue;
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
      reduceOnly && widget.data.mode == FuturesPositionMode.oneWay || _hedgeClosing;

  /// Close Long sells the LONG position; Close Short buys back the SHORT one.
  bool get _hedgeClosing => widget.closing && widget.data.mode == FuturesPositionMode.hedge;

  LiveOrderDraft get draft => buildDraft(effectiveAttachment);
  LiveOrderDraft buildDraft(LiveOrderAttachment? protection) {
    final entry = rawDraft(protection);
    return entry.withQuantity(_resolveSize(entry).quantity);
  }

  LiveOrderDraft rawDraft(LiveOrderAttachment? protection) => LiveOrderDraft(
    buy: buy,
    market: market,
    quantity: quantity.text.trim(),
    price: market || trailing || effectivePeg != null || protection?.entryPeg != null
        ? ''
        : price.text.trim(),
    reduceOnly: reduceOnly && widget.data.mode == FuturesPositionMode.oneWay,
    closingSide: _hedgeClosing ? (buy ? 'SHORT' : 'LONG') : null,
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
            kind: _triggerKind,
            price: triggerPrice.text.trim(),
            basis: triggerBasis,
            protect: protect,
          )
        : null,
  );

  /// As on Aster's site, the trigger direction follows the entered price: a
  /// buy above the reference (or a sell below it) is STOP, otherwise
  /// TAKE_PROFIT. Without a price or reference it stays STOP, and validation
  /// reports the missing reference.
  LiveOrderTriggerKind get _triggerKind {
    final stop = parseOrderDecimal(triggerPrice.text.trim());
    final data = _pricingContext ?? widget.data;
    final reference = triggerBasis == LiveOrderTriggerBasis.mark ? data.markPrice : data.lastPrice;
    if (stop == null || reference == null) return LiveOrderTriggerKind.stop;
    return (stop > reference) == buy ? LiveOrderTriggerKind.stop : LiveOrderTriggerKind.takeProfit;
  }

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
        if (previous != next) _resetForIdentity();
      },
    );
    _watchPrefill();
    final state = ref.watch(liveOrderProvider);
    final allocation = ref.watch(mainOrderAllocationProvider);
    ref.watch(mainOrderCapacityProvider);
    if (!reducing) ref.watch(mainOrderPricingProvider);
    ref.watch(symbolSettingsActivityProvider);
    final refresh = ref.watch(mainOrderRefreshProvider);
    final enabled =
        (!refresh.loading || refresh.background) &&
        (!state.busy || refresh.background && state.intent == null) &&
        !allocation.preparing;
    ref.listen<String>(orderPriceProvider, (_, value) {
      if (!mounted || value.isEmpty || !enabled || ref.read(symbolProvider) != widget.data.symbol) {
        return;
      }
      setState(() {
        _applyMode(LiveOrderEntryMode.limit);
        price.text = value;
        _limitEdited = true;
        peg = null;
      });
      widget.onModeChanged?.call(LiveOrderEntryMode.limit);
    });
    _syncRatioInput();
    return _embeddedLayout(contextData: _pricingContext ?? widget.data, enabled: enabled);
  }

  Widget _trailingControls(bool enabled) => LiveOrderTrailingControls(
    enabled: enabled,
    rate: trailingRate,
    activation: trailingActivation,
    basis: trailingBasis,
    onBasis: (value) => setState(() => trailingBasis = value),
    onInput: () => setState(() {}),
  );

  /// A different wallet or signer never inherits the previous order intent.
  void _resetForIdentity() {
    quantity.clear();
    quoteAmount.clear();
    _ratioInput.clear();
    sizeUnit = OrderSizeUnit.quote;
    price.clear();
    _limitSeeded = _limitEdited = false;
    triggerPrice.clear();
    trailing = false;
    trailingRate.clear();
    trailingActivation.clear();
    trailingBasis = LiveOrderTriggerBasis.mark;
    triggerBasis = LiveOrderTriggerBasis.mark;
    attachment = null;
    peg = null;
    attachmentGeneration++;
    timeInForce = _policy = LiveOrderTimeInForce.gtc;
    _prefilled = false;
  }

  void _render(VoidCallback change) => setState(change);
}
