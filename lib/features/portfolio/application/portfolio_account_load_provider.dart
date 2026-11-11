import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import 'account_read_provider.dart';
import 'portfolio_overview_provider.dart';

/// Only an active device grant may trigger a read on page entry. No wallet
/// prompt, grant creation or financial write is performed by navigation.
final portfolioAccountLoadProvider = Provider.autoDispose<void>((ref) {
  if (ref.watch(portfolioPreviewProvider)) return;
  final auth = ref.watch(authProvider);
  if (auth.busy || auth.needsWalletConnection) return;
  final agent = ref.watch(tradingAgentProvider).asData?.value;
  if (agent?.status != TradingAgentStatus.active) return;
  final identity = auth.identity!;
  scheduleMicrotask(() {
    if (!ref.mounted || ref.read(portfolioPreviewProvider)) return;
    final current = ref.read(authProvider);
    if (current.busy ||
        current.needsWalletConnection ||
        current.identity?.id != identity.id ||
        current.identity?.walletKind != identity.walletKind ||
        current.identity?.walletAddress != identity.walletAddress) {
      return;
    }
    final account = ref.read(accountReadProvider);
    // Keep this owner-scoped result until an explicit refresh checks again.
    // Navigation must not repeatedly query an account Aster says is uncreated.
    if (account.failure?.requiresDeposit == true) return;
    if (!account.busy && (account.account == null || account.stale || account.failure != null)) {
      unawaited(ref.read(portfolioRefreshProvider)());
    }
  });
});
