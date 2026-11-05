class AccountReadFailure implements Exception {
  const AccountReadFailure(this.key, {this.code});
  final String key;
  final int? code;
}

abstract interface class WalletAccountSnapshot {
  String get address;
  DateTime get receivedAt;
}

enum AccountReadStep { idle, preparing, signing, loading }

class AccountSnapshotState<T extends WalletAccountSnapshot> {
  const AccountSnapshotState({
    this.account,
    this.step = AccountReadStep.idle,
    this.failure,
    this.stale = false,
  });
  final T? account;
  final AccountReadStep step;
  final AccountReadFailure? failure;
  final bool stale;
  bool get busy => step != AccountReadStep.idle;
}

abstract interface class WalletAccountRepository<T extends WalletAccountSnapshot> {
  Future<T> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  });
}
