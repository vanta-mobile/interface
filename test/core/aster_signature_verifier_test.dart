import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart' as evm;
import 'package:vanta/core/data/aster_signature_verifier.dart';
import 'package:vanta/core/data/personal_signature_verifier.dart';
import 'package:vanta/features/portfolio/domain/aster_signature.dart';

import '../support/aster_signatures.dart';

void main() {
  final source =
      jsonDecode(File('test/support/aster_signature_vectors.json').readAsStringSync()) as Map;
  for (final v in source['vectors'] as List) {
    final vector = v as Map<String, dynamic>;
    final data = <String, Object?>{
      'types': vector['types'],
      'domain': vector['domain'],
      'message': vector['message'],
      'primaryType': vector['primaryType'],
    };
    test('independent ethers digest and recovered signer for ${vector['name']}', () {
      expect(evm.bytesToHex(asterTypedDataDigest(data), include0x: true), vector['digest']);
      expect(
        verifyAsterWalletSignature(
          vector['address'] as String,
          data,
          vector['signature'] as String,
        ),
        true,
      );
      expect(verifyAsterWalletSignature(fixtureChild, data, vector['signature'] as String), false);
    });
    test('changed message cannot reuse ${vector['name']} signature', () {
      final changed = {
        ...data,
        'message': {
          ...vector['message'] as Map<String, dynamic>,
          vector['primaryType'] == 'Message' ? 'msg' : 'amount': 'modified',
        },
      };
      expect(
        verifyAsterWalletSignature(
          vector['address'] as String,
          changed,
          vector['signature'] as String,
        ),
        false,
      );
    });
    test('wrong chain cannot reuse ${vector['name']} signature', () {
      final changed = {
        ...data,
        'domain': {...vector['domain'] as Map<String, dynamic>, 'chainId': 1},
      };
      expect(
        verifyAsterWalletSignature(
          vector['address'] as String,
          changed,
          vector['signature'] as String,
        ),
        false,
      );
    });
  }

  test('signers whose public key starts with a zero byte are recovered', () {
    // Key 153 derives a public key whose first byte is 0x00.
    final key = evm.EthPrivateKey.fromInt(BigInt.from(153));
    expect(evm.privateKeyBytesToPublic(key.privateKey).first, 0);
    final address = key.address.eip55With0x;
    String encode(evm.MsgSignature s) =>
        '0x${s.r.toRadixString(16).padLeft(64, '0')}'
        '${s.s.toRadixString(16).padLeft(64, '0')}${s.v.toRadixString(16).padLeft(2, '0')}';
    final data = asterReadTypedData('nonce=1&user=$fixtureMaster&signer=$address');
    final typed = encode(evm.sign(asterTypedDataDigest(data), key.privateKey));
    expect(verifyAsterWalletSignature(address, data, typed), true);
    const message = 'vanta';
    final digest = evm.keccak256(
      Uint8List.fromList(utf8.encode('\x19Ethereum Signed Message:\n${message.length}$message')),
    );
    expect(
      verifyPersonalSignature(address, message, encode(evm.sign(digest, key.privateKey))),
      true,
    );
  });
}
