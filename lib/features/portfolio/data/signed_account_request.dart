import '../../../core/network/request_scope.dart';
import '../domain/aster_signature.dart';
export '../domain/aster_signature.dart';
import '../../auth/domain/auth_session.dart';
import '../domain/account_snapshot.dart';
import '../domain/account_request_signing.dart';
export '../domain/account_request_signing.dart';

/// Shared by Perp, Spot and funding for the same connected signer.
class AsterReadNonces {
  int _last = 0;

  int next(int serverMilliseconds) {
    if (serverMilliseconds <= 0 || serverMilliseconds > 9223372036854775) {
      throw const FormatException();
    }
    // V3 validates microseconds, including /aster funding endpoints. The
    // funding demo's nanosecond description conflicts with the live API.
    final candidate = serverMilliseconds * 1000;
    if (_last == 9223372036854775807) throw const FormatException();
    _last = candidate > _last ? candidate : _last + 1;
    return _last;
  }
}

class SignedAccountRequest {
  SignedAccountRequest({
    required this.serverTime,
    required this.send,
    required this.sign,
    this.authorization,
    AsterReadNonces? nonces,
    this.signatureLifetime = const Duration(seconds: 50),
  }) : nonces = nonces ?? AsterReadNonces();
  final Future<int> Function() serverTime;
  final Future<Object?> Function({required String query, required String signature}) send;
  final AccountRequestSigner sign;
  final AccountRequestAuthorization? authorization;
  final AsterReadNonces nonces;
  final Duration signatureLifetime;

  Future<Object?> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
    Map<String, String> parameters = const {},
  }) => RequestScope.run(isCurrent, () async {
    AccountRequestIdentity? signing;
    void check() {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    }

    try {
      check();
      if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address)) {
        throw const AccountReadFailure('authWalletChanged');
      }
      if (parameters.keys.any({'user', 'signer', 'nonce', 'signature'}.contains)) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      onStep(AccountReadStep.preparing);
      signing = authorization == null
          ? AccountRequestIdentity(address: address, sign: sign)
          : await authorization!(address);
      check();
      final serverMilliseconds = await serverTime();
      check();
      final nonce = nonces.next(serverMilliseconds);
      // Freeze the exact query once: the bytes signed must match the bytes
      // transmitted. user always remains the account owner; signer can be the
      // separately authorized device agent. Never fall back after rejection.
      final query = Uri(
        queryParameters: {
          ...parameters,
          'nonce': '$nonce',
          'user': address,
          'signer': signing.address,
        },
      ).query;
      final started = Stopwatch()..start();
      onStep(AccountReadStep.signing);
      final signature = await signing.sign(
        expectedAddress: signing.address,
        typedData: asterReadTypedData(query),
      );
      check();
      if (started.elapsed >= signatureLifetime) {
        throw const AccountReadFailure('accountSignatureExpired');
      }
      onStep(AccountReadStep.loading);
      final payload = await send(query: query, signature: signature);
      check();
      return payload;
    } on AccountReadFailure catch (failure) {
      if (isCurrent() &&
          (failure.key == 'accountPermissionRequired' ||
              failure.key == 'accountSignatureRejected')) {
        try {
          await signing?.onRejected?.call();
        } catch (_) {
          // Preserve the server error. The next request still checks the grant.
        }
      }
      rethrow;
    } on AuthFailure catch (failure) {
      throw AccountReadFailure(failure.key);
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    } catch (_) {
      throw const AccountReadFailure('accountReadFailed');
    }
  });
}
