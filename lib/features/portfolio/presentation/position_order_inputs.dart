import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_icon.dart';

// Shared controls of the position TP/SL page and the Close Position sheet,
// drawn to the Futures design: 12 px-radius fields with a 10 px caption, a
// 14 px bold value and a compact suffix with the design caret.

/// The design's 6.37 x 3.64 dropdown caret (`policy-caret.svg`).
class PositionCaret extends StatelessWidget {
  const PositionCaret({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 6.37,
    height: 3.64,
    child: OverflowBox(
      maxWidth: 8,
      maxHeight: 8,
      child: TradeIcon('policy-caret', size: 8, color: TradeColors.muted),
    ),
  );
}

/// Compact field suffix such as "Last", "$" or "USDT" with the caret. A null
/// [onTap] renders it as plain text.
class PositionSuffix extends StatelessWidget {
  const PositionSuffix({
    super.key,
    required this.label,
    this.tooltip,
    this.onTap,
    this.caret = true,
  });
  final String label;
  final String? tooltip;
  final VoidCallback? onTap;
  final bool caret;
  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: TradeTypography.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (caret) ...[const SizedBox(width: 4), const PositionCaret()],
      ],
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: tooltip,
      child: PositionTapTarget(onTap: onTap, child: content),
    );
  }
}

/// Tappable compact control (suffix selectors) with an ink response.
class PositionTapTarget extends StatelessWidget {
  const PositionTapTarget({super.key, required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      InkWell(onTap: onTap, borderRadius: BorderRadius.circular(4), child: child);
}

/// Filled field shell: optional 10 px caption above its content.
class PositionField extends StatelessWidget {
  const PositionField({
    super.key,
    required this.child,
    this.label,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.border,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });
  final String? label;
  final Widget child;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: TradeColors.card,
      borderRadius: borderRadius,
      border: border ?? Border.all(color: TradeColors.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (label case final text?)
          Text(text, style: TradeTypography.small, maxLines: 1, overflow: TextOverflow.ellipsis),
        child,
      ],
    ),
  );
}

/// Numeric input row of a field: value, flexible space, suffix.
class PositionValueInput extends StatelessWidget {
  const PositionValueInput({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    this.suffix,
    this.signed = false,
    this.bold = true,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final bool enabled, signed;

  /// Design values are 14 px bold; limit prices are 12 px medium.
  final bool bold;
  final VoidCallback onChanged;
  final Widget? suffix;
  static const _bold = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
    color: TradeColors.text,
  );
  @override
  Widget build(BuildContext context) {
    final style = bold ? _bold : TradeTypography.body;
    // A fixed row height keeps IntrinsicHeight rows at the design size; the
    // text field's own intrinsic height would otherwise inflate them.
    return SizedBox(
      height: bold ? 22 : 18,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: fieldKey,
              controller: controller,
              readOnly: !enabled,
              style: style,
              keyboardType: TextInputType.numberWithOptions(decimal: true, signed: signed),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: '0',
                hintStyle: style.copyWith(color: TradeColors.muted),
                contentPadding: const EdgeInsets.symmetric(vertical: 1),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          if (suffix != null) ...[const SizedBox(width: 4), suffix!],
        ],
      ),
    );
  }
}

/// Limit price field with its BBO button. With BBO selected the field becomes
/// the level picker ("Queue 1"); the button gets the accent border and text.
class PositionPriceRow extends StatelessWidget {
  const PositionPriceRow({
    super.key,
    required this.controller,
    required this.caption,
    required this.enabled,
    required this.onChanged,
    required this.onBbo,
    this.suffix,
    this.bboLevel,
    this.onBboLevel,
  });
  final TextEditingController controller;
  final String caption;
  final bool enabled;
  final VoidCallback onChanged, onBbo;
  final Widget? suffix;

  /// Selected BBO level label; null while a manual price is used.
  final String? bboLevel;
  final VoidCallback? onBboLevel;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), bbo = bboLevel != null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: bbo
                ? Material(
                    color: TradeColors.card,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const Key('position-bbo-level'),
                      onTap: enabled ? onBboLevel : null,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(bboLevel!, style: TradeTypography.body)),
                            const PositionCaret(),
                          ],
                        ),
                      ),
                    ),
                  )
                : PositionField(
                    label: caption,
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: PositionValueInput(
                      fieldKey: const Key('position-limit-price'),
                      controller: controller,
                      enabled: enabled,
                      bold: false,
                      onChanged: onChanged,
                      suffix: suffix,
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          Material(
            color: TradeColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: bbo ? const BorderSide(color: TradeColors.accent) : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('position-bbo'),
              onTap: enabled ? onBbo : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    l10n.liveOrderBbo,
                    style: TradeTypography.body.copyWith(
                      color: bbo ? TradeColors.accent : TradeColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Five-stop amount slider of the design: a 4 px control track, a small first
/// stop, ringed stops at 25/50/75/100% and a white 12 px thumb.
class PositionAmountSlider extends StatelessWidget {
  const PositionAmountSlider({
    super.key,
    required this.percent,
    required this.onChanged,
    this.sliderKey,
  });
  final int percent;
  final ValueChanged<int>? onChanged;
  final Key? sliderKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth;
      int stopAt(double dx) => ((dx - 6) / (width - 12) * 4).round().clamp(0, 4) * 25;
      void pick(Offset position) {
        final value = stopAt(position.dx);
        if (value != percent) onChanged?.call(value);
      }

      return Semantics(
        key: sliderKey,
        slider: true,
        value: '$percent%',
        increasedValue: '${(percent + 25).clamp(0, 100)}%',
        decreasedValue: '${(percent - 25).clamp(0, 100)}%',
        onIncrease: onChanged == null || percent >= 100
            ? null
            : () => onChanged!((percent + 25).clamp(0, 100)),
        onDecrease: onChanged == null || percent <= 0
            ? null
            : () => onChanged!((percent - 25).clamp(0, 100)),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onChanged == null ? null : (d) => pick(d.localPosition),
          onHorizontalDragUpdate: onChanged == null ? null : (d) => pick(d.localPosition),
          child: SizedBox(height: 24, child: CustomPaint(painter: _SliderPainter(percent / 100))),
        ),
      );
    },
  );
}

class _SliderPainter extends CustomPainter {
  _SliderPainter(this.share);
  final double share;
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2, travel = size.width - 12;
    final track = RRect.fromLTRBR(0, y - 2, size.width, y + 2, const Radius.circular(999));
    canvas.drawRRect(track, Paint()..color = TradeColors.control);
    for (var i = 0; i < 5; i++) {
      final center = Offset(6 + travel * i / 4, y);
      if (i == 0) {
        canvas.drawCircle(center, 3, Paint()..color = TradeColors.muted);
        continue;
      }
      canvas.drawCircle(center, 5, Paint()..color = TradeColors.control);
      canvas.drawCircle(
        center,
        5,
        Paint()
          ..color = TradeColors.background
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(Offset(6 + travel * share, y), 6, Paint()..color = TradeColors.text);
  }

  @override
  bool shouldRepaint(_SliderPainter old) => old.share != share;
}

/// Bold 16 px tabs with the 1 px accent indicator (Partial / Entire close,
/// Market / Limit close).
class PositionTabs<T> extends StatelessWidget {
  const PositionTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });
  final List<(T, String)> tabs;
  final T selected;
  final ValueChanged<T>? onSelect;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: TradeColors.card)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (value, label) in tabs) ...[
            Semantics(
              selected: value == selected,
              button: true,
              child: InkWell(
                key: ValueKey('position-tab-$value'),
                onTap: onSelect == null ? null : () => onSelect!(value),
                child: IntrinsicWidth(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TradeTypography.action.copyWith(
                            color: value == selected ? TradeColors.text : TradeColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 1,
                          color: value == selected ? TradeColors.accent : TradeColors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
          ],
        ],
      ),
    ),
  );
}

/// 48 px action button; the primary one is the accent Confirm with a spinner
/// while pending, the secondary one the card-filled Cancel.
class PositionActionButton extends StatelessWidget {
  const PositionActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.pending = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary, pending;
  @override
  Widget build(BuildContext context) {
    final background = primary ? TradeColors.accent : TradeColors.card;
    final foreground = primary ? TradeColors.onAccent : TradeColors.text;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        // Pending keeps the action color; the spinner carries the busy state.
        disabledBackgroundColor: pending ? background : background.withValues(alpha: 0.5),
        disabledForegroundColor: foreground,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TradeTypography.action,
      ),
      child: pending
          ? SizedBox.square(
              key: const Key('position-action-loading'),
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
            )
          : Text(label, textAlign: TextAlign.center),
    );
  }
}
