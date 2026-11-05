import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/application/funding_catalog_provider.dart';
import 'package:vanta/features/funding/data/funding_catalog_mapper.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';

import '../../support/funding_info.dart';

void main() {
  const deposit = FundingCatalogQuery(TransferMarket.perp, FundingOperation.deposit);
  const withdraw = FundingCatalogQuery(TransferMarket.spot, FundingOperation.withdraw);
  late ProviderContainer container;
  late TestFundingCatalogRepository repository;
  late List<ProviderSubscription<FundingCatalogState>> listeners;
  void catalogTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      repository = TestFundingCatalogRepository();
      listeners = [];
      container = ProviderContainer(
        overrides: [fundingCatalogRepositoryProvider.overrideWithValue(repository)],
      );
      try {
        await body(tester);
      } finally {
        for (final l in listeners) {
          l.close();
        }
        container.dispose();
      }
    });
  }

  void listen(FundingCatalogQuery query) =>
      listeners.add(container.listen(fundingCatalogProvider(query), (_, _) {}));
  FundingCatalog catalog(FundingCatalogQuery query) =>
      mapFundingCatalog(fundingCatalogPayload(), query: query, receivedAt: DateTime.now());
  catalogTest('equal query instances share one anonymous request and parallel refresh is ignored', (
    tester,
  ) async {
    repository.gates[deposit] = Completer();
    listen(deposit);
    listen(FundingCatalogQuery(deposit.market, deposit.operation));
    await tester.pump();
    await container.read(fundingCatalogProvider(deposit).notifier).refresh();
    expect(repository.calls, [deposit]);
    repository.gates[deposit]!.complete(catalog(deposit));
    await tester.pump();
    expect(container.read(fundingCatalogProvider(deposit)).catalog!.query, deposit);
  });
  catalogTest('failed refresh retains old assets, marks stale and recovers explicitly', (
    tester,
  ) async {
    listen(deposit);
    await tester.pump();
    final old = container.read(fundingCatalogProvider(deposit)).catalog;
    repository.failure = const FormatException();
    await container.read(fundingCatalogProvider(deposit).notifier).refresh();
    expect(container.read(fundingCatalogProvider(deposit)).catalog, same(old));
    expect(container.read(fundingCatalogProvider(deposit)).stale, true);
    expect(container.read(fundingCatalogProvider(deposit)).failureKey, 'fundingCatalogFailed');
    repository.failure = null;
    await container.read(fundingCatalogProvider(deposit).notifier).refresh();
    expect(container.read(fundingCatalogProvider(deposit)).stale, false);
  });
  catalogTest('five-minute expiry survives a gated refresh and never silently refetches', (
    tester,
  ) async {
    listen(deposit);
    await tester.pump();
    repository.gates[deposit] = Completer();
    final pending = container.read(fundingCatalogProvider(deposit).notifier).refresh();
    await tester.pump(const Duration(minutes: 5));
    expect(container.read(fundingCatalogProvider(deposit)).loading, true);
    expect(container.read(fundingCatalogProvider(deposit)).stale, true);
    expect(repository.calls.length, 2);
    repository.gates[deposit]!.complete(catalog(deposit));
    await pending;
    expect(container.read(fundingCatalogProvider(deposit)).stale, false);
  });
  catalogTest('market/operation scopes do not reuse late results from a disposed family', (
    tester,
  ) async {
    repository.gates[deposit] = Completer();
    listen(deposit);
    await tester.pump();
    listeners.single.close();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    listen(withdraw);
    await tester.pump();
    repository.gates[deposit]!.complete(catalog(deposit));
    await tester.pump();
    expect(container.exists(fundingCatalogProvider(deposit)), false);
    expect(container.read(fundingCatalogProvider(withdraw)).catalog!.query, withdraw);
  });
  catalogTest('wrong repository query cannot label one market as another', (tester) async {
    repository.gates[deposit] = Completer();
    listen(deposit);
    await tester.pump();
    repository.gates[deposit]!.complete(catalog(withdraw));
    await tester.pump();
    expect(container.read(fundingCatalogProvider(deposit)).catalog, null);
    expect(container.read(fundingCatalogProvider(deposit)).failureKey, 'fundingCatalogFailed');
  });
  catalogTest('repository remains alive through requests and closes after the last family', (
    tester,
  ) async {
    container.dispose();
    var closed = 0;
    container = ProviderContainer(
      overrides: [
        fundingCatalogRepositoryProvider.overrideWith((ref) {
          ref.onDispose(() => closed++);
          return repository;
        }),
      ],
    );
    listen(deposit);
    listen(withdraw);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 0);
    listeners.first.close();
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 0);
    listeners.last.close();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 1);
  });
}
