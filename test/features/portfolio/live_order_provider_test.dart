import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';

import '../../support/aster_account.dart';
import '../../support/account_changes.dart';

import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';

import '../../support/identity_repository.dart';
import '../../support/live_order.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestLiveOrderRepository repository;
  late DateTime now;
  late TestAccountChangeRepository events;
  setUp(() async {
    now = liveOrderClock;
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestLiveOrderRepository();
    events = TestAccountChangeRepository()..now = now;
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
    container.read(liveOrderProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
    await events.dispose();
  });
  LiveOrderController controller() => container.read(liveOrderProvider.notifier);
  LiveOrderIntent intent() => controller().prepare('BTCUSDT', liveDraft())!;

  test('no automatic read; explicit preflight binds symbol and wallet', () async {
    expect(repository.reads, 0);
    expect(controller().prepare('BTCUSDT', liveDraft()), null);
    await controller().load('BTCUSDT');
    expect(intent().context.address, accountAddress);
    expect(intent().clientOrderId.length, lessThanOrEqualTo(36));
    expect(intent().clientOrderId, matches(RegExp(r'^[.A-Z:/a-z0-9_-]+$')));
    expect(controller().prepare('ETHUSDT', liveDraft()), null);
  });
  test('expired settings and stale confirmation cannot submit', () async {
    await controller().load('BTCUSDT');
    final old = intent();
    now = now.add(const Duration(seconds: 30));
    await controller().submit(old);
    expect(repository.submits, 0);
    now = liveOrderClock;
    controller().markStale();
    expect(controller().prepare('BTCUSDT', liveDraft()), null);
  });
  test('unknown IOC outcome retains its policy and ID through query-only recovery', () async {
    await controller().load('BTCUSDT');
    final prepared = controller().prepare(
      'BTCUSDT',
      liveDraft(timeInForce: LiveOrderTimeInForce.ioc),
    )!;
    repository.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await controller().submit(prepared);
    expect(container.read(liveOrderProvider).needsRecheck, true);
    expect(controller().prepare('BTCUSDT', liveDraft()), null);
    repository.result = LiveOrderResult(
      orderId: '12345',
      status: 'EXPIRED',
      executedQuantity: Decimal.parse('0.0004'),
    );
    await controller().recheck();
    expect(repository.lastIntent!.draft.timeInForce, LiveOrderTimeInForce.ioc);
    expect(repository.lastIntent!.clientOrderId, prepared.clientOrderId);
    expect(repository.submits, 1);
    expect(repository.checks, 1);
    expect(container.read(liveOrderProvider).result!.executedQuantity, Decimal.parse('0.0004'));
  });

  test('refreshed capabilities invalidate reviewed policy without falling back to GTC', () async {
    await controller().load('BTCUSDT');
    final draft = liveDraft(timeInForce: LiveOrderTimeInForce.postOnly);
    final prepared = controller().prepare('BTCUSDT', draft)!;
    repository.context = liveContext(policies: {LiveOrderTimeInForce.gtc});
    await controller().load('BTCUSDT');
    await controller().submit(prepared);
    expect(repository.submits, 0);
    expect(controller().prepare('BTCUSDT', draft), null);
    expect(controller().prepare('BTCUSDT', liveDraft()), isNotNull);
  });

  test('conditional unknown outcome preserves original trigger for GET-only recovery', () async {
    await controller().load('BTCUSDT');
    const trigger = LiveOrderTrigger(
      kind: LiveOrderTriggerKind.takeProfit,
      price: '79000',
      basis: LiveOrderTriggerBasis.mark,
      protect: true,
    );
    final prepared = controller().prepare('BTCUSDT', liveDraft(market: true, trigger: trigger))!;
    repository.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await controller().submit(prepared);
    expect(container.read(liveOrderProvider).needsRecheck, true);
    expect(controller().prepare('BTCUSDT', liveDraft()), null);
    repository.result = LiveOrderResult(
      orderId: '12345',
      status: 'NEW',
      executedQuantity: Decimal.zero,
    );
    await controller().recheck();
    expect(repository.lastIntent!.clientOrderId, prepared.clientOrderId);
    expect(repository.lastIntent!.draft.trigger, trigger);
    expect(repository.submits, 1);
    expect(repository.checks, 1);
  });

  test('refresh losing Last reference invalidates old trigger confirmation', () async {
    await controller().load('BTCUSDT');
    final draft = liveDraft(
      trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '81000'),
    );
    final prepared = controller().prepare('BTCUSDT', draft)!;
    repository.context = liveContext(lastPrice: null);
    await controller().load('BTCUSDT');
    await controller().submit(prepared);
    expect(repository.submits, 0);
    expect(controller().prepare('BTCUSDT', draft), null);
  });
  test('late approval after invalidation cannot cross send boundary', () async {
    await controller().load('BTCUSDT');
    repository.submitGate = Completer<void>();
    final pending = controller().submit(intent());
    controller().markStale();
    repository.submitGate!.complete();
    await pending;
    expect(container.read(liveOrderProvider).failure?.key, 'liveOrderContextExpired');
    expect(container.read(liveOrderProvider).needsRecheck, false);
  });
  test('normal external-wallet background does not invalidate an active signature', () async {
    await controller().load('BTCUSDT');
    repository.submitGate = Completer<void>();
    final pending = controller().submit(intent());
    controller().onLifecycleChanged();
    repository.submitGate!.complete();
    await pending;
    expect(container.read(liveOrderProvider).result?.orderId, '12345');
  });
  test('backgrounding an idle review invalidates its confirmation', () async {
    await controller().load('BTCUSDT');
    final old = intent();
    controller().onLifecycleChanged();
    await controller().submit(old);
    expect(repository.submits, 0);
  });
  test('duplicate confirm submits once and settings are locked during write', () async {
    await controller().load('BTCUSDT');
    final old = intent();
    repository.submitGate = Completer<void>();
    final pending = controller().submit(old);
    await controller().submit(old);
    expect(repository.submits, 1);
    expect(
      container.read(symbolSettingsActivityProvider.notifier).acquire(SymbolSetting.leverage),
      null,
    );
    repository.submitGate!.complete();
    await pending;
    expect(container.read(liveOrderProvider).result?.orderId, '12345');
    expect(container.read(liveOrderProvider).stale, true);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
  });
  test('unknown outcome releases lease and explicit recheck retains original ID', () async {
    await controller().load('BTCUSDT');
    final old = intent();
    repository.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await controller().submit(old);
    expect(container.read(liveOrderProvider).needsRecheck, true);
    expect(container.read(symbolSettingsActivityProvider).unresolved, false);
    expect(container.read(symbolSettingsActivityProvider).owner, isNull);
    repository.result = LiveOrderResult(
      orderId: '12345',
      status: 'NEW',
      executedQuantity: Decimal.zero,
    );
    await controller().recheck();
    expect(repository.lastIntent?.clientOrderId, old.clientOrderId);
    expect(repository.submits, 1);
    expect(repository.checks, 1);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
  });
  test('unknown order permits a fresh read and a newly confirmed intent', () async {
    await controller().load('BTCUSDT');
    final original = intent();
    repository.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await controller().submit(original);
    await controller().load('BTCUSDT');
    final next = intent();
    expect(next.clientOrderId, isNot(original.clientOrderId));
    expect(repository.reads, 2);
    expect(repository.submits, 1);
    await controller().submit(next);
    expect(repository.submits, 2);
  });
  test('unexpected exception after submission also stays query-only', () async {
    await controller().load('BTCUSDT');
    repository.failure = const AccountReadFailure('accountNetwork');
    repository.throwAfterSubmit = true;
    await controller().submit(intent());
    expect(container.read(liveOrderProvider).needsRecheck, true);
    expect(container.read(symbolSettingsActivityProvider).unresolved, false);
  });
  test('wallet change discards late callbacks and creates no extra wallet', () async {
    await controller().load('BTCUSDT');
    repository.submitGate = Completer<void>();
    final pending = controller().submit(intent());
    await container.read(authProvider.notifier).logout();
    expect(repository.latestCurrent!(), false);
    repository.submitGate!.complete();
    await pending;
    expect(container.read(liveOrderProvider).context, null);
    expect(container.read(liveOrderProvider).result, null);
    expect(identity.wallets, 0);
  });
  test('settings epoch invalidates an already reviewed intent', () async {
    await controller().load('BTCUSDT');
    final old = intent();
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.leverage)!;
    activity.submitted(lease);
    activity.finish(lease, unresolved: false);
    await controller().submit(old);
    expect(repository.submits, 0);
  });

  test('controller validates closing direction and amount against reviewed position', () async {
    repository.context = liveCloseContext();
    await controller().load('BTCUSDT');
    final close = liveCloseIntent().draft;
    expect(controller().prepare('BTCUSDT', close), isNotNull);
    expect(controller().prepare('BTCUSDT', liveDraft(buy: true, closingSide: 'BOTH')), null);
    expect(
      controller().prepare(
        'BTCUSDT',
        liveDraft(buy: false, closingSide: 'BOTH', quantity: '0.011'),
      ),
      null,
    );
    final prepared = controller().prepare('BTCUSDT', close)!;
    controller().markStale();
    await controller().submit(prepared);
    expect(repository.submits, 0);
  });

  test('refreshed position invalidates earlier close confirmation', () async {
    repository.context = liveCloseContext();
    await controller().load('BTCUSDT');
    final prepared = controller().prepare('BTCUSDT', liveCloseIntent().draft)!;
    repository.context = liveCloseContext(quantity: '0.005');
    await controller().load('BTCUSDT');
    await controller().submit(prepared);
    expect(repository.submits, 0);
    expect(
      controller().prepare(
        'BTCUSDT',
        liveDraft(buy: false, closingSide: 'BOTH', quantity: '0.006'),
      ),
      null,
    );
  });

  test(
    'opening cannot bypass missing signed funds, but explicit close read may skip them',
    () async {
      repository.context = liveContext(withFunds: false);
      await controller().load('BTCUSDT');
      expect(repository.lastIncludeFunds, true);
      expect(controller().prepare('BTCUSDT', liveDraft()), null);
      repository.context = liveCloseContext();
      await controller().load('BTCUSDT', includeFunds: false);
      expect(repository.lastIncludeFunds, false);
      expect(controller().prepare('BTCUSDT', liveCloseIntent().draft), isNotNull);
    },
  );

  test('signed account trading disabled prevents opening without creating a wallet', () async {
    repository.context = liveContext(canTrade: false);
    await controller().load('BTCUSDT');
    expect(controller().prepare('BTCUSDT', liveDraft()), null);
    expect(repository.submits, 0);
    expect(identity.wallets, 0);
  });
  test('same-time account replay during BBO signing invalidates original confirmation', () async {
    await container.read(accountChangeProvider.notifier).authorize();
    final event = AccountChangeEvent.changed(AccountChangeKind.configuration, now);
    events.channels.single.add(event);
    await Future<void>.delayed(Duration.zero);
    await controller().load('BTCUSDT');
    final prepared = controller().prepare(
      'BTCUSDT',
      liveDraft(peg: LiveOrderPeg.queue, price: ''),
    )!;
    repository.submitGate = Completer();
    final pending = controller().submit(prepared);
    await Future<void>.delayed(Duration.zero);
    events.channels.single.add(event);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(liveOrderProvider).stale, true);
    repository.submitGate!.complete();
    await pending;
    expect(container.read(liveOrderProvider).failure!.key, 'liveOrderContextExpired');
    expect(container.read(liveOrderProvider).needsRecheck, false);
  });
  test('unknown ordinary BBO preserves peg and original client ID for query-only retry', () async {
    await controller().load('BTCUSDT');
    final prepared = controller().prepare(
      'BTCUSDT',
      liveDraft(peg: LiveOrderPeg.counterparty, price: ''),
    )!;
    repository.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await controller().submit(prepared);
    expect(container.read(liveOrderProvider).needsRecheck, true);
    expect(controller().prepare('BTCUSDT', liveDraft()), null);
    repository.result = LiveOrderResult(
      orderId: '12345',
      status: 'NEW',
      executedQuantity: Decimal.zero,
    );
    await controller().recheck();
    expect(repository.submits, 1);
    expect(repository.checks, 1);
    expect(repository.lastIntent!.clientOrderId, prepared.clientOrderId);
    expect(repository.lastIntent!.draft.peg, LiveOrderPeg.counterparty);
    expect(repository.lastIntent!.draft.price, '');
    expect(identity.wallets, 0);
  });
}
