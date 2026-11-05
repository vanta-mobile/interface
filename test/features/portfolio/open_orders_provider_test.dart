import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/identity_repository.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestOpenOrdersRepository orders;
  setUp(() {
    identity = TestIdentityRepository()..restored = signingIdentity;
    orders = TestOpenOrdersRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        asterOpenOrdersRepositoryProvider.overrideWithValue(orders),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });

  Future<void> start() async {
    container.read(authProvider);
    container.read(openOrdersReadProvider);
    await Future<void>.delayed(Duration.zero);
  }

  test('orders are manual; duplicate taps are ignored and errors retain stale snapshot', () async {
    await start();
    expect(orders.calls, 0);
    final controller = container.read(openOrdersReadProvider.notifier);
    await controller.refresh();
    final old = container.read(openOrdersReadProvider).account;
    expect(old?.orders.length, 2);
    orders.gate = Completer<void>();
    final pending = controller.refresh();
    await controller.refresh();
    expect(orders.calls, 2);
    orders.failure = const AccountReadFailure('accountNetwork');
    orders.gate!.complete();
    await pending;
    expect(container.read(openOrdersReadProvider).account, same(old));
    expect(container.read(openOrdersReadProvider).stale, true);
    expect(container.read(openOrdersReadProvider).failure?.key, 'accountNetwork');
    orders.failure = null;
    await controller.refresh();
    expect(container.read(openOrdersReadProvider).stale, false);
  });

  test('wallet disconnection clears snapshot and blocks a pending result', () async {
    await start();
    final controller = container.read(openOrdersReadProvider.notifier);
    await controller.refresh();
    orders.gate = Completer<void>();
    final pending = controller.refresh();
    identity.events.add(null);
    expect(container.read(openOrdersReadProvider).account, null);
    orders.gate!.complete();
    await pending;
    expect(container.read(openOrdersReadProvider).account, null);
    expect(identity.wallets, 0);
  });

  test('wrong-wallet response cannot replace the previous orders', () async {
    await start();
    final controller = container.read(openOrdersReadProvider.notifier);
    await controller.refresh();
    final old = container.read(openOrdersReadProvider).account;
    orders.result = openOrdersFixture(address: '0x3333333333333333333333333333333333333333');
    await controller.refresh();
    expect(container.read(openOrdersReadProvider).account, same(old));
    expect(container.read(openOrdersReadProvider).failure?.key, 'authWalletChanged');
  });

  testWidgets('late refresh after background remains stale and expires after 30s', (tester) async {
    container.read(authProvider);
    await tester.pump();
    orders.gate = Completer<void>();
    final controller = container.read(openOrdersReadProvider.notifier);
    final pending = controller.refresh();
    controller.markStale();
    orders.gate!.complete();
    await pending;
    expect(container.read(openOrdersReadProvider).stale, true);
    await controller.refresh();
    expect(container.read(openOrdersReadProvider).stale, false);
    await tester.pump(const Duration(seconds: 31));
    expect(container.read(openOrdersReadProvider).stale, true);
    container.dispose();
    container = ProviderContainer();
  });
}
