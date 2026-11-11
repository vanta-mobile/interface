import 'dart:math';

/// Distinguishes explicit wallet requests even when the chain reuses a nonce.
String newFundingTransactionAttempt() {
  final random = Random.secure();
  return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
