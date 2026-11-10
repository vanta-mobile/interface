import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/domain/aster_account.dart';
import '../data/subaccount_balance_repository.dart';
import 'account_entries_provider.dart';
import 'generated_subaccount_provider.dart';

final subaccountBalanceRepositoryProvider = Provider.autoDispose<SubaccountBalanceReader>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SubaccountBalanceRepository(
    service,
    ref.watch(subaccountWalletStoreProvider),
    ref.watch(asterReadNoncesProvider),
  );
});

class AccountBalancesState {
  AccountBalancesState({
    Map<String, AsterAccount> accounts = const {},
    Map<String, AccountReadFailure> failures = const {},
    this.busy = false,
    this.stale = false,
  }) : accounts = Map.unmodifiable(accounts),
       failures = Map.unmodifiable(failures);
  final Map<String, AsterAccount> accounts;
  final Map<String, AccountReadFailure> failures;
  final bool busy, stale;
}

final accountBalancesProvider =
    NotifierProvider.autoDispose<AccountBalancesController, AccountBalancesState>(
      AccountBalancesController.new,
    );

class AccountBalancesController extends Notifier<AccountBalancesState> {
  int _revision = 0;
  Timer? _expiry;
  Future<void>? _pending;
  @override
  AccountBalancesState build() {
    ref.watch(subaccountBalanceRepositoryProvider);
    ref.watch(
      authProvider.select(
        (s) => (s.identity?.id, s.identity?.walletAddress, s.identity?.signingAvailable),
      ),
    );
    ref.listen(accountEntriesProvider, (before, after) {
      final oldAddresses = before?.map((e) => e.address.toLowerCase()).join(',');
      if (oldAddresses != after.map((e) => e.address.toLowerCase()).join(',')) _restart();
    });
    ref.listen(generatedWalletsProvider, (before, after) {
      if (after.hasValue && !identical(before?.value, after.value)) _restart();
    });
    _revision++;
    _expiry?.cancel();
    _pending = null;
    ref.onDispose(() {
      _revision++;
      _expiry?.cancel();
    });
    // These reads use already backed-up device keys and never open an external wallet.
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(refresh());
    });
    return AccountBalancesState();
  }

  void _restart() {
    _revision++;
    _pending = null;
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(refresh());
    });
  }

  Future<void> refresh() {
    if (_pending != null) return _pending!;
    final task = _refresh();
    _pending = task;
    return task.whenComplete(() {
      if (identical(_pending, task)) _pending = null;
    });
  }

  Future<void> _refresh() async {
    final revision = ++_revision;
    bool current() => ref.mounted && revision == _revision;
    final entries = ref.read(accountEntriesProvider);
    final owner = ref.read(activeAccountEntryProvider)?.owner.toLowerCase();
    state = AccountBalancesState(accounts: state.accounts, busy: true, stale: state.stale);
    final accounts = {...state.accounts}, failures = <String, AccountReadFailure>{};
    try {
      final wallets = await ref.read(generatedWalletsProvider.future);
      if (!current()) return;
      for (final wallet in wallets.where(
        (w) =>
            w.backedUp &&
            w.owner.toLowerCase() == owner &&
            entries.any(
              (e) => e.roleKnown && !e.main && e.address.toLowerCase() == w.address.toLowerCase(),
            ),
      )) {
        if (!current()) return;
        final key = wallet.address.toLowerCase();
        try {
          accounts[key] = await ref.read(subaccountBalanceRepositoryProvider).read(wallet, current);
        } catch (e) {
          failures[key] = e is AccountReadFailure
              ? e
              : const AccountReadFailure('accountReadFailed');
        }
      }
    } catch (_) {
      // The wallet store has its own existing error UI; never expose key payloads.
    }
    if (!current()) return;
    state = AccountBalancesState(
      accounts: accounts,
      failures: failures,
      stale: failures.isNotEmpty,
    );
    _expiry?.cancel();
    _expiry = Timer(const Duration(seconds: 30), () {
      if (current()) {
        state = AccountBalancesState(
          accounts: state.accounts,
          failures: state.failures,
          stale: true,
        );
      }
    });
  }
}
