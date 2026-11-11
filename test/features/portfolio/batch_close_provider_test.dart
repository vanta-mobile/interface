import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/batch_close_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/batch_close.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';

import '../../support/aster_account.dart';
import '../../support/batch_close.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/position_risk.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestPositionRiskRepository risk;
  late TestBatchLiveRepository repository;
  late DateTime now;
  setUp(() async {
    now = liveOrderClock;
    identity = TestIdentityRepository()..restored = signingIdentity;
    risk = TestPositionRiskRepository()..result = batchRiskFixture();
    repository = TestBatchLiveRepository(risk.result);
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        liveOrderRepositoryProvider.overrideWithValue(repository),
        liveOrderClockProvider.overrideWithValue(() => now),
        positionRiskRepositoryProvider.overrideWithValue(risk),
      ],
    );
    container.read(authProvider);
    container.read(batchCloseProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });
  BatchCloseController controller() => container.read(batchCloseProvider.notifier);
  BatchCloseState state() => container.read(batchCloseProvider);
  Future<BatchCloseIntent> prepare({String? symbol}) async {
    await container.read(positionRiskProvider.notifier).refresh();
    return controller().prepare(symbol: symbol)!;
  }

  test('explicit complete fresh snapshot required; scope excludes zero balance record', () async {
    expect(controller().prepare(), null);
    final intent = await prepare();
    expect(intent.targets.map((t) => t.key), ['BTCUSDT:BOTH', 'ETHUSDT:BOTH']);
    expect(intent.validTargets, true);
    expect(intent.targets.map((t) => t.clientOrderId).toSet().length, 2);
    expect(() => intent.targets.clear(), throwsUnsupportedError);
    expect(controller().prepare(symbol: 'BTCUSDT')!.targets.length, 1);
    expect(controller().prepare(symbol: 'MISSING'), null);
    expect(controller().prepare(symbol: 'ZEROUSDT'), null);
    expect(repository.reads, isEmpty);
    expect(repository.posts, isEmpty);
    expect(identity.wallets, 0);
    now = now.add(const Duration(seconds: 30));
    expect(controller().prepare(), null);
  });
  test(
    'sequential exact market close per side, frozen IDs and final signed position read',
    () async {
      final intent = await prepare();
      risk.result = PositionRiskSnapshot(address: accountAddress, receivedAt: now, positions: []);
      await controller().submit(intent);
      expect(repository.reads, ['BTCUSDT', 'ETHUSDT']);
      expect(repository.posts.map((p) => p.draft.quantity), ['0.01', '0.02']);
      expect(repository.posts.map((p) => p.side), ['SELL', 'BUY']);
      expect(
        repository.posts.map((p) => p.clientOrderId),
        intent.targets.map((t) => t.clientOrderId),
      );
      expect(repository.posts.every((p) => p.parameters['reduceOnly'] == 'true'), true);
      expect(
        repository.posts.every((p) => p.parameters['closePosition'] == null && p.draft.market),
        true,
      );
      expect(state().items.values.every((i) => i.result?.status == 'FILLED'), true);
      expect(state().remainingAfter, now);
      expect(state().busy, false);
      expect(risk.calls, 2);
      expect(container.read(positionRiskProvider).stale, false);
      expect(container.read(symbolSettingsActivityProvider).owner, null);
      expect(() => state().items.clear(), throwsUnsupportedError);
    },
  );
  test('current-symbol confirmation never expands to another symbol', () async {
    final intent = await prepare(symbol: 'BTCUSDT');
    await controller().submit(intent);
    expect(repository.posts.map((p) => p.context.symbol), ['BTCUSDT']);
    expect(state().intent!.symbol, 'BTCUSDT');
  });
  test('hedge close preserves original LONG/SHORT and excludes reduceOnly', () async {
    risk.result = batchRiskFixture(hedge: true);
    repository.contexts
      ..clear()
      ..addAll(batchContexts(risk.result, hedge: true));
    final intent = await prepare();
    await controller().submit(intent);
    expect(repository.posts.map((p) => '${p.context.symbol}:${p.positionSide}:${p.side}'), [
      'BTCUSDT:LONG:SELL',
      'BTCUSDT:SHORT:BUY',
      'ETHUSDT:LONG:SELL',
    ]);
    expect(repository.posts.every((p) => !p.parameters.containsKey('reduceOnly')), true);
  });
  test('changed position before confirmation invalidates whole old scope', () async {
    final intent = await prepare();
    risk.result = batchRiskFixture(btcQuantity: '0.009');
    await container.read(positionRiskProvider.notifier).refresh();
    await controller().submit(intent);
    expect(repository.reads, isEmpty);
  });
  test('stale and expired confirmations cannot start any signatures', () async {
    var intent = await prepare();
    container.read(positionRiskProvider.notifier).markStale();
    await controller().submit(intent);
    expect(repository.reads, isEmpty);
    intent = await prepare();
    now = now.add(const Duration(seconds: 30));
    await controller().submit(intent);
    expect(repository.reads, isEmpty);
  });
  test('configuration epoch change invalidates old batch confirmation', () async {
    final intent = await prepare();
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.leverage)!;
    activity.submitted(lease);
    activity.finish(lease, unresolved: false);
    await controller().submit(intent);
    expect(repository.reads, isEmpty);
  });
  test(
    'changed quantity in per-position preflight is retained as failure; no silent resize',
    () async {
      final intent = await prepare();
      repository.contexts['BTCUSDT'] = batchContexts(
        batchRiskFixture(btcQuantity: '0.009'),
      )['BTCUSDT']!;
      await controller().submit(intent);
      expect(repository.posts, isEmpty);
      expect(state().items['BTCUSDT:BOTH']!.failure!.key, 'liveClosePositionChanged');
      expect(state().items['ETHUSDT:BOTH']!.submitted, false);
      expect(state().needsRecheck, false);
      expect(risk.calls, 1);
    },
  );
  test('invalid exact whole-position quantity is not floored or split automatically', () async {
    risk.result = batchRiskFixture(btcQuantity: '0.0109');
    repository.contexts
      ..clear()
      ..addAll(batchContexts(risk.result));
    final intent = await prepare();
    await controller().submit(intent);
    expect(repository.posts, isEmpty);
    expect(state().items['BTCUSDT:BOTH']!.failure!.key, 'liveOrderQuantityFilter');
  });
  test('refused signature before POST stops all further submissions and prompts', () async {
    final intent = await prepare();
    repository.failure = const AccountReadFailure('authWalletRejected');
    await controller().submit(intent);
    expect(repository.posts, isEmpty);
    expect(state().items.values.first.failure!.key, 'authWalletRejected');
    expect(repository.reads.length, 1);
    expect(risk.calls, 1);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
  });
  test('unknown outcome releases trade settings; explicit recovery queries original ID', () async {
    final intent = await prepare();
    repository.unknown = true;
    await controller().submit(intent);
    expect(repository.posts.length, 1);
    expect(state().needsRecheck, true);
    expect(container.read(symbolSettingsActivityProvider).unresolved, false);
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    for (final setting in [SymbolSetting.order, SymbolSetting.leverage]) {
      final lease = activity.acquire(setting);
      expect(lease, isNotNull);
      activity.finish(lease!, unresolved: false);
    }
    repository.unknown = false;
    await controller().recheck();
    expect(state().needsRecheck, false);
    expect(repository.posts.length, 1);
    expect(repository.reads.length, 1);
    expect(repository.checks.last.clientOrderId, intent.targets.first.clientOrderId);
    expect(state().items['ETHUSDT:BOTH']!.submitted, false);
    expect(risk.calls, 1);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
  });
  test('exception after send retains frozen order for query without POST retry', () async {
    final intent = await prepare();
    repository
      ..failure = const AccountReadFailure('accountNetwork')
      ..failAfterPost = true;
    await controller().submit(intent);
    expect(state().needsRecheck, true);
    repository.failure = null;
    await controller().recheck();
    expect(repository.posts.length, 1);
    expect(repository.checks.single.clientOrderId, intent.targets.first.clientOrderId);
    expect(state().needsRecheck, false);
  });
  test('duplicate confirms and single trades cannot enter during batch', () async {
    final intent = await prepare();
    repository.signGate = Completer<void>();
    final pending = controller().submit(intent);
    await Future<void>.delayed(Duration.zero);
    await controller().submit(intent);
    expect(
      container.read(symbolSettingsActivityProvider.notifier).acquire(SymbolSetting.order),
      null,
    );
    repository.signGate!.complete();
    await pending;
    expect(repository.posts.length, 2);
  });
  test('stop before late signature prevents current and later POSTs', () async {
    final intent = await prepare();
    repository.signGate = Completer<void>();
    final pending = controller().submit(intent);
    await Future<void>.delayed(Duration.zero);
    controller().stop();
    repository.signGate!.complete();
    await pending;
    expect(repository.posts, isEmpty);
    expect(state().stopRequested, true);
    expect(state().busy, false);
  });
  test('stop after POST finishes that query but never sends the next position', () async {
    final intent = await prepare();
    repository.afterPost = controller().stop;
    await controller().submit(intent);
    expect(repository.posts.length, 1);
    expect(repository.checks.length, 1);
    expect(state().items['ETHUSDT:BOTH']!.submitted, false);
    expect(state().stopRequested, true);
  });
  test('late approval outside per-order freshness deadline cannot POST', () async {
    final intent = await prepare();
    repository.afterSign = () => now = now.add(const Duration(seconds: 30));
    await controller().submit(intent);
    expect(repository.posts, isEmpty);
    expect(state().items.values.first.failure!.key, 'liveOrderContextExpired');
  });
  test('identity change discards callbacks and releases only old lease', () async {
    final intent = await prepare();
    repository.signGate = Completer<void>();
    final pending = controller().submit(intent);
    await Future<void>.delayed(Duration.zero);
    await container.read(authProvider.notifier).logout();
    expect(repository.latestCurrent!(), false);
    repository.signGate!.complete();
    await pending;
    expect(repository.posts, isEmpty);
    expect(state().intent, null);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
    expect(identity.wallets, 0);
  });
  test(
    'final position refresh failure preserves verified orders and marks snapshot stale',
    () async {
      final intent = await prepare();
      risk.failure = const AccountReadFailure('authWalletRejected');
      await controller().submit(intent);
      expect(repository.posts.length, 2);
      expect(state().items.values.every((i) => i.result!.status == 'FILLED'), true);
      expect(container.read(positionRiskProvider).failure!.key, 'authWalletRejected');
      expect(container.read(positionRiskProvider).stale, true);
      expect(state().needsRecheck, false);
      expect(state().busy, false);
    },
  );
  test('forged duplicate or missing scope cannot bypass confirmed snapshot', () async {
    final intent = await prepare();
    for (final targets in [
      intent.targets.take(1),
      [intent.targets.first, intent.targets.first],
    ]) {
      final invalid = BatchCloseIntent(
        snapshot: intent.snapshot,
        targets: targets,
        revision: intent.revision,
        epoch: intent.epoch,
      );
      expect(invalid.validTargets, false);
      await controller().submit(invalid);
    }
    expect(repository.reads, isEmpty);
  });

  test('settled unknown single order lease allows a new batch confirmation', () async {
    final intent = await prepare();
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.order)!;
    activity.submitted(lease);
    activity.finish(lease, unresolved: true);
    expect(controller().prepare(), isNotNull);
    expect(container.read(symbolSettingsActivityProvider).owner, isNull);
    // A previously frozen pre-write confirmation is still invalidated by epoch.
    await controller().submit(intent);
    expect(repository.reads, isEmpty);
  });

  test('second position failure preserves first verified order and unsubmitted failure', () async {
    final intent = await prepare();
    repository.afterPost = () {
      repository.contexts['ETHUSDT'] = batchContexts(
        batchRiskFixture(btcQuantity: '0.009'),
      )['BTCUSDT']!;
    };
    await controller().submit(intent);
    expect(repository.posts.length, 1);
    expect(state().items['BTCUSDT:BOTH']!.result!.status, 'FILLED');
    expect(state().items['ETHUSDT:BOTH']!.failure!.key, 'liveClosePositionChanged');
    expect(state().items['ETHUSDT:BOTH']!.submitted, false);
    expect(state().needsRecheck, false);
    expect(state().remainingAfter, now);
    expect(risk.calls, 1);
  });
}
