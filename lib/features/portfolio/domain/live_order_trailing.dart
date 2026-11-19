import 'package:decimal/decimal.dart';

import 'live_order_draft.dart';
import 'live_order_trigger.dart';

/// Exchange-managed trailing market execution, with a fixed requested quantity.
class LiveOrderTrailing {
  const LiveOrderTrailing({
    required this.callbackRate,
    this.activationPrice,
    this.basis = LiveOrderTriggerBasis.last,
  });
  final String callbackRate;
  final String? activationPrice;
  final LiveOrderTriggerBasis basis;

  /// The exchange's callback rate range, in percent, shared by the field and
  /// order validation.
  static bool acceptsCallbackRate(String text) {
    final rate = parseOrderDecimal(text.trim());
    return rate != null && rate >= Decimal.parse('0.1') && rate <= Decimal.fromInt(5);
  }
}
