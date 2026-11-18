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

  /// Aster answered a dispatched write with an explicit client error code, so
  /// it was refused rather than executed. Timeouts, rate limits, redirects,
  /// 5xx and undecodable responses never qualify; display text is never read.
  bool get refusedWrite {
    final status = details?.status;
    return code != null &&
        status != null &&
        status >= 400 &&
        status < 500 &&
        status != 408 &&
        status != 418 &&
        status != 429;
  }

  /// A read was refused for missing permission, or no local grant is usable.
  /// This says nothing about the outcome or retry safety of a financial write.
  bool get requiresAuthorization =>
      key == 'accountPermissionRequired' ||
      key == 'authorizationRequired' ||
      key == 'builderAuthorizationRequired' ||
      key == 'builderApprovalUnknown';
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
