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
}
