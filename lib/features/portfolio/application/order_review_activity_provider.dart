import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks open confirmations. Only the main form's live review permits its
/// background account renewal; other dedicated reviews keep fixed facts.
final orderReviewActivityProvider = NotifierProvider<OrderReviewActivity, int>(
  OrderReviewActivity.new,
);

class OrderReviewActivity extends Notifier<int> {
  @override
  int build() => 0;
  void begin() => state++;
  void end() {
    if (ref.mounted) state--;
  }
}
