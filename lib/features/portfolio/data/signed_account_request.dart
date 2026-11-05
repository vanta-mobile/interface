import '../domain/aster_signature.dart';
export '../domain/aster_signature.dart';
import '../../auth/domain/auth_session.dart';
import '../domain/account_snapshot.dart';

typedef AccountRequestSigner = Future<String> Function({
  required String expectedAddress,
  required Map<String, Object?> typedData,
});

/// Shared by Perp and Spot for the same connected signer.
class AsterReadNonces {
  int _last = 0;
  int _lastNanoseconds = 0;
  int next(int serverMilliseconds) {
    final candidate = serverMilliseconds * 1000;
    _last = candidate > _last ? candidate : _last + 1;
    return _last;
  }

  /// The separate funding V3 document uses milliseconds × 1,000,000.
  /// Keep its counter separate from the microsecond trading protocol.
  int nextNanoseconds(int serverMilliseconds) {
    if (serverMilliseconds <= 0 || serverMilliseconds > 9223372036854) {
      throw const FormatException();
    }
    final candidate = serverMilliseconds * 1000000;
    _lastNanoseconds = candidate > _lastNanoseconds ? candidate : _lastNanoseconds + 1;
    return _lastNanoseconds;
  }
}

class SignedAccountRequest {
  SignedAccountRequest({
    required this.serverTime,
    required this.send,
    required this.sign,
    AsterReadNonces? nonces,
    this.nanosecondNonce = false,
    this.signatureLifetime = const Duration(seconds: 50),
  }) : nonces = nonces ?? AsterReadNonces();
  final Future<int> Function() serverTime;
  final Future<Object?> Function({required String query, required String signature}) send;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final bool nanosecondNonce;
  final Duration signatureLifetime;

  Future<Object?> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
    Map<String, String> parameters = const {},
  }) async {
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
      final serverMilliseconds = await serverTime();
      check();
      final nonce = nanosecondNonce
          ? nonces.nextNanoseconds(serverMilliseconds)
          : nonces.next(serverMilliseconds);
      // Freeze the exact query once: the bytes signed must match the bytes
      // transmitted. The connected wallet is both user and signer; an Aster
      // authorization rejection is surfaced, never bypassed with another key.
      final query = Uri(
        queryParameters: {...parameters, 'nonce': '$nonce', 'user': address, 'signer': address},
      ).query;
      final started = Stopwatch()..start();
      onStep(AccountReadStep.signing);
      final signature = await sign(expectedAddress: address, typedData: asterReadTypedData(query));
      check();
      if (started.elapsed >= signatureLifetime) {
        throw const AccountReadFailure('accountSignatureExpired');
      }
      onStep(AccountReadStep.loading);
      final payload = await send(query: query, signature: signature);
      check();
      return payload;
    } on AccountReadFailure {
      rethrow;
    } on AuthFailure catch (failure) {
      throw AccountReadFailure(failure.key);
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    } catch (_) {
      throw const AccountReadFailure('accountReadFailed');
    }
  }
}
