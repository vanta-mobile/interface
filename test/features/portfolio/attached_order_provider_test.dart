import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/attached_entry_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';

import '../../support/aster_account.dart';
import '../../support/attached_order.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestLiveOrderRepository repository;
  late DateTime now;
  LiveOrderController controller() => container.read(liveOrderProvider.notifier);
  LiveOrderIntent prepare() => controller().prepare('BTCUSDT', attachedIntent().draft)!;
  LiveOrderResult verified() => LiveOrderResult(
    strategy: AttachedOrderSnapshot(
      strategyId: '9876',
      status: 'WORKING',
      legs: const [
        AttachedOrderLeg(sequence: 1, status: 'NEW', orderId: '100'),
        AttachedOrderLeg(sequence: 2, status: 'PENDING_NEW'),
        AttachedOrderLeg(sequence: 3, status: 'PENDING_NEW'),
      ],
    ),
  );
  setUp(() async {
    now = liveOrderClock;
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestLiveOrderRepository()..result = verified();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        liveOrderRepositoryProvider.overrideWithValue(repository),
        liveOrderClockProvider.overrideWithValue(() => now),
      ],
    );
    container.read(authProvider);
    container.read(liveOrderProvider);
    await Future<void>.delayed(Duration.zero);
    await controller().load('BTCUSDT');
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });
  test('unknown BBO freezes its exact selected level and blocks a replacement strategy', () async {
    final intent = controller().prepare(
      'BTCUSDT',
      attachedIntent(peg: AttachedEntryPeg.queue10).draft,
    )!;
    repository.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await controller().submit(intent);
    expect(container.read(liveOrderProvider).needsRecheck, true);
    expect(
      controller().prepare('BTCUSDT', attachedIntent(peg: AttachedEntryPeg.counterparty1).draft),
      null,
    );
    repository.result = verified();
    await controller().recheck();
    expect(repository.submits, 1);
    expect(repository.checks, 1);
    expect(repository.lastIntent!.clientOrderId, intent.clientOrderId);
    expect(repository.lastIntent!.draft.attachment!.entryPeg, AttachedEntryPeg.queue10);
  });
  test('market BBO cannot produce an actionable intent', () {
    expect(
      controller().prepare(
        'BTCUSDT',
        attachedIntent(peg: AttachedEntryPeg.queue1, market: true).draft,
      ),
      null,
    );
    expect(repository.submits, 0);
  });
  test(
    'verified strategy ID does not become order ID; explicit refresh uses original intent',
    () async {
      final intent = prepare();
      await controller().submit(intent);
      expect(container.read(liveOrderProvider).needsRecheck, false);
      expect(container.read(liveOrderProvider).result!.orderId, null);
      expect(container.read(symbolSettingsActivityProvider).owner, null);
      await controller().recheck();
      expect(repository.submits, 1);
      expect(repository.checks, 1);
      expect(repository.lastIntent!.clientOrderId, intent.clientOrderId);
      expect(repository.lastIntent!.draft.attachment, same(intent.draft.attachment));
    },
  );
  test('unknown releases shared operations and recovery remains query only', () async {
    repository.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    final intent = prepare();
    await controller().submit(intent);
    expect(container.read(liveOrderProvider).needsRecheck, true);
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.leverage);
    expect(lease, isNotNull);
    activity.finish(lease!, unresolved: false);
    // The submitted account snapshot is stale until explicitly renewed.
    expect(controller().prepare('BTCUSDT', liveDraft()), null);
    repository.result = verified();
    now = now.add(const Duration(hours: 1));
    await controller().recheck();
    expect(repository.submits, 1);
    expect(repository.checks, 1);
    expect(repository.lastIntent!.clientOrderId, intent.clientOrderId);
    expect(container.read(liveOrderProvider).needsRecheck, false);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
    repository.context = liveContext(time: now);
    await controller().load('BTCUSDT');
    expect(repository.reads, 2);
    expect(controller().prepare('BTCUSDT', liveDraft()), isNotNull);
  });
  test('failed refresh of an accepted strategy retains its query-only recovery', () async {
    await controller().submit(prepare());
    final id = repository.lastIntent!.clientOrderId;
    repository.result = const LiveOrderResult(failure: AccountReadFailure('authWalletRejected'));
    await controller().recheck();
    expect(container.read(liveOrderProvider).needsRecheck, true);
    expect(repository.lastIntent!.clientOrderId, id);
    repository.result = verified();
    await controller().recheck();
    expect(repository.submits, 1);
    expect(repository.checks, 2);
  });
  test('identity exit while strategy query is pending discards old result', () async {
    await controller().submit(prepare());
    final gate = Completer<void>();
    repository.checkGate = gate;
    final pending = controller().recheck();
    await container.read(authProvider.notifier).logout();
    gate.complete();
    await pending;
    expect(container.read(liveOrderProvider).result, null);
    expect(container.read(liveOrderProvider).intent, null);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
  });
}
