import 'package:vanta/features/portfolio/application/main_order_pricing_provider.dart';

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_allocation_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_capacity_provider.dart';
import 'package:vanta/features/portfolio/application/order_recovery_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';
import 'package:vanta/features/portfolio/domain/main_order_allocation.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestLiveOrderRepository orders;
  late TestCapacityRepository capacities;
  late DateTime now;
  var formCurrent = true;
  setUp(() async {
    identity = TestIdentityRepository()..restored = signingIdentity;
    orders = TestLiveOrderRepository()..context = capacityContext();
    capacities = TestCapacityRepository();
    now = liveOrderClock;
    formCurrent = true;
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        liveOrderRepositoryProvider.overrideWithValue(orders),
        mainOrderPricingProvider.overrideWith(fixtureBoundedPricing),
        mainOrderCapacityRepositoryProvider.overrideWithValue(capacities),
        liveOrderClockProvider.overrideWithValue(() => now),
      ],
    );
    container.read(mainOrderAllocationProvider);
    await Future<void>.delayed(Duration.zero);
    await container.read(liveOrderProvider.notifier).load('BTCUSDT');
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });
  MainOrderAllocationController controller() =>
      container.read(mainOrderAllocationProvider.notifier);
  Future<void> select() async {
    await container.read(mainOrderCapacityProvider.notifier).load('BTCUSDT');
    controller().selectPercent(20);
  }

  Future<MainOrderAllocationReview?> prepare({bool buy = true, String quantity = '2'}) =>
      controller().prepare(
        liveDraft(buy: buy, price: '100', quantity: quantity),
        isFormCurrent: () => formCurrent,
      );

  test('initial ratio is zero and watching performs no capacity reads', () {
    expect(container.read(mainOrderAllocationProvider).percent, 0);
    expect(capacities.reads, 0);
    controller().selectPercent(20);
    expect(container.read(mainOrderAllocationProvider).percent, 0);
  });
  test('percentage and manual modes switch independently without requests', () async {
    await select();
    expect(container.read(mainOrderAllocationProvider).percent, 20);
    for (final value in [-1, 101]) {
      controller().selectPercent(value);
    }
    expect(container.read(mainOrderAllocationProvider).percent, 20);
    controller().manual();
    expect(container.read(mainOrderAllocationProvider).percent, null);
    controller().selectPercent(0);
    expect(container.read(mainOrderAllocationProvider).percent, 0);
    expect(capacities.reads, 1);
  });
  test('review freshly reads limits and freezes clicked side/type/quantity', () async {
    await select();
    final review = (await prepare(buy: false))!;
    expect(capacities.reads, 2);
    expect(controller().matches(review), true);
    expect(review.intent.draft.buy, false);
    expect(review.intent.draft.quantity, '2');
    expect(review.intent.draft.orderType, 'LIMIT');
    expect(review.side.cost!.total, Decimal.fromInt(20).toRational());
    expect(orders.submits, 0);
  });
  test('higher new maximum never enlarges the frozen clicked quantity', () async {
    await select();
    capacities.transform = (context) {
      final payload = capacityAccountPayload();
      (payload['assets'] as List).single['availableBalance'] = '200';
      return assembledCapacity(context: context, payload: payload);
    };
    final review = (await prepare())!;
    expect(review.side.capacity!.maximum, Decimal.fromInt(20));
    expect(review.intent.draft.quantity, '2');
    await controller().submit(review);
    expect(orders.lastIntent!.draft.quantity, '2');
    expect(orders.submits, 1);
    expect(container.read(mainOrderAllocationProvider).percent, 0);
  });
  test('smaller new maximum refuses clicked quantity and preserves percent', () async {
    await select();
    capacities.transform = (context) {
      final payload = capacityAccountPayload();
      (payload['assets'] as List).single['availableBalance'] = '1';
      return assembledCapacity(context: context, payload: payload);
    };
    expect(await prepare(), null);
    expect(container.read(mainOrderAllocationProvider).percent, 20);
    expect(container.read(mainOrderAllocationProvider).failure!.key, 'liveCapacityAboveMaximum');
    expect(orders.submits, 0);
  });
  test('wallet rejection while refreshing limits is safe and preserves percentage', () async {
    await select();
    capacities.failure = const AccountReadFailure('authWalletRejected');
    expect(await prepare(), null);
    expect(container.read(mainOrderAllocationProvider).failure!.key, 'authWalletRejected');
    expect(container.read(mainOrderAllocationProvider).percent, 20);
    expect(orders.submits, 0);
  });
  test('draft change during refresh discards response without submitting', () async {
    await select();
    capacities.gate = Completer<void>();
    final future = prepare();
    expect(container.read(mainOrderAllocationProvider).preparing, true);
    formCurrent = false;
    capacities.gate!.complete();
    expect(await future, null);
    expect(container.read(mainOrderAllocationProvider).failure!.key, 'liveAllocationChanged');
    expect(container.read(mainOrderAllocationProvider).percent, 20);
  });
  test('cancel releases the read immediately; late response cannot replace a new review', () async {
    await select();
    final gate = capacities.gate = Completer<void>();
    final future = prepare();
    controller().stop();
    expect(container.read(mainOrderAllocationProvider).preparing, false);
    expect(container.read(mainOrderAllocationProvider).percent, 20);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
    capacities.gate = null;
    final review = (await prepare(buy: false))!;
    gate.complete();
    expect(await future, null);
    expect(container.read(mainOrderAllocationProvider).review, same(review));
    expect(controller().matches(review), true);
  });
  for (final elapsed in [const Duration(seconds: 30), const Duration(microseconds: -1)]) {
    test('clock boundary during refresh prevents a review $elapsed', () async {
      await select();
      capacities.gate = Completer<void>();
      final future = prepare();
      now = now.add(elapsed);
      capacities.gate!.complete();
      expect(await future, null);
      expect(orders.submits, 0);
    });
    test('clock boundary after review prevents entering submission $elapsed', () async {
      await select();
      final review = (await prepare())!;
      now = now.add(elapsed);
      await controller().submit(review);
      expect(orders.submits, 0);
      expect(container.read(mainOrderAllocationProvider).percent, 20);
    });
  }
  for (final change in ['form', 'percent', 'manual', 'symbol', 'context', 'stale', 'capacity']) {
    test('changed $change invalidates frozen review before wallet submission', () async {
      await select();
      final review = (await prepare())!;
      switch (change) {
        case 'form':
          formCurrent = false;
        case 'percent':
          controller().selectPercent(50);
        case 'manual':
          controller().manual();
        case 'symbol':
          container.read(symbolProvider.notifier).select('ETHUSDT');
        case 'context':
          orders.context = capacityContext();
          await container.read(liveOrderProvider.notifier).load('BTCUSDT');
        case 'stale':
          container.read(liveOrderProvider.notifier).markStale();
        case 'capacity':
          container.invalidate(mainOrderCapacityProvider);
      }
      await controller().submit(review);
      expect(orders.submits, 0);
    });
  }
  for (final manual in [false, true]) {
    for (final change in ['form', 'expiry', 'clockBack', 'symbol', 'stale', 'capacity']) {
      test(
        '${manual ? 'manual' : 'percentage'} changed $change after wallet prompt blocks sending and preserves intent',
        () async {
          await select();
          if (manual) controller().manual();
          final review = (await prepare())!;
          orders.submitGate = Completer<void>();
          final future = controller().submit(review);
          expect(container.read(liveOrderProvider).step, LiveOrderStep.signing);
          switch (change) {
            case 'form':
              formCurrent = false;
            case 'expiry':
              now = now.add(const Duration(seconds: 30));
            case 'clockBack':
              now = now.subtract(const Duration(microseconds: 1));
            case 'symbol':
              container.read(symbolProvider.notifier).select('ETHUSDT');
            case 'stale':
              container.read(liveOrderProvider.notifier).markStale();
            case 'capacity':
              container.invalidate(mainOrderCapacityProvider);
          }
          orders.submitGate!.complete();
          await future;
          final result = container.read(liveOrderProvider);
          expect(result.result, null);
          expect(result.failure!.key, 'liveOrderContextExpired');
          expect(orders.lastIntent!.clientOrderId, review.intent.clientOrderId);
          expect(orders.lastIntent!.draft.quantity, '2');
        },
      );
    }
  }
  for (final user in [
    const AuthIdentity(
      id: 'new-user',
      walletAddress: accountAddress,
      walletKind: WalletKind.external,
      signingAvailable: true,
    ),
    const AuthIdentity(
      id: 'aster-test',
      walletAddress: accountAddress,
      walletKind: WalletKind.embedded,
      signingAvailable: true,
    ),
    const AuthIdentity(
      id: 'aster-test',
      walletAddress: accountAddress,
      walletKind: WalletKind.external,
    ),
  ].indexed) {
    test('changed identity scope ${user.$1} prevents review reuse', () async {
      await select();
      final review = (await prepare())!;
      identity.events.add(user.$2);
      await controller().submit(review);
      expect(orders.submits, 0);
      expect(container.read(mainOrderAllocationProvider).percent, 0);
    });
  }
  test('settings and recovery locks block submission before a wallet prompt', () async {
    await select();
    final review = (await prepare())!;
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.leverage)!;
    expect(controller().matches(review), false);
    activity.finish(lease, unresolved: false);
    await container
        .read(orderRecoveryJournalProvider)
        .prepare(OrderRecoveryRecord(query: OrderQuery.capture(liveIntent()), createdAt: now));
    await controller().submit(review);
    expect(orders.submits, 0);
  });
  test(
    'unknown result locks editing and only rechecks original ID; accepted recovery clears ratio',
    () async {
      await select();
      final review = (await prepare())!;
      orders.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
      await controller().submit(review);
      expect(container.read(mainOrderAllocationProvider).percent, 20);
      controller().manual();
      controller().selectPercent(50);
      expect(container.read(mainOrderAllocationProvider).percent, 20);
      expect(await prepare(), null);
      expect(capacities.reads, 2);
      orders.result = LiveOrderResult(
        orderId: '12345',
        status: 'NEW',
        executedQuantity: Decimal.zero,
      );
      await container.read(liveOrderProvider.notifier).recheck();
      expect(orders.submits, 1);
      expect(orders.checks, 1);
      expect(orders.lastIntent!.clientOrderId, review.intent.clientOrderId);
      expect(container.read(mainOrderAllocationProvider).percent, 0);
    },
  );
  test('refused wallet prompt preserves ratio and does not become an unknown write', () async {
    await select();
    final review = (await prepare())!;
    orders.failure = const AccountReadFailure('authWalletRejected');
    await controller().submit(review);
    expect(container.read(mainOrderAllocationProvider).percent, 20);
    expect(container.read(liveOrderProvider).needsRecheck, false);
    expect(container.read(liveOrderProvider).failure!.key, 'authWalletRejected');
  });
}
