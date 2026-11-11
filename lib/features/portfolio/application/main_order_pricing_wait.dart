import '../../../core/errors/api_error_details.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account_snapshot.dart';
import '../domain/main_order_capacity.dart';
import '../domain/futures_asset_mode.dart';
import '../domain/main_order_pricing.dart';
import '../domain/main_order_revaluation.dart';
import 'main_order_pricing_provider.dart';

/// New signed facts can expand the price scope. Await those initial public
/// snapshots without another wallet prompt; cancellation never waits for HTTP.
class MainOrderPricingWait {
  MainOrderPricingWait(this.ref, this.snapshot, this.current, {this.notBefore});
  final DateTime? notBefore;
  final Ref ref;
  final MainOrderCapacitySnapshot snapshot;
  final bool Function() current;
  final _result = Completer<MainOrderRevaluation>();
  ProviderSubscription<MainOrderPricing>? _subscription;
  Timer? _deadline, _checkTimer;
  AccountReadFailure? _lastFailure;
  Future<MainOrderRevaluation> get future => _result.future;

  void start() {
    _subscription = ref.listen(mainOrderPricingProvider, (_, _) => _check());
    _deadline = Timer(const Duration(seconds: 30), () {
      if (!_result.isCompleted) {
        _result.completeError(
          _lastFailure ??
              const AccountReadFailure(
                'liveCapacityPriceUnavailable',
                details: ApiErrorDetails(cause: ApiErrorCause.timeout),
              ),
        );
      }
      _close();
    });
    // The form can change without producing a provider update.
    _checkTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => _check());
    _check();
  }

  void _check() {
    if (_result.isCompleted) return;
    if (!ref.mounted || !current()) {
      cancel();
      return;
    }
    // Read once: a later read can rebuild the provider and re-enter _check
    // through the listener, completing the result twice.
    final source = ref.read(mainOrderPricingProvider);
    if (_result.isCompleted) return;
    try {
      final value = source.revalue(snapshot);
      if (notBefore case final since? when source is MainOrderMarketData) {
        final scope = mainOrderPriceScope(snapshot.context, snapshot);
        bool recent(DateTime? time) => time != null && !time.isBefore(since);
        if (scope.marks.split(',').any((s) => !recent(source.marks.quotes[s]?.receivedAt)) ||
            scope.last.any((s) => !recent(source.references[s]?.trade?.receivedAt)) ||
            !recent(source.references[snapshot.context.symbol]?.book?.receivedAt) ||
            snapshot.assetMode == FuturesAssetMode.multi && !recent(source.indices?.receivedAt)) {
          return;
        }
      }
      _result.complete(value);
      _close();
    } on AccountReadFailure catch (failure) {
      _lastFailure = failure;
      // Initial public marks/quotes and multi-asset collateral rates may still
      // be in flight; keep waiting until they settle or the deadline expires.
      if (const {
            'liveCapacityPriceUnavailable',
            'liveCapacityRatesUnavailable',
          }.contains(failure.key) &&
          source is MainOrderMarketData &&
          source.pending &&
          source.active) {
        return;
      }
      _result.completeError(failure);
      _close();
    }
  }

  void cancel() {
    if (!_result.isCompleted) {
      _result.completeError(const AccountReadFailure('liveAllocationChanged'));
    }
    _close();
  }

  void _close() {
    _subscription?.close();
    _deadline?.cancel();
    _checkTimer?.cancel();
  }
}
