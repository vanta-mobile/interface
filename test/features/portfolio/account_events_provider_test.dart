import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/account_update.dart';

import '../../support/account_changes.dart';
import '../../support/account_updates.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/position_risk.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestAccountChangeRepository changes;
  late TestAsterAccountRepository account;
  late TestPositionRiskRepository risk;
  setUp(() async {
    identity = TestIdentityRepository()..restored = signingIdentity;
    changes = TestAccountChangeRepository();
    account = TestAsterAccountRepository();
    risk = TestPositionRiskRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        accountChangeRepositoryProvider.overrideWithValue(changes),
        accountChangeClockProvider.overrideWithValue(() => changes.now),
        asterAccountRepositoryProvider.overrideWithValue(account),
        positionRiskRepositoryProvider.overrideWithValue(risk),
      ],
    );
    container.read(authProvider);
    container.read(accountChangeProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
    await changes.dispose();
  });
  Future<void> monitor() async {
    await container.read(accountChangeProvider.notifier).authorize();
    changes.channels.last.add(const AccountChangeEvent.connected());
  }

  Future<void> read() async {
    await container.read(accountReadProvider.notifier).refresh();
    await container.read(positionRiskProvider.notifier).refresh();
  }

  void emit([AccountUpdate? event]) {
    final update = event ?? accountUpdate();
    changes.channels.last.add(
      AccountChangeEvent.changed(AccountChangeKind.account, update.eventTime, account: update),
    );
  }

  test(
    'events require explicit signed baseline and never create a complete account by themselves',
    () async {
      await monitor();
      emit();
      expect(container.read(accountReadProvider).account, null);
      expect(container.read(positionRiskProvider).account, null);
      expect(account.calls, 0);
      expect(risk.calls, 0);
      await read();
      expect(
        container.read(accountReadProvider).account!.assets.first.walletBalance.toString(),
        '102.000000000000000001',
      );
      expect(
        container.read(positionRiskProvider).account!.positions.first.quantity.toString(),
        '-0.2',
      );
      expect(container.read(positionRiskProvider).stale, true);
      expect(identity.wallets, 0);
      expect(changes.authorizations, 1);
    },
  );
  test(
    'live updates reach both views and preserve unrelated rows with stale completeness',
    () async {
      await read();
      await monitor();
      emit();
      final a = container.read(accountReadProvider);
      final p = container.read(positionRiskProvider);
      expect(a.account!.positions.single.quantity.toString(), '-0.2');
      expect(p.account!.positions.first.quantity.toString(), '-0.2');
      expect(a.account!.assets.last.asset, 'BNB');
      expect(p.account!.positions.last.symbol, 'ETHUSDT');
      expect(a.stale && p.stale, true);
      expect(account.calls, 1);
      expect(risk.calls, 1);
      expect(identity.wallets, 0);
    },
  );
  test('events during reads survive late REST progress and reconcile returned values', () async {
    await read();
    await monitor();
    account.gate = Completer<void>();
    risk.gate = Completer<void>();
    final a = container.read(accountReadProvider.notifier).refresh();
    final p = container.read(positionRiskProvider.notifier).refresh();
    emit();
    expect(container.read(accountReadProvider).busy, true);
    expect(
      container.read(accountReadProvider).account!.assets.first.walletBalance.toString(),
      '102.000000000000000001',
    );
    account.gate!.complete();
    risk.gate!.complete();
    await Future.wait([a, p]);
    expect(
      container.read(accountReadProvider).account!.assets.first.walletBalance.toString(),
      '102.000000000000000001',
    );
    expect(
      container.read(positionRiskProvider).account!.positions.first.quantity.toString(),
      '-0.2',
    );
    expect(container.read(accountReadProvider).stale, true);
    expect(container.read(positionRiskProvider).stale, true);
  });
  test(
    'failed reads preserve event-updated values instead of restoring captured old snapshots',
    () async {
      await read();
      await monitor();
      account.gate = Completer<void>();
      risk.gate = Completer<void>();
      final a = container.read(accountReadProvider.notifier).refresh();
      final p = container.read(positionRiskProvider.notifier).refresh();
      emit();
      account.failure = risk.failure = const AccountReadFailure('accountNetwork');
      account.gate!.complete();
      risk.gate!.complete();
      await Future.wait([a, p]);
      expect(container.read(accountReadProvider).failure?.key, 'accountNetwork');
      expect(
        container.read(accountReadProvider).account!.assets.first.walletBalance.toString(),
        '102.000000000000000001',
      );
      expect(
        container.read(positionRiskProvider).account!.positions.first.quantity.toString(),
        '-0.2',
      );
    },
  );
  test(
    'fresh per-record REST clocks beat cached events and restore complete risk fields',
    () async {
      await read();
      await monitor();
      emit();
      final payload = accountPayload();
      (payload['assets']! as List).first['updateTime'] = accountEventClock + 10;
      (payload['positions']! as List).first['updateTime'] = accountEventClock + 10;
      account.result = mapAsterAccount(
        payload,
        address: accountAddress,
        receivedAt: DateTime.utc(2026, 11, 3),
      );
      risk.result = mapPositionRisk(
        [positionRiskRow()..['updateTime'] = accountEventClock + 10],
        address: accountAddress,
        receivedAt: account.result.receivedAt,
      );
      await read();
      expect(container.read(accountReadProvider).stale, false);
      expect(container.read(positionRiskProvider).stale, false);
      expect(container.read(positionRiskProvider).account!.positions.single.leverage, 5);
      emit(accountUpdate(time: accountEventClock + 2));
      expect(container.read(positionRiskProvider).account!.positions.single.leverage, 5);
      expect(container.read(accountReadProvider).account!.walletBalance, isNotNull);
    },
  );
  test('closed position cannot be revived by older REST but newer reopening is applied', () async {
    await read();
    await monitor();
    emit(
      accountUpdate(
        positions: [accountPositionUpdate(quantity: '0', wallet: '0')],
      ),
    );
    await read();
    expect(container.read(positionRiskProvider).account!.positions.single.symbol, 'ETHUSDT');
    expect(container.read(accountReadProvider).account!.positions, isEmpty);
    emit(accountUpdate(time: accountEventClock + 1));
    expect(container.read(positionRiskProvider).account!.positions.last.symbol, 'BTCUSDT');
    expect(container.read(accountReadProvider).account!.positions.single.symbol, 'BTCUSDT');
  });
  test(
    'disconnect and background preserve event-adjusted rows without replaying reads or signatures',
    () async {
      await read();
      await monitor();
      emit();
      final before = container.read(positionRiskProvider).account;
      changes.channels.last.addError(StateError('private payload'));
      container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
      container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
      changes.channels.last.add(const AccountChangeEvent.connected());
      expect(container.read(positionRiskProvider).account, same(before));
      expect(container.read(positionRiskProvider).stale, true);
      expect(account.calls, 1);
      expect(risk.calls, 1);
      expect(changes.authorizations, 1);
    },
  );
  test(
    'logout clears both ledgers and prevents pending results leaking into a restored session',
    () async {
      await read();
      await monitor();
      emit();
      risk.gate = Completer<void>();
      final pending = container.read(positionRiskProvider.notifier).refresh();
      identity.events.add(null);
      risk.gate!.complete();
      await pending;
      expect(container.read(accountReadProvider).account, null);
      expect(container.read(positionRiskProvider).account, null);
      await container.read(authProvider.notifier).bootstrap();
      await read();
      expect(container.read(accountReadProvider).account!.lastEventAt, null);
      expect(container.read(positionRiskProvider).account!.lastEventAt, null);
      expect(container.read(positionRiskProvider).stale, false);
    },
  );
  test(
    'conflicting identical timestamps stop monitoring safely without replacing displayed values',
    () async {
      await read();
      await monitor();
      emit();
      final before = container.read(accountReadProvider).account;
      emit(accountUpdate(balances: [accountBalanceUpdate(wallet: '999')]));
      expect(
        container.read(accountChangeProvider).connection,
        AccountChangeConnection.disconnected,
      );
      expect(container.read(accountChangeProvider).failure?.key, 'accountDataInvalid');
      expect(container.read(accountReadProvider).account, same(before));
      expect(changes.canceled, 1);
    },
  );
}
