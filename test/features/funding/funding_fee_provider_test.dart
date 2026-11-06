import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/application/funding_fee_provider.dart';
import 'package:vanta/features/funding/domain/funding_fee.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/funding_fee.dart';

void main() {
  const first = fundingFeeQuery;
  const other = FundingFeeQuery(market: TransferMarket.spot, chainId: 1, asset: 'ETH');
  late ProviderContainer container;
  late TestFundingFeeRepository repository;
  late List<ProviderSubscription<FundingFeeState>> listeners;
  void feeTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      repository = TestFundingFeeRepository();
      listeners = [];
      container = ProviderContainer(
        overrides: [fundingFeeRepositoryProvider.overrideWithValue(repository)],
      );
      try {
        await body(tester);
      } finally {
        for (final listener in listeners) {
          listener.close();
        }
        container.dispose();
      }
    });
  }

  void listen(FundingFeeQuery query) =>
      listeners.add(container.listen(fundingFeeProvider(query), (_, _) {}));
  feeTest('same scoped query shares one initial request and ignores duplicate refresh', (
    tester,
  ) async {
    repository.gates[first] = Completer();
    listen(first);
    listen(const FundingFeeQuery(market: TransferMarket.perp, chainId: 56, asset: 'USDT'));
    await tester.pump();
    final duplicate = container.read(fundingFeeProvider(first).notifier).refresh();
    var duplicateDone = false;
    duplicate.then((_) => duplicateDone = true);
    expect(duplicateDone, isFalse);
    expect(repository.calls, [first]);
    repository.gates[first]!.complete(fundingFeeFixture(first));
    await duplicate;
    expect(duplicateDone, isTrue);
    await tester.pump();
    expect(container.read(fundingFeeProvider(first)).quote!.query, first);
  });
  feeTest('failed refresh retains stale fee, safe reason, explicit retry recovers', (tester) async {
    listen(first);
    await tester.pump();
    final old = container.read(fundingFeeProvider(first)).quote;
    repository.failure = const AccountReadFailure('accountNetwork');
    await container.read(fundingFeeProvider(first).notifier).refresh();
    expect(container.read(fundingFeeProvider(first)).quote, same(old));
    expect(container.read(fundingFeeProvider(first)).stale, true);
    expect(container.read(fundingFeeProvider(first)).failureKey, 'accountNetwork');
    repository.failure = null;
    await container.read(fundingFeeProvider(first).notifier).refresh();
    expect(container.read(fundingFeeProvider(first)).stale, false);
    expect(container.read(fundingFeeProvider(first)).failureKey, null);
  });
  feeTest('initial invalid quote is unknown, never zero, and can be retried', (tester) async {
    repository.failure = const FormatException();
    listen(first);
    await tester.pump();
    expect(container.read(fundingFeeProvider(first)).quote, null);
    expect(container.read(fundingFeeProvider(first)).failureKey, 'fundingFeeFailed');
    repository.failure = null;
    await container.read(fundingFeeProvider(first).notifier).refresh();
    expect(container.read(fundingFeeProvider(first)).quote, isNotNull);
  });
  feeTest('30-second expiry works during refresh without automatic fee requests', (tester) async {
    listen(first);
    await tester.pump();
    repository.gates[first] = Completer();
    final pending = container.read(fundingFeeProvider(first).notifier).refresh();
    await tester.pump(const Duration(seconds: 30));
    expect(container.read(fundingFeeProvider(first)).stale, true);
    expect(container.read(fundingFeeProvider(first)).loading, true);
    expect(repository.calls.length, 2);
    repository.gates[first]!.complete(fundingFeeFixture(first));
    await pending;
    expect(container.read(fundingFeeProvider(first)).stale, false);
  });
  feeTest('different market/network/asset never displays a disposed query late result', (
    tester,
  ) async {
    repository.gates[first] = Completer();
    listen(first);
    await tester.pump();
    listeners.single.close();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    listen(other);
    await tester.pump();
    repository.gates[first]!.complete(fundingFeeFixture(first));
    await tester.pump();
    expect(container.exists(fundingFeeProvider(first)), false);
    expect(container.read(fundingFeeProvider(other)).quote!.query, other);
  });
  feeTest('wrong repository scope cannot replace the previous quoted fee', (tester) async {
    listen(first);
    await tester.pump();
    final previous = container.read(fundingFeeProvider(first)).quote;
    repository.gates[first] = Completer();
    final pending = container.read(fundingFeeProvider(first).notifier).refresh();
    repository.gates[first]!.complete(fundingFeeFixture(other));
    await pending;
    expect(container.read(fundingFeeProvider(first)).quote, same(previous));
    expect(container.read(fundingFeeProvider(first)).stale, true);
    expect(container.read(fundingFeeProvider(first)).failureKey, 'fundingFeeFailed');
  });
  feeTest('last route disposes shared transport after pending request, not during it', (
    tester,
  ) async {
    container.dispose();
    var closed = 0;
    container = ProviderContainer(
      overrides: [
        fundingFeeRepositoryProvider.overrideWith((ref) {
          ref.onDispose(() => closed++);
          return repository;
        }),
      ],
    );
    repository.gates[first] = Completer();
    listen(first);
    listen(other);
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
    repository.gates[first]!.complete(fundingFeeFixture(first));
    await tester.pump();
    expect(container.exists(fundingFeeProvider(first)), false);
  });
}
