import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/portfolio/application/asset_index_provider.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';

import '../../support/asset_indices.dart';

void main() {
  late DateTime now;
  late TestAssetIndexRepository repository;
  late ProviderContainer container;
  late ProviderSubscription<AssetIndexState> listener;
  void initialize() {
    now = DateTime.utc(2026, 11, 3, 12);
    repository = TestAssetIndexRepository(now: () => now);
    container = ProviderContainer(
      overrides: [
        assetIndexClockProvider.overrideWithValue(() => now),
        assetIndexRepositoryProvider.overrideWithValue(repository),
      ],
    );
    listener = container.listen(assetIndexProvider, (_, _) {});
  }

  void valueTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      initialize();
      try {
        await body(tester);
      } finally {
        listener.close();
        container.dispose();
      }
    });
  }

  Future<void> advance(WidgetTester tester, int seconds) async {
    now = now.add(Duration(seconds: seconds));
    await tester.pump(Duration(seconds: seconds));
    await tester.pump();
  }

  valueTest('price repository stays alive during delayed refresh and closes with its controller', (
    tester,
  ) async {
    listener.close();
    container.dispose();
    var closed = 0;
    container = ProviderContainer(
      overrides: [
        assetIndexClockProvider.overrideWithValue(() => now),
        assetIndexRepositoryProvider.overrideWith((ref) {
          ref.onDispose(() => closed++);
          return repository;
        }),
      ],
    );
    repository.gate = Completer();
    listener = container.listen(assetIndexProvider, (_, _) {});
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 0);
    repository.gate!.complete(assetIndexFixture(now));
    await tester.pump();
    expect(closed, 0);
    listener.close();
    await tester.pump(const Duration(milliseconds: 1));
    // Kept briefly for the next order-pricing subscription, then released.
    expect(closed, 0);
    await tester.pump(const Duration(seconds: 60));
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 1);
  });
  valueTest('initial public read, thirty-second polling, no parallel manual request', (
    tester,
  ) async {
    repository.gate = Completer();
    await tester.pump();
    expect(repository.calls, 1);
    expect(container.read(assetIndexProvider).loading, true);
    final duplicate = container.read(assetIndexProvider.notifier).refresh();
    expect(repository.calls, 1);
    repository.gate!.complete(assetIndexFixture(now));
    repository.gate = null;
    await tester.pump();
    await duplicate;
    expect(container.read(assetIndexProvider).loading, false);
    await advance(tester, 29);
    expect(repository.calls, 1);
    await advance(tester, 1);
    expect(repository.calls, 2);
    expect(container.read(assetIndexProvider).snapshot!.receivedAt, now);
  });
  valueTest('receipt expiry updates freshness during a gated request', (tester) async {
    await tester.pump();
    final snapshot = container.read(assetIndexProvider).snapshot!;
    repository.gate = Completer();
    await advance(tester, 30);
    expect(repository.calls, 2);
    expect(container.read(assetIndexProvider).fresh(snapshot.forAsset('USDT')!), true);
    await advance(tester, 30);
    final state = container.read(assetIndexProvider);
    expect(state.loading, true);
    expect(state.checkedAt, now);
    expect(state.fresh(snapshot.forAsset('USDT')!), false);
    repository.gate!.complete(assetIndexFixture(now));
    await tester.pump();
    expect(
      container
          .read(assetIndexProvider)
          .fresh(container.read(assetIndexProvider).snapshot!.forAsset('USDT')!),
      true,
    );
  });
  valueTest('source timestamp expires before receipt and missing prices remain safe', (
    tester,
  ) async {
    repository.result = assetIndexFixture(
      now.subtract(const Duration(seconds: 89)),
      receivedAt: now,
    );
    await tester.pump();
    expect(container.read(assetIndexProvider).fresh(repository.result!.forAsset('USDT')!), true);
    await advance(tester, 1);
    expect(container.read(assetIndexProvider).fresh(repository.result!.forAsset('USDT')!), false);
  });
  valueTest('failed refresh preserves values, marks stale and supports manual retry', (
    tester,
  ) async {
    await tester.pump();
    final snapshot = container.read(assetIndexProvider).snapshot;
    repository.failure = StateError('unavailable');
    await container.read(assetIndexProvider.notifier).refresh();
    var state = container.read(assetIndexProvider);
    expect(state.snapshot, same(snapshot));
    expect(state.failed, true);
    expect(state.fresh(snapshot!.forAsset('USDT')!), false);
    repository.failure = null;
    await container.read(assetIndexProvider.notifier).refresh();
    state = container.read(assetIndexProvider);
    expect(state.failed, false);
    expect(state.fresh(state.snapshot!.forAsset('USDT')!), true);
  });
  valueTest('pause stops polling, resume fetches, late pre-pause results cannot overwrite', (
    tester,
  ) async {
    final gate = repository.gate = Completer();
    await tester.pump();
    container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    await tester.pump();
    expect(container.read(assetIndexProvider).active, false);
    expect(container.read(assetIndexProvider).loading, false);
    await advance(tester, 120);
    expect(repository.calls, 1);
    repository.gate = null;
    container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await tester.pump();
    final resumed = container.read(assetIndexProvider).snapshot;
    expect(resumed!.receivedAt, now);
    expect(container.read(assetIndexProvider).active, true);
    gate.complete(assetIndexFixture(now.subtract(const Duration(hours: 1))));
    await tester.pump();
    expect(container.read(assetIndexProvider).snapshot, same(resumed));
    expect(repository.calls, 2);
  });
  valueTest('auto-disposal cancels timers and ignores pending network completion', (tester) async {
    await tester.pump();
    final gate = repository.gate = Completer();
    await advance(tester, 30);
    listener.close();
    await tester.pump(const Duration(milliseconds: 1));
    expect(container.exists(assetIndexProvider), true);
    await tester.pump(const Duration(seconds: 60));
    await tester.pump(const Duration(milliseconds: 1));
    expect(container.exists(assetIndexProvider), false);
    gate.complete(assetIndexFixture(now));
    await tester.pump();
    await advance(tester, 120);
    expect(repository.calls, 2);
  });
  valueTest('a resubscription within the grace period keeps the current rates', (tester) async {
    await tester.pump();
    expect(container.read(assetIndexProvider).snapshot, isNotNull);
    listener.close();
    await tester.pump(const Duration(seconds: 20));
    listener = container.listen(assetIndexProvider, (_, _) {});
    expect(container.read(assetIndexProvider).snapshot, isNotNull);
    await tester.pump(const Duration(seconds: 60));
    expect(container.exists(assetIndexProvider), true);
  });
  valueTest('a failed refresh keeps the last snapshot and retries after five seconds', (
    tester,
  ) async {
    await tester.pump();
    final calls = repository.calls;
    repository.failure = Exception('network');
    await advance(tester, 30);
    expect(repository.calls, calls + 1);
    expect(container.read(assetIndexProvider).failed, true);
    expect(container.read(assetIndexProvider).snapshot, isNotNull);
    repository.failure = null;
    await advance(tester, 5);
    expect(repository.calls, calls + 2);
    expect(container.read(assetIndexProvider).failed, false);
  });
}
