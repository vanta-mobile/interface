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
  test('an unconfirmed BBO entry is queried automatically with its exact level', () async {
    final intent = controller().prepare(
      'BTCUSDT',
      attachedIntent(peg: AttachedEntryPeg.queue10).draft,
    )!;
    repository.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    repository.checkResult = verified();
    await controller().submit(intent);
    expect(repository.submits, 1);
    expect(repository.checks, 1);
    expect(repository.lastIntent!.clientOrderId, intent.clientOrderId);
    expect(repository.lastIntent!.draft.attachment!.entryPeg, AttachedEntryPeg.queue10);
    expect(container.read(liveOrderProvider).failure, isNull);
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
  test('a verified strategy ID does not become an order ID; nothing else is blocked', () async {
    final intent = prepare();
    await controller().submit(intent);
    expect(container.read(liveOrderProvider).result!.orderId, null);
    expect(container.read(liveOrderProvider).result!.strategy, isNotNull);
    expect(repository.submits, 1);
    expect(repository.checks, 0);
    expect(repository.lastIntent!.clientOrderId, intent.clientOrderId);
    expect(container.read(symbolSettingsActivityProvider).busy, isFalse);
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    activity.finish(activity.acquire(SymbolSetting.leverage));
  });
  test('a still-unconfirmed strategy is reported as the query error, never re-sent', () async {
    repository.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await controller().submit(prepare());
    expect(repository.submits, 1);
    expect(repository.checks, 1);
    expect(container.read(liveOrderProvider).failure?.key, 'accountNetwork');
    expect(container.read(symbolSettingsActivityProvider).busy, isFalse);
  });
}
