import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../market/application/selection_providers.dart';
import '../../trade/application/navigation_provider.dart';
import '../domain/order_form_prefill.dart';

/// Pending order-form inputs for the main futures form. The form applies them
/// once, only to its own market and only while the user has typed nothing.
final orderFormPrefillProvider = NotifierProvider<OrderFormPrefillController, OrderFormPrefill?>(
  OrderFormPrefillController.new,
);

class OrderFormPrefillController extends Notifier<OrderFormPrefill?> {
  @override
  OrderFormPrefill? build() {
    // Leaving the market or the futures page abandons a suggestion not yet applied.
    ref.listen(symbolProvider, (_, next) {
      if (state != null && state!.symbol != next) state = null;
    });
    ref.listen(appDestinationProvider, (_, next) {
      if (next != AppDestination.futures) state = null;
    });
    return null;
  }

  void propose(OrderFormPrefill prefill) => state = prefill.isEmpty ? null : prefill;

  void clear() => state = null;
}
