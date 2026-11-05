import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vanta/features/portfolio/application/order_confirmation_provider.dart';
import 'package:vanta/features/portfolio/data/order_confirmation_preferences.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/order_confirmation.dart';

import '../../support/quick_order.dart';

class PreferenceBackend implements SharedPreferencesAsync {
  final values = <String, Object>{};
  final touched = <String>[];
  final failures = <String>{};
  bool get failRead => failures.contains('read');
  bool get failWrite => failures.contains('write');
  set failRead(bool value) {
    value ? failures.add('read') : failures.remove('read');
  }

  set failWrite(bool value) {
    value ? failures.add('write') : failures.remove('write');
  }

  @override
  Future<bool?> getBool(String key) async {
    touched.add(key);
    if (failRead) throw StateError('Read failed');
    return values[key] as bool?;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    touched.add(key);
    if (failWrite) throw StateError('Write failed');
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('Unexpected storage call');
}

class GatedPreferences implements OrderConfirmationPreferences {
  final reads = {for (final kind in OrderConfirmationKind.values) kind: Completer<bool>()};
  final writes = <(OrderConfirmationKind, bool)>[];
  final gates = <Completer<void>>[];
  final failing = <int>{};
  @override
  Future<bool> read(OrderConfirmationKind kind) => reads[kind]!.future;
  @override
  Future<void> write(OrderConfirmationKind kind, bool value) async {
    final index = writes.length;
    writes.add((kind, value));
    if (index < gates.length) await gates[index].future;
    if (failing.contains(index)) throw StateError('write failed');
  }
}

void main() {
  for (final policy in LiveOrderTimeInForce.values) {
    test('all ordinary limit policies share limit mode $policy', () {
      expect(
        orderConfirmationKind(
          LiveOrderDraft(buy: true, market: false, quantity: '1', price: '2', timeInForce: policy),
        ),
        OrderConfirmationKind.limit,
      );
    });
  }
  for (final buy in [true, false]) {
    for (final trigger in LiveOrderTriggerKind.values) {
      for (final market in [true, false]) {
        test('conditional kind separate from ordinary/type direction $buy $trigger $market', () {
          final draft = LiveOrderDraft(
            buy: buy,
            market: market,
            quantity: '1',
            price: market ? '' : '2',
            trigger: LiveOrderTrigger(kind: trigger, price: '2'),
          );
          expect(
            orderConfirmationKind(draft),
            market ? OrderConfirmationKind.stopMarket : OrderConfirmationKind.stopLimit,
          );
        });
      }
    }
  }
  test('market and quick entry share; trailing has its own mode', () {
    for (final quick in [true, false]) {
      expect(
        orderConfirmationKind(
          LiveOrderDraft(buy: true, market: true, quantity: '1', price: '', quickEntry: quick),
        ),
        OrderConfirmationKind.market,
      );
    }
    expect(
      orderConfirmationKind(
        const LiveOrderDraft(
          buy: false,
          market: true,
          quantity: '1',
          price: '',
          trailing: LiveOrderTrailing(callbackRate: '1'),
        ),
      ),
      OrderConfirmationKind.trailing,
    );
  });
  test('legacy explicit market false restores without disabling new modes', () async {
    final backend = PreferenceBackend()..values['vanta.confirmMarketOrders'] = false;
    final store = LocalOrderConfirmationPreferences(preferences: backend);
    expect(await store.read(OrderConfirmationKind.market), false);
    for (final kind in OrderConfirmationKind.values.where(
      (v) => v != OrderConfirmationKind.market,
    )) {
      expect(await store.read(kind), true);
    }
    expect(backend.values, {'vanta.confirmMarketOrders': false});
  });
  test('actual local store writes isolate modes and survive repository reconstruction', () async {
    final backend = PreferenceBackend();
    final store = LocalOrderConfirmationPreferences(preferences: backend);
    await store.write(OrderConfirmationKind.limit, false);
    await store.write(OrderConfirmationKind.stopMarket, false);
    final restored = LocalOrderConfirmationPreferences(preferences: backend);
    for (final kind in OrderConfirmationKind.values) {
      expect(
        await restored.read(kind),
        !{OrderConfirmationKind.limit, OrderConfirmationKind.stopMarket}.contains(kind),
      );
    }
    await restored.write(OrderConfirmationKind.limit, true);
    expect(await store.read(OrderConfirmationKind.limit), true);
    expect(await store.read(OrderConfirmationKind.stopMarket), false);
    expect(backend.values.length, 2);
  });
  for (final kind in OrderConfirmationKind.values) {
    test('per-mode default/restoration/read failure remains explicit $kind', () async {
      final store = MemoryOrderConfirmationPreferences()..failRead = true;
      final provider = orderConfirmationProvider(kind);
      final container = ProviderContainer(
        overrides: [orderConfirmationPreferencesProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      expect(container.read(provider).required, true);
      expect(container.read(provider).canSkip, false);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).failure, true);
      expect(container.read(provider).canSkip, false);
      store.failRead = false;
      await container.read(provider.notifier).select(false);
      expect(container.read(provider).canSkip, true);
      final restored = ProviderContainer(
        overrides: [orderConfirmationPreferencesProvider.overrideWithValue(store)],
      );
      addTearDown(restored.dispose);
      restored.read(provider);
      await Future<void>.delayed(Duration.zero);
      expect(restored.read(provider).required, false);
      expect(restored.read(provider).canSkip, true);
      for (final other in OrderConfirmationKind.values.where((v) => v != kind)) {
        expect(store.values[other], null);
      }
    });
    test('failed write while disabled requires review until explicitly saved $kind', () async {
      final store = MemoryOrderConfirmationPreferences()..values[kind] = false;
      final provider = orderConfirmationProvider(kind);
      final container = ProviderContainer(
        overrides: [orderConfirmationPreferencesProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      container.read(provider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).canSkip, true);
      store.failWrite = true;
      await container.read(provider.notifier).select(true);
      expect(container.read(provider).required, false);
      expect(container.read(provider).failure, true);
      expect(container.read(provider).canSkip, false);
      expect(store.values[kind], false);
      store.failWrite = false;
      await container.read(provider.notifier).select(true);
      expect(container.read(provider).required, true);
      expect(container.read(provider).failure, false);
    });
  }
  test('mode loads and writes are isolated while a second same-mode write stays ordered', () async {
    final store = GatedPreferences()..gates.add(Completer<void>());
    final container = ProviderContainer(
      overrides: [orderConfirmationPreferencesProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final limit = orderConfirmationProvider(OrderConfirmationKind.limit),
        market = marketOrderConfirmationProvider;
    container.read(limit);
    container.read(market);
    await Future<void>.delayed(Duration.zero);
    final a = container.read(limit.notifier).select(false);
    final b = container.read(limit.notifier).select(true);
    final c = container.read(market.notifier).select(false);
    store.reads[OrderConfirmationKind.limit]!.complete(false);
    store.reads[OrderConfirmationKind.market]!.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(limit).canSkip, false);
    expect(container.read(market).canSkip, true);
    expect(store.writes, [
      (OrderConfirmationKind.limit, false),
      (OrderConfirmationKind.market, false),
    ]);
    store.gates.first.complete();
    await Future.wait([a, b, c]);
    expect(store.writes.last, (OrderConfirmationKind.limit, true));
    expect(container.read(limit).required, true);
    expect(container.read(market).required, false);
  });
  test('failed queued write does not prevent later save; old failure cannot win', () async {
    final store = GatedPreferences()
      ..gates.add(Completer<void>())
      ..failing.add(0);
    final container = ProviderContainer(
      overrides: [orderConfirmationPreferencesProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final provider = orderConfirmationProvider(OrderConfirmationKind.trailing);
    container.read(provider);
    await Future<void>.delayed(Duration.zero);
    final a = container.read(provider.notifier).select(false),
        b = container.read(provider.notifier).select(true);
    store.gates.first.complete();
    await Future.wait([a, b]);
    store.reads[OrderConfirmationKind.trailing]!.complete(false);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).required, true);
    expect(container.read(provider).failure, false);
    expect(store.writes, [
      (OrderConfirmationKind.trailing, false),
      (OrderConfirmationKind.trailing, true),
    ]);
  });
  test('dispose before delayed read and save discards updates without a new load', () async {
    final store = GatedPreferences()..gates.add(Completer<void>());
    final container = ProviderContainer(
      overrides: [orderConfirmationPreferencesProvider.overrideWithValue(store)],
    );
    final provider = orderConfirmationProvider(OrderConfirmationKind.stopLimit);
    container.read(provider);
    await Future<void>.delayed(Duration.zero);
    final write = container.read(provider.notifier).select(false);
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    store.reads[OrderConfirmationKind.stopLimit]!.complete(true);
    store.gates.first.complete();
    await write;
    expect(store.writes, [(OrderConfirmationKind.stopLimit, false)]);
  });
  test('corrupted boolean and local write failures propagate to application boundary', () async {
    final backend = PreferenceBackend()..values['vanta.confirmLimitOrders'] = 'false';
    final store = LocalOrderConfirmationPreferences(preferences: backend);
    await expectLater(store.read(OrderConfirmationKind.limit), throwsA(isA<TypeError>()));
    backend.failWrite = true;
    await expectLater(store.write(OrderConfirmationKind.limit, false), throwsStateError);
    expect(backend.values['vanta.confirmLimitOrders'], 'false');
  });
}
