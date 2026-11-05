import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/application/order_cancellation_provider.dart';
import 'package:vanta/features/portfolio/data/aster_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/domain/order_cancellation.dart';

import '../../support/account_changes.dart';
import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/batch_order_cancellation.dart';
import '../../support/identity_repository.dart';
import '../../support/open_order_updates.dart';
import '../../support/order_cancellation.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestOpenOrdersRepository orders;
  late TestOrderCancellationRepository cancellation;
  late TestBatchCancellationRepository batch;
  late TestAccountChangeRepository changes;
  setUp(() async {
    identity = TestIdentityRepository()..restored = signingIdentity;
    orders = TestOpenOrdersRepository();
    cancellation = TestOrderCancellationRepository();
    batch = TestBatchCancellationRepository();
    changes = TestAccountChangeRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        asterOpenOrdersRepositoryProvider.overrideWithValue(orders),
        accountChangeRepositoryProvider.overrideWithValue(changes),
        accountChangeClockProvider.overrideWithValue(() => changes.now),
        orderCancellationRepositoryProvider.overrideWithValue(cancellation),
        batchOrderCancellationRepositoryProvider.overrideWithValue(batch),
      ],
    );
    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
    await changes.dispose();
  });
  OpenOrdersReadController controller() => container.read(openOrdersReadProvider.notifier);
  AsterOpenOrders snapshot() => container.read(openOrdersReadProvider).account!;
  void emit({
    String status = 'PARTIALLY_FILLED',
    String filled = '0.1',
    String id = '1917641',
    int time = orderEventClock,
  }) {
    final update = orderUpdate(status: status, filled: filled, id: id, eventTime: time);
    changes.channels.last.add(
      AccountChangeEvent.changed(AccountChangeKind.order, update.eventTime, order: update),
    );
  }

  Future<void> monitor() async {
    await container.read(accountChangeProvider.notifier).authorize();
    changes.channels.last.add(const AccountChangeEvent.connected());
  }

  test(
    'events update real order source, retain receipt and stale scope, no extra signatures',
    () async {
      await controller().refresh();
      final receipt = snapshot().receivedAt;
      await monitor();
      emit();
      final order = snapshot().orders.singleWhere((o) => o.symbol == 'BTCUSDT');
      expect(order.remainingQty.toString(), '0.3');
      expect(order.units?.base, 'BTC');
      expect(snapshot().receivedAt, receipt);
      expect(container.read(openOrdersReadProvider).stale, true);
      emit(status: 'FILLED', filled: '0.40', time: orderEventClock + 1);
      expect(snapshot().orders.single.symbol, 'ETHUSDT');
      expect(orders.calls, 1);
      expect(changes.authorizations, 1);
      expect(identity.wallets, 0);
    },
  );
  test(
    'events before first read never fabricate a complete account; events during read are replayed',
    () async {
      await monitor();
      emit(id: '2');
      expect(container.read(openOrdersReadProvider).account, null);
      orders.gate = Completer<void>();
      final pending = controller().refresh();
      emit(id: '3', time: orderEventClock + 1);
      orders.gate!.complete();
      await pending;
      expect(snapshot().orders.map((o) => o.orderId), contains('3'));
      expect(snapshot().orders.map((o) => o.orderId), isNot(contains('2')));
      expect(snapshot().orders.singleWhere((o) => o.orderId == '3').time, null);
      expect(container.read(openOrdersReadProvider).stale, true);
    },
  );
  test(
    'late REST and its loading step cannot revert an event; errors preserve event-adjusted rows',
    () async {
      await controller().refresh();
      await monitor();
      orders.gate = Completer<void>();
      final pending = controller().refresh();
      emit();
      expect(snapshot().orders.last.executedQty.toString(), '0.1');
      orders.failure = const AccountReadFailure('accountNetwork');
      orders.gate!.complete();
      await pending;
      expect(snapshot().orders.last.executedQty.toString(), '0.1');
      expect(container.read(openOrdersReadProvider).failure?.key, 'accountNetwork');
      orders.failure = null;
      await controller().refresh();
      expect(snapshot().orders.last.executedQty.toString(), '0.1');
      expect(container.read(openOrdersReadProvider).stale, true);
    },
  );
  test(
    'disconnect preserves rows and terminal protection across a signed refresh and resume',
    () async {
      await controller().refresh();
      await monitor();
      emit(status: 'CANCELED');
      changes.channels.last.addError(StateError('private uri'));
      await controller().refresh();
      expect(snapshot().orders.single.symbol, 'ETHUSDT');
      container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
      container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
      changes.channels.last.add(const AccountChangeEvent.connected());
      emit(status: 'NEW', filled: '0', time: orderEventClock + 5);
      expect(snapshot().orders.single.symbol, 'ETHUSDT');
      expect(container.read(openOrdersReadProvider).stale, true);
      expect(changes.authorizations, 1);
    },
  );
  test('logout resets event ledger and pending REST cannot leak into restored identity', () async {
    await controller().refresh();
    await monitor();
    emit(status: 'CANCELED');
    orders.gate = Completer<void>();
    final pending = controller().refresh();
    identity.events.add(null);
    orders.gate!.complete();
    await pending;
    expect(container.read(openOrdersReadProvider).account, null);
    await container.read(authProvider.notifier).bootstrap();
    await controller().refresh();
    expect(snapshot().orders.length, 2);
    expect(snapshot().lastEventAt, null);
  });
  test('single cancellation GET racing with a later final event cannot resurrect order', () async {
    await controller().refresh();
    await monitor();
    final action = container.read(orderCancellationProvider.notifier);
    final original = snapshot().orders.last;
    final confirmation = action.prepare(original)!;
    cancellation.gate = Completer<void>();
    cancellation.result = OrderCancellationResult(
      resolution: OrderResolution(
        symbol: original.symbol,
        orderId: original.orderId,
        status: 'NEW',
        openOrder: original,
      ),
    );
    final pending = action.cancel(confirmation);
    emit(status: 'FILLED', filled: '0.40');
    cancellation.gate!.complete();
    await pending;
    expect(snapshot().orders.single.symbol, 'ETHUSDT');
    expect(cancellation.cancels, 1);
    expect(container.read(orderCancellationProvider).result?.resolution?.status, 'NEW');
    expect(container.read(orderCancellationProvider).result?.newerOrderEvents, true);
  });
  test(
    'verified cancellation tombstone blocks active events even if no final event arrived',
    () async {
      await controller().refresh();
      await monitor();
      final action = container.read(orderCancellationProvider.notifier);
      await action.cancel(action.prepare(snapshot().orders.last)!);
      emit(status: 'NEW', filled: '0');
      expect(snapshot().orders.single.symbol, 'ETHUSDT');
      await controller().refresh();
      expect(snapshot().orders.single.symbol, 'ETHUSDT');
    },
  );
  test('bulk GET cannot erase new post-confirmation orders or restore final events', () async {
    await controller().refresh();
    await monitor();
    final action = container.read(orderCancellationProvider.notifier);
    final confirmation = action.prepareBatch(symbol: 'BTCUSDT')!;
    batch.gates['BTCUSDT'] = Completer<void>();
    final pending = action.cancelBatch(confirmation);
    emit(status: 'CANCELED');
    emit(id: '999', status: 'NEW', filled: '0', time: orderEventClock + 2);
    batch.gates['BTCUSDT']!.complete();
    await pending;
    expect(snapshot().orders.map((o) => o.orderId), contains('999'));
    expect(snapshot().orders.map((o) => o.orderId), isNot(contains('1917641')));
    expect(snapshot().orders.singleWhere((o) => o.orderId == '999').units?.base, 'BTC');
    expect(batch.cancelled, ['BTCUSDT']);
    expect(
      container.read(orderCancellationProvider).batch?.results['BTCUSDT']?.newerOrderEvents,
      true,
    );
    expect(container.read(openOrdersReadProvider).stale, true);
  });
  test('an event invalidates confirmation of the prior row without a DELETE', () async {
    await controller().refresh();
    await monitor();
    final action = container.read(orderCancellationProvider.notifier);
    final confirmation = action.prepare(snapshot().orders.last)!;
    emit();
    await action.cancel(confirmation);
    expect(cancellation.cancels, 0);
  });
  test(
    'newer REST takes precedence over an older stream event without moving receipt to event clock',
    () async {
      await controller().refresh();
      await monitor();
      emit();
      orders.result = mapAsterOpenOrders(
        [
          openOrder(status: 'PARTIALLY_FILLED', executedQty: '0.3')
            ..['updateTime'] = orderEventClock + 10,
        ],
        address: accountAddress,
        receivedAt: DateTime.utc(2026, 11, 3),
      );
      await controller().refresh();
      expect(snapshot().orders.single.executedQty.toString(), '0.3');
      emit(filled: '0.2', time: orderEventClock + 1);
      expect(snapshot().orders.single.executedQty.toString(), '0.3');
    },
  );
}
