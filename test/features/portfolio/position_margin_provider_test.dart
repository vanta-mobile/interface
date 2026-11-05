import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/data/wallet_operation_journal.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/position_margin_provider.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';
import 'package:vanta/features/portfolio/application/position_margin_storage_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/position_margin_adjustment.dart';

import '../../support/aster_account.dart';
import '../../support/account_changes.dart';

import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';

import '../../support/identity_repository.dart';
import '../../support/position_margin_adjustment.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestPositionMarginRepository repository;
  late MemoryWalletOperationJournal journal;
  late DateTime now;
  late TestAccountChangeRepository events;
  setUp(() async {
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestPositionMarginRepository();
    journal = MemoryWalletOperationJournal();
    now = marginClock;
    events = TestAccountChangeRepository()..now = now;
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        accountChangeRepositoryProvider.overrideWithValue(events),
        accountChangeClockProvider.overrideWithValue(() => now),
        positionMarginRepositoryProvider.overrideWithValue(repository),
        positionMarginJournalProvider.overrideWithValue(journal),
        positionMarginClockProvider.overrideWithValue(() => now),
        positionMarginReferenceProvider.overrideWithValue(() => marginReference),
      ],
    );
    container.read(authProvider);
    container.read(positionMarginProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
    await events.dispose();
    await journal.close();
  });
  PositionMarginController controller() => container.read(positionMarginProvider.notifier);
  Future<void> load() => controller().load('BTCUSDT', 'BOTH');
  PositionMarginIntent intent() => controller().prepare(MarginDirection.add, '10')!;
  test('no automatic signed reads; explicit load binds original wallet and side', () async {
    expect(repository.reads, 0);
    await load();
    expect(repository.reads, 1);
    expect(intent().context.account.address, accountAddress);
    expect(intent().context.position.side, 'BOTH');
    expect(identity.wallets, 0);
  });
  test(
    'same terms reuse reference; changed amount and direction invalidate old confirmation',
    () async {
      await load();
      final old = intent();
      expect(intent(), same(old));
      controller().prepare(MarginDirection.remove, '10');
      await controller().change(old);
      expect(repository.changes, 0);
    },
  );
  test('forged equivalent intent never executes', () async {
    await load();
    final issued = intent();
    final forged = PositionMarginIntent(
      context: issued.context,
      direction: issued.direction,
      amount: issued.amount,
      reference: issued.reference,
      revision: issued.revision,
    );
    await controller().change(forged);
    expect(repository.changes, 0);
  });
  for (final seconds in [30, -1]) {
    test('expired or backwards clock $seconds invalidates confirmation', () async {
      await load();
      final old = intent();
      now = now.add(Duration(seconds: seconds));
      expect(controller().prepare(MarginDirection.add, '10'), null);
      await controller().change(old);
      expect(repository.changes, 0);
    });
  }
  test('stale event invalidates reviewed confirmation', () async {
    await load();
    final old = intent();
    controller().markStale();
    await controller().change(old);
    expect(repository.changes, 0);
  });
  test('invalidation during read keeps returned context stale', () async {
    repository.readGate = Completer<void>();
    final pending = load();
    controller().markStale();
    repository.readGate!.complete();
    await pending;
    expect(container.read(positionMarginProvider).stale, true);
    expect(controller().prepare(MarginDirection.add, '10'), null);
  });
  test('original receipt consumes read time instead of resetting 30 seconds', () async {
    repository.readGate = Completer<void>();
    final pending = load();
    now = now.add(const Duration(seconds: 31));
    repository.readGate!.complete();
    await pending;
    expect(container.read(positionMarginProvider).stale, true);
  });
  test('same-timestamp stream event during signing invalidates margin intent', () async {
    await container.read(accountChangeProvider.notifier).authorize();
    final event = AccountChangeEvent.changed(AccountChangeKind.configuration, now);
    events.channels.single.add(event);
    await Future<void>.delayed(Duration.zero);
    await load();
    repository.changeGate = Completer<void>();
    final pending = controller().change(intent());
    events.channels.single.add(event);
    await Future<void>.delayed(Duration.zero);
    expect(repository.canSubmitLatest!(), false);
    repository.changeGate!.complete();
    await pending;
    expect(repository.submitted, false);
  });
  test('shared settings owner blocks load and confirmation', () async {
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final token = activity.acquire(SymbolSetting.leverage)!;
    await load();
    expect(repository.reads, 0);
    activity.finish(token, unresolved: false);
    await load();
    expect(repository.reads, 1);
  });
  test('one confirmed call while signing; event between review and send blocks dispatch', () async {
    await load();
    repository.changeGate = Completer<void>();
    final old = intent();
    final pending = controller().change(old);
    await controller().change(old);
    expect(repository.changes, 1);
    controller().markStale();
    expect(repository.canSubmitLatest!(), false);
    repository.changeGate!.complete();
    await pending;
    expect(repository.submitted, false);
  });
  test('own submission epoch does not stale a verified newly read context', () async {
    await load();
    repository.result = MarginAdjustmentResult(
      record: marginRecord(acknowledged: true, reference: marginReference),
      verified: true,
      context: repository.context,
      position: repository.context.position,
    );
    await controller().change(intent());
    expect(repository.submitted, true);
    expect(container.read(positionMarginProvider).stale, false);
    expect(container.read(positionMarginProvider).result?.verified, true);
  });
  test('stop before send makes delayed callback ineligible', () async {
    await load();
    repository.changeGate = Completer<void>();
    final pending = controller().change(intent());
    controller().stop();
    expect(repository.canSubmitLatest!(), false);
    repository.changeGate!.complete();
    await pending;
    expect(repository.submitted, false);
    expect(container.read(positionMarginProvider).result, null);
  });
  test('logout before send clears context and prevents delayed callback', () async {
    await load();
    repository.changeGate = Completer<void>();
    final pending = controller().change(intent());
    await container.read(authProvider.notifier).logout();
    expect(repository.current!(), false);
    repository.changeGate!.complete();
    await pending;
    expect(container.read(positionMarginProvider).context, null);
    expect(identity.wallets, 0);
  });
  test(
    'pending startup record blocks new writes across shared workflows and check is GET only',
    () async {
      await journal.prepare(marginRecord());
      await load();
      expect(repository.reads, 0);
      final activity = container.read(symbolSettingsActivityProvider.notifier);
      expect(activity.acquire(SymbolSetting.order), null);
      expect(activity.acquire(SymbolSetting.leverage), null);
      await controller().check(marginRecord());
      expect(repository.checks, 1);
      expect(repository.changes, 0);
    },
  );
  test('foreign wallet record cannot be checked; caller cannot alter stored terms', () async {
    final record = marginRecord();
    await journal.prepare(record);
    final forged = WalletOperationRecord(
      kind: record.kind,
      address: record.address,
      nonce: record.nonce,
      preparedAt: record.preparedAt,
      terms: {...record.terms, 'amount': '999'},
    );
    await controller().check(forged);
    expect(repository.checks, 1); // Canonical stored record is passed.
    await container.read(authProvider.notifier).logout();
    await controller().check(record);
    expect(repository.checks, 1);
  });
  test('corrupt storage blocks reads and new confirms without private requests', () async {
    journal.publish(WalletOperationStorage(failed: true));
    await load();
    expect(repository.reads, 0);
    expect(controller().prepare(MarginDirection.add, '10'), null);
  });
  test('verified full reads update primary account and positions before returning', () async {
    await load();
    final fresh = marginContext(
      account: marginAccount(wallet: '60'),
      risk: marginRisk(wallet: '60'),
    );
    final positions = PositionRiskSnapshot(
      address: accountAddress,
      receivedAt: now,
      positions: [fresh.position],
    );
    repository.result = MarginAdjustmentResult(
      record: marginRecord(acknowledged: true, reference: marginReference),
      verified: true,
      context: fresh,
      position: fresh.position,
      account: fresh.account,
      positions: positions,
    );
    await controller().change(intent());
    expect(container.read(accountReadProvider).account?.positions.single.isolatedWallet, md('60'));
    expect(container.read(positionRiskProvider).account?.positions.single.isolatedWallet, md('60'));
  });
  test('verified closed position removes old form context', () async {
    await load();
    repository.result = MarginAdjustmentResult(
      record: marginRecord(acknowledged: true, reference: marginReference),
      verified: true,
    );
    await controller().change(intent());
    expect(container.read(positionMarginProvider).context, null);
  });
}
