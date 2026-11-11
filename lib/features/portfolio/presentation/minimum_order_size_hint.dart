import 'package:flutter/widgets.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/live_order.dart';
import '../domain/live_order_size.dart';
import '../domain/minimum_order_size.dart';

String? minimumOrderSizeHint(
  BuildContext context, {
  required LiveOrderContext? data,
  required LiveOrderDraft draft,
  required OrderSizeUnit unit,
  bool bothDirections = false,
}) {
  if (data == null) return null;
  final minimum = minimumOrderSize(
    context: data,
    draft: draft,
    unit: unit,
    bothDirections: bothDirections,
  );
  if (minimum == null) return null;
  // An editable threshold must retain every digit; adaptive rounding could
  // advertise an input that floors below the actual minimum quantity step.
  final text = TokenAmountFormatter.formatFixed(DecimalValue('$minimum'), decimals: minimum.scale);
  return AppLocalizations.of(context).liveOrderMinimumPlaceholder(text);
}
