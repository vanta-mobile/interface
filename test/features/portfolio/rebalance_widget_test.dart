import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/rebalance_provider.dart';
import 'package:vanta/features/portfolio/data/rebalance_journal.dart';
import 'package:vanta/features/portfolio/presentation/rebalance_screen.dart';
import 'package:vanta/features/portfolio/presentation/rebalance_entry.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/rebalance.dart';
import '../../support/trade_fixture.dart';
import '../funding/deposit_wallet_widget_test.dart' show reveal;

void main() {
  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    testWidgets(
      'explicit collateral conversion, cancellation, result and wallet isolation fit $spec',
      (tester) async {
        final now = DateTime.now().toUtc(),
            identity = TestIdentityRepository()..restored = signingIdentity;
        final repository = TestRebalanceRepository()..now = () => now;
        final journal = MemoryRebalanceJournal();
        addTearDown(identity.dispose);
        addTearDown(journal.close);
        final c = setup(
          tester,
          width: spec.$1,
          scale: 1.5,
          language: Locale(spec.$3),
          identityRepository: identity,
          rebalanceRepository: repository,
          rebalanceJournal: journal,
          rebalanceClock: () => now,
        );
        tester.view.physicalSize = Size(spec.$1, spec.$2);
        await launch(tester, c);
        openRebalance(tester.element(find.byKey(const Key('account-button'))));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(RebalanceScreen)));
        Future<void> tap(String key) async {
          final f = find.byKey(Key(key));
          await reveal(tester, f, scrollKey: 'rebalance-scroll');
          await tester.tap(f.hitTestable());
          await tester.pumpAndSettle();
        }

        expect(repository.reads, 0);
        await tap('rebalance-read');
        await reveal(tester, find.text(l10n.rebalanceRequired), scrollKey: 'rebalance-scroll');
        await tap('rebalance-review');
        expect(find.byType(RebalanceConfirmation), findsOneWidget);
        expect(repository.posts, 0);
        await tester.ensureVisible(find.byKey(const Key('rebalance-cancel')));
        await tester.tap(find.byKey(const Key('rebalance-cancel')).hitTestable());
        await tester.pumpAndSettle();
        expect(repository.posts, 0);
        await tap('rebalance-review');
        await tester.ensureVisible(find.byKey(const Key('rebalance-confirm')));
        await tester.tap(find.byKey(const Key('rebalance-confirm')).hitTestable());
        await tester.pumpAndSettle();
        expect(repository.posts, 1);
        expect(journal.snapshot.records, isEmpty);
        await reveal(tester, find.text(l10n.rebalanceReported), scrollKey: 'rebalance-scroll');
        expect(find.text('9007199254740993'), findsOneWidget);
        expect(identity.wallets, 0);
        identity.events.add(null);
        await tester.pumpAndSettle();
        expect(c.read(rebalanceProvider).context, null);
        expect(find.text('9007199254740993'), findsNothing);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
  for (final known in [false, true]) {
    testWidgets(
      '${known ? 'known reply' : 'unknown request'} recovery checks current state without resubmission',
      (tester) async {
        final now = DateTime.now().toUtc(),
            identity = TestIdentityRepository()..restored = signingIdentity;
        final journal = MemoryRebalanceJournal(
          records: [
            rebalanceRecord(
              now: now,
              reply: known ? rebalanceReply(now: now) : null,
            ),
          ],
        );
        final repository = TestRebalanceRepository()..now = () => now;
        repository.context = rebalanceContext(now: now, usdt: '0');
        addTearDown(identity.dispose);
        addTearDown(journal.close);
        final c = setup(
          tester,
          width: 320,
          scale: 1.5,
          identityRepository: identity,
          rebalanceRepository: repository,
          rebalanceJournal: journal,
          rebalanceClock: () => now,
        );
        await launch(tester, c);
        openRebalance(tester.element(find.byKey(const Key('account-button'))));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(RebalanceScreen)));
        final read = find.byKey(const Key('rebalance-read'));
        await reveal(tester, read, scrollKey: 'rebalance-scroll');
        await tester.tap(read.hitTestable());
        await tester.pumpAndSettle();
        expect(repository.posts, 0);
        expect(journal.snapshot.records.length, known ? 0 : 1);
        final text = known ? l10n.rebalanceReported : l10n.rebalanceUnknown;
        await reveal(tester, find.text(text), scrollKey: 'rebalance-scroll');
        final review = find.byKey(const Key('rebalance-review'));
        await reveal(tester, review, scrollKey: 'rebalance-scroll');
        expect(tester.widget<OutlinedButton>(review).onPressed, null);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
  testWidgets(
    'stop or back during signing prevents POST; late response after route exit persists',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestRebalanceRepository(), journal = MemoryRebalanceJournal();
      addTearDown(identity.dispose);
      addTearDown(journal.close);
      final c = setup(
        tester,
        identityRepository: identity,
        rebalanceRepository: repository,
        rebalanceJournal: journal,
      );
      await launch(tester, c);
      openRebalance(tester.element(find.byKey(const Key('account-button'))));
      await tester.pumpAndSettle();
      await c.read(rebalanceProvider.notifier).load();
      await tester.pumpAndSettle();
      final controller = c.read(rebalanceProvider.notifier), review = controller.prepare()!;
      repository.signGate = Completer();
      final pending = controller.confirm(review);
      await tester.pump();
      Navigator.of(tester.element(find.byType(RebalanceScreen))).pop();
      await tester.pumpAndSettle();
      repository.signGate!.complete();
      await pending;
      expect(repository.posts, 0);
      expect(journal.snapshot.records, isEmpty);
      openRebalance(tester.element(find.byKey(const Key('account-button'))));
      await tester.pumpAndSettle();
      await controller.load();
      final second = controller.prepare()!;
      repository.signGate = null;
      repository.postGate = Completer();
      final sent = controller.confirm(second);
      await tester.pump();
      expect(repository.posts, 1);
      Navigator.of(tester.element(find.byType(RebalanceScreen))).pop();
      await tester.pumpAndSettle();
      repository.postGate!.complete();
      await sent;
      expect(journal.snapshot.records.single.reply, isNotNull);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
