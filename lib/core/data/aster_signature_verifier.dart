import 'dart:convert';
import 'dart:typed_data';

import 'package:web3dart/web3dart.dart' as evm;

/// Restricted EIP-712 encoding for Aster's flat Message and Action structs.
/// No signing keys, RPC or generic arbitrary nested types are involved.
Uint8List asterTypedDataDigest(Map<String, Object?> data) {
  final domain = data['domain'] as Map<String, Object?>;
  final message = data['message'] as Map<String, Object?>;
  final types = data['types'] as Map<String, Object?>;
  Uint8List word(String type, Object? value) {
    if (type == 'string' && value is String) return evm.keccak256(utf8.encode(value));
    if (type == 'address' && value is String && RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value)) {
      return evm.hexToBytes(value.substring(2).padLeft(64, '0'));
    }
    if (type == 'uint256') {
      final n = BigInt.tryParse('$value');
      if (n != null && n >= BigInt.zero && n < BigInt.one << 256) {
        return evm.hexToBytes(n.toRadixString(16).padLeft(64, '0'));
      }
    }
    throw const FormatException();
  }

  Uint8List struct(String name, Map<String, Object?> values) {
    final fields = (types[name] as List).cast<Map<String, Object?>>();
    final signature = '$name(${fields.map((f) => '${f['type']} ${f['name']}').join(',')})';
    return evm.keccak256(
      Uint8List.fromList([
        ...evm.keccak256(utf8.encode(signature)),
        for (final f in fields) ...word(f['type']! as String, values[f['name']]),
      ]),
    );
  }

  return evm.keccak256(
    Uint8List.fromList([
      0x19,
      0x01,
      ...struct('EIP712Domain', domain),
      ...struct(data['primaryType']! as String, message),
    ]),
  );
}

bool verifyAsterWalletSignature(String address, Map<String, Object?> data, String signature) {
  try {
    if (!RegExp(r'^0x[0-9a-fA-F]{130}$').hasMatch(signature)) return false;
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
    final public = evm.ecRecover(asterTypedDataDigest(data), evm.MsgSignature(r, s, v));
    return evm.bytesToHex(evm.publicKeyToAddress(public), include0x: true).toLowerCase() ==
        address.toLowerCase();
  } catch (_) {
    return false;
  }
}
