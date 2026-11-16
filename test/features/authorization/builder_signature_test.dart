import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/data/aster_signature_verifier.dart';
import 'package:vanta/features/authorization/data/builder_authorization_mapper.dart';

import '../../support/aster_signatures.dart';

void main() {
  // Independent ethers v6 vectors, using the official demo.py parameter order,
  // Mainnet AsterChain, chain 56 and the public deterministic fixture wallet.
  const vectors = [
    (
      update: false,
      digest: 'f02bc3cea985d46703416c62368e1e9cc385d76520cb618d6bc0954aea0bbfd4',
      signature: '0xc88aae336ba51ad1eb1920205b6d7e5dd90bdab2f3164a3ca233e5b6a9ab620902d5fdf9c6d2435fcb2eec1eddcbaac943d1fe15d74679ca531110d61998e3b01b',
    ),
    (
      update: true,
      digest: 'fd75d00eb7c009236a829dc387b2a04db4963a6f5fc3b08af4fa84ef0037dd09',
      signature: '0xaea68eba1297134c0da5d890154614de6a4ffe3924aff7fe641c726313444d8e13e429dd9a17dae3214503932ba212d0e5cbd1bcd3f1db157928c5c02c3db3c51c',
    ),
  ];
  for (final vector in vectors) {
    test('Builder update=${vector.update} matches the official Mainnet signature schema', () {
      final data = builderApprovalTypedData(
        owner: fixtureMaster,
        nonce: 1794787200000001,
        update: vector.update,
      );
      expect(
        asterTypedDataDigest(data).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        vector.digest,
      );
      expect(verifyAsterWalletSignature(fixtureMaster, data, vector.signature), true);

      final types = data['types']! as Map<String, Object?>;
      final primary = data['primaryType']! as String;
      types[primary] = (types[primary]! as List)
          .where((field) => (field as Map)['name'] != 'AsterChain')
          .toList();
      expect(verifyAsterWalletSignature(fixtureMaster, data, vector.signature), false);
    });
  }
}
