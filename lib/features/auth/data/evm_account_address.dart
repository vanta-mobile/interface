import 'package:eip55/eip55.dart';

/// Privy SIWE requires an EIP-55 address even when WalletConnect returns the
/// CAIP-10 account in lowercase.
String? canonicalEvmAddress(String value) {
  if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value)) return null;
  return toEIP55Address(value.toLowerCase());
}
