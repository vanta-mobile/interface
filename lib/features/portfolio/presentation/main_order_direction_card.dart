import '../../../core/presentation/status_view.dart';

import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rational/rational.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/live_order.dart';
import '../domain/live_order_capacity.dart';
import '../domain/live_order_size.dart';
import '../domain/main_order_capacity_preview.dart';
import 'direction_action_card.dart';
import '../../../core/theme.dart' show PressFeedback;

/// Liquidation estimate rounded to the symbol's price precision, or null.
String? mainOrderLiquidationText(MainOrderSidePreview? value, LiveOrderContext data) {
  final price = value?.liquidation, precision = data.rules.pricePrecision;
  if (price == null || precision == null || precision < 0 || precision > 80) return null;
  // `toDecimal` keeps a terminating value unrounded (e.g. 236.6875), which the
  // fixed-decimals formatter rejects; round to the price precision first.
  final rounded = Decimal.fromBigInt((price * Rational(BigInt.from(10).pow(precision))).round())
      .shift(-precision);
  if (rounded <= Decimal.zero) return null;
  return TokenAmountFormatter.formatFixed(DecimalValue(rounded.toString()), decimals: precision);
}

/// Trade-workspace direction summary and its review button, as designed.
class MainOrderDirectionCard extends StatelessWidget {
  const MainOrderDirectionCard({
    super.key,
    required this.value,
    required this.data,
    required this.unit,
    required this.buy,
    required this.hasSize,
    required this.onReview,
    this.pending = false,
    this.resultsPending = false,
    this.retainedCapacity,
    this.showLiquidation = true,
    this.label,
  });
  final MainOrderSidePreview? value;
  final LiveOrderContext data;
  final OrderSizeUnit unit;
  final bool buy;
  final bool hasSize;
  final VoidCallback? onReview;
  final bool pending;
  final bool resultsPending;
  final LiveOrderSideCapacity? retainedCapacity;

  /// Conditional entries fill later at an unknown price; the design omits it.
  final bool showLiquidation;

  /// Replaces Long/Short, e.g. with hedge Open/Close actions.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), side = buy ? 'buy' : 'sell';
    final color = buy ? TradeColors.positive : TradeColors.negative;
    final quote = data.rules.quoteAsset,
        capacity = value?.capacity ?? retainedCapacity,
        cost = hasSize ? value?.cost : null;
    // Two-decimal display never understates cost or overstates the maximum.
    String? fixed(Decimal? amount) => amount == null
        ? null
        : TokenAmountFormatter.formatFixed(DecimalValue(amount.toString()), decimals: 2);
    final margin = cost == null
        ? null
        : Decimal.fromBigInt((cost.total * Rational.fromInt(100)).ceil()).shift(-2);
    final rows = [
      if (showLiquidation)
        (
          l.tradeEstimatedLiquidation,
          hasSize ? mainOrderLiquidationText(value, data) : null,
          quote,
          'liquidation',
        ),
      (l.tradeMargin, fixed(margin), quote, 'cost'),
      if (unit == OrderSizeUnit.quote)
        (l.accountsMax, fixed(capacity?.maximumQuote.floor(scale: 2)), quote, 'maximum')
      else
        (l.accountsMax, capacity?.maximum.toString(), data.rules.baseAsset, 'maximum'),
    ];
    return DirectionActionCard(
      key: Key('main-order-capacity-$side'),
      rows: [
        for (final (label, amount, asset, name) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TradeTypography.caption.copyWith(fontSize: 14, height: 20 / 14),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: resultsPending && (name == 'maximum' ? retainedCapacity == null : hasSize)
                      ? Align(
                          key: Key('main-order-$name-pending-$side'),
                          alignment: Alignment.centerRight,
                          child: const SkeletonBox(width: 72, height: 14),
                        )
                      : Text.rich(
                          key: Key('main-order-$name-$side'),
                          TextSpan(
                            children: [
                              TextSpan(
                                text: amount ?? '—',
                                style: TextStyle(color: amount == null ? TradeColors.text : color),
                              ),
                              if (amount != null) TextSpan(text: ' $asset'),
                            ],
                          ),
                          textAlign: TextAlign.end,
                          style: TradeTypography.caption.copyWith(
                            fontSize: 14,
                            height: 20 / 14,
                            color: TradeColors.text,
                          ),
                        ),
                ),
              ],
            ),
          ),
      ],
      button: FilledButton(
        key: Key('main-order-review-$side'),
        onPressed: pending ? null : onReview,
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          backgroundColor: color,
          foregroundColor: TradeColors.text,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          disabledBackgroundColor: color.withValues(alpha: .35),
          disabledForegroundColor: TradeColors.muted,
          shape: DirectionActionCard.buttonShape,
          textStyle: TradeTypography.body.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        ).copyWith(overlayColor: PressFeedback.overlay),
        child: pending
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: TradeColors.text),
              )
            : Text(label ?? (buy ? l.long : l.short)),
      ),
    );
  }
}
