import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/app_toast.dart';
import '../../../core/strings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_option_sheet.dart';
import '../application/live_order_provider.dart';
import '../application/main_order_capacity_preview_provider.dart';
import '../application/scaled_order_provider.dart';
import '../domain/account_snapshot.dart';
import '../domain/futures_position_mode.dart';
import '../domain/live_order.dart';
import '../domain/live_order_size.dart';
import '../domain/live_order_time_in_force.dart';
import '../domain/scaled_order.dart';
import 'embedded_time_in_force_selector.dart';
import 'live_order_embedded_controls.dart';
import 'live_order_embedded_inputs.dart';
import 'scaled_order_confirmation.dart';
import 'scaled_order_distribution.dart';
import 'scaled_order_sheets.dart';
import 'scaled_order_side_card.dart';

/// Scaled Order in the trade workspace (design 10.01–10.10): a price range
/// split into 2–110 limit orders, previewed and confirmed before signing.
class ScaledOrderEmbeddedForm extends ConsumerStatefulWidget {
  const ScaledOrderEmbeddedForm({super.key, required this.data, required this.enabled});
  final LiveOrderContext data;
  final bool enabled;
  @override
  ConsumerState<ScaledOrderEmbeddedForm> createState() => _ScaledOrderEmbeddedFormState();
}

class _ScaledOrderEmbeddedFormState extends ConsumerState<ScaledOrderEmbeddedForm> {
  final low = TextEditingController(), high = TextEditingController();
  final count = TextEditingController(), size = TextEditingController();
  ScaledSizeUnit unit = ScaledSizeUnit.base;
  ScaledDistribution distribution = ScaledDistribution.equal;
  ScaledConstant constant = ScaledConstant.difference;
  LiveOrderTimeInForce timeInForce = LiveOrderTimeInForce.gtc;
  bool reduceOnly = false;
  int? randomSeed;

  /// The side whose button is reading or reviewing.
  bool? _pendingSide;

  /// The side last clicked while its plan exceeded that side's maximum; like
  /// Aster, only the clicked direction is checked. Any edit clears it.
  bool? _overSide;

  /// Whether each side currently exceeds its maximum, from the last build.
  ({bool buy, bool sell}) _overNow = (buy: false, sell: false);

  /// Last maximum and its terms, shown while background renewal re-reads the
  /// account, as the main order form does; other terms never reuse it.
  ({Object terms, Decimal? buy, Decimal? sell})? _retained;

  LiveOrderContext get data => widget.data;

  @override
  void dispose() {
    for (final c in [low, high, count, size]) {
      c.dispose();
    }
    super.dispose();
  }

  ScaledOrderDraft? _draft(bool buy) {
    final orders = int.tryParse(count.text.trim());
    if ([low, high, size].any((c) => c.text.trim().isEmpty) || orders == null) return null;
    return ScaledOrderDraft(
      buy: buy,
      lowest: low.text.trim(),
      highest: high.text.trim(),
      quantity: size.text.trim(),
      count: orders,
      unit: unit,
      distribution: distribution,
      constant: constant,
      randomSeed: randomSeed,
      reduceOnly: data.mode == FuturesPositionMode.oneWay && reduceOnly,
      timeInForce: timeInForce,
    );
  }

  /// The plan, or the reason it cannot be built, named per child order. A
  /// price-range failure at the lowest or highest price is reported under
  /// that field instead (keyed by the field).
  (ScaledOrderPlan?, String?, String?) _plan(AppLocalizations l10n) {
    final draft = _draft(true);
    if (draft == null) return (null, null, null);
    try {
      return (planScaledOrder(data, draft), null, null);
    } on ScaledChildFailure catch (error) {
      if (const {'liveOrderPercentFilter', 'liveOrderPriceFilter'}.contains(error.key)) {
        final price = parseOrderDecimal(error.order.price);
        for (final (field, text) in [('scaled-high', high.text), ('scaled-low', low.text)]) {
          if (price != null && price == parseOrderDecimal(text.trim())) {
            return (null, null, field);
          }
        }
      }
      return (
        null,
        l10n.scaledChildInvalid(
          error.index + 1,
          error.order.price,
          error.order.quantity,
          tr(context, error.key),
        ),
        null,
      );
    } on AccountReadFailure catch (error) {
      return (null, tr(context, error.key), null);
    }
  }

  /// Largest base quantity each direction can open, read like Aster's form:
  /// the ordinary limit-order capacity priced at the plan's average (or the
  /// last price before a plan exists). Null before account facts arrive.
  ({Decimal? buy, Decimal? sell, Decimal price})? _capacity(ScaledOrderPlan? plan) {
    final reference = plan == null ? data.lastPrice ?? data.markPrice : scaledAveragePrice(plan);
    final tick = data.rules.priceTick;
    if (reference == null || reference <= Decimal.zero || tick <= Decimal.zero) return null;
    final price = Decimal.fromBigInt((reference / tick).floor()) * tick;
    final preview = ref.watch(
      mainOrderCapacityPreviewProvider((
        context: data,
        draft: LiveOrderDraft(buy: true, market: false, quantity: '', price: '$price'),
        unit: OrderSizeUnit.base,
        input: '',
        percent: null,
      )),
    );
    final terms = (
      data.address.toLowerCase(),
      data.symbol,
      data.leverage,
      data.mode,
      data.marginMode,
      price,
    );
    final buy = preview?.buy.capacity?.maximum, sell = preview?.sell.capacity?.maximum;
    if (buy != null || sell != null) {
      _retained = (terms: terms, buy: buy, sell: sell);
      return (buy: buy, sell: sell, price: price);
    }
    final retained = _retained;
    return retained != null && retained.terms == terms
        ? (buy: retained.buy, sell: retained.sell, price: price)
        : null;
  }

  /// A side whose plan exceeds its maximum; reducing orders are not capped.
  bool _over(ScaledOrderPlan plan, Decimal? maximum) =>
      !(data.mode == FuturesPositionMode.oneWay && reduceOnly) &&
      maximum != null &&
      plan.totalQuantity > maximum;

  ({String amount, String unit}) _maximumText(Decimal maximum, Decimal price) =>
      unit == ScaledSizeUnit.quote
      ? (amount: (maximum * price).floor(scale: 2).toStringAsFixed(2), unit: data.rules.quoteAsset)
      : (amount: '$maximum', unit: data.rules.baseAsset);

  void _changed() => setState(() => _overSide = null);

  /// Sheets open without the keyboard and do not hand focus back to a field.
  Future<T> _sheet<T>(Future<T> Function() open) {
    FocusScope.of(context).unfocus();
    return open();
  }

  Future<void> _chooseUnit() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    final value = await showTradeOptionSheet(
      context,
      key: const Key('scaled-unit-sheet'),
      title: l10n.tradeSelectUnitType,
      selected: unit,
      options: [
        (value: ScaledSizeUnit.quote, label: data.rules.quoteAsset, description: null),
        (value: ScaledSizeUnit.base, label: data.rules.baseAsset, description: null),
      ],
    );
    if (value != null && value != unit && mounted) {
      setState(() {
        unit = value;
        size.clear();
        _overSide = null;
      });
    }
  }

  Future<void> _chooseDistribution() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    final value = await showTradeOptionSheet(
      context,
      key: const Key('scaled-distribution-sheet'),
      title: l10n.scaledDistributionLabel,
      selected: distribution,
      options: [
        for (final option in ScaledDistribution.values)
          (value: option, label: _distributionLabel(l10n, option), description: null),
      ],
    );
    if (value == null || !mounted) return;
    setState(() {
      distribution = value;
      _overSide = null;
      if (value == ScaledDistribution.random) {
        randomSeed ??= ref.read(scaledOrderProvider.notifier).createRandomSeed();
      }
    });
  }

  static String _distributionLabel(AppLocalizations l10n, ScaledDistribution value) =>
      switch (value) {
        ScaledDistribution.equal => l10n.scaledEqual,
        ScaledDistribution.increasing => l10n.scaledIncreasing,
        ScaledDistribution.decreasing => l10n.scaledDecreasing,
        ScaledDistribution.random => l10n.scaledRandom,
      };

  /// Prepares the plan against fresh facts, reading them once if they lapsed.
  Future<void> _review(bool buy) async {
    if (buy ? _overNow.buy : _overNow.sell) {
      setState(() => _overSide = buy);
      return;
    }
    final draft = _draft(buy);
    if (draft == null || _pendingSide != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _pendingSide = buy);
    try {
      final controller = ref.read(scaledOrderProvider.notifier);
      var intent = controller.prepare(data.symbol, draft);
      if (intent == null) {
        await ref.read(liveOrderProvider.notifier).load(data.symbol);
        if (!mounted) return;
        intent = controller.prepare(data.symbol, draft);
      }
      if (intent == null) {
        final failure = ref.read(liveOrderProvider).failure;
        AppToast.showFailure(
          context,
          accountErrorText(context, failure ?? const AccountReadFailure('scaledRefreshRequired')),
        );
        return;
      }
      setState(() => _pendingSide = null);
      if (await confirmScaledOrder(context, intent) && mounted) {
        setState(size.clear);
      }
    } finally {
      if (mounted) setState(() => _pendingSide = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(scaledOrderProvider.select((s) => s.busy));
    final enabled = widget.enabled && !busy && _pendingSide == null;
    final (plan, invalid, priceField) = _plan(l10n);
    final capacity = _capacity(plan);
    final over = (
      buy: plan != null && _over(plan, capacity?.buy),
      sell: plan != null && _over(plan, capacity?.sell),
    );
    _overNow = over;
    // Aster's "Maximum qty is …" for the clicked direction, while still over.
    final side = _overSide;
    final exceeded = side == null || !(side ? over.buy : over.sell)
        ? null
        : side
        ? capacity!.buy
        : capacity!.sell;
    final maximum = exceeded == null
        ? null
        : l10n.scaledMaximumSize(switch (_maximumText(exceeded, capacity!.price)) {
            (:final amount, :final unit) => '$amount $unit',
          });
    final error = maximum ?? invalid;
    return Column(
      key: const Key('scaled-order-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        ..._fields(l10n, enabled, sizeError: maximum != null, priceField: priceField),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error,
              key: const Key('scaled-error'),
              style: TradeTypography.small.copyWith(color: TradeColors.negative),
            ),
          ),
        const SizedBox(height: 4),
        ScaledDistributionRow(
          onInfo: () => _sheet(() => showScaledDistributionInfo(context, constant: constant)),
          onPreview: plan == null
              ? null
              : () => _sheet(() => showScaledPreviewSheet(context, plan: plan, data: data)),
        ),
        const SizedBox(height: 4),
        ScaledDistributionChip(
          label: _distributionLabel(l10n, distribution),
          constant:
              distribution == ScaledDistribution.increasing ||
                  distribution == ScaledDistribution.decreasing
              ? constant
              : null,
          onDistribution: enabled ? _chooseDistribution : null,
          onConstant: enabled
              ? () => setState(
                  () => constant = constant == ScaledConstant.difference
                      ? ScaledConstant.ratio
                      : ScaledConstant.difference,
                )
              : null,
        ),
        EmbeddedAvailableRow(data: data),
        EmbeddedAdvancedSection(children: _advanced(l10n, enabled)),
        const SizedBox(height: 12),
        for (final buy in [true, false]) ...[
          if (!buy) const SizedBox(height: 12),
          ScaledSideCard(
            data: data,
            buy: buy,
            margin: plan == null ? null : scaledMargin(plan, data),
            maximum: !buy || capacity?.buy == null
                ? null
                : _maximumText(capacity!.buy!, capacity.price),
            pending: _pendingSide == buy,
            onPressed: enabled && plan != null ? () => _review(buy) : null,
          ),
        ],
      ],
    );
  }

  /// Price range, order count and size, as designed (10.01–10.03).
  List<Widget> _fields(
    AppLocalizations l10n,
    bool enabled, {
    required bool sizeError,
    String? priceField,
  }) {
    final quote = data.rules.quoteAsset;
    return [
      for (final (key, label, controller, hint, decimal) in [
        ('scaled-low', l10n.scaledLowestPrice, low, '0.00', true),
        ('scaled-high', l10n.scaledHighestPrice, high, '0.00', true),
        ('scaled-count', l10n.scaledOrderCount, count, l10n.scaledCountRange, false),
      ]) ...[
        EmbeddedInputBox(
          label: label,
          error: priceField == key,
          child: Row(
            children: [
              Expanded(
                child: EmbeddedTextInput(
                  fieldKey: Key(key),
                  controller: controller,
                  enabled: enabled,
                  hint: hint,
                  onChanged: _changed,
                ),
              ),
              if (decimal) Text(quote, style: TradeTypography.body),
            ],
          ),
        ),
        if (priceField == key)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.scaledPriceOutOfRange,
              key: Key('$key-error'),
              style: TradeTypography.small.copyWith(color: TradeColors.negative),
            ),
          ),
        const SizedBox(height: 8),
      ],
      EmbeddedInputBox(
        label: l10n.tradeOrderSize,
        error: sizeError,
        child: Row(
          children: [
            Expanded(
              child: EmbeddedTextInput(
                fieldKey: const Key('scaled-size'),
                controller: size,
                enabled: enabled,
                hint: '0.00',
                onChanged: _changed,
              ),
            ),
            EmbeddedSelector(
              key: const Key('scaled-unit'),
              label: unit == ScaledSizeUnit.quote ? quote : data.rules.baseAsset,
              tooltip: l10n.tradeSelectUnitType,
              onTap: enabled ? _chooseUnit : null,
            ),
          ],
        ),
      ),
    ];
  }

  /// Hidden Order, then Reduce-only (one-way only) with the time in force.
  List<Widget> _advanced(AppLocalizations l10n, bool enabled) {
    final rules = data.rules, hidden = timeInForce == LiveOrderTimeInForce.hidden;
    final oneWay = data.mode == FuturesPositionMode.oneWay;
    final policies = {
      // Scaled children are GTC, or HIDDEN when Hidden Order is on.
      for (final policy in [LiveOrderTimeInForce.gtc])
        if (rules.timeInForce.contains(policy)) policy,
    };
    final policy = hidden || policies.isEmpty
        ? null
        : EmbeddedTimeInForceSelector(
            key: const Key('scaled-policy'),
            selected: timeInForce,
            available: policies,
            onChanged: enabled ? (value) => setState(() => timeInForce = value) : null,
          );
    return [
      if (rules.timeInForce.contains(LiveOrderTimeInForce.hidden))
        EmbeddedCheckRow(
          key: const Key('scaled-hidden'),
          label: l10n.tradeHiddenOrder,
          help: l10n.tradeHiddenOrderHelp,
          value: hidden,
          trailing: oneWay ? null : policy,
          onChanged: enabled
              ? (value) => setState(
                  () =>
                      timeInForce = value ? LiveOrderTimeInForce.hidden : LiveOrderTimeInForce.gtc,
                )
              : null,
        ),
      if (oneWay)
        EmbeddedCheckRow(
          key: const Key('scaled-reduce-only'),
          label: l10n.reduceOnly,
          help: l10n.tradeReduceOnlyHelp,
          value: reduceOnly,
          trailing: policy,
          onChanged: enabled
              ? (value) => setState(() {
                  reduceOnly = value;
                  _overSide = null;
                })
              : null,
        ),
    ];
  }
}
