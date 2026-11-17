import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../market/application/market_providers.dart';
import 'account_read_provider.dart';
import 'batch_close_provider.dart';
import 'open_orders_auto_read_provider.dart';
import 'open_orders_provider.dart';
import 'position_risk_provider.dart';

/// Read the shared positions snapshot on trade-page entry so its tab count is
/// current before the tab is opened. Also used by standalone position sections.
final positionRiskAutoReadProvider = Provider.autoDispose<void>((ref) {
  // Exchange-side fills, such as a triggered trailing stop, send no signal
  // without account events; while shown with the device grant, positions and
  // open orders are re-read quietly at this interval.
  Timer? renewal;
  void schedule() {
    if (activeTradingGrant(ref) == null) {
      renewal?.cancel();
      renewal = null;
      return;
    }
    renewal ??= Timer.periodic(_renewalInterval, (_) {
      if (!ref.read(quoteUpdatesActiveProvider) || activeTradingGrant(ref) == null) return;
      ref.read(positionRiskProvider.notifier).markStale();
      ref.read(openOrdersReadProvider.notifier).markStale();
    });
  }

  ref.onDispose(() => renewal?.cancel());
  ref.listen(authProvider, (_, _) => schedule());
  ref.listen(tradingAgentProvider, (_, _) => schedule());
  schedule();
  autoReadWalletAccount(
    ref,
    positionRiskProvider,
    blocked: () => ref.read(batchCloseProvider).busy,
    triggers: [batchCloseProvider],
  );
});

/// The visible Positions tab also needs account totals for cross margin and
/// open orders for TP/SL rows. Share the page's read owners to avoid duplicates.
/// Never prompts a wallet, and pauses account reads during a batch close.
final positionsAutoReadProvider = Provider.autoDispose<void>((ref) {
  ref.watch(positionRiskAutoReadProvider);
  ref.watch(openOrdersAutoReadProvider);
  bool closing() => ref.read(batchCloseProvider).busy;
  autoReadWalletAccount(ref, accountReadProvider, blocked: closing, triggers: [batchCloseProvider]);
});

const _renewalInterval = Duration(seconds: 15);
