import 'dart:async';

import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_connection.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';

const identityWithoutWallet = AuthIdentity(id: 'user-1', email: 'test@example.com');
const identityWithWallet = AuthIdentity(
  id: 'user-1',
  email: 'test@example.com',
  walletAddress: '0x1111111111111111111111111111111111111111',
);

class TestIdentityRepository implements IdentityRepository {
  AuthIdentity? restored;
  AuthFailure? sendFailure, verifyFailure, walletFailure, logoutFailure, initializeFailure;
  Completer<void>? sendGate, verifyGate, walletGate, initializeGate;
  int sent = 0, verified = 0, wallets = 0, logouts = 0, initializations = 0;
  SocialLoginProvider? socialProvider;
  Completer<void>? socialGate;
  AuthFailure? socialFailure;

  @override
  Future<AuthIdentity> loginWithSocial(SocialLoginProvider provider) async {
    socialProvider = provider;
    await socialGate?.future;
    if (socialFailure case final failure?) throw failure;
    return identityWithoutWallet;
  }

  final events = StreamController<AuthIdentity?>.broadcast(sync: true);

  @override
  Stream<AuthIdentity?> get changes => events.stream;

  @override
  Future<AuthIdentity?> initialize() async {
    initializations++;
    await initializeGate?.future;
    if (initializeFailure case final failure?) throw failure;
    return restored;
  }

  @override
  Future<void> sendCode(String email) async {
    sent++;
    await sendGate?.future;
    if (sendFailure case final failure?) throw failure;
  }

  @override
  Future<AuthIdentity> verifyCode(String email, String code) async {
    verified++;
    await verifyGate?.future;
    if (verifyFailure case final failure?) throw failure;
    return identityWithoutWallet;
  }

  @override
  Future<AuthIdentity> ensureWallet() async {
    wallets++;
    await walletGate?.future;
    if (walletFailure case final failure?) throw failure;
    return identityWithWallet;
  }

  AuthFailure? externalFailure;
  Completer<void>? externalGate;
  int externalLogins = 0;
  @override
  Future<AuthIdentity> loginWithWallet(WalletConnection connection) async {
    externalLogins++;
    await externalGate?.future;
    if (externalFailure case final failure?) throw failure;
    return AuthIdentity(
      id: 'external-user',
      walletAddress: connection.address,
      walletKind: WalletKind.external,
      walletName: connection.walletName,
      signingAvailable: true,
    );
  }

  @override
  Future<String> signWalletRequest({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) => signExternalRequest(expectedAddress: expectedAddress, typedData: typedData);

  @override
  Future<String> signExternalRequest({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) async => throw const AuthFailure('authWalletReconnect');

  @override
  Future<void> logout() async {
    logouts++;
    if (logoutFailure case final failure?) throw failure;
  }

  @override
  Future<WalletTransactionResult> sendWalletTransaction({
    required EvmWalletTransaction transaction,
    required bool Function() isCurrent,
  }) async => throw const WalletTransactionNotSent('authWalletReconnect');

  Future<void> dispose() async {
    if (initializeGate case final gate? when !gate.isCompleted) gate.complete();
    if (socialGate case final gate? when !gate.isCompleted) gate.complete();
    if (externalGate case final gate? when !gate.isCompleted) gate.complete();
    if (sendGate case final gate? when !gate.isCompleted) gate.complete();
    if (verifyGate case final gate? when !gate.isCompleted) gate.complete();
    if (walletGate case final gate? when !gate.isCompleted) gate.complete();
    await events.close();
  }
}
