import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/application/order_cancellation_provider.dart';
import 'package:vanta/features/portfolio/domain/order_cancellation.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/identity_repository.dart';
import '../../support/order_cancellation.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestOpenOrdersRepository orders;
  late TestOrderCancellationRepository cancellation;
  setUp(() async {
    identity = TestIdentityRepository()..restored = signingIdentity;
    orders = TestOpenOrdersRepository();
    cancellation = TestOrderCancellationRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        asterOpenOrdersRepositoryProvider.overrideWithValue(orders),
        orderCancellationRepositoryProvider.overrideWithValue(cancellation),
      ],
    );
    container.read(authProvider);
    container.read(orderCancellationProvider);
    await Future<void>.delayed(Duration.zero);
    await container.read(openOrdersReadProvider.notifier).refresh();
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });

  OrderCancelIntent intent() {
    final order = container
        .read(openOrdersReadProvider)
        .account!
        .orders
        .firstWhere((o) => o.symbol == 'BTCUSDT');
    return container.read(orderCancellationProvider.notifier).prepare(order)!;
  }

  test(
    'one confirmed action only; verified terminal order removed and other orders stale',
    () async {
      final action = container.read(orderCancellationProvider.notifier);
      final confirmation = intent();
      cancellation.gate = Completer<void>();
      final pending = action.cancel(confirmation);
      await action.cancel(confirmation);
      expect(cancellation.cancels, 1);
      cancellation.gate!.complete();
      await pending;
      expect(container.read(openOrdersReadProvider).account!.orders.map((o) => o.symbol), [
        'ETHUSDT',
      ]);
      expect(container.read(openOrdersReadProvider).stale, true);
      expect(container.read(orderCancellationProvider).result?.resolution?.status, 'CANCELED');
    },
  );

  test(
    'an unconfirmed cancellation is queried automatically; a failed query is an error',
    () async {
      cancellation.result = const OrderCancellationResult();
      cancellation.checkResult = const OrderCancellationResult(
        resolution: OrderResolution(symbol: 'BTCUSDT', orderId: '1917641', status: 'FILLED'),
      );
      final action = container.read(orderCancellationProvider.notifier);
      await action.cancel(intent());
      expect(cancellation.cancels, 1);
      expect(cancellation.checks, 1);
      expect(container.read(orderCancellationProvider).result?.resolution?.status, 'FILLED');
      expect(container.read(openOrdersReadProvider).account!.orders.length, 1);
    },
  );

  test('a cancellation still unconfirmed after the query is an error, not unknown', () async {
    cancellation.result = const OrderCancellationResult();
    final action = container.read(orderCancellationProvider.notifier);
    final confirmation = intent();
    await action.cancel(confirmation);
    expect(cancellation.cancels, 1);
    expect(cancellation.checks, 1);
    expect(container.read(orderCancellationProvider).result?.failure?.key, 'accountNetwork');
    expect(container.read(orderCancellationProvider).result?.resolution, isNull);
    expect(container.read(openOrdersReadProvider).account!.orders.length, 2);
    // Nothing is locked: the order can be confirmed for cancellation again.
    expect(action.prepare(confirmation.order), isNotNull);
  });

  test('a list refresh while the confirmation is open still sends the cancellation', () async {
    final action = container.read(orderCancellationProvider.notifier);
    final confirmation = intent();
    // A new read returns new instances of the same exchange orders.
    orders.result = openOrdersFixture();
    await container.read(openOrdersReadProvider.notifier).refresh();
    final refreshed = container
        .read(openOrdersReadProvider)
        .account!
        .orders
        .firstWhere((o) => o.symbol == 'BTCUSDT');
    expect(identical(refreshed, confirmation.order), false);
    await action.cancel(confirmation);
    expect(cancellation.cancels, 1);
  });
  test('logout and restoration of the same identity invalidate an open confirmation', () async {
    final confirmation = intent();
    identity.events.add(null);
    await container.read(authProvider.notifier).bootstrap();
    await container.read(openOrdersReadProvider.notifier).refresh();
    await container.read(orderCancellationProvider.notifier).cancel(confirmation);
    expect(cancellation.cancels, 0);
  });

  test('inconsistent resolution never removes an order or permits another DELETE', () async {
    cancellation.result = const OrderCancellationResult(
      resolution: OrderResolution(symbol: 'BTCUSDT', orderId: '1917641', status: 'NEW'),
    );
    await container.read(orderCancellationProvider.notifier).cancel(intent());
    expect(container.read(openOrdersReadProvider).account!.orders.length, 2);
    expect(container.read(orderCancellationProvider).result?.failure?.key, 'accountDataInvalid');
  });

  test('late result after logout is discarded without exposing prior order data', () async {
    cancellation.gate = Completer<void>();
    final pending = container.read(orderCancellationProvider.notifier).cancel(intent());
    identity.events.add(null);
    cancellation.gate!.complete();
    await pending;
    expect(container.read(orderCancellationProvider).intent, null);
    expect(container.read(openOrdersReadProvider).account, null);
  });

  test('older in-flight snapshot cannot restore a terminal order after reconciliation', () async {
    cancellation.gate = Completer<void>();
    final pending = container.read(orderCancellationProvider.notifier).cancel(intent());
    orders.gate = Completer<void>();
    final staleRead = container.read(openOrdersReadProvider.notifier).refresh();
    cancellation.gate!.complete();
    await pending;
    orders.gate!.complete();
    await staleRead;
    expect(container.read(openOrdersReadProvider).account!.orders.length, 1);
  });
}
