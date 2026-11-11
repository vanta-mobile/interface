import '../../../core/errors/api_error_details.dart';

class AccountReadFailure implements Exception, DetailedApiFailure {
  const AccountReadFailure(this.key, {this.code, this.details, this.reasonKey});
  @override
  final ApiErrorDetails? details;
  final String key;

  /// Concrete localized cause; the stable key still controls recovery behavior.
  final String? reasonKey;
  final int? code;

  /// Aster confirms that the exchange account has not been created by a deposit.
  /// Neither a zero balance nor the displayed server text proves this status.
  bool get requiresDeposit => code == -5050;
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
