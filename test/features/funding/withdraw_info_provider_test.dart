import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/application/withdraw_info_provider.dart';
import 'package:vanta/features/funding/domain/withdraw_info.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/spot_account_change_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/account_changes.dart';
import '../../support/aster_account.dart';
import '../../support/funding_info.dart';
import '../../support/identity_repository.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestWithdrawInfoRepository repository;
  late TestAccountChangeRepository perp, spot;
  ProviderSubscription<WithdrawInfoState>? listener;
  setUp(() {
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestWithdrawInfoRepository();
    perp = TestAccountChangeRepository();
    spot = TestAccountChangeRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        withdrawInfoRepositoryProvider.overrideWithValue(repository),
        accountChangeRepositoryProvider.overrideWithValue(perp),
        spotAccountChangeRepositoryProvider.overrideWithValue(spot),
        accountChangeClockProvider.overrideWithValue(() => perp.now),
      ],
    );
  });
  tearDown(() async {
    listener?.close();
    listener = null;
    container.dispose();
    await identity.dispose();
    await perp.dispose();
    await spot.dispose();
  });
  Future<WithdrawInfoController> start() async {
    container.read(authProvider);
    listener = container.listen(withdrawInfoProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return container.read(withdrawInfoProvider.notifier);
  }

  test('only explicit reads, duplicate guard, failed refresh retention and retry', () async {
    final controller = await start();
    expect(repository.calls, 0);
    await controller.refresh();
    final prior = container.read(withdrawInfoProvider).account;
    repository.gate = Completer();
    final pending = controller.refresh();
    await controller.refresh();
    expect(repository.calls, 2);
    repository.failure = const AccountReadFailure('accountNetwork');
    repository.gate!.complete();
    await pending;
    expect(container.read(withdrawInfoProvider).account, same(prior));
    expect(container.read(withdrawInfoProvider).stale, true);
    repository.failure = null;
    await controller.refresh();
    expect(container.read(withdrawInfoProvider).failure, null);
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
    AuthIdentity(id: signingIdentity.id, walletAddress: accountAddress, signingAvailable: true),
  ]) {
    test(
      'identity scope clears private info and drops a pending signature: ${next?.walletKind} ${next?.walletAddress} ${next?.signingAvailable}',
      () async {
        final controller = await start();
        await controller.refresh();
        repository.gate = Completer();
        final pending = controller.refresh();
        identity.events.add(next);
        expect(container.read(withdrawInfoProvider).account, null);
        repository.gate!.complete();
        await pending;
        expect(repository.sends, 1);
        expect(container.read(withdrawInfoProvider).account, null);
      },
    );
  }
  test('restored non-signing wallet cannot read, and stop prevents late sends', () async {
    identity.restored = const AuthIdentity(
      id: 'restore',
      walletAddress: accountAddress,
      walletKind: WalletKind.external,
    );
    final controller = await start();
    await controller.refresh();
    expect(repository.calls, 0);
    expect(container.read(withdrawInfoProvider).failure?.key, 'authWalletReconnect');
    identity.events.add(signingIdentity);
    repository.gate = Completer();
    final pending = controller.refresh();
    controller.stopRead();
    repository.gate!.complete();
    await pending;
    expect(repository.sends, 0);
    expect(identity.wallets, 0);
  });
  test('response for another wallet cannot replace the old snapshot', () async {
    final controller = await start();
    await controller.refresh();
    final prior = container.read(withdrawInfoProvider).account;
    repository.result = withdrawInfoFixture(address: '0x3333333333333333333333333333333333333333');
    await controller.refresh();
    expect(container.read(withdrawInfoProvider).account, same(prior));
    expect(container.read(withdrawInfoProvider).failure?.key, 'authWalletChanged');
  });
  test('Spot and Futures events, including repeated timestamps and pending-read events, mark limits stale without signatures', () async {
    final controller = await start();
    await container.read(accountChangeProvider.notifier).authorize();
    await container.read(spotAccountChangeProvider.notifier).authorize();
    final time = perp.now;
    await controller.refresh();
    perp.channels.single.add(AccountChangeEvent.changed(AccountChangeKind.configuration, time));
    expect(container.read(withdrawInfoProvider).stale, true);
    await controller.refresh();
    perp.channels.single.add(AccountChangeEvent.changed(AccountChangeKind.configuration, time));
    expect(container.read(withdrawInfoProvider).stale, true);
    await controller.refresh();
    repository.gate = Completer();
    final pending = controller.refresh();
    spot.channels.single.add(AccountChangeEvent.changed(AccountChangeKind.account, time));
    repository.gate!.complete();
    await pending;
    expect(container.read(withdrawInfoProvider).stale, true);
    expect(repository.calls, 4);
  });
  test('last consumer disposal invalidates pending work', () async {
    final controller = await start();
    repository.gate = Completer();
    final pending = controller.refresh();
    listener!.close();
    listener = null;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    repository.gate!.complete();
    await pending;
    expect(repository.sends, 0);
    expect(container.exists(withdrawInfoProvider), false);
  });
  testWidgets('thirty-second expiry does not automatically request a new signature', (
    tester,
  ) async {
    container.read(authProvider);
    listener = container.listen(withdrawInfoProvider, (_, _) {});
    await tester.pump();
    await container.read(withdrawInfoProvider.notifier).refresh();
    await tester.pump(const Duration(seconds: 30));
    expect(container.read(withdrawInfoProvider).stale, true);
    expect(repository.calls, 1);
    container.dispose();
    container = ProviderContainer();
  });
}
