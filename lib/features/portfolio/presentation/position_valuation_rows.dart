import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/position_mark_prices_provider.dart';
import '../application/position_risk_provider.dart';
import '../domain/position_risk.dart';
import '../../market/domain/mark_prices.dart';

/// The public mark that may replace [p]'s snapshot values, with its freshness.
/// A newer private snapshot takes precedence until another public price is
/// received; a retained mark must not silently roll it back after refresh.
(MarkPriceQuote?, bool) watchPositionMark(WidgetRef ref, PositionRisk p) {
  final mark = ref.watch(
    positionMarkPricesProvider.select(
      (s) => (s.value?.quotes[p.symbol], s.value?.fresh.contains(p.symbol) == true),
    ),
  );
  final received = ref.watch(positionRiskProvider.select((s) => s.account?.receivedAt));
  final quote =
      p.balanceOnly ||
          received == null ||
          mark.$1 == null ||
          mark.$1!.receivedAt.isBefore(received) ||
          p.eventTime != null && p.updatedAt != null && mark.$1!.eventTime.isBefore(p.updatedAt!)
      ? null
      : mark.$1;
  return (quote, mark.$2);
}
