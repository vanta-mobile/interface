import 'package:web3dart/web3dart.dart' as evm;
import 'package:vanta/core/data/aster_signature_verifier.dart';

// Public deterministic test vectors; never an application or real wallet key.
const fixtureMaster = '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf';
const fixtureChild = '0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF';
String fixtureSign(Map<String, Object?> data, {bool child = false}) {
  final key = evm.hexToBytes((child ? '2' : '1').padLeft(64, '0'));
  final s = evm.sign(asterTypedDataDigest(data), key);
  return '0x${s.r.toRadixString(16).padLeft(64, '0')}${s.s.toRadixString(16).padLeft(64, '0')}${s.v.toRadixString(16).padLeft(2, '0')}';
}

Future<String> fixtureWalletSign({
  required String expectedAddress,
  required Map<String, Object?> typedData,
}) async {
  if (expectedAddress.toLowerCase() != fixtureMaster.toLowerCase()) {
    throw StateError('fixture address');
  }
  return fixtureSign(typedData);
}
