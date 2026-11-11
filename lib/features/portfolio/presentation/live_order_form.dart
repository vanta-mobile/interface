import 'minimum_order_size_hint.dart';
import 'embedded_time_in_force_selector.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../../trade/application/providers.dart' show orderPriceProvider, symbolProvider;
import '../application/live_order_provider.dart';
import '../application/main_order_allocation_provider.dart';
import '../application/main_order_capacity_provider.dart';
import '../application/main_order_refresh_provider.dart';
import '../application/main_order_capacity_preview_provider.dart';
import '../application/main_order_pricing_provider.dart';
import '../domain/account_snapshot.dart';
import '../domain/main_order_pricing.dart';
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
import '../domain/main_order_review_input.dart';
import '../../../core/domain/decimal_value.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../funding/domain/funding_catalog.dart';
import '../../funding/presentation/funding_screen.dart';
import '../../trade/presentation/trade_theme.dart';
import 'live_order_embedded_controls.dart';
import 'live_order_embedded_inputs.dart';
import 'live_order_embedded_triggers.dart';
import '../../trade/presentation/widgets/trade_option_sheet.dart';

part 'live_order_allocation_binding.dart';
part 'live_order_form_embedded.dart';
part 'live_order_form_full.dart';

class LiveOrderForm extends ConsumerStatefulWidget {
  const LiveOrderForm({
    super.key,
    required this.data,
    this.closingSide,
    this.initialConditional = false,
    this.initialCloseMarket = true,
    this.mode,
    this.onModeChanged,
    this.bookPricing = false,
    this.embedded = false,
  });
  final LiveOrderContext data;
  final String? closingSide;
  final bool initialConditional;
  final bool initialCloseMarket;
  final LiveOrderEntryMode? mode;
  final ValueChanged<LiveOrderEntryMode>? onModeChanged;
  final bool bookPricing;

  /// Trade-workspace layout; closing and position-trigger forms keep theirs.
  final bool embedded;
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
  bool? _refreshingReviewDirection;
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
      if (mode == LiveOrderEntryMode.postOnly) _constrainPostOnly();
    }
    entireClose = false;
  }

  void _constrainPostOnly() {
    if (peg != null) peg = LiveOrderPeg.queue;
    if (entryPeg != null) entryPeg = AttachedEntryPeg.queue1;
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
        if (previous != next) _resetForIdentity();
      },
    );
    final state = ref.watch(liveOrderProvider);
    final allocation = ref.watch(mainOrderAllocationProvider);
    ref.watch(mainOrderCapacityProvider);
    if (!reducing) ref.watch(mainOrderPricingProvider);
    ref.watch(symbolSettingsActivityProvider);
    final controller = ref.read(liveOrderProvider.notifier);
    final refresh = ref.watch(mainOrderRefreshProvider);
    final enabled =
        (!refresh.loading || refresh.background) &&
        (!state.busy || refresh.background && state.intent == null) &&
        !allocation.preparing;
    if (widget.bookPricing) {
      ref.listen<String>(orderPriceProvider, (_, value) {
        if (!mounted ||
            value.isEmpty ||
            !enabled ||
            ref.read(symbolProvider) != widget.data.symbol) {
          return;
        }
        setState(() {
          _applyMode(LiveOrderEntryMode.limit);
          price.text = value;
          _limitEdited = true;
          peg = null;
          entryPeg = null;
        });
        widget.onModeChanged?.call(LiveOrderEntryMode.limit);
      });
    }
    final contextData = _pricingContext ?? widget.data;
    _syncRatioInput();
    final size = sizing;
    final invalid =
        size.failure ??
        (!reducing && _pricingContext == null ? _pricing.failure?.key : null) ??
        attachmentFailure ??
        contextData.validate(draft);
    final intent = invalid == null
        ? controller.prepare(contextData.symbol, draft, pricingContext: _pricingContext)
        : null;
    if (widget.embedded && widget.closingSide == null && !widget.initialConditional) {
      return _embeddedLayout(contextData: contextData, invalid: invalid, enabled: enabled);
    }
    return _fullLayout(
      contextData: contextData,
      invalid: invalid,
      intent: intent,
      size: size,
      enabled: enabled,
      stale: state.stale,
      pending: allocation.preparing || state.busy && state.intent != null,
    );
  }

  Widget _trailingControls(LiveOrderContext data, bool enabled, {required bool showToggle}) =>
      LiveOrderTrailingControls(
        showToggle: showToggle,
        data: data,
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
      );

  /// A different wallet or signer never inherits the previous order intent.
  void _resetForIdentity() {
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

  void _render(VoidCallback change) => setState(change);
}
