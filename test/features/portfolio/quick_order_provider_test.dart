import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/quick_order_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/quick_order.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestLiveOrderRepository orders;
  late TestQuickOrderRepository sizing;
  late DateTime now;
  setUp(() async {
    identity = TestIdentityRepository()..restored = signingIdentity;
    orders = TestLiveOrderRepository()..context = liveContext(bid: '79999', ask: '80001');
    sizing = TestQuickOrderRepository();
    now = liveOrderClock;
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        liveOrderRepositoryProvider.overrideWithValue(orders),
        quickOrderRepositoryProvider.overrideWithValue(sizing),
        liveOrderClockProvider.overrideWithValue(() => now),
      ],
    );
    container.read(authProvider);
    container.read(quickOrderProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });
  QuickOrderController controller() => container.read(quickOrderProvider.notifier);
  test('no automatic read, empty quantity and separate percentage sizing', () async {
    expect(orders.reads, 0);
    expect(sizing.reads, 0);
    expect(container.read(quickOrderProvider).quantity, '');
    expect(container.read(quickOrderProvider).percent, null);
    expect(controller().prepare(true), null);
    await controller().load();
    expect(orders.reads, 1);
    expect(sizing.reads, 1);
    expect(controller().prepare(true), null);
    controller().selectPercent(50);
    expect(controller().quantity(true), '0.005');
    expect(controller().prepare(true)!.draft.quickEntry, true);
    controller().setQuantity('0.001');
    expect(container.read(quickOrderProvider).percent, null);
    expect(controller().prepare(false)!.draft.buy, false);
  });
  test('sizing failure preserves manual input and permits valid manual MARKET only', () async {
    controller().setQuantity('0.001');
    sizing.failure = const AccountReadFailure('accountNetwork');
    await controller().load();
    expect(container.read(quickOrderProvider).quantity, '0.001');
    expect(controller().prepare(true), isNotNull);
    controller().selectPercent(100);
    expect(controller().quantity(true), null);
    expect(controller().prepare(true), null);
    sizing.failure = null;
    await controller().load();
    expect(controller().prepare(true), isNotNull);
  });
  test(
    'known accepted result clears quantity and percentage; refused submission preserves input',
    () async {
      await controller().load();
      controller().setQuantity('0.001');
      orders.failure = const AccountReadFailure('authWalletRejected');
      await controller().submit(controller().prepare(true)!);
      expect(container.read(quickOrderProvider).quantity, '0.001');
      orders.failure = null;
      await controller().load();
      controller().selectPercent(25);
      await controller().submit(controller().prepare(true)!);
      expect(container.read(quickOrderProvider).quantity, '');
      expect(container.read(quickOrderProvider).percent, null);
      expect(orders.lastIntent!.draft.quickEntry, true);
    },
  );
  test('unknown outcome allows editing while explicit recheck keeps original intent', () async {
    await controller().load();
    controller().setQuantity('0.001');
    orders.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await controller().submit(controller().prepare(true)!);
    final intent = orders.lastIntent!;
    expect(container.read(quickOrderProvider).quantity, '0.001');
    controller().setQuantity('1');
    expect(container.read(quickOrderProvider).quantity, '1');
    expect(orders.submits, 1);
    orders.result = LiveOrderResult(
      orderId: '12345',
      status: 'FILLED',
      executedQuantity: Decimal.parse('0.001'),
    );
    await container.read(liveOrderProvider.notifier).recheck();
    expect(orders.submits, 1);
    expect(orders.checks, 1);
    expect(orders.lastIntent!.clientOrderId, intent.clientOrderId);
    expect(container.read(quickOrderProvider).quantity, '');
  });
  test('snapshot age and changes after confirmation block quick submission', () async {
    await controller().load();
    controller().setQuantity('0.001');
    final intent = controller().prepare(true)!;
    now = now.add(const Duration(seconds: 30));
    expect(controller().prepare(true), null);
    await controller().submit(intent);
    expect(orders.submits, 0);
    now = liveOrderClock;
    controller().setQuantity('0.002');
    await controller().submit(intent);
    expect(orders.submits, 0);
  });
  test('symbol change discards a pending sizing response and resets independent input', () async {
    sizing.gate = Completer<void>();
    controller().setQuantity('0.001');
    final future = controller().load();
    await Future<void>.delayed(Duration.zero);
    expect(sizing.reads, 1);
    container.read(symbolProvider.notifier).select('ETHUSDT');
    expect(sizing.latestCurrent!(), false);
    sizing.gate!.complete();
    await future;
    expect(container.read(quickOrderProvider).quantity, '');
    expect(container.read(quickOrderProvider).sizing, null);
    expect(controller().prepare(true), null);
  });
  test('expiry while sizing discards late read and preserves quantity', () async {
    sizing.gate = Completer<void>();
    controller().setQuantity('0.001');
    final future = controller().load();
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 30));
    expect(sizing.latestCurrent!(), false);
    sizing.gate!.complete();
    await future;
    expect(container.read(quickOrderProvider).sizing, null);
    expect(container.read(quickOrderProvider).quantity, '0.001');
    expect(controller().prepare(true), null);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
  });
  test('logout invalidates pending sizing and clears the wallet input scope', () async {
    sizing.gate = Completer<void>();
    controller().setQuantity('0.001');
    final future = controller().load();
    await Future<void>.delayed(Duration.zero);
    await container.read(authProvider.notifier).logout();
    expect(sizing.latestCurrent!(), false);
    sizing.gate!.complete();
    await future;
    expect(container.read(quickOrderProvider).quantity, '');
    expect(container.read(quickOrderProvider).sizing, null);
    expect(controller().prepare(true), null);
  });
  test('settings exclusion blocks quick confirmation and percentage read', () async {
    await controller().load();
    controller().setQuantity('0.001');
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.leverage)!;
    expect(controller().prepare(true), null);
    await controller().load();
    expect(sizing.reads, 1);
    activity.finish(lease, unresolved: false);
  });
}
