import 'wallet_connection.dart';
import 'wallet_transaction.dart';

enum WalletKind { embedded, external }

class AuthIdentity {
  const AuthIdentity({
    required this.id,
    this.email,
    this.walletAddress,
    this.walletKind = WalletKind.embedded,
    this.signingAvailable = false,
  });
  final String id;
  final String? email, walletAddress;
  final WalletKind walletKind;
  final bool signingAvailable;
}

class AuthFailure implements Exception {
  const AuthFailure(this.key, {this.reason});
  final String key;
  final String? reason;
}

enum AuthPhase { initializing, signedOut, awaitingCode, signedIn }

enum WalletLoginStep { connecting, signing }

class AuthSession {
  const AuthSession({
    this.phase = AuthPhase.initializing,
    this.identity,
    this.email = '',
    this.busy = false,
    this.failure,
    this.resendAt,
    this.walletStep,
  });
  final AuthPhase phase;
  final AuthIdentity? identity;
  final String email;
  final bool busy;
  final AuthFailure? failure;
  final DateTime? resendAt;
  final WalletLoginStep? walletStep;
}

abstract interface class IdentityRepository {
  Stream<AuthIdentity?> get changes;
  Future<AuthIdentity?> initialize();
  Future<void> sendCode(String email);
  Future<AuthIdentity> verifyCode(String email, String code);
  Future<AuthIdentity> ensureWallet();
  Future<AuthIdentity> loginWithWallet(WalletConnection connection);
  Future<String> signWalletRequest({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  });
  Future<String> signExternalRequest({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  });
  Future<void> logout();
  Future<WalletTransactionResult> sendWalletTransaction({
    required EvmWalletTransaction transaction,
    required bool Function() isCurrent,
  });
}
