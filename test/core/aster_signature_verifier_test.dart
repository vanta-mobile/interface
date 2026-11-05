import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart' as evm;
import 'package:vanta/core/data/aster_signature_verifier.dart';

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
}
