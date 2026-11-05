import 'account_snapshot.dart';
import 'order_query.dart';
import 'live_order.dart';

class OrderRecoveryRecord {
  const OrderRecoveryRecord({required this.query, required this.createdAt});
  final OrderQuery query;
  final DateTime createdAt;
  String get key => query.key;
}

class OrderRecoverySnapshot {
  OrderRecoverySnapshot({
    Iterable<OrderRecoveryRecord> records = const [],
    this.ready = true,
    this.failure,
  }) : records = List.unmodifiable(records);
  final List<OrderRecoveryRecord> records;
  final bool ready;
  final AccountReadFailure? failure;
}

abstract interface class OrderRecoveryJournal {
  OrderRecoverySnapshot get snapshot;
  Stream<OrderRecoverySnapshot> get changes;
  Future<void> reload();
  Future<void> prepare(OrderRecoveryRecord record);
  Future<void> complete(String key);
  Future<void> close();
}

abstract interface class OrderRecoveryRepository {
  Future<LiveOrderResult> query(
    OrderQuery query, {
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
  });
}
