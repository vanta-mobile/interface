import '../../../core/errors/error_text.dart';
import '../../../core/presentation/drag_throttle.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/live_order_provider.dart';
import '../application/main_order_allocation_provider.dart';
import '../application/main_order_capacity_provider.dart';
import '../application/main_order_refresh_provider.dart';
import '../application/main_order_pricing_provider.dart';
import '../domain/account_snapshot.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/main_order_allocation.dart';
import '../domain/live_order_size.dart';
import '../domain/percent_share.dart';
import 'main_order_amount_slider.dart';

class MainOrderPercentageControl extends ConsumerStatefulWidget {
  const MainOrderPercentageControl({
    super.key,
    this.unit = OrderSizeUnit.quote,
    this.manualCheck = true,
    this.compact = false,
    this.scale,
    this.amount,
    this.onAmount,
  });
  final OrderSizeUnit unit;
  final bool manualCheck;

  /// Compact only: the slider range in the shown unit, the current manual
  /// amount, and how an intermediate position becomes manual input. The
  /// track's end selects 100%, each direction's exact maximum.
  final MainOrderSliderScale? scale;
  final Decimal? amount;
  final ValueChanged<String>? onAmount;

  /// Trade-workspace slider: five stops and failures only, as designed.
  final bool compact;

  @override
  ConsumerState<MainOrderPercentageControl> createState() => _MainOrderPercentageControlState();
}

class _MainOrderPercentageControlState extends ConsumerState<MainOrderPercentageControl> {
  /// Each committed percent re-sizes and rebuilds the whole order form, so a
  /// drag follows the finger locally and commits at most once per interval.
  late final _throttle = DragThrottle<int>(_commit);
  int? _dragPercent;
  MainOrderSliderScale? _lastScale;

  @override
  void didUpdateWidget(MainOrderPercentageControl old) {
    super.didUpdateWidget(old);
    if (old.unit != widget.unit) _lastScale = null;
  }

  @override
  void dispose() {
    _throttle.cancel();
    super.dispose();
  }

  void _drag(double value) {
    setState(() => _dragPercent = value.round());
    _throttle.add(value.round());
  }

  void _dragEnd(double value) {
    _throttle.end(value.round());
    if (mounted) setState(() => _dragPercent = null);
  }

  /// A position before the end becomes a whole-unit (or sub-unit) amount.
  void _commitPosition(double position, MainOrderSliderScale? scale) {
    final choice = sliderChoice(
      position,
      maximum: widget.onAmount == null ? null : scale?.maximum,
      fine: scale?.fine ?? Decimal.zero,
    );
    if (choice.amount case final amount?) return widget.onAmount!('$amount');
    _commit(choice.percent!);
  }

  void _commit(int percent) {
    if (ref.read(mainOrderAllocationProvider).percent != percent) {
      ref
          .read(mainOrderAllocationProvider.notifier)
          .selectPercent(percent, pending: widget.compact);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(mainOrderAllocationProvider);
    ref.watch(mainOrderCapacityProvider);
    ref.watch(liveOrderProvider);
    ref.watch(symbolSettingsActivityProvider);
    ref.watch(mainOrderRefreshProvider);
    final controller = ref.read(mainOrderAllocationProvider.notifier);
    final pricing = ref.watch(mainOrderPricingProvider);
    var available = false;
    final snapshot = ref.read(mainOrderCapacityProvider.notifier).current;
    if (snapshot != null) {
      try {
        pricing.revalue(snapshot);
        available = true;
      } on AccountReadFailure {
        /* Missing prices keep the slider disabled. */
      }
    }
    // The trade-workspace slider stays usable through silent polling and
    // before capacity/prices are current; review re-reads them on click.
    final interactive = widget.compact ? controller.adjustable : available && controller.editable;
    final onChanged = interactive ? _drag : null;
    final onChangeEnd = interactive ? _dragEnd : null;
    if (!interactive) {
      // A drag cut off by disabling never reports its end; drop its local value.
      _throttle.cancel();
      _dragPercent = null;
    }
    final percent = _dragPercent ?? state.percent;
    final failure = state.failure == null ? null : _failureText(context, state.failure!);
    if (widget.compact) {
      // Keep the last known range while a refresh briefly drops the preview.
      final scale = _lastScale = widget.scale ?? _lastScale;
      final amount = widget.amount;
      final position = sliderPosition(
        percent: state.percent,
        amount: amount,
        maximum: scale?.maximum,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MainOrderAmountSlider(
            position: position,
            continuous: scale != null && widget.onAmount != null,
            onCommit: interactive ? (value) => _commitPosition(value, scale) : null,
            semanticLabel: (value) => l10n.liveAllocationPercent((value * 100).round()),
          ),
          ?failure,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.liveAllocationPercent(percent ?? 0)),
        // Keep the adjustable control in its own accessible subtree while the
        // dialog route closes and the form changes between enabled/disabled.
        Semantics(
          container: true,
          child: Slider(
            key: const Key('main-order-percentage'),
            min: 0,
            max: 100,
            divisions: 100,
            value: (percent ?? 0).toDouble(),
            label: '${percent ?? 0}%',
            semanticFormatterCallback: (value) => l10n.liveAllocationPercent(value.round()),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        if (state.percent == null) Text(l10n.liveAllocationManual),
        Text(
          state.percent == null && widget.manualCheck
              ? l10n.liveAllocationManualHint
              : l10n.liveAllocationHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (state.preparing) Text(l10n.liveAllocationChecking),
        ?failure,
      ],
    );
  }

  Widget _failureText(BuildContext context, AccountReadFailure failure) {
    final l10n = AppLocalizations.of(context);
    return Text(
      failure is MainOrderCapacityExceeded
          ? l10n.liveAllocationMaximumChanged(
              failure.capacity.buy ? l10n.long : l10n.short,
              widget.unit == OrderSizeUnit.quote
                  ? '≈ ${failure.capacity.maximumQuote}'
                  : '${failure.capacity.maximum}',
              widget.unit == OrderSizeUnit.quote
                  ? failure.context.rules.quoteAsset
                  : failure.context.rules.baseAsset,
            )
          : accountErrorText(context, failure),
      key: const Key('main-order-allocation-failure'),
      style: const TextStyle(color: AppColors.negative),
    );
  }
}
