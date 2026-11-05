import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/rebalance_provider.dart';
import 'package:vanta/features/portfolio/application/rebalance_storage_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/data/rebalance_codec.dart';
import 'package:vanta/features/portfolio/data/rebalance_journal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/asset_rebalance.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';

import '../../support/aster_account.dart';
import '../../support/account_changes.dart';
import '../../support/identity_repository.dart';
import '../../support/rebalance.dart';

void main() {
  final time = DateTime.utc(2026, 11, 4, 8);
  late DateTime now;
  late ProviderContainer c;
  late TestIdentityRepository identity;
  late TestRebalanceRepository repository;
  late GatedRebalanceJournal journal;
  late TestAccountChangeRepository events;
  RebalanceController controller() => c.read(rebalanceProvider.notifier);
  RebalanceState state() => c.read(rebalanceProvider);
  void rebalanceTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      now = time;
      identity = TestIdentityRepository()..restored = signingIdentity;
      repository = TestRebalanceRepository()..now = () => now;
      journal = GatedRebalanceJournal();
      events = TestAccountChangeRepository()..now = now;
      c = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          rebalanceClockProvider.overrideWithValue(() => now),
          rebalanceRepositoryProvider.overrideWithValue(repository),
          rebalanceJournalProvider.overrideWithValue(journal),
          accountChangeRepositoryProvider.overrideWithValue(events),
          accountChangeClockProvider.overrideWithValue(() => now),
        ],
      );
      c.read(authProvider);
      c.read(rebalanceProvider);
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

  Future<RebalanceReview> review() async {
    await controller().load();
    return controller().prepare()!;
  }

  rebalanceTest(
    'explicit review and persistence precede one dispatch; terminal response requires separate current read',
    (tester) async {
      expect(repository.reads, 0);
      final r = await review();
      expect(repository.posts, 0);
      repository.beforeDispatch = () async {
        expect(journal.snapshot.records.single.reply, null);
        expect(journal.snapshot.records.single.previousUsdt, r.context.usdt);
      };
      await controller().confirm(r);
      expect(repository.submits, 1);
      expect(repository.posts, 1);
      expect(repository.reads, 2);
      expect(journal.snapshot.records, isEmpty);
      expect(state().reply!.accountId, '9007199254740993');
      expect(
        state().context!.needed,
        true,
      ); // The returned balance never replaces a current account read.
      expect(identity.wallets, 0);
      await controller().confirm(r);
      expect(repository.posts, 1);
      expect(c.read(symbolSettingsActivityProvider).recoveryBlocked, false);
    },
  );
  rebalanceTest('no-op remains a reported no-op, not proof of clearing debt', (tester) async {
    repository.reply = const RebalanceReply.noExchange();
    await controller().confirm(await review());
    expect(state().reply!.noExchange, true);
    expect(state().context!.needed, true);
    expect(journal.snapshot.records, isEmpty);
  });
  rebalanceTest('cancel preserves context and never dispatches', (tester) async {
    final r = await review();
    controller().cancel(r);
    await controller().confirm(r);
    expect(repository.posts, 0);
    expect(state().context, same(r.context));
  });
  for (final usdt in ['0', '1']) {
    rebalanceTest('nonnegative $usdt cannot prepare', (tester) async {
      repository.context = rebalanceContext(now: now, usdt: usdt);
      await controller().load();
      expect(controller().prepare(), null);
      expect(repository.posts, 0);
    });
  }
  for (final issue in ['single', 'missing', 'wrongWallet', 'old', 'future']) {
    rebalanceTest('$issue context cannot submit', (tester) async {
      repository.context = rebalanceContext(
        now: now.add(
          Duration(
            seconds: issue == 'old'
                ? -30
                : issue == 'future'
                ? 1
                : 0,
          ),
        ),
        mode: issue == 'single' ? FuturesAssetMode.single : FuturesAssetMode.multi,
        missingUsdt: issue == 'missing',
        address: issue == 'wrongWallet'
            ? '0x3333333333333333333333333333333333333333'
            : accountAddress,
      );
      await controller().load();
      expect(controller().prepare(), null);
      expect(repository.posts, 0);
    });
  }
  rebalanceTest('restored EOA requires same wallet reconnection, never creates wallet', (
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
  rebalanceTest('busy dedup and stopped read discard late context', (tester) async {
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
  rebalanceTest('failure preserves stale snapshot and safe reason', (tester) async {
    await controller().load();
    final previous = state().context;
    repository.readFailure = const FormatException('raw private detail');
    await controller().load();
    expect(state().context, same(previous));
    expect(state().stale, true);
    expect(state().failure, 'accountReadFailed');
  });
  rebalanceTest('review expires without auto read', (tester) async {
    final r = await review();
    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(state().stale, true);
    await controller().confirm(r);
    expect(repository.submits, 0);
    expect(repository.reads, 1);
  });
  rebalanceTest('settings epoch invalidates review before dispatch', (tester) async {
    final r = await review();
    final activity = c.read(symbolSettingsActivityProvider.notifier),
        lease = activity.acquire(SymbolSetting.leverage)!;
    activity.submitted(lease);
    activity.finish(lease, unresolved: false);
    await controller().confirm(r);
    expect(repository.posts, 0);
    expect(state().review, null);
  });
  rebalanceTest('other unknown mutation blocks new rebalance', (tester) async {
    await controller().load();
    final activity = c.read(symbolSettingsActivityProvider.notifier),
        lease = activity.acquire(SymbolSetting.assetMode)!;
    activity.submitted(lease);
    activity.finish(lease, unresolved: true);
    expect(controller().prepare(), null);
    expect(repository.posts, 0);
  });
  rebalanceTest('same-time replay during signing invalidates review before dispatch', (
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
    expect(state().failure, 'rebalanceChanged');
  });
  rebalanceTest('account event during final check leaves returned snapshot stale', (tester) async {
    await c.read(accountChangeProvider.notifier).authorize();
    final r = await review();
    repository.postGate = Completer();
    final pending = controller().confirm(r);
    await tester.pump();
    expect(repository.posts, 1);
    repository.readGate = Completer();
    repository.postGate!.complete();
    await tester.pump();
    expect(state().step, RebalanceStep.checking);
    events.channels.single.add(AccountChangeEvent.changed(AccountChangeKind.account, now));
    await tester.pump();
    repository.readGate!.complete();
    await pending;
    expect(state().stale, true);
    expect(state().reply, isNotNull);
    expect(controller().prepare(), null);
    expect(journal.snapshot.records, isEmpty);
    expect(repository.posts, 1);
  });
  rebalanceTest('storage write failure blocks POST', (tester) async {
    final r = await review();
    journal.prepareFailure = const AccountReadFailure('rebalanceStorage');
    await controller().confirm(r);
    expect(repository.posts, 0);
    expect(state().failure, 'rebalanceStorage');
  });
  for (final loss in ['stop', 'expire', 'logout']) {
    rebalanceTest('$loss while prewriting removes known-not-sent record', (tester) async {
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
  rebalanceTest('unknown POST persisted and locks new orders/configuration across checks', (
    tester,
  ) async {
    repository.submitFailure = const AccountReadFailure('accountNetwork');
    await controller().confirm(await review());
    expect(journal.snapshot.records.single.reply, null);
    expect(state().failure, 'accountNetwork');
    expect(c.read(symbolSettingsActivityProvider.notifier).acquire(SymbolSetting.order), null);
    repository.context = rebalanceContext(now: now, usdt: '0');
    await controller().load();
    expect(journal.snapshot.records.length, 1);
    expect(controller().prepare(), null);
    expect(repository.posts, 1);
    expect(c.read(symbolSettingsActivityProvider).recoveryBlocked, true);
  });
  rebalanceTest('known response with failed account check can only recheck then releases lock', (
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
    rebalanceTest('server reply after $loss persists under original wallet', (tester) async {
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
  rebalanceTest(
    'wallet and signing-kind changes hide old snapshots, keep original pending record',
    (tester) async {
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
      expect(c.read(pendingRebalancesProvider), isEmpty);
      expect(journal.snapshot.records.length, 1);
    },
  );
  rebalanceTest('host journal exists before dispatch and rebuilt unknown never retries', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('vanta-rebalance-controller-');
      final disk = FileRebalanceJournal(() async => dir);
      await disk.reload();
      c.dispose();
      c = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          rebalanceClockProvider.overrideWithValue(() => now),
          rebalanceRepositoryProvider.overrideWithValue(repository),
          rebalanceJournalProvider.overrideWithValue(disk),
        ],
      );
      c.read(authProvider);
      c.read(rebalanceProvider);
      await Future<void>.delayed(Duration.zero);
      repository.beforeDispatch = () async {
        final records = decodeRebalanceJournal(
          await File('${dir.path}/pending-asset-rebalances-v1.json').readAsString(),
        );
        expect(records.single.reply, null);
      };
      repository.submitFailure = const AccountReadFailure('accountNetwork');
      await controller().confirm(await review());
      await disk.close();
      final rebuilt = FileRebalanceJournal(() async => dir);
      await rebuilt.reload();
      expect(rebuilt.snapshot.records.single.reply, null);
      expect(repository.posts, 1);
      await rebuilt.close();
      await dir.delete(recursive: true);
    });
  });
}
