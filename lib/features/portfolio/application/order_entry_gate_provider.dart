import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import 'account_read_provider.dart';
import 'live_order_provider.dart';
import 'main_order_capacity_provider.dart';
import 'main_order_refresh_provider.dart';

enum OrderEntryGate { connect, deposit, ready }

/// Only the verified Aster business code establishes a deposit prerequisite.
final orderEntryGateProvider = Provider<OrderEntryGate>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.identity?.signingAvailable != true || auth.identity?.walletAddress == null) {
    return OrderEntryGate.connect;
  }
  final failures = [
    ref.watch(accountReadProvider).failure,
    ref.watch(liveOrderProvider).failure,
    ref.watch(liveOrderProvider).context?.fundsFailure,
    ref.watch(mainOrderCapacityProvider).failure,
    ref.watch(mainOrderRefreshProvider).failure,
  ];
  return failures.any((failure) => failure?.requiresDeposit == true)
      ? OrderEntryGate.deposit
      : OrderEntryGate.ready;
});
