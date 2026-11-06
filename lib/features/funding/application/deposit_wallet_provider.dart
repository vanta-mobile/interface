import '../../../core/network/network_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../data/deposit_rpc_service.dart';
import '../data/deposit_wallet_repository.dart';
import '../domain/deposit_wallet.dart';

final depositWalletRepositoryProvider = Provider.autoDispose<DepositWalletRepository>((ref) {
  final service = DepositRpcService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return RpcDepositWalletRepository(service);
});
final depositWalletProvider = NotifierProvider.autoDispose
    .family<
      DepositWalletController,
      AccountSnapshotState<DepositWalletSnapshot>,
      DepositWalletQuery
    >(DepositWalletController.new);

class DepositWalletController extends Notifier<AccountSnapshotState<DepositWalletSnapshot>> {
  DepositWalletController(this.query);
  final DepositWalletQuery query;
  int _generation = 0;
  Timer? _expiry;
  @override
  AccountSnapshotState<DepositWalletSnapshot> build() {
    ref.watch(depositWalletRepositoryProvider);
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

  Future<void> refresh() async {
    if (state.busy) return;
    final identity = ref.read(authProvider).identity;
    final address = identity?.walletAddress;
    if (identity == null || address == null) return;
    final generation = ++_generation;
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
      final snapshot = await ref
          .read(depositWalletRepositoryProvider)
          .read(address: address, query: query, isCurrent: current);
      if (!current()) return;
      if (snapshot.query != query || snapshot.address.toLowerCase() != address.toLowerCase()) {
        throw const AccountReadFailure('depositRpcInvalid');
      }
      state = AccountSnapshotState(
        account: snapshot,
        stale: snapshot.receivedAt.difference(snapshot.blockTime) > const Duration(minutes: 2),
      );
      _expiry?.cancel();
      _expiry = Timer(const Duration(seconds: 30), () {
        if (ref.mounted) {
          state = AccountSnapshotState(
            account: state.account,
            step: state.step,
            stale: state.account != null,
            failure: state.failure,
          );
        }
      });
    } catch (error) {
      if (!current()) return;
      state = AccountSnapshotState(
        account: state.account,
        stale: state.account != null,
        failure: error is AccountReadFailure ? error : const AccountReadFailure('depositRpcFailed'),
      );
    }
  }

  void stop() {
    if (!state.busy) return;
    _generation++;
    _expiry?.cancel();
    state = AccountSnapshotState(account: state.account, stale: state.account != null);
  }
}
