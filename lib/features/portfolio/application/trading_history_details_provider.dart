import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/request_scope.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import 'trading_history_access_provider.dart';
import '../domain/trading_history.dart';
import 'trading_history_provider.dart';

class HistoryOrderDetails {
  HistoryOrderDetails(Iterable<HistoryFill> fills, {required this.complete})
    : fills = List.unmodifiable(fills);
  final List<HistoryFill> fills;
  final bool complete;
  Decimal? get realizedPnl => !complete || fills.any((f) => f.realizedPnl == null)
      ? null
      : fills.fold<Decimal>(Decimal.zero, (sum, f) => sum + f.realizedPnl!);
  String? get feeAsset => fills.isEmpty || fills.any((f) => f.feeAsset != fills.first.feeAsset)
      ? null
      : fills.first.feeAsset;
  Decimal? get fee => !complete || feeAsset == null
      ? null
      : fills.fold<Decimal>(Decimal.zero, (sum, f) => sum - f.fee);
}

/// Exact symbol + order ID linkage only. Bound scanning, report incomplete data,
/// and never infer maker/taker from active_buy or aggregate unlike fee units.
final tradingOrderDetailsProvider = FutureProvider.autoDispose
    .family<HistoryOrderDetails?, HistoryOrder>(retry: (_, _) => null, (ref, order) async {
      final session = ref.watch(tradingHistoryAccessProvider(TradingHistoryTab.orders));
      final owner = ref.watch(tradingHistoryIdentityProvider);
      final repository = ref.watch(tradingOrderFillsRepositoryProvider);
      if (!session.ready || session.address == null) return null;
      if (order.executed == Decimal.zero) return HistoryOrderDetails(const [], complete: true);
      bool current() =>
          ref.mounted &&
          ref.read(tradingHistoryIdentityProvider) == owner &&
          ref.read(tradingHistoryAccessProvider(TradingHistoryTab.orders)).ready;
      return RequestScope.runOwned(current, () async {
        final fills = <String, HistoryFill>{};
        final seen = <String>{};
        TradingHistoryCursor? cursor;
        var complete = false;
        for (var pageIndex = 0; pageIndex < 20; pageIndex++) {
          final page = await repository.readOrderFills(
            order,
            address: session.address!,
            cursor: cursor,
          );
          if (!current()) throw const VantaApiFailure(vantaApiRequestFailed);
          if (page.address != session.address) throw const VantaApiFailure(vantaApiDataInvalid);
          for (final fill in page.records.whereType<HistoryFill>()) {
            if (fill.symbol == order.symbol && fill.orderId == order.id) fills[fill.key] = fill;
          }
          final quantity = fills.values.fold(Decimal.zero, (sum, f) => sum + f.quantity);
          if (quantity > order.executed) throw const VantaApiFailure(vantaApiDataInvalid);
          if (quantity == order.executed) {
            complete = true;
            break;
          }
          cursor = page.next;
          if (cursor == null) break;
          if (cursor.main == null || !seen.add(cursor.main!)) {
            throw const VantaApiFailure(vantaApiDataInvalid);
          }
        }
        final sorted = fills.values.toList()..sort((a, b) => b.time.compareTo(a.time));
        return HistoryOrderDetails(sorted, complete: complete);
      });
    });
