import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/request_scope.dart';
import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import '../../market/application/market_providers.dart';
import '../../market/application/selection_providers.dart';
import '../../trade/application/navigation_provider.dart';
import 'live_order_provider.dart';
import 'main_order_allocation_provider.dart';
import 'main_order_refresh_provider.dart';
import 'main_order_review_submission_provider.dart';
import 'order_review_activity_provider.dart';
import 'order_entry_gate_provider.dart';
import 'symbol_settings_activity.dart';

/// Renew signed reads before their 30-second deadline using the existing device
/// grant. An open main-order confirmation follows the renewed facts; signing
/// still freezes one submission. Never prompt a wallet or replay a write.
final automaticOrderRefreshProvider = Provider.autoDispose<void>((ref) {
  Timer? timer;
  Object? scope;
  DateTime? nextAttempt;
  var scheduled = false, refreshing = false, failures = 0;
  bool visible() =>
      ref.read(quoteUpdatesActiveProvider) &&
      ref.read(appDestinationProvider) == AppDestination.futures;

  void inspect() {
    if (scheduled) return;
    scheduled = true;
    scheduleMicrotask(() async {
      scheduled = false;
      if (!ref.mounted) return;
      if (!visible()) {
        timer?.cancel();
        timer = null;
        if (refreshing) ref.read(mainOrderRefreshProvider.notifier).stop();
        return;
      }
      final auth = ref.read(authProvider), identity = auth.identity;
      final agent = ref.read(tradingAgentProvider).asData?.value;
      final symbol = ref.read(symbolProvider);
      final key = (identity?.id, identity?.walletAddress?.toLowerCase(), agent?.address, symbol);
      if (scope != key) {
        scope = key;
        nextAttempt = null;
        failures = 0;
      }
      final activity = ref.read(symbolSettingsActivityProvider);
      final live = ref.read(liveOrderProvider);
      if (identity?.signingAvailable != true ||
          identity?.walletAddress == null ||
          agent?.status != TradingAgentStatus.active ||
          agent!.identityId != identity!.id ||
          agent.owner.toLowerCase() != identity.walletAddress!.toLowerCase() ||
          !agent.expiresAt.isAfter(ref.read(tradingAgentClockProvider)())) {
        timer?.cancel();
        timer = null;
        return;
      }
      timer ??= Timer.periodic(const Duration(seconds: 1), (_) => inspect());
      if (refreshing ||
          ref.read(mainOrderReviewSubmissionProvider) ||
          auth.busy ||
          auth.failure != null ||
          activity.owner != null ||
          activity.recoveryBlocked ||
          activity.unresolved ||
          live.busy ||
          ref.read(mainOrderAllocationProvider).preparing ||
          ref.read(orderReviewActivityProvider) > 0 &&
              ref.read(mainOrderAllocationProvider).review?.input == null ||
          ref.read(orderEntryGateProvider) != OrderEntryGate.ready ||
          ref.read(mainOrderRefreshProvider).loading) {
        return;
      }
      final now = ref.read(liveOrderClockProvider)();
      if (nextAttempt != null && now.isBefore(nextAttempt!)) return;
      final context = live.context;
      if (failures == 0 &&
          context?.symbol == symbol &&
          !live.stale &&
          now.difference(context!.receivedAt) < const Duration(seconds: 15)) {
        return;
      }
      refreshing = true;
      // Set the next slot before dispatch, so synchronous failures cannot spin.
      nextAttempt = now.add(const Duration(seconds: 5));
      // Provider notifications may arrive inside a completed read's zone.
      // This scheduled refresh owns a new lifetime; signed children still
      // inherit it and stop when its market/visibility/owner changes.
      final succeeded = await RequestScope.runOwned(
        () => ref.mounted && scope == key && visible() && refreshing,
        () => ref
            .read(mainOrderRefreshProvider.notifier)
            .refresh(symbol, reconnectPrices: false, background: true),
      );
      refreshing = false;
      if (!ref.mounted || scope != key) return;
      if (succeeded) {
        failures = 0;
        nextAttempt = ref.read(liveOrderClockProvider)().add(const Duration(seconds: 1));
      } else {
        failures = (failures + 1).clamp(1, 5);
        nextAttempt = ref.read(liveOrderClockProvider)().add(Duration(seconds: 2 << failures));
      }
    });
  }

  ref.listen(authProvider, (_, _) => inspect());
  ref.listen(tradingAgentProvider, (_, _) => inspect());
  ref.listen(symbolProvider, (_, _) => inspect());
  ref.listen(symbolSettingsActivityProvider, (_, _) => inspect());
  ref.listen(quoteUpdatesActiveProvider, (_, _) => inspect());
  ref.listen(appDestinationProvider, (_, _) => inspect());
  ref.listen(mainOrderRefreshProvider, (_, _) => inspect());
  ref.listen(liveOrderProvider, (_, _) => inspect());
  ref.listen(orderReviewActivityProvider, (_, _) => inspect());
  ref.listen(mainOrderReviewSubmissionProvider, (_, _) => inspect());
  ref.onCancel(() {
    if (refreshing) ref.read(mainOrderRefreshProvider.notifier).stop();
    timer?.cancel();
    timer = null;
  });
  ref.onResume(inspect);
  ref.onDispose(() => timer?.cancel());
  inspect();
});
