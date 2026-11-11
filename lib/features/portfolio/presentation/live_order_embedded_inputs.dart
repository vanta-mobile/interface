import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_option_sheet.dart';
import '../domain/live_order.dart';
import '../domain/live_order_size.dart';
import 'live_order_embedded_controls.dart';

/// Design-matching price box for the trade workspace. Stepping keeps the price
/// on the exchange tick; validation still belongs to the order rules.
class EmbeddedPriceField extends StatelessWidget {
  const EmbeddedPriceField({
    super.key,
    required this.controller,
    required this.asset,
    required this.tick,
    required this.enabled,
    required this.onChanged,
    this.fixedLabel,
    this.bboSelected = false,
    this.onBbo,
    this.bboLevel,
    this.onBboLevel,
  });
  final TextEditingController controller;
  final String asset;
  final Decimal tick;
  final bool enabled;
  final VoidCallback onChanged;

  /// Replaces the editable price, e.g. for market or BBO execution.
  final String? fixedLabel;
  final bool bboSelected;
  final VoidCallback? onBbo;

  /// Selected BBO level; when set, the price box becomes the BBO mode picker.
  final String? bboLevel;
  final VoidCallback? onBboLevel;

  void _step(int direction) {
    final current = parseOrderDecimal(controller.text.trim());
    if (current == null || tick <= Decimal.zero) return;
    final floor = Decimal.fromBigInt((current / tick).floor()) * tick;
    final next = direction < 0 && floor != current
        ? floor
        : floor + tick * Decimal.fromInt(direction);
    if (next <= Decimal.zero) return;
    controller.text = next.toString();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final editable = enabled && fixedLabel == null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: bboLevel != null
                ? _BboModeBox(level: bboLevel!, onTap: enabled ? onBboLevel : null)
                : EmbeddedInputBox(
                    label: l.tradeOrderPrice(asset),
                    child: Row(
                      children: [
                        Expanded(
                          child: fixedLabel != null
                              ? Text(fixedLabel!, style: TradeTypography.body, maxLines: 1)
                              : EmbeddedTextInput(
                                  fieldKey: const Key('live-order-price'),
                                  controller: controller,
                                  enabled: enabled,
                                  onChanged: onChanged,
                                ),
                        ),
                        _StepButton(
                          icon: Icons.remove,
                          tooltip: l.tradePriceDown,
                          onPressed: editable ? () => _step(-1) : null,
                        ),
                        _StepButton(
                          icon: Icons.add,
                          tooltip: l.tradePriceUp,
                          onPressed: editable ? () => _step(1) : null,
                        ),
                      ],
                    ),
                  ),
          ),
          if (onBbo != null || bboSelected) ...[
            const SizedBox(width: 4),
            Material(
              color: bboSelected ? TradeColors.accentBackground : TradeColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: bboSelected ? const BorderSide(color: TradeColors.positive) : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('live-order-bbo'),
                onTap: enabled ? onBbo : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Text(
                      l.liveOrderBbo,
                      style: TradeTypography.body.copyWith(
                        color: bboSelected ? TradeColors.accent : TradeColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// BBO price source from the design: the caption names the mode and the
/// value opens the level sheet.
class _BboModeBox extends StatelessWidget {
  const _BboModeBox({required this.level, required this.onTap});
  final String level;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('live-order-bbo-level'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: EmbeddedInputBox(
          label: l.liveOrderBboModeLabel,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(
              children: [
                Expanded(child: Text(level, style: TradeTypography.body, maxLines: 1)),
                const Icon(Icons.arrow_drop_down, size: 18, color: TradeColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmbeddedSizeField extends StatelessWidget {
  const EmbeddedSizeField({
    super.key,
    required this.data,
    required this.unit,
    required this.controller,
    required this.enabled,
    required this.onUnit,
    required this.onInput,
    this.minimumHint,
  });
  final LiveOrderContext data;
  final OrderSizeUnit unit;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<OrderSizeUnit> onUnit;
  final VoidCallback onInput;
  final String? minimumHint;

  String _label(OrderSizeUnit value) =>
      value == OrderSizeUnit.quote ? data.rules.quoteAsset : data.rules.baseAsset;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmbeddedInputBox(
      label: l.tradeOrderSize,
      child: Row(
        children: [
          Expanded(
            child: EmbeddedTextInput(
              fieldKey: const Key('live-order-quantity'),
              controller: controller,
              enabled: enabled,
              onChanged: onInput,
              hint: minimumHint ?? '',
            ),
          ),
          EmbeddedSelector(
            key: const Key('live-order-unit'),
            label: _label(unit),
            tooltip: l.tradeSelectUnitType,
            onTap: enabled
                ? () async {
                    final value = await showTradeOptionSheet(
                      context,
                      title: l.tradeSelectUnitType,
                      selected: unit,
                      options: [
                        for (final option in OrderSizeUnit.values.reversed)
                          (value: option, label: _label(option), description: null),
                      ],
                    );
                    if (value != null && value != unit) onUnit(value);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// Filled, rounded field shell with a small caption above its content.
class EmbeddedInputBox extends StatelessWidget {
  const EmbeddedInputBox({super.key, required this.label, required this.child, this.labelTrailing});
  final String label;
  final Widget child;

  /// Inline control after the caption, e.g. a trigger price-type selector.
  final Widget? labelTrailing;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(color: TradeColors.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TradeTypography.small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (labelTrailing != null) ...[const SizedBox(width: 6), labelTrailing!],
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class EmbeddedTextInput extends StatelessWidget {
  const EmbeddedTextInput({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    this.hint = '0',
    this.signed = false,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;
  final String hint;
  final bool signed;
  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      readOnly: !enabled,
      style: TradeTypography.body,
      keyboardType: TextInputType.numberWithOptions(decimal: true, signed: signed),
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      color: TradeColors.secondary,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 28, height: 32),
      padding: EdgeInsets.zero,
    );
  }
}
