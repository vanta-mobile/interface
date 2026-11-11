import 'account_snapshot.dart';
import 'live_order.dart';
import 'live_order_capacity.dart';

/// Preserve exact capacity and units for the existing maximum-amount feedback.
class MainOrderCapacityExceeded extends AccountReadFailure {
  const MainOrderCapacityExceeded({required this.capacity, required this.context})
    : super('liveCapacityAboveMaximum');
  final LiveOrderSideCapacity capacity;
  final LiveOrderContext context;
}
