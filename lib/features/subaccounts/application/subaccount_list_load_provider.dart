import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import 'account_entries_provider.dart';
import 'subaccount_list_provider.dart';

/// Only an active device grant may read the directory on page entry; the
/// owner wallet is never prompted by navigation. Without a grant the page
/// keeps its explicit read action.
final subaccountListAutoLoadProvider = Provider.autoDispose<bool>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.busy || auth.needsWalletConnection) return false;
  if (!ref.watch(canInspectAccountsProvider)) return false;
  return ref.watch(tradingAgentProvider).asData?.value?.status == TradingAgentStatus.active;
});

final subaccountListLoadProvider = Provider.autoDispose<void>((ref) {
  if (!ref.watch(subaccountListAutoLoadProvider)) return;
  final identity = ref.read(authProvider).identity!;
  scheduleMicrotask(() {
    if (!ref.mounted) return;
    final current = ref.read(authProvider).identity;
    if (current?.id != identity.id || current?.walletAddress != identity.walletAddress) return;
    final directory = ref.read(subaccountListProvider);
    // A failed read stays visible until the user refreshes; never loop on it.
    if (!directory.busy && directory.account == null && directory.failure == null) {
      unawaited(ref.read(subaccountListProvider.notifier).refresh());
    }
  });
});
