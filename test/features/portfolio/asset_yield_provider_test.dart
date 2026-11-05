import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/portfolio/application/asset_yield_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/asset_yield.dart';

import '../../support/asset_yields.dart';

void main() {
  late DateTime now;
  late TestAssetYieldRepository repository;
  late ProviderContainer container;
  final listeners = <ProviderSubscription<AssetYieldState>>[];
  void initialize() {
    now = DateTime.utc(2026, 11, 4, 12);
    repository = TestAssetYieldRepository(now: () => now);
    container = ProviderContainer(
      overrides: [
        assetYieldClockProvider.overrideWithValue(() => now),
        assetYieldRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  void watch(YieldAsset asset) =>
      listeners.add(container.listen(assetYieldProvider(asset), (_, _) {}));
  AssetYieldState state([YieldAsset asset = YieldAsset.usdf]) =>
      container.read(assetYieldProvider(asset));
  Future<void> advance(WidgetTester tester, Duration duration) async {
    now = now.add(duration);
    await tester.pump(duration);
    await tester.pump();
  }

  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      initialize();
      try {
        await body(tester);
      } finally {
        for (final listener in listeners) {
          listener.close();
        }
        listeners.clear();
        container.dispose();
      }
    });
  }

  scenario('no requests before a displayed asset subscribes; shared family deduplicates readers', (
    tester,
  ) async {
    await tester.pump();
    expect(repository.calls, isEmpty);
    watch(YieldAsset.usdf);
    watch(YieldAsset.usdf);
    await tester.pump();
    expect(repository.calls, [YieldAsset.usdf]);
    expect(state().quote!.percent.toString(), '11.45');
  });
  scenario('different assets fail independently without discarding a successful rate', (
    tester,
  ) async {
    repository.failures[YieldAsset.asbnb] = const AccountReadFailure('accountNetwork');
    watch(YieldAsset.usdf);
    watch(YieldAsset.asbnb);
    await tester.pump();
    expect(state().quote, isNotNull);
    expect(state().failureKey, null);
    expect(state(YieldAsset.asbnb).quote, null);
    expect(state(YieldAsset.asbnb).failureKey, 'accountNetwork');
  });
  scenario('five-minute polling; manual requests deduplicate while in flight', (tester) async {
    repository.gates[YieldAsset.usdf] = Completer();
    watch(YieldAsset.usdf);
    await tester.pump();
    expect(state().loading, true);
    await container.read(assetYieldProvider(YieldAsset.usdf).notifier).refresh();
    expect(repository.calls.length, 1);
    repository.gates.remove(YieldAsset.usdf)!.complete(assetYieldFixture(YieldAsset.usdf, now));
    await tester.pump();
    await advance(tester, const Duration(minutes: 4, seconds: 59));
    expect(repository.calls.length, 1);
    await advance(tester, const Duration(seconds: 1));
    expect(repository.calls.length, 2);
    expect(state().quote!.receivedAt, now);
  });
  scenario('old receipt becomes stale during a gated refresh, not just after completion', (
    tester,
  ) async {
    watch(YieldAsset.usdf);
    await tester.pump();
    repository.gates[YieldAsset.usdf] = Completer();
    await advance(tester, const Duration(minutes: 5));
    expect(state().loading, true);
    expect(state().stale, true);
    repository.gates.remove(YieldAsset.usdf)!.complete(assetYieldFixture(YieldAsset.usdf, now));
    await tester.pump();
    expect(state().stale, false);
  });
  scenario('failed refresh retains old quote and explicit retry recovers', (tester) async {
    watch(YieldAsset.usdf);
    await tester.pump();
    final old = state().quote;
    repository.failures[YieldAsset.usdf] = const AccountReadFailure('accountDataInvalid');
    await container.read(assetYieldProvider(YieldAsset.usdf).notifier).refresh();
    expect(state().quote, same(old));
    expect(state().stale, true);
    expect(state().failureKey, 'accountDataInvalid');
    repository.failures.clear();
    await container.read(assetYieldProvider(YieldAsset.usdf).notifier).refresh();
    expect(state().failureKey, null);
    expect(state().stale, false);
  });
  scenario('fresh HTTP read does not make an old source day current', (tester) async {
    final old = assetYieldFixture(YieldAsset.usdf, now.subtract(const Duration(days: 3)));
    repository.quotes[YieldAsset.usdf] = AssetYieldQuote(
      asset: old.asset,
      percent: old.percent,
      sourceDay: old.sourceDay,
      receivedAt: now,
    );
    watch(YieldAsset.usdf);
    await tester.pump();
    expect(state().stale, true);
    await container.read(assetYieldProvider(YieldAsset.usdf).notifier).refresh();
    expect(state().stale, true);
  });
  scenario('UTC day boundary expires published rate during an in-flight read', (tester) async {
    now = DateTime.utc(2026, 11, 4, 23, 59, 59);
    final base = assetYieldFixture(YieldAsset.usdf, now.subtract(const Duration(days: 2)));
    repository.quotes[YieldAsset.usdf] = AssetYieldQuote(
      asset: base.asset,
      percent: base.percent,
      sourceDay: base.sourceDay,
      receivedAt: now,
    );
    watch(YieldAsset.usdf);
    await tester.pump();
    expect(state().stale, false);
    repository.gates[YieldAsset.usdf] = Completer();
    unawaited(container.read(assetYieldProvider(YieldAsset.usdf).notifier).refresh());
    await tester.pump();
    await advance(tester, const Duration(seconds: 1));
    expect(state().stale, true);
    repository.gates.remove(YieldAsset.usdf)!.complete(assetYieldFixture(YieldAsset.usdf, now));
    await tester.pump();
    expect(state().stale, false);
  });
  scenario('background discards late quote, suspends reads/timers, foreground refreshes', (
    tester,
  ) async {
    watch(YieldAsset.usdf);
    await tester.pump();
    final old = state().quote;
    repository.gates[YieldAsset.usdf] = Completer();
    final pending = container.read(assetYieldProvider(YieldAsset.usdf).notifier).refresh();
    container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    expect(state().active, false);
    expect(state().loading, false);
    expect(state().stale, true);
    repository.gates
        .remove(YieldAsset.usdf)!
        .complete(assetYieldFixture(YieldAsset.usdf, now.add(const Duration(minutes: 1))));
    await pending;
    expect(state().quote, same(old));
    await advance(tester, const Duration(minutes: 20));
    await container.read(assetYieldProvider(YieldAsset.usdf).notifier).refresh();
    expect(repository.calls.length, 2);
    container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await tester.pump();
    expect(repository.calls.length, 3);
    expect(state().quote!.receivedAt, now);
  });
  scenario('initial inactive page does not request, then reads on foreground', (tester) async {
    container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    watch(YieldAsset.usdf);
    await tester.pump();
    expect(repository.calls, isEmpty);
    expect(state().active, false);
    container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await tester.pump();
    expect(repository.calls, [YieldAsset.usdf]);
  });
  scenario('late response after last listener is disposed is discarded and timers stop', (
    tester,
  ) async {
    repository.gates[YieldAsset.usdf] = Completer();
    watch(YieldAsset.usdf);
    await tester.pump();
    listeners.removeLast().close();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(container.exists(assetYieldProvider(YieldAsset.usdf)), false);
    repository.gates.remove(YieldAsset.usdf)!.complete(assetYieldFixture(YieldAsset.usdf, now));
    await tester.pump();
    await advance(tester, const Duration(minutes: 10));
    expect(repository.calls.length, 1);
    watch(YieldAsset.usdf);
    await tester.pump();
    expect(repository.calls.length, 2);
  });
  scenario('wrong asset quote is rejected and failures expose only safe keys', (tester) async {
    repository.quotes[YieldAsset.usdf] = assetYieldFixture(YieldAsset.asbnb, now);
    watch(YieldAsset.usdf);
    await tester.pump();
    expect(state().quote, null);
    expect(state().failureKey, 'accountDataInvalid');
    repository.quotes.clear();
    repository.failures[YieldAsset.usdf] = const AccountReadFailure('sensitive raw credentials');
    await container.read(assetYieldProvider(YieldAsset.usdf).notifier).refresh();
    expect(state().failureKey, 'assetYieldFailed');
    repository.failures[YieldAsset.usdf] = StateError('sensitive stack');
    await container.read(assetYieldProvider(YieldAsset.usdf).notifier).refresh();
    expect(state().failureKey, 'assetYieldFailed');
  });
  scenario('repository stays alive during delayed request and releases after last asset listener', (
    tester,
  ) async {
    container.dispose();
    var closed = 0;
    container = ProviderContainer(
      overrides: [
        assetYieldClockProvider.overrideWithValue(() => now),
        assetYieldRepositoryProvider.overrideWith((ref) {
          ref.onDispose(() => closed++);
          return repository;
        }),
      ],
    );
    repository.gates[YieldAsset.usdf] = Completer();
    watch(YieldAsset.usdf);
    watch(YieldAsset.asbnb);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 0);
    listeners.removeLast().close();
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 0);
    repository.gates.remove(YieldAsset.usdf)!.complete(assetYieldFixture(YieldAsset.usdf, now));
    await tester.pump();
    expect(closed, 0);
    listeners.removeLast().close();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 1);
  });
}
