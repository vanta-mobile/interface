import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/application/position_adl_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/account_changes.dart';
import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/identity_repository.dart';
import '../../support/position_adl.dart';
import '../../support/position_risk.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestAccountChangeRepository changes;
  late TestPositionRiskRepository risk;
  late TestAsterAccountRepository account;
  late TestOpenOrdersRepository orders;
  late TestPositionAdlRepository adl;
  setUp(() {
    identity = TestIdentityRepository()..restored = signingIdentity;
    changes = TestAccountChangeRepository();
    risk = TestPositionRiskRepository();
    account = TestAsterAccountRepository();
    orders = TestOpenOrdersRepository();
    adl = TestPositionAdlRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        accountChangeRepositoryProvider.overrideWithValue(changes),
        accountChangeClockProvider.overrideWithValue(() => changes.now),
        positionRiskRepositoryProvider.overrideWithValue(risk),
        asterAccountRepositoryProvider.overrideWithValue(account),
        asterOpenOrdersRepositoryProvider.overrideWithValue(orders),
        positionAdlRepositoryProvider.overrideWithValue(adl),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
    await changes.dispose();
  });
  Future<void> start() async {
    container.read(authProvider);
    container.read(accountChangeProvider);
    await Future<void>.delayed(Duration.zero);
  }

  AccountChangeController controller() => container.read(accountChangeProvider.notifier);
  AccountChangeState state() => container.read(accountChangeProvider);
  Future<void> readSnapshots() async {
    await container.read(accountReadProvider.notifier).refresh();
    await container.read(openOrdersReadProvider.notifier).refresh();
    await container.read(positionRiskProvider.notifier).refresh();
    await container.read(positionAdlProvider.notifier).refresh();
  }

  void expectStale(bool stale) {
    expect(container.read(accountReadProvider).stale, stale);
    expect(container.read(openOrdersReadProvider).stale, stale);
    expect(container.read(positionRiskProvider).stale, stale);
    expect(container.read(positionAdlProvider).stale, stale);
  }

  test('monitoring is explicit; connection never signs or refreshes snapshots', () async {
    await start();
    expect(changes.authorizations, 0);
    expect(changes.channels, isEmpty);
    await readSnapshots();
    expectStale(false);
    final original = container.read(positionRiskProvider).account;
    await controller().authorize();
    expectStale(true);
    changes.channels.single.add(const AccountChangeEvent.connected());
    expect(state().connection, AccountChangeConnection.connected);
    expect(container.read(positionRiskProvider).account, same(original));
    expect(risk.calls, 1);
    expect(changes.authorizations, 1);
    expect(identity.wallets, 0);
  });
  test(
    'every event invalidates all futures snapshots without merging partial financial payloads',
    () async {
      await start();
      await controller().authorize();
      changes.channels.single.add(const AccountChangeEvent.connected());
      for (final kind in AccountChangeKind.values) {
        await readSnapshots();
        expectStale(false);
        final original = container.read(accountReadProvider).account;
        changes.channels.single.add(AccountChangeEvent.changed(kind, DateTime.utc(2026, 11, 3)));
        expectStale(true);
        expect(container.read(accountReadProvider).account, same(original));
      }
      expect(changes.authorizations, 1);
      expect(account.calls, AccountChangeKind.values.length);
    },
  );
  test('out-of-order and duplicate E still invalidate in-flight reads and latest displayed time never regresses', () async {
    await start();
    await controller().authorize();
    changes.channels.single.add(const AccountChangeEvent.connected());
    final latest = DateTime.utc(2026, 11, 3);
    changes.channels.single.add(AccountChangeEvent.changed(AccountChangeKind.account, latest));
    risk.gate = Completer<void>();
    final pending = container.read(positionRiskProvider.notifier).refresh();
    changes.channels.single.add(
      AccountChangeEvent.changed(
        AccountChangeKind.account,
        latest.subtract(const Duration(seconds: 1)),
      ),
    );
    changes.channels.single.add(AccountChangeEvent.changed(AccountChangeKind.account, latest));
    risk.gate!.complete();
    await pending;
    expect(container.read(positionRiskProvider).stale, true);
    expect(state().lastEventAt, latest);
    expect(changes.authorizations, 1);
  });
  test('disconnect requires manual no-sign reconnect; background resume reuses lease and preserves stale flags', () async {
    await start();
    await controller().authorize();
    changes.channels.last.add(const AccountChangeEvent.connected());
    await readSnapshots();
    changes.channels.last.addError(StateError('secret must not escape'));
    expect(state().failure?.key, 'accountNetwork');
    expect(state().connection, AccountChangeConnection.disconnected);
    expectStale(true);
    expect(changes.channels.length, 1);
    controller().reconnect();
    expect(changes.channels.length, 2);
    changes.channels.last.add(const AccountChangeEvent.connected());
    await readSnapshots();
    container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    expect(state().connection, AccountChangeConnection.paused);
    expectStale(true);
    container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    expect(changes.channels.length, 3);
    changes.channels.last.add(const AccountChangeEvent.connected());
    expectStale(true);
    expect(changes.authorizations, 1);
    expect(changes.canceled, 2);
    expect(risk.calls, 2);
  });
  test('logout or stop during signing discards result and never reopens connection', () async {
    await start();
    for (final logout in [false, true]) {
      changes.gate = Completer<void>();
      final pending = controller().authorize();
      await controller().authorize();
      if (logout) {
        identity.events.add(null);
      } else {
        controller().stop();
      }
      changes.gate!.complete();
      await pending;
      expect(changes.channels, isEmpty);
      expect(state().connection, AccountChangeConnection.stopped);
    }
    expect(changes.authorizations, 2);
    expect(identity.wallets, 0);
  });
  test('refusal preserves snapshots as historical and never connects', () async {
    await start();
    await readSnapshots();
    changes.failure = const AccountReadFailure('authWalletRejected');
    await controller().authorize();
    expect(state().failure?.key, 'authWalletRejected');
    expect(changes.channels, isEmpty);
    expectStale(true);
    expect(container.read(accountReadProvider).account, isNotNull);
  });
  test(
    'expiry event clears key, closes stream and cannot be revived by background resume',
    () async {
      await start();
      await controller().authorize();
      changes.channels.last.add(const AccountChangeEvent.connected());
      changes.channels.last.add(const AccountChangeEvent.expired());
      expect(state().connection, AccountChangeConnection.expired);
      container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
      container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
      expect(changes.channels.length, 1);
      expect(changes.canceled, 1);
    },
  );
  testWidgets('renewal reminder at 50 minutes and hard expiry at 60 never sign automatically', (
    tester,
  ) async {
    container.read(authProvider);
    container.read(accountChangeProvider);
    await tester.pump();
    await controller().authorize();
    changes.channels.last.add(const AccountChangeEvent.connected());
    changes.now = changes.now.add(const Duration(minutes: 50));
    await tester.pump(const Duration(minutes: 50));
    expect(state().renewalDue, true);
    expect(state().connection, AccountChangeConnection.connected);
    expect(changes.authorizations, 1);
    changes.now = changes.now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(minutes: 10));
    expect(state().connection, AccountChangeConnection.expired);
    expect(changes.authorizations, 1);
    expect(changes.canceled, 1);
    container.dispose();
    container = ProviderContainer();
  });
}
