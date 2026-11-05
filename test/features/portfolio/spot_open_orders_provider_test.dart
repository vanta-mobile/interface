import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/spot_account_change_provider.dart';
import 'package:vanta/features/portfolio/application/spot_open_orders_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/account_changes.dart';
import '../../support/identity_repository.dart';
import '../../support/spot_open_orders.dart';
import 'spot_open_orders_events_test.dart' show spotUpdate;

void main() {
  late ProviderContainer c;
  late TestSpotOpenOrdersRepository repository;
  late TestIdentityRepository identity;
  late TestAccountChangeRepository events;
  final now = DateTime.utc(2026, 11, 4, 8);
  SpotOpenOrdersController controller() => c.read(spotOpenOrdersProvider.notifier);
  void spotTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      repository = TestSpotOpenOrdersRepository();
      identity = TestIdentityRepository()..restored = signingIdentity;
      events = TestAccountChangeRepository()..now = now;
      c = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          spotOpenOrdersRepositoryProvider.overrideWithValue(repository),
          spotAccountChangeRepositoryProvider.overrideWithValue(events),
          accountChangeClockProvider.overrideWithValue(() => now),
        ],
      );
      c.read(authProvider);
      c.read(spotOpenOrdersProvider);
      await tester.pump();
      try {
        await body(tester);
      } finally {
        c.dispose();
        await identity.dispose();
        await events.dispose();
      }
    });
  }

  spotTest('no automatic reads; signed baseline clears pending spinner and uses current wallet', (
    tester,
  ) async {
    expect(repository.calls, 0);
    await controller().refresh();
    expect(repository.calls, 1);
    expect(c.read(spotOpenOrdersProvider).account!.orders.length, 2);
    expect(c.read(spotOpenOrdersProvider).busy, false);
    expect(identity.wallets, 0);
  });
  spotTest('restored EOA needs reconnection without generating another wallet', (tester) async {
    identity.events.add(
      const AuthIdentity(
        id: 'aster-test',
        walletAddress: accountAddress,
        walletKind: WalletKind.external,
      ),
    );
    await tester.pump();
    await controller().refresh();
    expect(repository.calls, 0);
    expect(c.read(spotOpenOrdersProvider).failure!.key, 'authWalletReconnect');
    expect(identity.wallets, 0);
  });
  spotTest('failure retains stale rows and hides raw transport errors', (tester) async {
    await controller().refresh();
    final old = c.read(spotOpenOrdersProvider).account;
    repository.failure = StateError('private payload');
    await controller().refresh();
    final state = c.read(spotOpenOrdersProvider);
    expect(state.account, same(old));
    expect(state.stale, true);
    expect(state.failure!.key, 'accountReadFailed');
  });
  spotTest('stop discards late read and busy repeated refresh cannot prompt twice', (tester) async {
    repository.gate = Completer();
    final pending = controller().refresh();
    await controller().refresh();
    expect(repository.calls, 1);
    controller().stopRead();
    expect(repository.current!(), false);
    repository.gate!.complete();
    await pending;
    expect(c.read(spotOpenOrdersProvider).account, null);
  });
  spotTest('wrong wallet response does not leak another account', (tester) async {
    repository.result = spotOrdersFixture(address: '0x3333333333333333333333333333333333333333');
    await controller().refresh();
    expect(c.read(spotOpenOrdersProvider).account, null);
    expect(c.read(spotOpenOrdersProvider).failure!.key, 'authWalletChanged');
  });
  spotTest('events alone never establish an account baseline', (tester) async {
    controller().applyEvent(spotUpdate());
    expect(c.read(spotOpenOrdersProvider).account, null);
    expect(repository.calls, 0);
    repository.result = spotOrdersFixture(rows: []);
    await controller().refresh();
    expect(c.read(spotOpenOrdersProvider).account!.orders, isEmpty);
  });
  spotTest('partial fill during REST read is reapplied; same-time replay keeps snapshot stale', (
    tester,
  ) async {
    repository.gate = Completer();
    final pending = controller().refresh();
    controller().applyEvent(spotUpdate());
    repository.gate!.complete();
    await pending;
    expect(c.read(spotOpenOrdersProvider).account!.orders.first.executed.toString(), '0.01');
    expect(c.read(spotOpenOrdersProvider).stale, true);
    controller().applyEvent(spotUpdate());
    expect(c.read(spotOpenOrdersProvider).stale, true);
  });
  spotTest('terminal event during read prevents stale REST revival on later reads', (tester) async {
    repository.gate = Completer();
    final pending = controller().refresh();
    controller().applyEvent(spotUpdate(status: 'CANCELED'));
    repository.gate!.complete();
    await pending;
    expect(c.read(spotOpenOrdersProvider).account!.orders.length, 1);
    await controller().refresh();
    expect(c.read(spotOpenOrdersProvider).account!.orders.length, 1);
  });
  spotTest('expiry marks stale without any new signature or network read', (tester) async {
    await controller().refresh();
    await tester.pump(const Duration(seconds: 30));
    expect(c.read(spotOpenOrdersProvider).stale, true);
    expect(repository.calls, 1);
  });
  spotTest('Spot stream routes typed updates; disconnect preserves rows and marks stale', (
    tester,
  ) async {
    await controller().refresh();
    await c.read(spotAccountChangeProvider.notifier).authorize();
    events.channels.single.add(
      AccountChangeEvent.changed(AccountChangeKind.order, now, spotOrder: spotUpdate()),
    );
    await tester.pump();
    expect(c.read(spotOpenOrdersProvider).account!.orders.first.executed.toString(), '0.01');
    events.channels.single.addError(const AccountReadFailure('accountNetwork'));
    await tester.pump();
    expect(c.read(spotOpenOrdersProvider).account!.orders.length, 2);
    expect(c.read(spotOpenOrdersProvider).stale, true);
    expect(repository.calls, 1);
  });
  for (final change in ['logout', 'address', 'kind']) {
    spotTest('$change clears private rows and terminal event book before another wallet read', (
      tester,
    ) async {
      await controller().refresh();
      controller().applyEvent(spotUpdate(status: 'CANCELED'));
      identity.events.add(
        change == 'logout'
            ? null
            : AuthIdentity(
                id: 'other',
                walletAddress: change == 'address'
                    ? '0x3333333333333333333333333333333333333333'
                    : accountAddress,
                walletKind: WalletKind.embedded,
                signingAvailable: true,
              ),
      );
      await tester.pump();
      expect(c.read(spotOpenOrdersProvider).account, null);
      if (change != 'logout') {
        await controller().refresh();
        expect(c.read(spotOpenOrdersProvider).account!.orders.length, 2);
      }
    });
  }
}
