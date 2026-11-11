import 'dart:async';

import '../domain/live_order.dart';
import '../domain/order_query.dart';
import '../domain/order_recovery.dart';

/// Best-effort diagnostics. Storage latency/failure never controls execution.
void recordOrderAttempt(OrderRecoveryJournal? journal, LiveOrderIntent intent, DateTime createdAt) {
  if (journal == null) return;
  unawaited(_record(journal, intent, createdAt));
}

Future<void> _record(
  OrderRecoveryJournal journal,
  LiveOrderIntent intent,
  DateTime createdAt,
) async {
  try {
    await journal.prepare(
      OrderRecoveryRecord(query: OrderQuery.capture(intent), createdAt: createdAt),
    );
  } catch (_) {
    // The journal reports its own diagnostic state; do not fail the order.
  }
}

void completeOrderRecord(OrderRecoveryJournal? journal, String key) {
  if (journal == null) return;
  unawaited(_complete(journal, key));
}

Future<void> _complete(OrderRecoveryJournal journal, String key) async {
  try {
    await journal.complete(key);
  } catch (_) {
    // Retain the record for later inspection without delaying the result.
  }
}
