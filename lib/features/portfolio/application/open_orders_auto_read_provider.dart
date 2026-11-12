import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import '../domain/account_snapshot.dart';
import 'open_orders_provider.dart';
import 'wallet_account_controller.dart';
import 'order_cancellation_provider.dart';

/// Silently reads open orders with the active device trading grant while the
/// trade page or a standalone order tab is shown: once when no snapshot exists
/// and again when stream events mark it stale. Never prompts a wallet; a failure stops
/// automatic reads until the user retries.
final openOrdersAutoReadProvider = Provider.autoDispose<void>((ref) {
  autoReadWalletAccount(
    ref,
    openOrdersReadProvider,
    blocked: () {
      final cancellation = ref.read(orderCancellationProvider);
      return cancellation.busy || cancellation.needsRecheck;
    },
    triggers: [orderCancellationProvider],
  );
});

/// Keeps one signed snapshot current through the active device trading grant:
/// reads once when none exists and again when stream events mark it stale,
/// at most every [_minimumInterval]. Never prompts a wallet; a failure stops
/// automatic reads for that grant until a user-initiated read succeeds.
void autoReadWalletAccount<T extends WalletAccountSnapshot>(
  Ref ref,
  NotifierProvider<WalletAccountController<T>, AccountSnapshotState<T>> provider, {
  bool Function()? blocked,
  Iterable<ProviderListenable<Object?>> triggers = const [],
}) {
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
      final state = ref.read(provider);
      if (state.failure != null) {
        failedScope = scope;
        return;
      }
      if (failedScope == scope ||
          state.busy ||
          blocked?.call() == true ||
          (state.account != null && !state.stale)) {
        return;
      }
      // Full-account reads weigh 40; event bursts share one read slot.
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
      unawaited(ref.read(provider.notifier).refresh());
    });
  }

  ref.listen(authProvider, (_, _) => inspect());
  ref.listen(tradingAgentProvider, (_, _) => inspect());
  ref.listen(provider, (previous, next) {
    // A user-initiated read clears the failure and re-enables automatic reads.
    if (previous?.failure != null && next.failure == null) failedScope = null;
    inspect();
  });
  for (final trigger in triggers) {
    ref.listen(trigger, (_, _) => inspect());
  }
  inspect();
}

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
