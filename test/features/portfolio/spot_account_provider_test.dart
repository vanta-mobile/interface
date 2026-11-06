import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/spot_account_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/aster_spot_account.dart';
import '../../support/identity_repository.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestSpotRepository spots;
  late TestAsterAccountRepository perps;
  setUp(() {
    identity = TestIdentityRepository()..restored = signingIdentity;
    spots = TestSpotRepository();
    perps = TestAsterAccountRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        asterSpotRepositoryProvider.overrideWithValue(spots),
        asterAccountRepositoryProvider.overrideWithValue(perps),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });

  Future<void> start() async {
    container.read(authProvider);
    container.read(spotAccountReadProvider);
    container.read(accountReadProvider);
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'Perp and Spot are independently manual; failure retains only its own stale snapshot',
    () async {
      await start();
      expect(spots.calls, 0);
      await container.read(accountReadProvider.notifier).refresh();
      expect(spots.calls, 0);
      await container.read(spotAccountReadProvider.notifier).refresh();
      final previous = container.read(spotAccountReadProvider).account;
      expect(perps.calls, 1);
      spots.gate = Completer<void>();
      final controller = container.read(spotAccountReadProvider.notifier);
      final pending = controller.refresh();
      final duplicate = controller.refresh();
      expect(spots.calls, 2);
      spots.failure = const AccountReadFailure('accountNetwork');
      spots.gate!.complete();
      await Future.wait([pending, duplicate]);
      expect(container.read(spotAccountReadProvider).account, same(previous));
      expect(container.read(spotAccountReadProvider).stale, true);
      expect(container.read(spotAccountReadProvider).failure?.key, 'accountNetwork');
      expect(container.read(accountReadProvider).stale, false);
      spots.failure = null;
      await controller.refresh();
      expect(container.read(spotAccountReadProvider).failure, null);
      expect(container.read(spotAccountReadProvider).stale, false);
    },
  );

  test('logout clears both snapshots and discards a pending Spot read', () async {
    await start();
    await container.read(accountReadProvider.notifier).refresh();
    final controller = container.read(spotAccountReadProvider.notifier);
    await controller.refresh();
    spots.gate = Completer<void>();
    final pending = controller.refresh();
    identity.events.add(null);
    expect(container.read(accountReadProvider).account, null);
    expect(container.read(spotAccountReadProvider).account, null);
    spots.gate!.complete();
    await pending;
    expect(container.read(spotAccountReadProvider).account, null);
    expect(identity.wallets, 0);
  });

  testWidgets('backgrounding during a pending read leaves its eventual result stale', (
    tester,
  ) async {
    container.read(authProvider);
    await tester.pump();
    spots.gate = Completer<void>();
    final controller = container.read(spotAccountReadProvider.notifier);
    final pending = controller.refresh();
    controller.markStale();
    spots.gate!.complete();
    await pending;
    expect(container.read(spotAccountReadProvider).stale, true);
    await controller.refresh();
    expect(container.read(spotAccountReadProvider).stale, false);
    await tester.pump(const Duration(seconds: 31));
    expect(container.read(spotAccountReadProvider).stale, true);
    expect(spots.calls, 2);
    container.dispose();
    container = ProviderContainer();
  });

  test('an account returned for a different wallet cannot replace the previous snapshot', () async {
    await start();
    final controller = container.read(spotAccountReadProvider.notifier);
    await controller.refresh();
    final previous = container.read(spotAccountReadProvider).account;
    spots.result = spotFixture(address: '0x3333333333333333333333333333333333333333');
    await controller.refresh();
    expect(container.read(spotAccountReadProvider).account, same(previous));
    expect(container.read(spotAccountReadProvider).failure?.key, 'authWalletChanged');
  });
}
