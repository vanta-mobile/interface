import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import '../domain/order_query.dart';
import '../domain/order_recovery.dart';

Future<void> persistOrderBeforePost(
  OrderRecoveryJournal? journal,
  LiveOrderIntent intent,
  DateTime createdAt,
  bool Function() canSubmit,
) async {
  if (journal == null) return;
  final query = OrderQuery.capture(intent);
  await journal.prepare(OrderRecoveryRecord(query: query, createdAt: createdAt));
  // Disk I/O can outlive the confirmation. Refuse the send if it did.
  if (!canSubmit()) {
    await journal.complete(query.key);
    throw const AccountReadFailure('liveOrderContextExpired');
  }
}
