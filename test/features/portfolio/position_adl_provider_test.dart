import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/position_adl_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/position_adl.dart';
import '../../support/identity_repository.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestPositionAdlRepository positions;
  setUp(() {
    identity = TestIdentityRepository()..restored = signingIdentity;
    positions = TestPositionAdlRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        positionAdlRepositoryProvider.overrideWithValue(positions),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });

  Future<void> start() async {
    container.read(authProvider);
    container.read(positionAdlProvider);
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'positions are manual; duplicate taps are ignored and errors retain stale snapshot',
    () async {
      await start();
      expect(positions.calls, 0);
      final controller = container.read(positionAdlProvider.notifier);
      await controller.refresh();
      final old = container.read(positionAdlProvider).account;
      expect(old?.symbols.length, 1);
      positions.gate = Completer<void>();
      final pending = controller.refresh();
      await controller.refresh();
      expect(positions.calls, 2);
      positions.failure = const AccountReadFailure('accountNetwork');
      positions.gate!.complete();
      await pending;
      expect(container.read(positionAdlProvider).account, same(old));
      expect(container.read(positionAdlProvider).stale, true);
      expect(container.read(positionAdlProvider).failure?.key, 'accountNetwork');
      positions.failure = null;
      await controller.refresh();
      expect(container.read(positionAdlProvider).stale, false);
    },
  );

  test('wallet disconnection clears snapshot and blocks a pending result', () async {
    await start();
    final controller = container.read(positionAdlProvider.notifier);
    await controller.refresh();
    positions.gate = Completer<void>();
    final pending = controller.refresh();
    identity.events.add(null);
    expect(container.read(positionAdlProvider).account, null);
    positions.gate!.complete();
    await pending;
    expect(container.read(positionAdlProvider).account, null);
    expect(identity.wallets, 0);
  });

  test('wrong-wallet response cannot replace the previous positions', () async {
    await start();
    final controller = container.read(positionAdlProvider.notifier);
    await controller.refresh();
    final old = container.read(positionAdlProvider).account;
    positions.result = positionAdlFixture(address: '0x3333333333333333333333333333333333333333');
    await controller.refresh();
    expect(container.read(positionAdlProvider).account, same(old));
    expect(container.read(positionAdlProvider).failure?.key, 'authWalletChanged');
  });

  test(
    'loss of signing capability clears data and requires reconnect without wallet creation',
    () async {
      await start();
      final controller = container.read(positionAdlProvider.notifier);
      await controller.refresh();
      identity.events.add(
        const AuthIdentity(
          id: 'aster-test',
          walletAddress: accountAddress,
          walletKind: WalletKind.external,
          signingAvailable: false,
        ),
      );
      expect(container.read(positionAdlProvider).account, null);
      await controller.refresh();
      expect(positions.calls, 1);
      expect(container.read(positionAdlProvider).failure?.key, 'authWalletReconnect');
      expect(identity.wallets, 0);
    },
  );

  testWidgets('late refresh after background remains stale and expires after 30s', (tester) async {
    container.read(authProvider);
    await tester.pump();
    positions.gate = Completer<void>();
    final controller = container.read(positionAdlProvider.notifier);
    final pending = controller.refresh();
    controller.markStale();
    positions.gate!.complete();
    await pending;
    expect(container.read(positionAdlProvider).stale, true);
    await controller.refresh();
    expect(container.read(positionAdlProvider).stale, false);
    await tester.pump(const Duration(seconds: 31));
    expect(container.read(positionAdlProvider).stale, true);
    container.dispose();
    container = ProviderContainer();
  });
}
