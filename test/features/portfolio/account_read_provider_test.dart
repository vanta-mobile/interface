import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestAsterAccountRepository accounts;

  Future<AccountReadController> start() async {
    container.read(authProvider);
    container.read(accountReadProvider);
    await Future<void>.delayed(Duration.zero);
    return container.read(accountReadProvider.notifier);
  }

  setUp(() {
    identity = TestIdentityRepository()..restored = signingIdentity;
    accounts = TestAsterAccountRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        asterAccountRepositoryProvider.overrideWithValue(accounts),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });

  test('manual reads ignore duplicate taps, retain failed snapshots and retry', () async {
    final controller = await start();
    expect(accounts.calls, 0);
    await controller.refresh();
    final previous = container.read(accountReadProvider).account;
    expect(previous, same(accounts.result));
    accounts.gate = Completer<void>();
    final pending = controller.refresh();
    final duplicate = controller.refresh();
    expect(accounts.calls, 2);
    expect(container.read(accountReadProvider).busy, true);
    expect(container.read(accountReadProvider).stale, true);
    accounts.failure = const AccountReadFailure('accountNetwork');
    accounts.gate!.complete();
    await Future.wait([pending, duplicate]);
    expect(container.read(accountReadProvider).account, same(previous));
    expect(container.read(accountReadProvider).failure?.key, 'accountNetwork');
    expect(container.read(accountReadProvider).stale, true);
    expect(container.read(accountReadProvider).busy, false);
    accounts.failure = null;
    await controller.refresh();
    expect(container.read(accountReadProvider).failure, null);
    expect(container.read(accountReadProvider).stale, false);
  });

  test('signed-out or disconnected identities never request a read or create wallets', () async {
    identity.restored = null;
    final controller = await start();
    await controller.refresh();
    expect(accounts.calls, 0);
    identity.restored = const AuthIdentity(
      id: 'test',
      walletAddress: accountAddress,
      walletKind: WalletKind.external,
    );
    await container.read(authProvider.notifier).bootstrap();
    await controller.refresh();
    expect(container.read(accountReadProvider).failure?.key, 'authWalletReconnect');
    expect(accounts.calls, 0);
    expect(identity.wallets, 0);
  });

  for (final next in <AuthIdentity?>[
    null,
    AuthIdentity(
      id: signingIdentity.id,
      walletAddress: '0x3333333333333333333333333333333333333333',
      walletKind: WalletKind.external,
      signingAvailable: true,
    ),
    AuthIdentity(
      id: signingIdentity.id,
      walletAddress: accountAddress,
      walletKind: WalletKind.external,
    ),
  ]) {
    test(
      'identity change clears old snapshots and discards pending completion ${next?.walletAddress}',
      () async {
        final controller = await start();
        await controller.refresh();
        accounts.gate = Completer<void>();
        final pending = controller.refresh();
        identity.events.add(next);
        expect(container.read(accountReadProvider).account, null);
        expect(container.read(accountReadProvider).busy, false);
        accounts.gate!.complete();
        await pending;
        expect(container.read(accountReadProvider).account, null);
        expect(container.read(accountReadProvider).failure, null);
      },
    );
  }

  test(
    'a response for another address is rejected without replacing the previous snapshot',
    () async {
      final controller = await start();
      await controller.refresh();
      final previous = container.read(accountReadProvider).account;
      accounts.result = accountFixture(address: '0x3333333333333333333333333333333333333333');
      await controller.refresh();
      expect(container.read(accountReadProvider).failure?.key, 'authWalletChanged');
      expect(container.read(accountReadProvider).account, same(previous));
      expect(container.read(accountReadProvider).stale, true);
    },
  );

  test('late errors after provider disposal are harmless', () async {
    final controller = await start();
    accounts.gate = Completer<void>();
    final pending = controller.refresh();
    container.dispose();
    accounts.failure = const AccountReadFailure('accountNetwork');
    accounts.gate!.complete();
    await pending;
    container = ProviderContainer();
  });

  testWidgets('a snapshot expires without another wallet request', (tester) async {
    container.read(authProvider);
    await tester.pump();
    await container.read(accountReadProvider.notifier).refresh();
    expect(container.read(accountReadProvider).stale, false);
    await tester.pump(const Duration(seconds: 31));
    expect(container.read(accountReadProvider).stale, true);
    expect(accounts.calls, 1);
    container.dispose();
    container = ProviderContainer();
  });
}
