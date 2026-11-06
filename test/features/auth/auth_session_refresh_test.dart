import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

import '../../support/identity_repository.dart';

void main() {
  late ProviderContainer c;
  late TestIdentityRepository repository;
  late AuthController controller;
  setUp(() async {
    repository = TestIdentityRepository()..restored = identityWithWallet;
    c = ProviderContainer(overrides: [identityRepositoryProvider.overrideWithValue(repository)]);
    c.read(authProvider);
    await Future<void>.delayed(Duration.zero);
    controller = c.read(authProvider.notifier);
  });
  tearDown(() async {
    c.dispose();
    await repository.dispose();
  });

  test('same session produces no busy state, wallet creation or downstream notification', () async {
    final original = c.read(authProvider);
    final states = <AuthSession>[];
    c.listen(authProvider, (_, next) => states.add(next));
    // A new SDK model instance with equal fields is still the same session.
    repository.restored = AuthIdentity(
      id: identityWithWallet.id,
      email: identityWithWallet.email,
      walletAddress: identityWithWallet.walletAddress,
    );
    repository.initializeGate = Completer<void>();
    final refresh = controller.refreshSession();
    await controller.refreshSession();
    expect(repository.initializations, 2);
    expect(c.read(authProvider), same(original));
    repository.initializeGate!.complete();
    await refresh;
    expect(c.read(authProvider), same(original));
    expect(states, isEmpty);
    expect(repository.wallets, 0);
  });

  for (final change in ['expired', 'wallet', 'kind', 'signing']) {
    test('session refresh applies actual $change without creating a wallet', () async {
      repository.restored = switch (change) {
        'expired' => null,
        'wallet' => const AuthIdentity(
          id: 'user-1',
          walletAddress: '0x2222222222222222222222222222222222222222',
        ),
        'kind' => AuthIdentity(
          id: identityWithWallet.id,
          walletAddress: identityWithWallet.walletAddress,
          walletKind: WalletKind.external,
        ),
        _ => AuthIdentity(
          id: identityWithWallet.id,
          walletAddress: identityWithWallet.walletAddress,
          signingAvailable: true,
        ),
      };
      await controller.refreshSession();
      expect(c.read(authProvider).identity, same(repository.restored));
      expect(c.read(authProvider).busy, false);
      if (change == 'expired') expect(c.read(authProvider).failure?.key, 'authSessionUnavailable');
      expect(repository.wallets, 0);
    });
  }

  test('SDK identity change supersedes an older in-flight session read', () async {
    repository.initializeGate = Completer<void>();
    final refresh = controller.refreshSession();
    const next = AuthIdentity(
      id: 'new-user',
      walletAddress: '0x2222222222222222222222222222222222222222',
    );
    repository.events.add(next);
    expect(c.read(authProvider).identity, same(next));
    repository.initializeGate!.complete();
    await refresh;
    expect(c.read(authProvider).identity, same(next));
  });

  test('explicit logout cannot be undone by a late session read', () async {
    repository.initializeGate = Completer<void>();
    final refresh = controller.refreshSession();
    await controller.logout();
    repository.initializeGate!.complete();
    await refresh;
    expect(c.read(authProvider).identity, isNull);
    expect(repository.wallets, 0);
  });

  test('failed refresh preserves identity and exposes only the safe auth failure', () async {
    repository.initializeFailure = const AuthFailure('authNetwork', reason: 'Connection timed out');
    await controller.refreshSession();
    expect(c.read(authProvider).identity, same(identityWithWallet));
    expect(c.read(authProvider).busy, false);
    expect(c.read(authProvider).failure?.reason, 'Connection timed out');
  });

  test('signed-out resume refresh never implicitly logs back in', () async {
    await controller.logout();
    await controller.refreshSession();
    expect(repository.initializations, 1);
    expect(c.read(authProvider).identity, isNull);
  });

  test('late session read after disposal does not update state', () async {
    repository.initializeGate = Completer<void>();
    final refresh = controller.refreshSession();
    c.dispose();
    c = ProviderContainer();
    repository.initializeGate!.complete();
    await refresh;
    expect(repository.wallets, 0);
  });
}
