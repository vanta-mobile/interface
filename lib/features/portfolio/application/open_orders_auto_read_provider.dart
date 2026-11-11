import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import 'open_orders_provider.dart';
import 'order_cancellation_provider.dart';

/// Silently reads open orders with the active device trading grant while the
/// trade page's order tab is shown: once when no snapshot exists and again
/// when stream events mark it stale. Never prompts a wallet; a failure stops
/// automatic reads until the user retries.
final openOrdersAutoReadProvider = Provider.autoDispose<void>((ref) {
  Object? failedScope;
  DateTime? lastRead;
  Timer? deferred;
  var scheduled = false;
  ref.onDispose(() => deferred?.cancel());

  void inspect() {
    if (scheduled) return;
    scheduled = true;
    scheduleMicrotask(() {
      scheduled = false;
      if (!ref.mounted) return;
      final grant = activeTradingGrant(ref);
      if (grant == null) return;
      final scope = grant;
      final state = ref.read(openOrdersReadProvider);
      final cancellation = ref.read(orderCancellationProvider);
      if (state.failure != null) {
        failedScope = scope;
        return;
      }
      if (failedScope == scope ||
          state.busy ||
          cancellation.busy ||
          cancellation.needsRecheck ||
          (state.account != null && !state.stale)) {
        return;
      }
      // The full-account read weighs 40; event bursts share one read slot.
      final now = DateTime.now();
      final wait = lastRead == null ? Duration.zero : _minimumInterval - now.difference(lastRead!);
      if (wait > Duration.zero) {
        deferred ??= Timer(wait, () {
          deferred = null;
          inspect();
        });
        return;
      }
      lastRead = now;
      unawaited(ref.read(openOrdersReadProvider.notifier).refresh());
    });
  }

  ref.listen(authProvider, (_, _) => inspect());
  ref.listen(tradingAgentProvider, (_, _) => inspect());
  ref.listen(openOrdersReadProvider, (previous, next) {
    // A user-initiated read clears the failure and re-enables automatic reads.
    if (previous?.failure != null && next.failure == null) failedScope = null;
    inspect();
  });
  ref.listen(orderCancellationProvider, (_, _) => inspect());
  inspect();
});

const _minimumInterval = Duration(seconds: 5);

/// Identity, owner and agent of an active, unexpired device trading grant, or
/// null. Reads signed under this grant never prompt the wallet.
(String, String, String)? activeTradingGrant(Ref ref) {
  final auth = ref.read(authProvider), identity = auth.identity;
  final agent = ref.read(tradingAgentProvider).asData?.value;
  if (auth.busy ||
      identity?.signingAvailable != true ||
      identity?.walletAddress == null ||
      agent?.status != TradingAgentStatus.active ||
      agent!.identityId != identity!.id ||
      agent.owner.toLowerCase() != identity.walletAddress!.toLowerCase() ||
      !agent.expiresAt.isAfter(ref.read(tradingAgentClockProvider)())) {
    return null;
  }
  return (identity.id, identity.walletAddress!.toLowerCase(), agent.address);
}
