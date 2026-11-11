import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../domain/account_snapshot.dart';
import '../domain/main_order_allocation.dart';
import '../domain/main_order_pricing.dart';
import 'live_order_provider.dart';
import 'main_order_allocation_provider.dart';
import 'main_order_capacity_provider.dart';
import 'main_order_pricing_provider.dart';
import 'main_order_refresh_provider.dart';
import 'symbol_settings_activity.dart';

typedef MainOrderReviewState = ({MainOrderAllocationReview? review, AccountReadFailure? failure});

/// Current confirmation values. Account renewal retains the dialog's last
/// displayed terms; fresh public receipts recalculate its raw input locally.
final mainOrderReviewProvider = Provider.autoDispose
    .family<MainOrderReviewState, MainOrderAllocationReview>((ref, original) {
      final live = ref.watch(liveOrderProvider);
      final capacity = ref.watch(mainOrderCapacityProvider);
      final refresh = ref.watch(mainOrderRefreshProvider);
      final prices = ref.watch(mainOrderPricingProvider);
      ref.watch(authProvider);
      ref.watch(mainOrderAllocationProvider);
      ref.watch(symbolSettingsActivityProvider);
      if (refresh.loading ||
          capacity.loading ||
          live.busy ||
          prices is MainOrderMarketData && prices.pending) {
        return (review: null, failure: null);
      }
      try {
        return (
          review: ref.read(mainOrderAllocationProvider.notifier).reprice(original),
          failure: null,
        );
      } on AccountReadFailure catch (failure) {
        return (
          review: null,
          // Expiry is renewed by the existing automatic account refresh.
          // A completed API failure still carries its concrete safe reason.
          failure:
              refresh.failure ??
              (const {'liveOrderContextExpired', 'liveCapacityStale'}.contains(failure.key)
                  ? null
                  : failure),
        );
      }
    });
