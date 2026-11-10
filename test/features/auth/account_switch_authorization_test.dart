import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/data/aster_signature_verifier.dart';
import 'package:vanta/features/auth/data/account_switch_authorization.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:web3dart/web3dart.dart' as evm;

String _signature(evm.EthPrivateKey key, Map<String, Object?> data) {
  final s = evm.sign(asterTypedDataDigest(data), key.privateKey);
  return '0x${s.r.toRadixString(16).padLeft(64, '0')}${s.s.toRadixString(16).padLeft(64, '0')}${s.v.toRadixString(16).padLeft(2, '0')}';
}

void main() {
  final key = evm.EthPrivateKey.fromHex('01'.padLeft(64, '0'));
  final address = key.address.eip55With0x;
  const target = '0x3333333333333333333333333333333333333333';
  test('switch intent binds the current signer, target, domain, nonce and lifetime', () async {
    final messages = <Map<String, Object?>>[];
    var nonce = 0;
    final authorization = AccountSwitchAuthorization(
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, address);
        messages.add(typedData);
        return _signature(key, typedData);
      },
      now: () => DateTime.utc(2026, 11, 9),
      nonce: () => '${++nonce}',
    );
    for (var i = 0; i < 2; i++) {
      await authorization.authorize(from: address, to: target, isCurrent: () => true);
    }
    expect(messages.first['domain'], {'name': 'Vanta Account Switch', 'version': '1'});
    final message = messages.first['message']! as Map;
    expect(message['from'], address);
    expect(message['to'], target);
    expect(message['expiresAt'], '2026-11-09T00:02:00.000Z');
    expect((messages.last['message']! as Map)['nonce'], isNot(message['nonce']));
  });
  for (final issue in [
    'declined',
    'wrong-signer',
    'tampered-target',
    'expired',
    'identity-changed',
  ]) {
    test('rejects $issue authorization', () async {
      var now = DateTime.utc(2026, 11, 9), current = true;
      final authorization = AccountSwitchAuthorization(({
        required expectedAddress,
        required typedData,
      }) async {
        if (issue == 'declined') throw const AuthFailure('authWalletCancelled');
        if (issue == 'expired') now = now.add(const Duration(minutes: 2));
        if (issue == 'identity-changed') current = false;
        if (issue == 'tampered-target') {
          typedData = {
            ...typedData,
            'message': <String, Object?>{
              ...typedData['message']! as Map<String, Object?>,
              'to': address,
            },
          };
        }
        return _signature(
          issue == 'wrong-signer' ? evm.EthPrivateKey.fromHex('02'.padLeft(64, '0')) : key,
          typedData,
        );
      }, now: () => now);
      await expectLater(
        authorization.authorize(from: address, to: target, isCurrent: () => current),
        throwsA(isA<AuthFailure>()),
      );
    });
  }
}
