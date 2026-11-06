import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/portfolio/application/asset_metadata_provider.dart';
import 'package:vanta/features/portfolio/data/asset_metadata_mapper.dart';
import 'package:vanta/features/portfolio/domain/asset_metadata.dart';

import '../../support/asset_metadata.dart';

void main() {
  final base = DateTime.utc(2026, 11, 4);
  const names = AssetMetadataSource.names, logos = AssetMetadataSource.logos;
  late DateTime now;
  late ProviderContainer c;
  late TestAssetMetadataRepository repository;
  final listeners = <ProviderSubscription<AssetMetadataState>>[];
  AssetMetadataSnapshot snapshot(AssetMetadataSource source) =>
      mapAssetMetadata(metadataPayload(source), source: source, receivedAt: now);
  AssetMetadataState state([AssetMetadataSource source = names]) =>
      c.read(assetMetadataProvider(source));
  Future<void> refresh([AssetMetadataSource source = names]) =>
      c.read(assetMetadataProvider(source).notifier).refresh();
  void check(String name, Future<void> Function(WidgetTester) run) {
    testWidgets(name, (t) async {
      now = base;
      repository = TestAssetMetadataRepository(now: () => now);
      c = ProviderContainer(
        overrides: [
          assetMetadataClockProvider.overrideWithValue(() => now),
          assetMetadataRepositoryProvider.overrideWithValue(repository),
        ],
      );
      listeners.add(c.listen(assetMetadataProvider(names), (_, _) {}));
      try {
        await run(t);
      } finally {
        for (final l in listeners) {
          l.close();
        }
        listeners.clear();
        c.dispose();
      }
    });
  }

  check(
    'initial public catalogs shared by consumers, independent source failures retain the other source',
    (t) async {
      repository.snapshots[names] = snapshot(names);
      repository.failures[logos] = StateError('fixture');
      listeners.add(c.listen(assetMetadataProvider(logos), (_, _) {}));
      listeners.add(c.listen(assetMetadataProvider(names), (_, _) {}));
      await t.pump();
      expect(repository.calls.where((s) => s == names).length, 1);
      expect(repository.calls.where((s) => s == logos).length, 1);
      expect(state().snapshot!.forSymbol('USDT')!.name, 'TetherUS');
      expect(state(logos).failed, true);
      expect(state().failed, false);
    },
  );
  check('manual refresh joins busy state without another request', (t) async {
    repository.gates[names] = Completer();
    await t.pump();
    expect(state().loading, true);
    final duplicate = refresh();
    expect(repository.calls.length, 1);
    repository.gates.remove(names)!.complete(snapshot(names));
    await t.pump();
    await duplicate;
    expect(state().snapshot, isNotNull);
  });
  check('failed refresh keeps previous names and marks them stale, no timer retries', (t) async {
    repository.snapshots[names] = snapshot(names);
    await t.pump();
    repository.failures[names] = StateError('fixture');
    await refresh();
    expect(state().failed, true);
    expect(state().stale, true);
    expect(state().snapshot!.forSymbol('USDT')!.name, 'TetherUS');
    now = now.add(const Duration(hours: 1));
    await t.pump(const Duration(hours: 1));
    expect(repository.calls.length, 2);
  });
  check('metadata becomes stale after15 minutes, no background polling', (t) async {
    await t.pump();
    now = now.add(const Duration(minutes: 15));
    await t.pump(const Duration(minutes: 15));
    expect(state().stale, true);
    expect(repository.calls.length, 1);
  });
  check('pause discards in-flight result; resume explicitly refreshes missing or expired source', (
    t,
  ) async {
    repository.gates[names] = Completer();
    await t.pump();
    c.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    repository.gates.remove(names)!.complete(snapshot(names));
    await t.pump();
    expect(state().snapshot, null);
    expect(state().active, false);
    c.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await t.pump();
    expect(repository.calls.length, 2);
    expect(state().snapshot, isNotNull);
  });
  check('resume reuses fresh source and leaves failed requests for manual retry', (t) async {
    await t.pump();
    c.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    c.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await t.pump();
    expect(repository.calls.length, 1);
    repository.failures[names] = StateError('fixture');
    await refresh();
    c.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    c.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await t.pump();
    expect(repository.calls.length, 2);
    expect(state().failed, true);
    repository.failures.clear();
    await refresh();
    expect(state().failed, false);
    expect(repository.calls.length, 3);
  });
  for (final mismatch in ['source', 'stale', 'future']) {
    check('wrong $mismatch repository result never replaces displayed metadata', (t) async {
      repository.snapshots[names] = AssetMetadataSnapshot(
        source: mismatch == 'source' ? logos : names,
        receivedAt: mismatch == 'stale'
            ? now.subtract(const Duration(minutes: 15))
            : mismatch == 'future'
            ? now.add(const Duration(minutes: 1))
            : now,
        entries: const {},
      );
      await t.pump();
      expect(state().failed, true);
      expect(state().snapshot, null);
    });
  }
  check('disposal during public read discards late data without another request', (t) async {
    repository.gates[names] = Completer();
    await t.pump();
    for (final l in listeners) {
      l.close();
    }
    listeners.clear();
    await t.pump();
    repository.gates.remove(names)!.complete(snapshot(names));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1));
    await t.pump(const Duration(milliseconds: 1));
    expect(c.exists(assetMetadataProvider(names)), false);
    expect(repository.calls.length, 1);
  });
}
