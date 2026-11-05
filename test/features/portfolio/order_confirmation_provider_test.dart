import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/order_confirmation_provider.dart';
import 'package:vanta/features/portfolio/data/order_confirmation_preferences.dart';

import '../../support/quick_order.dart';

import 'package:vanta/features/portfolio/domain/order_confirmation.dart';

class DelayedPreferences implements OrderConfirmationPreferences {
  final readGate = Completer<bool>(), firstWrite = Completer<void>();
  final writes = <bool>[];
  @override
  Future<bool> read(OrderConfirmationKind kind) => readGate.future;
  @override
  Future<void> write(OrderConfirmationKind kind, bool value) async {
    writes.add(value);
    if (writes.length == 1) await firstWrite.future;
  }
}

void main() {
  test('default/read failure requires confirmation; a saved preference restores', () async {
    final store = MemoryOrderConfirmationPreferences()..failRead = true;
    final container = ProviderContainer(
      overrides: [orderConfirmationPreferencesProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    expect(container.read(marketOrderConfirmationProvider).required, true);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(marketOrderConfirmationProvider).required, true);
    expect(container.read(marketOrderConfirmationProvider).failure, true);
    await container.read(marketOrderConfirmationProvider.notifier).select(false);
    expect(store.required, false);
    store.failRead = false;
    final restored = ProviderContainer(
      overrides: [orderConfirmationPreferencesProvider.overrideWithValue(store)],
    );
    addTearDown(restored.dispose);
    restored.read(marketOrderConfirmationProvider);
    await Future<void>.delayed(Duration.zero);
    expect(restored.read(marketOrderConfirmationProvider).required, false);
  });
  test('failed save retains the last persisted preference and reports failure', () async {
    final store = MemoryOrderConfirmationPreferences();
    final container = ProviderContainer(
      overrides: [orderConfirmationPreferencesProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    container.read(marketOrderConfirmationProvider);
    await Future<void>.delayed(Duration.zero);
    store.failWrite = true;
    await container.read(marketOrderConfirmationProvider.notifier).select(false);
    expect(container.read(marketOrderConfirmationProvider).required, true);
    expect(container.read(marketOrderConfirmationProvider).failure, true);
    expect(store.required, true);
  });
  test('late load cannot overwrite an explicit preference and writes stay ordered', () async {
    final store = DelayedPreferences();
    final container = ProviderContainer(
      overrides: [orderConfirmationPreferencesProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    container.read(marketOrderConfirmationProvider);
    await Future<void>.delayed(Duration.zero);
    final first = container.read(marketOrderConfirmationProvider.notifier).select(false);
    final second = container.read(marketOrderConfirmationProvider.notifier).select(true);
    store.readGate.complete(false);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(marketOrderConfirmationProvider).required, true);
    expect(store.writes, [false]);
    store.firstWrite.complete();
    await Future.wait([first, second]);
    expect(store.writes, [false, true]);
    expect(container.read(marketOrderConfirmationProvider).required, true);
  });
}
