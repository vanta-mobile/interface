import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/application/order_cancellation_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/data/aster_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/domain/order_cancellation.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/batch_order_cancellation.dart';
import '../../support/identity_repository.dart';
import '../../support/order_cancellation.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestOpenOrdersRepository orders;
  late TestBatchCancellationRepository batch;
  late TestOrderCancellationRepository single;
  late OrderCancellationController controller;
  setUp(() async {
    identity = TestIdentityRepository()..restored = signingIdentity;
    orders = TestOpenOrdersRepository();
    batch = TestBatchCancellationRepository();
    single = TestOrderCancellationRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        asterOpenOrdersRepositoryProvider.overrideWithValue(orders),
        orderCancellationRepositoryProvider.overrideWithValue(single),
        batchOrderCancellationRepositoryProvider.overrideWithValue(batch),
      ],
    );
    container.read(authProvider);
    controller = container.read(orderCancellationProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await container.read(openOrdersReadProvider.notifier).refresh();
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });

  test('confirmed unique symbols execute sequentially and reconcile independently', () async {
    final intent = controller.prepareBatch()!;
    expect(intent.symbols, ['BTCUSDT', 'ETHUSDT']);
    expect(intent.orderCount, 2);
    batch.gates['BTCUSDT'] = Completer<void>();
    final pending = controller.cancelBatch(intent);
    expect(batch.cancelled, ['BTCUSDT']);
    await controller.cancelBatch(intent);
    batch.gates['BTCUSDT']!.complete();
    await pending;
    expect(batch.cancelled, ['BTCUSDT', 'ETHUSDT']);
    expect(container.read(openOrdersReadProvider).account!.orders, isEmpty);
    expect(container.read(openOrdersReadProvider).stale, true);
    expect(
      container
          .read(orderCancellationProvider)
          .batch!
          .results
          .values
          .every((r) => r.snapshot != null),
      true,
    );
  });

  test('current-symbol scope leaves other symbols untouched', () async {
    final intent = controller.prepareBatch(symbol: 'BTCUSDT')!;
    expect(intent.orderCount, 1);
    await controller.cancelBatch(intent);
    expect(batch.cancelled, ['BTCUSDT']);
    expect(container.read(openOrdersReadProvider).account!.orders.single.symbol, 'ETHUSDT');
  });

  test('unknown result stops the queue; GET recheck never resumes unsubmitted symbols', () async {
    batch.results['BTCUSDT'] = const BatchSymbolCancellation(
      symbol: 'BTCUSDT',
      submitted: true,
      failure: AccountReadFailure('accountNetwork'),
    );
    await controller.cancelBatch(controller.prepareBatch()!);
    expect(batch.cancelled, ['BTCUSDT']);
    final report = container.read(orderCancellationProvider).batch!;
    expect(report.results['ETHUSDT']!.submitted, false);
    expect(report.needsRecheck, true);
    expect(controller.prepareBatch(), null);
    expect(container.read(openOrdersReadProvider).account!.orders.length, 2);
    batch.results.remove('BTCUSDT');
    await controller.recheckBatch();
    expect(batch.checked, ['BTCUSDT']);
    expect(batch.cancelled, ['BTCUSDT']);
    expect(container.read(orderCancellationProvider).needsRecheck, false);
    expect(controller.prepareBatch()!.symbols, ['ETHUSDT']);
  });

  test('signature refusal stops before later symbols and keeps original orders', () async {
    batch.results['BTCUSDT'] = const BatchSymbolCancellation(
      symbol: 'BTCUSDT',
      submitted: false,
      failure: AccountReadFailure('authWalletRejected'),
    );
    await controller.cancelBatch(controller.prepareBatch()!);
    expect(batch.cancelled, ['BTCUSDT']);
    expect(container.read(openOrdersReadProvider).account!.orders.length, 2);
    expect(container.read(orderCancellationProvider).needsRecheck, false);
    expect(container.read(orderCancellationProvider).batch!.results['ETHUSDT']!.submitted, false);
  });

  test('stop lets the current action finish checking without submitting the next symbol', () async {
    batch.gates['BTCUSDT'] = Completer<void>();
    final pending = controller.cancelBatch(controller.prepareBatch()!);
    controller.stopBatch();
    batch.gates['BTCUSDT']!.complete();
    await pending;
    expect(batch.cancelled, ['BTCUSDT']);
    expect(container.read(orderCancellationProvider).batch!.stopRequested, true);
    expect(container.read(orderCancellationProvider).busy, false);
    expect(container.read(openOrdersReadProvider).account!.orders.single.symbol, 'ETHUSDT');
  });

  test('single and bulk actions share the same lock and confirmation revision', () async {
    final order = container.read(openOrdersReadProvider).account!.orders.first;
    final singleIntent = controller.prepare(order)!;
    batch.gates['BTCUSDT'] = Completer<void>();
    final pending = controller.cancelBatch(controller.prepareBatch()!);
    expect(controller.prepare(order), null);
    await controller.cancel(singleIntent);
    expect(single.cancels, 0);
    batch.gates['BTCUSDT']!.complete();
    await pending;
    expect(single.cancels, 0);
  });

  test('changed snapshot or restored identity invalidates a pending bulk confirmation', () async {
    final oldSnapshot = controller.prepareBatch()!;
    await container.read(openOrdersReadProvider.notifier).refresh();
    // The fake repository returns the same instance; replace it explicitly.
    container.read(openOrdersReadProvider.notifier).acceptSnapshot(openOrdersFixture());
    await controller.cancelBatch(oldSnapshot);
    expect(batch.cancelled, isEmpty);
    final oldIdentity = controller.prepareBatch()!;
    identity.events.add(null);
    await container.read(authProvider.notifier).bootstrap();
    await container.read(openOrdersReadProvider.notifier).refresh();
    await controller.cancelBatch(oldIdentity);
    expect(batch.cancelled, isEmpty);
  });

  test(
    'pending or unknown single cancellation also blocks a previously prepared bulk intent',
    () async {
      final batchIntent = controller.prepareBatch()!;
      final order = container.read(openOrdersReadProvider).account!.orders.first;
      single.gate = Completer<void>();
      single.result = const OrderCancellationResult(failure: AccountReadFailure('accountNetwork'));
      final pending = controller.cancel(controller.prepare(order)!);
      expect(controller.prepareBatch(), null);
      await controller.cancelBatch(batchIntent);
      expect(batch.cancelled, isEmpty);
      single.gate!.complete();
      await pending;
      expect(controller.prepareBatch(), null);
      await controller.cancelBatch(batchIntent);
      expect(batch.cancelled, isEmpty);
      expect(container.read(openOrdersReadProvider).account!.orders.length, 2);
    },
  );

  test('late result after logout clears report and cannot submit another symbol', () async {
    batch.gates['BTCUSDT'] = Completer<void>();
    final pending = controller.cancelBatch(controller.prepareBatch()!);
    identity.events.add(null);
    batch.gates['BTCUSDT']!.complete();
    await pending;
    expect(batch.cancelled, ['BTCUSDT']);
    expect(container.read(orderCancellationProvider).batch, null);
    expect(container.read(openOrdersReadProvider).account, null);
  });

  test('remaining and new in-scope orders are kept; unconfirmed symbols are preserved', () async {
    final remaining = mapAsterOpenOrders(
      [openOrder(status: 'PARTIALLY_FILLED', executedQty: '0.25'), openOrder(id: 123)],
      address: accountAddress,
      receivedAt: DateTime.utc(2026),
    );
    batch.results['BTCUSDT'] = BatchSymbolCancellation(
      symbol: 'BTCUSDT',
      submitted: true,
      snapshot: remaining,
    );
    final intent = controller.prepareBatch(symbol: 'BTCUSDT')!;
    batch.gates['BTCUSDT'] = Completer<void>();
    final pending = controller.cancelBatch(intent);
    final added = mapAsterOpenOrders(
      [openOrder(symbol: 'SOLUSDT', id: 44)],
      address: accountAddress,
      receivedAt: DateTime.utc(2026),
    );
    container
        .read(openOrdersReadProvider.notifier)
        .acceptSnapshot(
          AsterOpenOrders(
            address: accountAddress,
            receivedAt: DateTime.utc(2026),
            orders: [...orders.result.orders, ...added.orders],
          ),
        );
    batch.gates['BTCUSDT']!.complete();
    await pending;
    final result = container.read(openOrdersReadProvider).account!;
    expect(result.orders.where((o) => o.symbol == 'BTCUSDT').length, 2);
    expect(result.orders.any((o) => o.symbol == 'SOLUSDT'), true);
    expect(result.orders.any((o) => o.symbol == 'ETHUSDT'), true);
  });

  test('wrong account or symbol snapshot stays unknown and cannot clear orders', () async {
    for (final wrongAddress in [true, false]) {
      batch.results['BTCUSDT'] = BatchSymbolCancellation(
        symbol: 'BTCUSDT',
        submitted: true,
        snapshot: AsterOpenOrders(
          address: wrongAddress ? '0x3333333333333333333333333333333333333333' : accountAddress,
          receivedAt: DateTime.utc(2026),
          orders: wrongAddress ? [] : orders.result.orders,
        ),
      );
      if (container.read(orderCancellationProvider).needsRecheck) {
        await controller.recheckBatch();
      } else {
        await controller.cancelBatch(controller.prepareBatch()!);
      }
      expect(container.read(openOrdersReadProvider).account!.orders.length, 2);
      expect(container.read(orderCancellationProvider).needsRecheck, true);
      expect(
        container.read(orderCancellationProvider).batch!.results['BTCUSDT']!.failure?.key,
        'accountDataInvalid',
      );
    }
  });

  test('older in-flight list refresh cannot undo a verified per-symbol result', () async {
    batch.gates['BTCUSDT'] = Completer<void>();
    final pending = controller.cancelBatch(controller.prepareBatch(symbol: 'BTCUSDT')!);
    orders.gate = Completer<void>();
    final oldRefresh = container.read(openOrdersReadProvider.notifier).refresh();
    batch.gates['BTCUSDT']!.complete();
    await pending;
    orders.gate!.complete();
    await oldRefresh;
    expect(container.read(openOrdersReadProvider).account!.orders.single.symbol, 'ETHUSDT');
  });
}
