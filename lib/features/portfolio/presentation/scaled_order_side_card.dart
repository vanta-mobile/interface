import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/live_order.dart';
import 'direction_action_card.dart';
import '../../../core/theme.dart' show PressFeedback;

/// Direction summary and order button of the Scaled Order form, styled like
/// the main order card: Margin for both sides, Max on the long side.
class ScaledSideCard extends StatelessWidget {
  const ScaledSideCard({
    super.key,
    required this.data,
    required this.buy,
    required this.margin,
    required this.maximum,
    required this.pending,
    required this.onPressed,
  });
  final LiveOrderContext data;
  final bool buy, pending;

  /// Null shows zero, as designed for an empty form.
  final Decimal? margin;

  /// Amount and unit, in the size field's unit.
  final ({String amount, String unit})? maximum;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), side = buy ? 'long' : 'short';
    final color = buy ? TradeColors.positive : TradeColors.negative;
    final quote = data.rules.quoteAsset;
    final rows = [
      (l10n.tradeMargin, (margin ?? Decimal.zero).toStringAsFixed(2), quote, 'margin'),
      if (maximum case final max?) (l10n.accountsMax, max.amount, max.unit, 'max'),
    ];
    return DirectionActionCard(
      key: Key('scaled-side-$side'),
      rows: [
        for (final (label, value, asset, name) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(label, style: TradeTypography.caption)),
                const SizedBox(width: 4),
                Text.rich(
                  key: Key('scaled-$name-$side'),
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(color: color),
                      ),
                      TextSpan(text: ' $asset'),
                    ],
                  ),
                  textAlign: TextAlign.end,
                  style: TradeTypography.caption.copyWith(color: TradeColors.text),
                ),
              ],
            ),
          ),
      ],
      button: FilledButton(
        key: Key('scaled-review-$side'),
        onPressed: pending ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          backgroundColor: color,
          foregroundColor: TradeColors.text,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          disabledBackgroundColor: pending ? color : color.withValues(alpha: .35),
          disabledForegroundColor: TradeColors.muted,
          shape: DirectionActionCard.buttonShape,
          textStyle: TradeTypography.body.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        ).copyWith(overlayColor: PressFeedback.overlay),
        child: pending
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: TradeColors.text),
              )
            : Text(buy ? l10n.long : l10n.short),
      ),
    );
  }
}
