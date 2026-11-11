import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/application/deposit_wallet_provider.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_wallet.dart';
import '../../support/identity_repository.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestDepositWalletRepository repository;
  final query = depositQuery();
  ProviderSubscription<AccountSnapshotState<DepositWalletSnapshot>>? listener;
  void walletTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      identity = TestIdentityRepository()
        ..restored = const AuthIdentity(
          id: 'public-wallet',
          walletAddress: accountAddress,
          walletKind: WalletKind.external,
        );
      repository = TestDepositWalletRepository();
      container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          depositWalletRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.read(authProvider);
      listener = container.listen(depositWalletProvider(query), (_, _) {});
      await tester.pump();
      try {
        await body(tester);
      } finally {
        listener?.close();
        listener = null;
        container.dispose();
        await identity.dispose();
      }
    });
  }

  walletTest('explicit public reads work with restored non-signing EOA and no wallet creation', (
    tester,
  ) async {
    expect(repository.calls, isEmpty);
    await container.read(depositWalletProvider(query).notifier).refresh();
    expect(repository.calls.length, 1);
    expect(container.read(depositWalletProvider(query)).account!.address, accountAddress);
    expect(identity.wallets, 0);
    expect(container.read(authProvider).identity!.signingAvailable, false);
  });
  walletTest('duplicate reads await the same operation; failed refresh retains data and retries', (
    tester,
  ) async {
    final controller = container.read(depositWalletProvider(query).notifier);
    await controller.refresh();
    final old = container.read(depositWalletProvider(query)).account;
    repository.gate = Completer();
    final pending = controller.refresh();
    final duplicate = controller.refresh();
    var duplicateDone = false;
    duplicate.then((_) => duplicateDone = true);
    await tester.pump();
    expect(duplicateDone, isFalse);
    expect(repository.calls.length, 2);
    repository.failure = const FormatException();
    repository.gate!.complete();
    await pending;
    await duplicate;
    expect(duplicateDone, isTrue);
    expect(container.read(depositWalletProvider(query)).account, same(old));
    expect(container.read(depositWalletProvider(query)).stale, true);
    expect(container.read(depositWalletProvider(query)).failure!.key, 'depositRpcFailed');
    repository.failure = null;
    await controller.refresh();
    expect(container.read(depositWalletProvider(query)).stale, false);
  });
  walletTest('30-second expiry is manual-only, old chain blocks already historical', (
    tester,
  ) async {
    final controller = container.read(depositWalletProvider(query).notifier);
    await controller.refresh();
    await tester.pump(const Duration(seconds: 30));
    expect(container.read(depositWalletProvider(query)).stale, true);
    expect(repository.calls.length, 1);
    repository.result = depositSnapshot(query: query, blockAge: const Duration(minutes: 3));
    await controller.refresh();
    expect(container.read(depositWalletProvider(query)).stale, true);
  });
  for (final change in <AuthIdentity?>[
    null,
    const AuthIdentity(
      id: 'public-wallet',
      walletAddress: '0x3333333333333333333333333333333333333333',
      walletKind: WalletKind.external,
    ),
    const AuthIdentity(
      id: 'public-wallet',
      walletAddress: accountAddress,
      walletKind: WalletKind.embedded,
    ),
    const AuthIdentity(
      id: 'public-wallet',
      walletAddress: accountAddress,
      walletKind: WalletKind.external,
      signingAvailable: true,
    ),
  ]) {
    walletTest(
      'scope changes clear wallet data and drop late responses: ${change?.walletAddress}/${change?.walletKind}/${change?.signingAvailable}',
      (tester) async {
        final controller = container.read(depositWalletProvider(query).notifier);
        await controller.refresh();
        repository.gate = Completer();
        final pending = controller.refresh();
        identity.events.add(change);
        await tester.pump();
        expect(container.read(depositWalletProvider(query)).account, null);
        repository.gate!.complete();
        await pending;
        expect(container.read(depositWalletProvider(query)).account, null);
      },
    );
  }
  walletTest('stop waiting discards late initial and refresh responses', (tester) async {
    final controller = container.read(depositWalletProvider(query).notifier);
    repository.gate = Completer();
    final first = controller.refresh();
    controller.stop();
    repository.gate!.complete();
    await first;
    expect(container.read(depositWalletProvider(query)).account, null);
    await controller.refresh();
    final old = container.read(depositWalletProvider(query)).account;
    repository.gate = Completer();
    final second = controller.refresh();
    controller.stop();
    repository.gate!.complete();
    await second;
    expect(container.read(depositWalletProvider(query)).account, same(old));
    expect(container.read(depositWalletProvider(query)).stale, true);
  });
  walletTest('wrong wallet or token scope cannot replace previously read balance', (tester) async {
    final controller = container.read(depositWalletProvider(query).notifier);
    await controller.refresh();
    final previous = container.read(depositWalletProvider(query)).account;
    for (final result in [
      depositSnapshot(query: depositQuery(chain: 1)),
      depositSnapshot(query: query, address: '0x3333333333333333333333333333333333333333'),
    ]) {
      repository.result = result;
      await controller.refresh();
      expect(container.read(depositWalletProvider(query)).account, same(previous));
      expect(container.read(depositWalletProvider(query)).failure!.key, 'depositRpcInvalid');
    }
  });
  walletTest('transport retained through pending read and released with last family', (
    tester,
  ) async {
    listener!.close();
    container.dispose();
    var closed = 0;
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        depositWalletRepositoryProvider.overrideWith((ref) {
          ref.onDispose(() => closed++);
          return repository;
        }),
      ],
    );
    container.read(authProvider);
    listener = container.listen(depositWalletProvider(query), (_, _) {});
    await tester.pump();
    repository.gate = Completer();
    final pending = container.read(depositWalletProvider(query).notifier).refresh();
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 0);
    listener!.close();
    listener = null;
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 1);
    repository.gate!.complete();
    await pending;
    expect(container.exists(depositWalletProvider(query)), false);
  });
}
