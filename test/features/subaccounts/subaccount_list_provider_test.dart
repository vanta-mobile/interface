import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/subaccounts/application/subaccount_list_provider.dart';
import 'package:vanta/features/subaccounts/domain/subaccount_directory.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/subaccounts.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestSubaccountListRepository repository;
  ProviderSubscription<SubaccountListState>? listener;
  Future<SubaccountListController> start() async {
    container.read(authProvider);
    listener = container.listen(subaccountListProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container.read(subaccountListProvider.notifier);
  }

  setUp(() {
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestSubaccountListRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        subaccountListRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });
  tearDown(() async {
    listener?.close();
    listener = null;
    container.dispose();
    await identity.dispose();
  });
  test(
    'repository survives event-loop turns and a gated request until its consumer is disposed',
    () async {
      container.dispose();
      var closed = 0;
      container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          subaccountListRepositoryProvider.overrideWith((ref) {
            ref.onDispose(() => closed++);
            return repository;
          }),
        ],
      );
      final controller = await start();
      repository.gate = Completer();
      final pending = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(closed, 0);
      repository.gate!.complete();
      await pending;
      expect(closed, 0);
      listener!.close();
      listener = null;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(closed, 1);
    },
  );

  test(
    'manual directory refresh ignores parallel taps, retains failed snapshot and retries',
    () async {
      final controller = await start();
      expect(repository.calls, 0);
      await controller.refresh();
      final previous = container.read(subaccountListProvider).account;
      repository.gate = Completer();
      final pending = controller.refresh();
      await controller.refresh();
      expect(repository.calls, 2);
      expect(container.read(subaccountListProvider).busy, true);
      repository.failure = const AccountReadFailure('accountNetwork');
      repository.gate!.complete();
      await pending;
      expect(container.read(subaccountListProvider).account, same(previous));
      expect(container.read(subaccountListProvider).stale, true);
      expect(container.read(subaccountListProvider).failure?.key, 'accountNetwork');
      repository.failure = null;
      await controller.refresh();
      expect(container.read(subaccountListProvider).stale, false);
      expect(container.read(authProvider).identity, same(signingIdentity));
      expect(identity.wallets, 0);
    },
  );
  test(
    'signed-out and restored EOA without signing capability do not read or create a wallet',
    () async {
      identity.restored = null;
      final controller = await start();
      await controller.refresh();
      expect(repository.calls, 0);
      identity.restored = const AuthIdentity(
        id: 'restore',
        walletAddress: accountAddress,
        walletKind: WalletKind.external,
      );
      await container.read(authProvider.notifier).bootstrap();
      await controller.refresh();
      expect(repository.calls, 0);
      expect(container.read(subaccountListProvider).failure?.key, 'authWalletReconnect');
      expect(identity.wallets, 0);
    },
  );
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
    AuthIdentity(id: signingIdentity.id, walletAddress: accountAddress, signingAvailable: true),
  ]) {
    test(
      'scope change clears directory and prevents old signing completion: ${next?.walletAddress} ${next?.walletKind} ${next?.signingAvailable}',
      () async {
        final controller = await start();
        await controller.refresh();
        repository.gate = Completer();
        final pending = controller.refresh();
        identity.events.add(next);
        expect(container.read(subaccountListProvider).account, null);
        repository.gate!.complete();
        await pending;
        expect(repository.sends, 1);
        expect(container.read(subaccountListProvider).account, null);
        expect(container.read(subaccountListProvider).failure, null);
      },
    );
  }
  test(
    'stop waiting retains prior directory and discards pending send, then allows a new read',
    () async {
      final controller = await start();
      await controller.refresh();
      final previous = container.read(subaccountListProvider).account;
      repository.gate = Completer();
      final pending = controller.refresh();
      controller.stopRead();
      expect(container.read(subaccountListProvider).busy, false);
      expect(container.read(subaccountListProvider).account, same(previous));
      expect(container.read(subaccountListProvider).stale, true);
      repository.gate!.complete();
      await pending;
      expect(repository.sends, 1);
      expect(container.read(subaccountListProvider).failure, null);
      await controller.refresh();
      expect(repository.sends, 2);
    },
  );
  test('directory scoped to another wallet cannot replace existing data', () async {
    final controller = await start();
    await controller.refresh();
    final previous = container.read(subaccountListProvider).account;
    repository.result = subaccountFixture(address: '0x3333333333333333333333333333333333333333');
    await controller.refresh();
    expect(container.read(subaccountListProvider).account, same(previous));
    expect(container.read(subaccountListProvider).failure?.key, 'authWalletChanged');
  });
  test('leaving the only consumer disposes directory and prevents a pending signed read', () async {
    final controller = await start();
    repository.gate = Completer();
    final pending = controller.refresh();
    listener!.close();
    listener = null;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.exists(subaccountListProvider), false);
    repository.gate!.complete();
    await pending;
    expect(repository.sends, 0);
  });
  testWidgets('directory expires after thirty seconds without signing again', (tester) async {
    container.read(authProvider);
    listener = container.listen(subaccountListProvider, (_, _) {});
    await tester.pump();
    await container.read(subaccountListProvider.notifier).refresh();
    await tester.pump(const Duration(seconds: 30));
    expect(container.read(subaccountListProvider).stale, true);
    expect(repository.calls, 1);
    container.dispose();
    container = ProviderContainer();
  });
}
