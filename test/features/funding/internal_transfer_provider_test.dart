import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/spot_account_change_provider.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/spot_account_provider.dart';
import 'package:vanta/features/funding/application/internal_transfer_provider.dart';
import 'package:vanta/features/funding/application/internal_transfer_storage_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/funding/data/internal_transfer_codec.dart';
import 'package:vanta/features/funding/data/internal_transfer_journal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/funding/domain/internal_transfer.dart';

import '../../support/aster_account.dart';
import '../../support/account_changes.dart';
import '../../support/identity_repository.dart';
import '../../support/internal_transfer.dart';

void main() {
  final time = DateTime.utc(2026, 11, 4, 8);
  late DateTime now;
  late ProviderContainer c;
  late TestIdentityRepository identity;
  late TestInternalTransferRepository repository;
  late GatedInternalTransferJournal journal;
  late TestAccountChangeRepository events;
  InternalTransferController controller() => c.read(internalTransferProvider.notifier);
  InternalTransferState state() => c.read(internalTransferProvider);
  void transferTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      now = time;
      identity = TestIdentityRepository()..restored = signingIdentity;
      repository = TestInternalTransferRepository()..now = () => now;
      journal = GatedInternalTransferJournal();
      events = TestAccountChangeRepository()..now = now;
      c = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          internalTransferClockProvider.overrideWithValue(() => now),
          internalTransferRepositoryProvider.overrideWithValue(repository),
          internalTransferJournalProvider.overrideWithValue(journal),
          accountChangeRepositoryProvider.overrideWithValue(events),
          spotAccountChangeRepositoryProvider.overrideWithValue(events),
          accountChangeClockProvider.overrideWithValue(() => now),
        ],
      );
      c.read(authProvider);
      c.read(internalTransferProvider);
      await tester.pump();
      try {
        await body(tester);
      } finally {
        c.dispose();
        await identity.dispose();
        await journal.close();
        await events.dispose();
      }
    });
  }

  Future<InternalTransferReview> review() async {
    await controller().load();
    controller().setAmount('1.01');
    return controller().prepare()!;
  }

  transferTest(
    'explicit review and persistence precede one dispatch; terminal response requires separate current read',
    (tester) async {
      expect(repository.reads, 0);
      final r = await review();
      expect(repository.posts, 0);
      repository.beforeDispatch = () async {
        expect(journal.snapshot.records.single.reply, null);
        expect(journal.snapshot.records.single.amount, r.amount);
        expect(journal.snapshot.records.single.clientId, r.clientId);
      };
      await controller().confirm(r);
      expect(repository.submits, 1);
      expect(repository.posts, 1);
      expect(repository.reads, 2);
      expect(journal.snapshot.records, isEmpty);
      expect(state().record!.reply!.transactionId, '9007199254740993');
      expect(state().amount, '');
      expect(identity.wallets, 0);
      await controller().confirm(r);
      expect(repository.posts, 1);
      expect(c.read(symbolSettingsActivityProvider).recoveryBlocked, false);
    },
  );
  transferTest('cancel preserves context and never dispatches', (tester) async {
    final r = await review();
    controller().cancel(r);
    await controller().confirm(r);
    expect(repository.posts, 0);
    expect(state().context, same(r.context));
  });
  for (final issue in ['missing', 'wrongWallet', 'old', 'future']) {
    transferTest('$issue context cannot submit', (tester) async {
      repository.context = transferContext(
        now: now.add(
          Duration(
            seconds: issue == 'old'
                ? -30
                : issue == 'future'
                ? 1
                : 0,
          ),
        ),
        address: issue == 'wrongWallet'
            ? '0x3333333333333333333333333333333333333333'
            : accountAddress,
        asset: issue == 'missing' ? 'NOPE' : 'USDT',
      );
      await controller().load();
      controller().setAmount('1.01');
      expect(controller().prepare(), null);
      expect(repository.posts, 0);
    });
  }
  transferTest('restored EOA requires same wallet reconnection, never creates wallet', (
    tester,
  ) async {
    identity.events.add(
      const AuthIdentity(
        id: 'aster-test',
        walletAddress: accountAddress,
        walletKind: WalletKind.external,
      ),
    );
    await tester.pump();
    await controller().load();
    expect(state().failure, 'authWalletReconnect');
    expect(repository.reads, 0);
    expect(identity.wallets, 0);
  });
  transferTest('busy dedup and stopped read discard late context', (tester) async {
    repository.readGate = Completer();
    final pending = controller().load();
    await controller().load();
    expect(repository.reads, 1);
    controller().stop();
    await controller().load();
    expect(repository.reads, 1);
    repository.readGate!.complete();
    await pending;
    expect(state().context, null);
  });
  transferTest('failure preserves stale snapshot and safe reason', (tester) async {
    await controller().load();
    final previous = state().context;
    repository.readFailure = const FormatException('raw private detail');
    await controller().load();
    expect(state().context, same(previous));
    expect(state().stale, true);
    expect(state().failure, 'accountReadFailed');
  });
  transferTest('review expires without auto read', (tester) async {
    final r = await review();
    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(state().stale, true);
    await controller().confirm(r);
    expect(repository.submits, 0);
    expect(repository.reads, 1);
  });
  transferTest('settings epoch invalidates review before dispatch', (tester) async {
    final r = await review();
    final activity = c.read(symbolSettingsActivityProvider.notifier),
        lease = activity.acquire(SymbolSetting.leverage)!;
    activity.submitted(lease);
    activity.finish(lease, unresolved: false);
    await controller().confirm(r);
    expect(repository.posts, 0);
    expect(state().review, null);
  });
  transferTest('other unknown mutation blocks new rebalance', (tester) async {
    await controller().load();
    final activity = c.read(symbolSettingsActivityProvider.notifier),
        lease = activity.acquire(SymbolSetting.assetMode)!;
    activity.submitted(lease);
    activity.finish(lease, unresolved: true);
    expect(controller().prepare(), null);
    expect(repository.posts, 0);
  });
  transferTest('same-time replay during signing invalidates review before dispatch', (
    tester,
  ) async {
    await c.read(accountChangeProvider.notifier).authorize();
    final event = AccountChangeEvent.changed(AccountChangeKind.configuration, now);
    events.channels.single.add(event);
    await tester.pump();
    final r = await review();
    repository.signGate = Completer();
    final pending = controller().confirm(r);
    await tester.pump();
    events.channels.single.add(event);
    await tester.pump();
    repository.signGate!.complete();
    await pending;
    expect(repository.posts, 0);
    expect(journal.snapshot.records, isEmpty);
    expect(state().failure, 'internalTransferChanged');
  });
  transferTest('account event during final check leaves returned snapshot stale', (tester) async {
    await c.read(accountChangeProvider.notifier).authorize();
    final r = await review();
    repository.postGate = Completer();
    final pending = controller().confirm(r);
    await tester.pump();
    expect(repository.posts, 1);
    repository.readGate = Completer();
    repository.postGate!.complete();
    await tester.pump();
    expect(state().step, InternalTransferStep.checking);
    events.channels.single.add(AccountChangeEvent.changed(AccountChangeKind.account, now));
    await tester.pump();
    repository.readGate!.complete();
    await pending;
    expect(state().stale, true);
    expect(state().record!.reply, isNotNull);
    expect(controller().prepare(), null);
    expect(journal.snapshot.records, isEmpty);
    expect(repository.posts, 1);
  });
  transferTest('storage write failure blocks POST', (tester) async {
    final r = await review();
    journal.prepareFailure = const AccountReadFailure('internalTransferStorage');
    await controller().confirm(r);
    expect(repository.posts, 0);
    expect(state().failure, 'internalTransferStorage');
  });
  for (final loss in ['stop', 'expire', 'logout']) {
    transferTest('$loss while prewriting removes known-not-sent record', (tester) async {
      final r = await review();
      journal.gate = Completer();
      final pending = controller().confirm(r);
      await tester.pump();
      if (loss == 'stop') controller().stop();
      if (loss == 'expire') now = now.add(const Duration(seconds: 30));
      if (loss == 'logout') identity.events.add(null);
      await tester.pump();
      journal.gate!.complete();
      await pending;
      expect(repository.posts, 0);
      expect(journal.snapshot.records, isEmpty);
    });
  }
  transferTest('unknown POST persisted and locks new orders/configuration across checks', (
    tester,
  ) async {
    repository.submitFailure = const AccountReadFailure('accountNetwork');
    await controller().confirm(await review());
    expect(journal.snapshot.records.single.reply, null);
    expect(state().failure, 'accountNetwork');
    expect(c.read(symbolSettingsActivityProvider.notifier).acquire(SymbolSetting.order), null);
    repository.context = transferContext(now: now);
    await controller().load();
    expect(journal.snapshot.records.length, 1);
    expect(controller().prepare(), null);
    expect(repository.posts, 1);
    expect(c.read(symbolSettingsActivityProvider).recoveryBlocked, true);
  });
  transferTest('known response with failed account check can only recheck then releases lock', (
    tester,
  ) async {
    final r = await review();
    repository.readFailure = const AccountReadFailure('authWalletRejected');
    await controller().confirm(r);
    expect(journal.snapshot.records.single.reply, isNotNull);
    expect(repository.posts, 1);
    repository.readFailure = null;
    await controller().load();
    expect(journal.snapshot.records, isEmpty);
    expect(c.read(symbolSettingsActivityProvider).owner, null);
    expect(c.read(symbolSettingsActivityProvider).recoveryBlocked, false);
    final lease = c.read(symbolSettingsActivityProvider.notifier).acquire(SymbolSetting.order);
    expect(lease, isNotNull);
    c.read(symbolSettingsActivityProvider.notifier).finish(lease!, unresolved: false);
  });
  for (final loss in ['stop', 'logout', 'dispose']) {
    transferTest('server reply after $loss persists under original wallet', (tester) async {
      final r = await review();
      repository.postGate = Completer();
      final pending = controller().confirm(r);
      await tester.pump();
      expect(repository.posts, 1);
      if (loss == 'stop') controller().stop();
      if (loss == 'logout') identity.events.add(null);
      if (loss == 'dispose') c.dispose();
      await tester.pump();
      repository.postGate!.complete();
      await pending;
      expect(journal.snapshot.records.single.reply, isNotNull);
      expect(journal.snapshot.records.single.address, accountAddress);
      expect(repository.posts, 1);
    });
  }
  transferTest('wallet and signing-kind changes hide old snapshots, keep original pending record', (
    tester,
  ) async {
    repository.submitFailure = const AccountReadFailure('accountNetwork');
    await controller().confirm(await review());
    identity.events.add(
      const AuthIdentity(
        id: 'other',
        walletAddress: '0x3333333333333333333333333333333333333333',
        walletKind: WalletKind.embedded,
        signingAvailable: true,
      ),
    );
    await tester.pump();
    expect(state().context, null);
    expect(c.read(pendingInternalTransfersProvider), isEmpty);
    expect(journal.snapshot.records.length, 1);
  });
  transferTest('host journal exists before dispatch and rebuilt unknown never retries', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('vanta-internal-transfer-controller-');
      final disk = FileInternalTransferJournal(() async => dir);
      await disk.reload();
      c.dispose();
      c = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          internalTransferClockProvider.overrideWithValue(() => now),
          internalTransferRepositoryProvider.overrideWithValue(repository),
          internalTransferJournalProvider.overrideWithValue(disk),
        ],
      );
      c.read(authProvider);
      c.read(internalTransferProvider);
      await Future<void>.delayed(Duration.zero);
      repository.beforeDispatch = () async {
        final records = decodeInternalTransferJournal(
          await File('${dir.path}/pending-internal-transfers-v1.json').readAsString(),
        );
        expect(records.single.reply, null);
      };
      repository.submitFailure = const AccountReadFailure('accountNetwork');
      await controller().confirm(await review());
      await disk.close();
      final rebuilt = FileInternalTransferJournal(() async => dir);
      await rebuilt.reload();
      expect(rebuilt.snapshot.records.single.reply, null);
      expect(repository.posts, 1);
      await rebuilt.close();
      await dir.delete(recursive: true);
    });
  });
  transferTest(
    'exact max floor and selection clear amount and old review before another explicit read',
    (tester) async {
      await controller().load();
      controller().max();
      expect(state().amount, '99');
      final r = controller().prepare()!;
      await controller().select(direction: InternalTransferDirection.futuresToSpot);
      expect(state().amount, '');
      expect(state().review, null);
      expect(repository.reads, 2);
      await controller().confirm(r);
      expect(repository.posts, 0);
      controller().max();
      expect(state().amount, '19.99');
      await controller().select(asset: 'BTC');
      expect(state().amount, '');
      expect(repository.reads, 3);
      controller().max();
      expect(state().context!.maximum, null);
      expect(state().amount, '');
      expect(controller().prepare(), null);
    },
  );
  transferTest(
    'read failure retains exact amount and context; success refreshes both shared snapshots',
    (tester) async {
      await controller().load();
      controller().setAmount('1.0100');
      final old = state().context;
      repository.readFailure = const AccountReadFailure('accountNetwork');
      await controller().load();
      expect(state().amount, '1.0100');
      expect(state().context, same(old));
      expect(state().stale, true);
      repository.readFailure = null;
      await controller().load();
      final r = controller().prepare()!;
      await controller().confirm(r);
      expect(state().amount, '');
      expect(c.read(accountReadProvider).account, same(state().context!.futures));
      expect(c.read(spotAccountReadProvider).account, same(state().context!.spot));
    },
  );
  transferTest('unknown and final read failure preserve amount until known success recovery', (
    tester,
  ) async {
    final r = await review();
    repository.readFailure = const AccountReadFailure('accountNetwork');
    await controller().confirm(r);
    expect(state().amount, '1.01');
    expect(journal.snapshot.records.single.reply, isNotNull);
    repository.readFailure = null;
    await controller().load();
    expect(state().amount, '');
    expect(journal.snapshot.records, isEmpty);
    expect(repository.posts, 1);
  });
  transferTest('persistence completion failure retains reported response and typed amount', (
    tester,
  ) async {
    final r = await review();
    journal.completeFailure = const AccountReadFailure('internalTransferStorage');
    await controller().confirm(r);
    expect(state().amount, '1.01');
    expect(journal.snapshot.records.single.reply, isNotNull);
    expect(controller().prepare(), null);
    journal.completeFailure = null;
    await controller().load();
    expect(state().amount, '');
    expect(repository.posts, 1);
  });
  transferTest('same-time Spot replay during signing prevents dispatch', (tester) async {
    await c.read(spotAccountChangeProvider.notifier).authorize();
    final event = AccountChangeEvent.changed(AccountChangeKind.account, now);
    events.channels.single.add(event);
    await tester.pump();
    final r = await review();
    repository.signGate = Completer();
    final pending = controller().confirm(r);
    await tester.pump();
    events.channels.single.add(event);
    await tester.pump();
    repository.signGate!.complete();
    await pending;
    expect(repository.posts, 0);
    expect(state().review, null);
    expect(journal.snapshot.records, isEmpty);
  });
  transferTest(
    'transfer pending blocks order, configuration and Rebalance but belongs only to original wallet',
    (tester) async {
      repository.submitFailure = const AccountReadFailure('accountNetwork');
      await controller().confirm(await review());
      final activity = c.read(symbolSettingsActivityProvider.notifier);
      for (final kind in [SymbolSetting.order, SymbolSetting.leverage, SymbolSetting.rebalance]) {
        expect(activity.acquire(kind), null);
      }
      identity.events.add(
        const AuthIdentity(
          id: 'other',
          walletAddress: '0x3333333333333333333333333333333333333333',
          walletKind: WalletKind.external,
          signingAvailable: true,
        ),
      );
      await tester.pump();
      expect(c.read(pendingInternalTransfersProvider), isEmpty);
      final lease = activity.acquire(SymbolSetting.order);
      expect(lease, isNotNull);
      activity.finish(lease!, unresolved: false);
      expect(journal.snapshot.records.length, 1);
    },
  );
  transferTest('empty, oversized and overly precise amounts never prepare', (tester) async {
    await controller().load();
    for (final text in ['', '0', '99.01', '1.001', '1e2']) {
      controller().setAmount(text);
      expect(controller().prepare(), null);
    }
    expect(repository.posts, 0);
  });
  transferTest('read expiry disables Max and preserves input without new signatures', (
    tester,
  ) async {
    await controller().load();
    controller().setAmount('1.01');
    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    controller().max();
    expect(state().amount, '1.01');
    expect(controller().prepare(), null);
    expect(repository.reads, 1);
  });
}
