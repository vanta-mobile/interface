import 'package:flutter/material.dart';

import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_icon.dart';

/// Labeled 14 px checkbox from the Futures design, e.g. "Hide other symbols"
/// above the order and position lists or a TP/SL leg's "Limit order".
class TradeCheckOption extends StatelessWidget {
  const TradeCheckOption({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.tapKey,
    this.minHeight = 44,
    this.inline = false,
  });
  final String label;

  /// Touch height; inline section-header controls use the design's row height.
  final double minHeight;

  /// Sizes to its content for use inside a row; otherwise left-aligned and
  /// wrapping its label within the available width.
  final bool inline;
  final bool value;
  final Key? tapKey;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: TradeTypography.body.copyWith(color: TradeColors.secondary));
    final option = Semantics(
      checked: value,
      child: InkWell(
        key: tapKey,
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value ? TradeColors.accent : null,
                  border: value ? null : Border.all(color: TradeColors.secondary, width: .7),
                  borderRadius: BorderRadius.circular(5.6),
                ),
                child: value
                    ? const TradeIcon('check', size: 9, color: TradeColors.background)
                    : null,
              ),
              const SizedBox(width: 6),
              if (inline) text else Flexible(child: text),
            ],
          ),
        ),
      ),
    );
    return inline ? option : Align(alignment: Alignment.centerLeft, child: option);
  }
}
