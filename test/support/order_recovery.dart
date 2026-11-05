import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';

/// Old journal fields, for migration tests. Legacy exits were always market
/// and only driven by FILLED. Do not reinterpret them as today's defaults.
Map<String, Object?> legacyRecoveryFields(Map<String, Object?> current) {
  final row = jsonDecode(jsonEncode(current)) as Map<String, dynamic>;
  final attachment = (row['draft'] as Map)['attachment'] as Map?;
  if (attachment != null) {
    attachment.remove('drivenOn');
    for (final key in ['takeProfit', 'stopLoss']) {
      (attachment[key] as Map?)?.remove('execution');
      (attachment[key] as Map?)?.remove('limitPrice');
    }
  }
  return row;
}

class TestOrderRecoveryRepository implements OrderRecoveryRepository {
  TestOrderRecoveryRepository(this.journal);
  final OrderRecoveryJournal journal;
  int calls = 0;
  OrderQuery? latestQuery;
  Completer<void>? gate;
  LiveOrderResult result = LiveOrderResult(
    orderId: '12345',
    status: 'NEW',
    executedQuantity: Decimal.zero,
  );
  @override
  Future<LiveOrderResult> query(
    OrderQuery query, {
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
  }) async {
    calls++;
    latestQuery = query;
    onStep(LiveOrderStep.checkSigning);
    await gate?.future;
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    if (!result.needsRecheck) await journal.complete(query.key);
    return result;
  }
}
