import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/order_recovery_provider.dart';
import 'package:vanta/features/portfolio/application/strategy_execution_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';
import 'package:vanta/features/portfolio/domain/strategy_execution.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/strategy_execution.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestStrategyExecutionRepository repository;
  late StrategyExecutionFixture fixture;
  late MemoryOrderRecoveryJournal journal;
  late DateTime now;
  late ProviderSubscription<StrategyExecutionState> listener;
  StrategyExecutionController controller() =>
      container.read(strategyExecutionProvider(fixture.query).notifier);
  StrategyExecutionState state() => container.read(strategyExecutionProvider(fixture.query));
  Future<void> setup() async {
    now = liveOrderClock;
    fixture = StrategyExecutionFixture();
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestStrategyExecutionRepository(fixture);
    journal = MemoryOrderRecoveryJournal();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        strategyExecutionRepositoryProvider.overrideWithValue(repository),
        liveOrderClockProvider.overrideWithValue(() => now),
        orderRecoveryJournalProvider.overrideWithValue(journal),
      ],
    );
    container.read(authProvider);
    listener = container.listen(strategyExecutionProvider(fixture.query), (_, _) {});
    await Future<void>.delayed(Duration.zero);
  }

  tearDown(() async {
    container.dispose();
    await identity.dispose();
    await journal.close();
  });

  test(
    'opening is passive; reads explicitly and never creates a wallet or completes pending journal',
    () async {
      await setup();
      expect(repository.calls, 0);
      expect(identity.wallets, 0);
      journal.publish(
        OrderRecoverySnapshot(
          records: [OrderRecoveryRecord(query: fixture.query.order, createdAt: now)],
        ),
      );
      await controller().read();
      expect(repository.calls, 1);
      expect(state().snapshot, isNotNull);
      expect(journal.snapshot.records.length, 1);
      expect(container.read(symbolSettingsActivityProvider).busy, isFalse);
      expect(identity.wallets, 0);
    },
  );
  test('a duplicate read waits; a read for another order runs independently', () async {
    await setup();
    repository.gate = Completer<void>();
    final pending = controller().read();
    expect(state().busy, true);
    await controller().read();
    final other = StrategyExecutionFixture();
    final otherListener = container.listen(strategyExecutionProvider(other.query), (_, _) {});
    final otherRead = container.read(strategyExecutionProvider(other.query).notifier).read();
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, 2);
    expect(container.read(symbolSettingsActivityProvider).busy, true);
    repository.gate!.complete();
    await pending;
    await otherRead;
    otherListener.close();
    expect(container.read(symbolSettingsActivityProvider).busy, isFalse);
  });
  test('an order in progress does not block this read or lose its own lease', () async {
    await setup();
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.order);
    await controller().read();
    expect(repository.calls, 1);
    expect(container.read(symbolSettingsActivityProvider).isRunning(SymbolSetting.order), isTrue);
    activity.finish(lease);
  });
  test('corrupt diagnostic storage does not block explicit reads', () async {
    await setup();
    journal.publish(
      OrderRecoverySnapshot(failure: const AccountReadFailure('orderRecoveryStorage')),
    );
    await controller().read();
    expect(repository.calls, 1);
  });
  test('refresh failure preserves the prior snapshot, stale and retryable', () async {
    await setup();
    await controller().read();
    final previous = state().snapshot;
    repository.failure = const AccountReadFailure('accountNetwork');
    await controller().read();
    expect(state().snapshot, same(previous));
    expect(state().stale, true);
    expect(state().failure!.key, 'accountNetwork');
    repository.failure = null;
    await controller().read();
    expect(state().failure, null);
    expect(state().stale, false);
    expect(repository.calls, 3);
  });
  test('stop retains previous evidence and releases lease without late replacement', () async {
    await setup();
    await controller().read();
    final previous = state().snapshot;
    repository.gate = Completer<void>();
    final pending = controller().read();
    final oldCurrent = repository.current!;
    controller().stop();
    expect(oldCurrent(), false);
    expect(state().snapshot, same(previous));
    expect(state().failure!.key, 'strategyExecutionStopped');
    expect(container.read(symbolSettingsActivityProvider).busy, isFalse);
    repository.gate!.complete();
    await pending;
    expect(state().snapshot, same(previous));
  });
  test('old stopped future cannot release a newer read lease', () async {
    await setup();
    final oldGate = Completer<void>();
    repository.gate = oldGate;
    final old = controller().read();
    controller().stop();
    final newGate = Completer<void>();
    repository.gate = newGate;
    final fresh = controller().read();
    oldGate.complete();
    await old;
    expect(state().busy, true);
    expect(container.read(symbolSettingsActivityProvider).busy, true);
    expect(
      container.read(symbolSettingsActivityProvider).isRunning(SymbolSetting.recovery),
      isTrue,
    );
    newGate.complete();
    await fresh;
    expect(state().snapshot, isNotNull);
    expect(container.read(symbolSettingsActivityProvider).busy, isFalse);
  });
  for (final change in ['identity', 'address', 'kind', 'signing']) {
    test('changing $change clears private data and invalidates in-flight responses', () async {
      await setup();
      await controller().read();
      repository.gate = Completer<void>();
      final pending = controller().read();
      final oldCurrent = repository.current!;
      identity.events.add(
        AuthIdentity(
          id: change == 'identity' ? 'other' : signingIdentity.id,
          walletAddress: change == 'address'
              ? '0x3333333333333333333333333333333333333333'
              : accountAddress,
          walletKind: change == 'kind' ? WalletKind.embedded : WalletKind.external,
          signingAvailable: change != 'signing',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(state().snapshot, null);
      expect(state().busy, false);
      expect(oldCurrent(), false);
      repository.gate!.complete();
      await pending;
      expect(state().snapshot, null);
      expect(container.read(symbolSettingsActivityProvider).busy, isFalse);
    });
  }
  test('disposal while reading releases ownership and rejects late result', () async {
    await setup();
    repository.gate = Completer<void>();
    final pending = controller().read();
    final current = repository.current!;
    listener.close();
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(current(), false);
    expect(container.read(symbolSettingsActivityProvider).busy, isFalse);
    repository.gate!.complete();
    await pending;
  });
  test('a snapshot for another query is rejected', () async {
    await setup();
    repository.wrongQuery = true;
    await controller().read();
    expect(state().snapshot, null);
    expect(state().failure!.key, 'accountDataInvalid');
  });
  test('background transition during read makes eventual result stale', () async {
    await setup();
    repository.gate = Completer<void>();
    final pending = controller().read();
    controller().onLifecycleChanged();
    repository.gate!.complete();
    await pending;
    expect(state().stale, true);
    expect(repository.calls, 1);
  });
  test('settings submission marks existing evidence stale without another signature', () async {
    await setup();
    await controller().read();
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.order);
    activity.submitted(lease);
    activity.finish(lease);
    expect(state().stale, true);
    expect(repository.calls, 1);
  });
  for (final offset in [const Duration(seconds: 31), const Duration(seconds: -1)]) {
    test('snapshot age or backwards clock is stale immediately $offset', () async {
      await setup();
      now = now.add(offset);
      await controller().read();
      expect(state().stale, true);
      expect(repository.calls, 1);
    });
  }
}
