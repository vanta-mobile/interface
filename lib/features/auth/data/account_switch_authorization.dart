import 'dart:math';

import '../../../core/data/aster_signature_verifier.dart';
import '../../portfolio/data/signed_account_request.dart';
import '../domain/auth_session.dart';

/// A local, single-use intent. Its domain cannot authorize an Aster API write.
class AccountSwitchAuthorization {
  AccountSwitchAuthorization(this.sign, {DateTime Function()? now, String Function()? nonce})
    : now = now ?? DateTime.now,
      nonce = nonce ?? _nonce;
  final AccountRequestSigner sign;
  final DateTime Function() now;
  final String Function() nonce;
  static String _nonce() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> authorize({
    required String from,
    required String to,
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) throw const AuthFailure('authWalletChanged');
    final issued = now().toUtc();
    final expires = issued.add(const Duration(minutes: 2));
    final data = <String, Object?>{
      'types': {
        'EIP712Domain': [
          {'name': 'name', 'type': 'string'},
          {'name': 'version', 'type': 'string'},
        ],
        'SwitchAccount': [
          {'name': 'action', 'type': 'string'},
          {'name': 'from', 'type': 'address'},
          {'name': 'to', 'type': 'address'},
          {'name': 'nonce', 'type': 'string'},
          {'name': 'issuedAt', 'type': 'string'},
          {'name': 'expiresAt', 'type': 'string'},
        ],
      },
      'primaryType': 'SwitchAccount',
      'domain': {'name': 'Vanta Account Switch', 'version': '1'},
      'message': {
        'action': 'Switch active account',
        'from': from,
        'to': to,
        'nonce': nonce(),
        'issuedAt': issued.toIso8601String(),
        'expiresAt': expires.toIso8601String(),
      },
    };
    final signature = await sign(expectedAddress: from, typedData: data).timeout(
      const Duration(minutes: 2),
      onTimeout: () => throw const AuthFailure('authWalletSignature'),
    );
    if (!isCurrent()) throw const AuthFailure('authWalletChanged');
    if (now().toUtc().isBefore(issued) ||
        !now().toUtc().isBefore(expires) ||
        !verifyAsterWalletSignature(from, data, signature)) {
      throw const AuthFailure('authWalletSignature');
    }
  }
}
