import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_capacity_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/account_changes.dart';
import '../../support/main_order_capacity.dart';
import '../../support/main_order_live_pricing.dart';
import '../../support/main_order_revaluation.dart';

void main() {
  late MainOrderLiveFixture f;
  late TestAccountChangeRepository changes;
  setUp(() {
    changes = TestAccountChangeRepository();
    f = MainOrderLiveFixture(changes: changes);
    changes.now = f.now;
  });
  tearDown(() async {
    await f.close();
    await changes.dispose();
  });
  MainOrderRefreshController controller() => f.container.read(mainOrderRefreshProvider.notifier);
  MainOrderRefreshState state() => f.container.read(mainOrderRefreshProvider);

  test('observation never signs; explicit refresh reads context and full capacity once', () async {
    state();
    await f.flush();
    expect(f.orders.reads, 0);
    expect(f.capacities.reads, 0);
    expect(changes.authorizations, 0);
    final result = await controller().refresh('BTCUSDT');
    expect(result, true);
    expect(f.orders.reads, 1);
    expect(f.capacities.reads, 1);
    expect(changes.authorizations, 0);
    expect(changes.channels, isEmpty);
    expect(state().loading, false);
    expect(state().failure, isNull);
    expect(f.container.read(mainOrderCapacityProvider.notifier).current, isNotNull);
    expect(f.orders.submits, 0);
  });
  test('deposit prerequisite suppresses subsequent account and capacity reads', () async {
    state();
    await f.flush();
    f.orders.readFailure = const AccountReadFailure('accountDepositRequired', code: -5050);
    expect(await controller().refresh('BTCUSDT'), false);
    expect(f.orders.reads, 1);
    expect(f.capacities.reads, 0);
    expect(state().failure?.requiresDeposit, true);
    expect(await controller().refresh('BTCUSDT'), false);
    f.container.read(symbolProvider.notifier).select('ETHUSDT');
    expect(await controller().refresh('ETHUSDT'), false);
    expect(f.orders.reads, 1);
    expect(f.capacities.reads, 0);
  });
  test('stale/expired account is completely re-read using a new original lease', () async {
    await f.open();
    final previous = f.orders.context;
    f.now = f.now.add(const Duration(seconds: 30));
    f.container.read(liveOrderProvider.notifier).markStale();
    f.orders.context = capacityContext(time: f.now);
    f.prices();
    await f.flush();
    final refreshed = await controller().refresh('BTCUSDT');
    expect(refreshed, true, reason: state().failure?.key);
    expect(f.container.read(liveOrderProvider).context!.receivedAt, f.now);
    expect(f.container.read(liveOrderProvider).context, isNot(same(previous)));
    expect(f.orders.reads, 2);
    expect(f.capacities.reads, 2);
  });
  test('existing disconnected monitor reconnects before any private snapshot read', () async {
    await f.open();
    await f.container.read(accountChangeProvider.notifier).authorize();
    changes.channels.last.add(const AccountChangeEvent.connected());
    await changes.channels.last.close();
    await f.flush();
    final reads = f.orders.reads;
    final result = controller().refresh('BTCUSDT');
    await f.flush();
    expect(state().stage, MainOrderRefreshStage.monitoring);
    expect(f.orders.reads, reads);
    expect(changes.channels.length, 2);
    changes.channels.last.add(const AccountChangeEvent.connected());
    expect(await result, true);
    expect(f.orders.reads, reads + 1);
    expect(changes.authorizations, 1);
    expect(f.container.read(mainOrderCapacityProvider.notifier).current, isNotNull);
  });
  test('pending monitor authorization never overlaps new wallet read prompts', () async {
    await f.open();
    changes.gate = Completer<void>();
    final monitoring = f.container.read(accountChangeProvider.notifier).authorize();
    expect(await controller().refresh('BTCUSDT'), false);
    expect(state().failure!.key, 'liveOrderSettingsBusy');
    expect(f.orders.reads, 1);
    expect(f.capacities.reads, 1);
    changes.gate!.complete();
    await monitoring;
  });
  test('failed reconnect never proceeds with private snapshots or reauthorizes', () async {
    await f.open();
    await f.container.read(accountChangeProvider.notifier).authorize();
    changes.channels.last.add(const AccountChangeEvent.connected());
    await changes.channels.last.close();
    await f.flush();
    final reads = f.orders.reads;
    final result = controller().refresh('BTCUSDT');
    await f.flush();
    changes.channels.last.addError(const AccountReadFailure('accountNetwork'));
    expect(await result, false);
    expect(f.orders.reads, reads);
    expect(state().failure!.key, 'accountNetwork');
    expect(changes.authorizations, 1);
  });
  test('old fresh quotes cannot complete a refresh until new receipts arrive', () async {
    await f.open();
    f.now = f.now.add(const Duration(seconds: 3));
    final result = controller().refresh('BTCUSDT');
    await f.flush();
    expect(state().stage, MainOrderRefreshStage.pricing);
    f.marks.emit(revaluationMarks({'BTCUSDT': '100'}, time: f.now));
    await f.flush();
    expect(state().stage, MainOrderRefreshStage.pricing);
    f.prices();
    expect(await result, true);
    expect(f.orders.reads, 2);
    expect(f.capacities.reads, 2);
  });
  test('duplicate refresh shares no new reads or signatures', () async {
    await f.open();
    f.orders.readGate = Completer<void>();
    final result = controller().refresh('BTCUSDT');
    await f.flush();
    expect(await controller().refresh('BTCUSDT'), false);
    expect(f.orders.reads, 2);
    f.orders.readGate!.complete();
    expect(await result, true);
    expect(f.capacities.reads, 2);
  });
  for (final stage in [
    MainOrderRefreshStage.account,
    MainOrderRefreshStage.capacity,
    MainOrderRefreshStage.pricing,
  ]) {
    test('cancel $stage returns promptly, releases lease and ignores late reads', () async {
      await f.open();
      if (stage == MainOrderRefreshStage.account) f.orders.readGate = Completer<void>();
      if (stage == MainOrderRefreshStage.capacity) f.capacities.gate = Completer<void>();
      if (stage == MainOrderRefreshStage.pricing) f.now = f.now.add(const Duration(seconds: 3));
      final result = controller().refresh('BTCUSDT');
      await f.flush();
      expect(state().stage, stage);
      controller().stop();
      expect(await result.timeout(const Duration(seconds: 1)), false);
      expect(state().loading, false);
      expect(f.container.read(symbolSettingsActivityProvider).owner, isNull);
      f.orders.readGate?.complete();
      f.capacities.gate?.complete();
      f.prices();
      await f.flush();
      expect(state().loading, false);
      expect(state().failure, isNull);
      expect(f.orders.submits, 0);
    });
  }
  test('new symbol cancels the captured refresh and prevents a late capacity read', () async {
    await f.open();
    f.orders.readGate = Completer<void>();
    final result = controller().refresh('BTCUSDT');
    await f.flush();
    f.container.read(symbolProvider.notifier).select('ETHUSDT');
    expect(await result, false);
    f.orders.readGate!.complete();
    await f.flush();
    expect(f.capacities.reads, 1);
    expect(state().loading, false);
  });
  test('account event during refresh invalidates new facts instead of claiming success', () async {
    await f.open();
    f.capacities.gate = Completer<void>();
    final pending = controller().refresh('BTCUSDT');
    await f.flush();
    expect(state().stage, MainOrderRefreshStage.capacity);
    f.container.read(liveOrderProvider.notifier).markStale();
    f.capacities.gate!.complete();
    expect(await pending, false);
    expect(f.container.read(mainOrderCapacityProvider.notifier).current, isNull);
    expect(f.orders.submits, 0);
  });
  test('cancellation during monitor reconnect returns without opening any new read', () async {
    await f.open();
    await f.container.read(accountChangeProvider.notifier).authorize();
    changes.channels.last.add(const AccountChangeEvent.connected());
    await changes.channels.last.close();
    await f.flush();
    final reads = f.orders.reads;
    final pending = controller().refresh('BTCUSDT');
    await f.flush();
    expect(state().stage, MainOrderRefreshStage.monitoring);
    controller().stop();
    expect(await pending, false);
    changes.channels.last.add(const AccountChangeEvent.connected());
    await f.flush();
    expect(f.orders.reads, reads);
    expect(state().loading, false);
    expect(state().failure, isNull);
  });
  test('signed capacity failure is retained and no quote wait or order begins', () async {
    await f.open();
    f.capacities.failure = const AccountReadFailure('authWalletRejected');
    expect(await controller().refresh('BTCUSDT'), false);
    expect(state().failure!.key, 'authWalletRejected');
    expect(f.container.read(mainOrderCapacityProvider).stale, true);
    expect(f.orders.submits, 0);
  });
}
