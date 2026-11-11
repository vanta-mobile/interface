import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error_details.dart';
import '../../auth/application/auth_provider.dart';
import '../../market/application/selection_providers.dart';
import '../domain/account_snapshot.dart';
import '../domain/main_order_allocation.dart';
import '../domain/main_order_pricing.dart';
import 'live_order_provider.dart';
import 'main_order_allocation_provider.dart';
import 'main_order_capacity_provider.dart';
import 'main_order_pricing_provider.dart';
import 'main_order_refresh_provider.dart';
import 'main_order_review_provider.dart';

final mainOrderReviewSubmissionProvider =
    NotifierProvider<MainOrderReviewSubmissionController, bool>(
      MainOrderReviewSubmissionController.new,
    );

/// One user confirmation waits for current facts, then freezes one submission.
/// Polling may finish its current read but cannot start another during this wait.
class MainOrderReviewSubmissionController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> submit(MainOrderAllocationReview original) async {
    if (state) throw const AccountReadFailure('liveOrderSettingsBusy');
    state = true;
    final identity = ref.read(authProvider).identity;
    bool current() =>
        ref.mounted &&
        ref.read(authProvider).identity == identity &&
        !ref.read(authProvider).busy &&
        ref.read(symbolProvider) == original.intent.context.symbol;
    final completed = Completer<MainOrderAllocationReview>();
    var renewed = false;
    void inspect() {
      if (completed.isCompleted) return;
      if (!current()) {
        completed.completeError(const AccountReadFailure('authWalletChanged'));
        return;
      }
      final value = ref.read(mainOrderReviewProvider(original));
      final pricing = ref.read(mainOrderPricingProvider);
      if (value.review case final review?) {
        completed.complete(review);
      } else if (value.failure case final failure?) {
        completed.completeError(failure);
      } else if (!renewed &&
          !ref.read(mainOrderRefreshProvider).loading &&
          !ref.read(liveOrderProvider).busy &&
          !ref.read(mainOrderCapacityProvider).loading &&
          !(pricing is MainOrderMarketData && pricing.pending)) {
        // Expired facts are renewed on this click, including after background
        // suspension. The existing read path owns cancellation and timeouts.
        renewed = true;
        unawaited(
          ref
              .read(mainOrderRefreshProvider.notifier)
              .refresh(original.intent.context.symbol, reconnectPrices: false, background: true),
        );
      }
    }

    // Schedule inspections after notifications to avoid starting another read
    // or changing state from inside a provider's rebuild.
    void changed() => scheduleMicrotask(inspect);
    final subscriptions = [
      ref.listen(mainOrderReviewProvider(original), (_, _) => changed()),
      ref.listen(mainOrderRefreshProvider, (_, _) => changed()),
      ref.listen(authProvider, (_, _) => changed()),
      ref.listen(symbolProvider, (_, _) => changed()),
    ];
    void disposed() {
      if (!completed.isCompleted) {
        completed.completeError(const AccountReadFailure('authWalletChanged'));
      }
    }

    final removeDispose = ref.onDispose(disposed);
    final deadline = Timer(const Duration(seconds: 30), () {
      if (!completed.isCompleted) {
        completed.completeError(
          const AccountReadFailure(
            'accountNetwork',
            details: ApiErrorDetails(cause: ApiErrorCause.timeout),
          ),
        );
      }
    });
    try {
      inspect();
      final review = await completed.future;
      if (!current()) throw const AccountReadFailure('authWalletChanged');
      await ref.read(mainOrderAllocationProvider.notifier).submit(review);
    } finally {
      deadline.cancel();
      for (final subscription in subscriptions) {
        subscription.close();
      }
      if (ref.mounted) {
        removeDispose();
        state = false;
      }
    }
  }
}
