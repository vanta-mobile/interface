import 'dart:convert';
import 'dart:typed_data';

import 'package:web3dart/web3dart.dart' as evm;

/// EIP-191 `personal_sign` recovery; low-s only, so malleable signatures are refused.
bool verifyPersonalSignature(String address, String message, String signature) {
  try {
    if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature)) return false;
    final bytes = evm.hexToBytes(signature);
    final v = bytes[64] < 27 ? bytes[64] + 27 : bytes[64];
    final r = evm.bytesToUnsignedInt(bytes.sublist(0, 32)),
        s = evm.bytesToUnsignedInt(bytes.sublist(32, 64));
    final order = BigInt.parse(
      'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
      radix: 16,
    );
    if (![27, 28].contains(v) ||
        r <= BigInt.zero ||
        r >= order ||
        s <= BigInt.zero ||
        s > order >> 1) {
      return false;
    }
    final body = utf8.encode(message);
    final digest = evm.keccak256(
      Uint8List.fromList([...utf8.encode('\x19Ethereum Signed Message:\n${body.length}'), ...body]),
    );
    final public = evm.ecRecover(digest, evm.MsgSignature(r, s, v));
    return evm.bytesToHex(evm.publicKeyToAddress(public), include0x: true).toLowerCase() ==
        address.toLowerCase();
  } catch (_) {
    return false;
  }
}
