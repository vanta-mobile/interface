import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

import '../../support/identity_repository.dart';

void main() {
  late TestIdentityRepository repository;
  late ProviderContainer container;

  Future<AuthController> start() async {
    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);
    return container.read(authProvider.notifier);
  }

  setUp(() {
    repository = TestIdentityRepository();
    container = ProviderContainer(
      overrides: [identityRepositoryProvider.overrideWithValue(repository)],
    );
  });
  tearDown(() async {
    container.dispose();
    await repository.dispose();
  });

  test('wallet-kind changes at the same identity and address update signing scope', () async {
    repository.restored = identityWithWallet;
    await start();
    final next = AuthIdentity(
      id: identityWithWallet.id,
      walletAddress: identityWithWallet.walletAddress,
      walletKind: WalletKind.external,
    );
    repository.events.add(next);
    expect(container.read(authProvider).identity, same(next));
    expect(repository.wallets, 0);
  });

  test('wallet display name changes update an otherwise unchanged identity', () async {
    repository.restored = identityWithWallet;
    await start();
    repository.events.add(
      AuthIdentity(
        id: identityWithWallet.id,
        email: identityWithWallet.email,
        walletAddress: identityWithWallet.walletAddress,
        walletName: 'MetaMask',
      ),
    );
    expect(container.read(authProvider).identity?.walletName, 'MetaMask');
  });

  test('restores the existing identity without recreating its wallet', () async {
    repository.restored = identityWithWallet;
    await start();
    expect(container.read(authProvider).identity?.walletAddress, identityWithWallet.walletAddress);
    expect(repository.wallets, 0);
  });

  for (final provider in SocialLoginProvider.values) {
    test('$provider signs in once and creates an embedded wallet', () async {
      final controller = await start();
      repository.socialGate = Completer<void>();
      final pending = controller.loginWithSocial(provider);
      await controller.loginWithSocial(provider);
      expect(container.read(authProvider).busy, true);
      expect(repository.socialProvider, provider);
      repository.socialGate!.complete();
      await pending;
      expect(repository.wallets, 1);
      expect(container.read(authProvider).identity?.walletKind, WalletKind.embedded);
    });
  }

  test('expired code unlocks resend and failed resend retains its email', () async {
    final controller = await start();
    await controller.sendCode('test@example.com');
    repository.verifyFailure = const AuthFailure('authCodeExpired');
    await controller.verifyCode('482619');
    expect(container.read(authProvider).resendAt, null);
    repository.sendFailure = const AuthFailure('authNetwork');
    await controller.sendCode('test@example.com');
    expect(repository.sent, 2);
    expect(container.read(authProvider).email, 'test@example.com');
    expect(container.read(authProvider).phase, AuthPhase.awaitingCode);
  });

  test('social completion after disposal does not create a wallet', () async {
    final controller = await start();
    repository.socialGate = Completer<void>();
    final pending = controller.loginWithSocial(SocialLoginProvider.google);
    container.dispose();
    repository.socialGate!.complete();
    await pending;
    expect(repository.wallets, 0);
  });

  test('normalizes email and guards duplicate sends / resend cooldown', () async {
    final controller = await start();
    repository.sendGate = Completer<void>();
    final pending = controller.sendCode(' test@example.com ');
    await controller.sendCode('test@example.com');
    expect(repository.sent, 1);
    repository.sendGate!.complete();
    await pending;
    expect(container.read(authProvider).phase, AuthPhase.awaitingCode);
    expect(container.read(authProvider).email, 'test@example.com');
    await controller.sendCode('test@example.com');
    expect(repository.sent, 1);
    controller.changeEmail();
    await controller.sendCode('test@example.com');
    expect(container.read(authProvider).phase, AuthPhase.awaitingCode);
    expect(repository.sent, 1);
  });

  test('invalid inputs stay local and safe failures preserve the email', () async {
    final controller = await start();
    await controller.sendCode('not-an-email');
    expect(container.read(authProvider).failure?.key, 'authInvalidEmail');
    expect(repository.sent, 0);
    repository.sendFailure = const AuthFailure('authNetwork', reason: 'Connection timed out');
    await controller.sendCode('test@example.com');
    expect(container.read(authProvider).failure?.reason, 'Connection timed out');
    expect(container.read(authProvider).email, 'test@example.com');
    expect(container.read(authProvider).busy, false);
  });

  test('invalid verification preserves the code step and can retry', () async {
    final controller = await start();
    await controller.sendCode('test@example.com');
    await controller.verifyCode('abc');
    expect(repository.verified, 0);
    repository.verifyFailure = const AuthFailure('authInvalidCode', reason: 'Code expired');
    await controller.verifyCode('123456');
    expect(container.read(authProvider).phase, AuthPhase.awaitingCode);
    expect(container.read(authProvider).email, 'test@example.com');
    expect(container.read(authProvider).failure?.reason, 'Code expired');
    repository.verifyFailure = null;
    await controller.verifyCode('654321');
    expect(container.read(authProvider).phase, AuthPhase.signedIn);
    expect(container.read(authProvider).identity?.walletAddress, identityWithWallet.walletAddress);
  });

  test('wallet creation failure retains identity and retries wallet only', () async {
    final controller = await start();
    await controller.sendCode('test@example.com');
    repository.walletFailure = const AuthFailure('authNetwork');
    await controller.verifyCode('123456');
    expect(container.read(authProvider).identity?.id, 'user-1');
    expect(container.read(authProvider).identity?.walletAddress, null);
    expect(container.read(authProvider).failure?.key, 'authNetwork');
    repository.walletFailure = null;
    await controller.createWallet();
    expect(container.read(authProvider).identity?.walletAddress, identityWithWallet.walletAddress);
    expect(repository.verified, 1);
    expect(repository.wallets, 2);
  });

  test(
    'duplicate verification is ignored and late completion after disposal is harmless',
    () async {
      final controller = await start();
      await controller.sendCode('test@example.com');
      repository.verifyGate = Completer<void>();
      final pending = controller.verifyCode('123456');
      await controller.verifyCode('123456');
      expect(repository.verified, 1);
      container.dispose();
      repository.verifyGate!.complete();
      await pending;
      expect(repository.wallets, 0);
      // The tearDown owns disposal; use an empty replacement container.
      container = ProviderContainer();
    },
  );

  test('failed logout retains visible identity; successful logout clears it', () async {
    repository.restored = identityWithWallet;
    final controller = await start();
    repository.logoutFailure = const AuthFailure('authNetwork', reason: 'Network unavailable');
    await controller.logout();
    expect(container.read(authProvider).identity?.id, 'user-1');
    expect(container.read(authProvider).failure?.reason, 'Network unavailable');
    repository.logoutFailure = null;
    await controller.logout();
    expect(container.read(authProvider).phase, AuthPhase.signedOut);
    expect(container.read(authProvider).identity, null);
  });

  test('SDK expiry clears the identity instead of retaining a signed-in header', () async {
    repository.restored = identityWithWallet;
    await start();
    repository.events.add(null);
    expect(container.read(authProvider).identity, null);
    expect(container.read(authProvider).failure?.key, 'authSessionUnavailable');
  });
  test(
    'wallet creation completing after SDK expiry cannot restore the previous identity',
    () async {
      final controller = await start();
      await controller.sendCode('test@example.com');
      repository.walletGate = Completer<void>();
      final verification = controller.verifyCode('123456');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authProvider).busy, true);
      repository.events.add(null);
      expect(container.read(authProvider).identity, null);
      repository.walletGate!.complete();
      await verification;
      expect(container.read(authProvider).identity, null);
      expect(container.read(authProvider).failure?.key, 'authSessionUnavailable');
    },
  );
}
