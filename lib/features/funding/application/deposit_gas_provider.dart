import '../../../core/network/network_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../data/deposit_rpc_service.dart';
import '../data/deposit_gas_repository.dart';
import '../domain/deposit_wallet.dart';
import '../domain/deposit_transaction.dart';
import '../domain/deposit_quote_validation.dart';

final depositGasClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final depositGasRepositoryProvider = Provider.autoDispose<DepositGasRepository>((ref) {
  final service = DepositRpcService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return RpcDepositGasRepository(service, now: ref.watch(depositGasClockProvider));
});
final depositGasProvider = NotifierProvider.autoDispose
    .family<DepositGasController, AccountSnapshotState<DepositGasQuote>, DepositWalletQuery>(
      DepositGasController.new,
    );

class DepositGasController extends Notifier<AccountSnapshotState<DepositGasQuote>> {
  DepositGasController(this.query);
  final DepositWalletQuery query;
  int _generation = 0;
  Timer? _expiry;
  DateTime get _now => ref.read(depositGasClockProvider)().toUtc();
  @override
  AccountSnapshotState<DepositGasQuote> build() {
    ref.watch(depositGasRepositoryProvider);
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (before, after) {
        if (before == after) return;
        _generation++;
        _expiry?.cancel();
        state = const AccountSnapshotState();
      },
    );
    ref.onDispose(() {
      _generation++;
      _expiry?.cancel();
    });
    return const AccountSnapshotState();
  }

  Future<void> estimate(String amount) async {
    final auth = ref.read(authProvider), identity = ref.read(authProvider).identity;
    final address = identity?.walletAddress;
    if (state.busy || auth.busy || address == null || identity == null) return;
    final generation = ++_generation;
    _expiry?.cancel();
    bool current() =>
        ref.mounted &&
        generation == _generation &&
        ref.read(authProvider).identity?.id == identity.id &&
        ref.read(authProvider).identity?.walletAddress == address;
    state = AccountSnapshotState(
      account: state.account,
      step: AccountReadStep.loading,
      stale: state.account != null,
    );
    try {
      final quote = await ref
          .read(depositGasRepositoryProvider)
          .estimate(address: address, query: query, amount: amount, isCurrent: current);
      if (!current()) return;
      validatedDepositQuote(
        quote: quote,
        address: address,
        query: query,
        amount: amount,
        now: _now,
      );
      state = AccountSnapshotState(account: quote);
      _expiry = Timer(depositQuoteDeadline(quote).difference(_now), () {
        if (ref.mounted) {
          state = AccountSnapshotState(
            account: state.account,
            stale: true,
            step: state.step,
            failure: state.failure,
          );
        }
      });
    } catch (error) {
      if (current()) {
        state = AccountSnapshotState(
          account: state.account,
          stale: state.account != null,
          failure: error is AccountReadFailure
              ? error
              : const AccountReadFailure('depositRpcFailed'),
        );
      }
    }
  }

  void stop() {
    if (!ref.mounted || !state.busy) return;
    _generation++;
    _expiry?.cancel();
    state = AccountSnapshotState(account: state.account, stale: state.account != null);
  }
}
