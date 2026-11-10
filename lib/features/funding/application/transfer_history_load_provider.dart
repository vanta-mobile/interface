import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import '../../portfolio/application/account_read_provider.dart';
import 'transfer_history_provider.dart';

/// Opening history reads with an existing device grant; it never opens a wallet
/// or creates an authorization. The server response remains owner-scoped.
final transferHistoryLoadProvider = Provider.autoDispose<void>((ref) {
  final auth = ref.watch(authProvider);
  final agent = ref.watch(tradingAgentProvider).asData?.value;
  if (auth.busy || auth.needsWalletConnection || agent?.status != TradingAgentStatus.active) return;
  final identity = auth.identity!;
  scheduleMicrotask(() {
    if (!ref.mounted) return;
    final current = ref.read(authProvider);
    if (current.busy || current.identity != identity) return;
    final history = ref.read(transferHistoryProvider);
    if (history.busy ||
        history.failure?.requiresDeposit == true ||
        ref.read(accountReadProvider).failure?.requiresDeposit == true) {
      return;
    }
    final received = history.account?.receivedAt;
    if (received == null ||
        history.stale ||
        history.failure != null ||
        DateTime.now().toUtc().difference(received) >= const Duration(seconds: 30)) {
      unawaited(ref.read(transferHistoryProvider.notifier).refresh());
    }
  });
});
