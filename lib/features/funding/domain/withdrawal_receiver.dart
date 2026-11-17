import 'dart:convert';

import 'package:web3dart/web3dart.dart' as evm;

import '../../../core/domain/wallet_operation.dart';
import '../../auth/domain/auth_session.dart';

/// A nonzero EVM address. Mixed case must match its EIP-55 checksum, so a
/// mistyped character in a copied checksummed address is caught.
bool validWithdrawalReceiver(String value) {
  if (!validOperationAddress(value)) return false;
  final hex = value.substring(2), lower = hex.toLowerCase();
  if (hex == lower || hex == hex.toUpperCase()) return true;
  final hash = evm.keccak256(utf8.encode(lower));
  for (var i = 0; i < 40; i++) {
    final nibble = i.isEven ? hash[i ~/ 2] >> 4 : hash[i ~/ 2] & 0x0f;
    final expected = nibble >= 8 ? lower[i].toUpperCase() : lower[i];
    if (hex[i] != expected) return false;
  }
  return true;
}

/// Embedded (Privy) wallets withdraw to an entered address, as on the Aster
/// website; external wallets withdraw only to themselves.
bool entersWithdrawalReceiver(AuthIdentity? identity) =>
    identity?.walletKind == WalletKind.embedded;
