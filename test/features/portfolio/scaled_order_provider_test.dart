import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/scaled_order_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/scaled_order.dart';

import '../../support/aster_account.dart';
import '../../support/account_changes.dart';

import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/order_recovery_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';

import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/scaled_order.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestScaledRepository repository;
  late DateTime now;
  late TestAccountChangeRepository events;
  ScaledOrderController controller() => container.read(scaledOrderProvider.notifier);
  ScaledOrderState state() => container.read(scaledOrderProvider);
  Future<ScaledOrderIntent> prepare() async {
    await container.read(liveOrderProvider.notifier).load('BTCUSDT');
    return controller().prepare('BTCUSDT', scaledDraft())!;
  }

  setUp(() async {
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestScaledRepository();
    events = TestAccountChangeRepository()..now = liveOrderClock;
    now = liveOrderClock;
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        accountChangeRepositoryProvider.overrideWithValue(events),
        accountChangeClockProvider.overrideWithValue(() => now),
        liveOrderRepositoryProvider.overrideWithValue(repository),
        liveOrderClockProvider.overrideWithValue(() => now),
      ],
    );
    container.read(authProvider);
    container.read(scaledOrderProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
    await events.dispose();
  });
  test('explicit read, exact symbol, invalid draft, stale and future context guards', () async {
    expect(controller().prepare('BTCUSDT', scaledDraft()), null);
    final intent = await prepare();
    expect(intent.valid, true);
    expect(intent.clientIds.toSet().length, 3);
    expect(controller().prepare('ETHUSDT', scaledDraft()), null);
    expect(controller().prepare('BTCUSDT', scaledDraft(count: 111)), null);
    now = now.add(const Duration(seconds: 30));
    expect(controller().prepare('BTCUSDT', scaledDraft()), null);
    await controller().submit(intent);
    expect(repository.posts, isEmpty);
    expect(identity.wallets, 0);
  });
  test('sequential children re-read funds, preserve terms/IDs, and release lock', () async {
    final intent = await prepare();
    await controller().submit(intent);
    expect(repository.reads.length, 4); // initial plus one per child
    expect(repository.includesFunds.every((v) => v), true);
    expect(repository.posts.map((p) => p.clientOrderId), intent.clientIds);
    expect(repository.posts.map((p) => p.draft.price), ['79000', '80000', '81000']);
    expect(repository.posts.map((p) => p.draft.quantity), ['0.003', '0.003', '0.002']);
    expect(
      repository.posts.every(
        (p) => p.parameters['timeInForce'] == 'GTC' && p.parameters['type'] == 'LIMIT',
      ),
      true,
    );
    expect(state().items.every((i) => i.submitted && !i.needsRecheck), true);
    expect(state().busy, false);
    expect(container.read(liveOrderProvider).stale, true);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
    expect(() => state().items.clear(), throwsUnsupportedError);
    await controller().submit(intent); // no replay of confirmed plan
    expect(repository.posts.length, 3);
  });
  test('unknown first child releases lease; recheck only queries its original ID', () async {
    final intent = await prepare();
    repository.unknown = true;
    await controller().submit(intent);
    expect(repository.posts.length, 1);
    expect(state().items.map((i) => i.submitted), [true, false, false]);
    expect(state().needsRecheck, true);
    expect(container.read(symbolSettingsActivityProvider).unresolved, false);
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.leverage);
    expect(lease, isNotNull);
    activity.finish(lease!, unresolved: false);
    await controller().submit(intent);
    expect(repository.posts.length, 1);
    repository.unknown = false;
    await controller().recheck();
    expect(repository.checks.single.clientOrderId, intent.clientIds.first);
    expect(repository.posts.length, 1);
    expect(repository.reads.length, 2);
    expect(state().items.skip(1).every((i) => !i.submitted), true);
    expect(state().needsRecheck, false);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
  });
  test('refused signature preserves all unsent IDs and releases lock', () async {
    final intent = await prepare();
    repository.failure = const AccountReadFailure('authWalletRejected');
    await controller().submit(intent);
    expect(repository.posts, isEmpty);
    expect(state().items.first.failure?.key, 'authWalletRejected');
    expect(state().items.map((i) => i.clientId), intent.clientIds);
    expect(state().needsRecheck, false);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
  });
  for (final status in ['REJECTED', 'CANCELED', 'EXPIRED', 'EXPIRED_IN_MATCH']) {
    test('verified terminal unsuccessful child $status stops remaining plan', () async {
      final intent = await prepare();
      repository.status = status;
      await controller().submit(intent);
      expect(repository.posts.length, 1);
      expect(state().needsRecheck, false);
      expect(state().items.skip(1).every((i) => !i.submitted), true);
    });
  }
  test('stop while signing prevents first POST and cannot resume frozen intent', () async {
    final intent = await prepare();
    repository.signingGate = Completer<void>();
    final future = controller().submit(intent);
    await Future<void>.delayed(Duration.zero);
    expect(state().busy, true);
    controller().stop();
    repository.signingGate!.complete();
    await future;
    expect(repository.posts, isEmpty);
    expect(state().stopRequested, true);
    expect(state().busy, false);
    await controller().submit(intent);
    expect(repository.posts, isEmpty);
  });
  test('stop after sending permits query result but no next child', () async {
    final intent = await prepare();
    repository.afterPost = controller().stop;
    await controller().submit(intent);
    expect(repository.posts.length, 1);
    expect(state().items.first.result?.status, 'NEW');
    expect(state().items.skip(1).every((i) => !i.submitted), true);
    expect(state().stopRequested, true);
  });
  test('stop during private read makes isCurrent false and sends nothing', () async {
    final intent = await prepare();
    repository.readGate = Completer<void>();
    final future = controller().submit(intent);
    await Future<void>.delayed(Duration.zero);
    controller().stop();
    expect(repository.latestCurrent!(), false);
    repository.readGate!.complete();
    await future;
    expect(repository.posts, isEmpty);
  });
  test('per-child context expiry during wallet signature stops before POST', () async {
    final intent = await prepare();
    repository.signingGate = Completer<void>();
    final future = controller().submit(intent);
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 30));
    repository.signingGate!.complete();
    await future;
    expect(repository.posts, isEmpty);
    expect(state().items.first.failure?.key, 'liveOrderContextExpired');
  });
  for (final kind in ['mode', 'asset', 'policy', 'rules']) {
    test('configuration drift $kind stops plan before another POST', () async {
      final intent = await prepare();
      repository.afterPost = () {
        repository.context = switch (kind) {
          'mode' => liveContext(mode: FuturesPositionMode.hedge),
          'asset' => liveContext(assetMode: FuturesAssetMode.multi),
          'policy' => liveContext(policies: {LiveOrderTimeInForce.ioc}),
          _ => scaledContext(rules: scaledRules(types: {'MARKET'})),
        };
      };
      await controller().submit(intent);
      expect(repository.posts.length, 1);
      expect(state().items[1].failure?.key, 'scaledConfigurationChanged');
      expect(state().items[2].submitted, false);
    });
  }
  test('missing fresh funds on next child stops rather than silently continuing', () async {
    final intent = await prepare();
    repository.afterPost = () => repository.context = liveContext(withFunds: false);
    await controller().submit(intent);
    expect(repository.posts.length, 1);
    expect(state().items[1].failure?.key, 'liveOrderReadFunds');
  });
  test('external configuration epoch invalidates an open confirmation', () async {
    final intent = await prepare();
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.leverage)!;
    activity.submitted(lease);
    activity.finish(lease, unresolved: false);
    await controller().submit(intent);
    expect(repository.posts, isEmpty);
  });
  for (final changed in [
    null,
    const AuthIdentity(id: 'another', walletAddress: accountAddress, signingAvailable: true),
    const AuthIdentity(
      id: 'signed',
      walletAddress: accountAddress,
      walletKind: WalletKind.external,
      signingAvailable: false,
    ),
  ]) {
    test('wallet/auth scope change abandons stale callbacks: $changed', () async {
      final intent = await prepare();
      repository.signingGate = Completer<void>();
      final future = controller().submit(intent);
      await Future<void>.delayed(Duration.zero);
      identity.events.add(changed);
      await Future<void>.delayed(Duration.zero);
      repository.signingGate!.complete();
      await future;
      expect(repository.posts, isEmpty);
      expect(state().intent, null);
      expect(state().busy, false);
    });
  }
  test('shared busy owner blocks preparing and submitting', () async {
    final intent = await prepare();
    container.read(symbolSettingsActivityProvider.notifier).acquire(SymbolSetting.leverage);
    expect(controller().prepare('BTCUSDT', scaledDraft()), null);
    await controller().submit(intent);
    expect(repository.posts, isEmpty);
  });
  test('replayed same-time account event during signing still blocks POST', () async {
    await container.read(accountChangeProvider.notifier).authorize();
    final event = AccountChangeEvent.changed(AccountChangeKind.configuration, now);
    events.channels.single.add(event);
    await Future<void>.delayed(Duration.zero);
    final intent = await prepare();
    repository.signingGate = Completer<void>();
    final future = controller().submit(intent);
    await Future<void>.delayed(Duration.zero);
    events.channels.single.add(event);
    await Future<void>.delayed(Duration.zero);
    repository.signingGate!.complete();
    await future;
    expect(repository.posts, isEmpty);
    expect(state().items.first.failure?.key, 'liveOrderContextExpired');
  });
  test('new account event while confirmation open makes old plan unusable', () async {
    await container.read(accountChangeProvider.notifier).authorize();
    final intent = await prepare();
    events.channels.single.add(AccountChangeEvent.changed(AccountChangeKind.order, now));
    await Future<void>.delayed(Duration.zero);
    await controller().submit(intent);
    expect(repository.posts, isEmpty);
    expect(repository.reads.length, 1);
  });
  test('a previous diagnostic record allows fresh scaled submissions', () async {
    final intent = await prepare();
    await container
        .read(orderRecoveryJournalProvider)
        .prepare(OrderRecoveryRecord(query: OrderQuery.capture(liveIntent()), createdAt: now));
    await Future<void>.delayed(Duration.zero);
    expect(controller().prepare('BTCUSDT', scaledDraft()), isNotNull);
    await controller().submit(intent);
    expect(repository.posts.length, 3);
  });
  test('unexpected error after POST stays unknown and permits GET only', () async {
    final intent = await prepare();
    repository.afterPost = () => throw StateError('fixture');
    await controller().submit(intent);
    expect(repository.posts.length, 1);
    expect(state().needsRecheck, true);
    expect(state().items.first.failure?.key, 'accountReadFailed');
    await controller().recheck();
    expect(repository.posts.length, 1);
    expect(repository.checks.length, 1);
    expect(state().needsRecheck, false);
  });
  for (final unit in ScaledSizeUnit.values) {
    for (final count in [6, 110]) {
      test('expanded count keeps original full plan and stops on unknown: $count $unit', () async {
        await container.read(liveOrderProvider.notifier).load('BTCUSDT');
        final intent = controller().prepare(
          'BTCUSDT',
          scaledDraft(
            count: count,
            unit: unit,
            quantity: unit == ScaledSizeUnit.base
                ? (count == 6 ? '0.012' : '0.22')
                : (count == 6 ? '960' : '17600'),
          ),
        );
        expect(intent, isNotNull);
        expect(intent!.valid, true);
        expect(intent.clientIds.toSet().length, count);
        expect(intent.clientIds.every((id) => id.length <= 36), true);
        repository.unknown = true;
        await controller().submit(intent);
        expect(state().items.length, count);
        expect(repository.posts.length, 1);
        expect(state().items.skip(1).every((i) => !i.submitted), true);
        repository.unknown = false;
        await controller().recheck();
        expect(repository.posts.length, 1);
        expect(repository.checks.single.clientOrderId, intent.clientIds.first);
        expect(repository.checks.single.draft.quantity, intent.plan.orders.first.quantity);
        expect(state().needsRecheck, false);
        expect(identity.wallets, 0);
      });
    }
  }
  for (final distribution in [ScaledDistribution.increasing, ScaledDistribution.random]) {
    test('weighted plan never resizes or resamples after funds read: $distribution', () async {
      repository.context = liveContext(available: '1000');
      await container.read(liveOrderProvider.notifier).load('BTCUSDT');
      final intent = controller().prepare(
        'BTCUSDT',
        scaledDraft(
          unit: ScaledSizeUnit.quote,
          quantity: '2400',
          distribution: distribution,
          seed: 42,
        ),
      )!;
      final quantities = intent.plan.orders.map((o) => o.quantity).toList();
      repository.afterPost = () {
        repository.context = liveContext(available: '900');
      };
      await controller().submit(intent);
      expect(repository.posts.map((o) => o.draft.quantity), quantities);
      expect(repository.posts.map((o) => o.clientOrderId), intent.clientIds);
      expect(intent.valid, true);
    });
  }
}
