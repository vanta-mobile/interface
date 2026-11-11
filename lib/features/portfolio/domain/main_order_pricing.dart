import '../../market/domain/mark_prices.dart';
import '../../market/domain/order_reference_prices.dart';
import 'account_snapshot.dart';
import 'asset_valuation.dart';
import 'live_order.dart';
import 'main_order_capacity.dart';
import 'main_order_revaluation.dart';

/// Pricing boundary shared by previews, text conversion and the last send
/// guard. Calling it rechecks receipt ages with the clock, not a cached flag.
abstract interface class MainOrderPricing {
  LiveOrderContext priceContext(LiveOrderContext anchor);
  MainOrderRevaluation revalue(MainOrderCapacitySnapshot snapshot);
}

class MainOrderMarketData implements MainOrderPricing {
  MainOrderMarketData({
    required this.anchor,
    required this.marks,
    required Map<String, OrderReferencePrices> references,
    required this.indices,
    required this.active,
    required this.now,
    this.pending = false,
    this.failure,
  }) : references = Map.unmodifiable(references);
  final LiveOrderContext? anchor;
  final MarkPrices marks;
  final Map<String, OrderReferencePrices> references;
  final AssetIndexSnapshot? indices;
  final bool active;
  final bool pending;
  final AccountReadFailure? failure;
  final DateTime Function() now;

  void _check(LiveOrderContext context) {
    if (failure != null) throw failure!;
    if (!active || context != anchor) {
      throw const AccountReadFailure(
        'liveCapacityPriceUnavailable',
        reasonKey: 'livePriceDisconnected',
      );
    }
    final age = now().difference(context.receivedAt);
    if (age.isNegative || age >= const Duration(seconds: 30)) {
      throw const AccountReadFailure('liveOrderContextExpired');
    }
  }

  @override
  LiveOrderContext priceContext(LiveOrderContext context) {
    _check(context);
    return mainOrderPriceContext(
      context: context,
      marks: marks,
      reference: references[context.symbol],
      now: now(),
    );
  }

  @override
  MainOrderRevaluation revalue(MainOrderCapacitySnapshot snapshot) {
    _check(snapshot.context);
    return revalueMainOrderCapacity(
      snapshot: snapshot,
      marks: marks,
      references: references,
      indices: indices,
      now: now(),
    );
  }
}
