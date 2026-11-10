import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/application/internal_transfer_provider.dart';
import 'package:vanta/features/funding/data/internal_transfer_journal.dart';
import 'package:vanta/features/funding/presentation/internal_transfer_confirmation.dart';
import 'package:vanta/features/funding/presentation/internal_transfer_entry.dart';
import 'package:vanta/features/funding/presentation/internal_transfer_screen.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/internal_transfer.dart';
import '../../support/trade_fixture.dart';
import 'deposit_wallet_widget_test.dart' show reveal;

Future<void> tapTransfer(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await reveal(tester, f, scrollKey: 'internal-transfer-scroll');
  await tester.tap(f.hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    testWidgets(
      'explicit read, direction, exact Max, cancel, one transfer, balance result and logout fit $spec',
      (tester) async {
        final now = DateTime.now().toUtc(),
            identity = TestIdentityRepository()..restored = signingIdentity;
        final repository = TestInternalTransferRepository()..now = () => now;
        final journal = MemoryInternalTransferJournal();
        addTearDown(identity.dispose);
        addTearDown(journal.close);
        final c = setup(
          tester,
          width: spec.$1,
          scale: 1.5,
          language: Locale(spec.$3),
          identityRepository: identity,
          internalTransferRepository: repository,
          internalTransferJournal: journal,
          internalTransferClock: () => now,
        );
        tester.view.physicalSize = Size(spec.$1, spec.$2);
        await launch(tester, c);
        openInternalTransfer(tester.element(find.byType(Navigator).first));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(InternalTransferScreen)));
        expect(repository.reads, 0);
        expect(repository.posts, 0);
        await tapTransfer(tester, 'internal-transfer-read');
        await tapTransfer(tester, 'internal-transfer-futuresToSpot');
        expect(repository.reads, 2);
        await tapTransfer(tester, 'internal-transfer-max');
        expect(c.read(internalTransferProvider).amount, '19.99');
        await tapTransfer(tester, 'internal-transfer-review');
        expect(find.byType(InternalTransferConfirmation), findsOneWidget);
        expect(find.text('19.99 USDT'), findsOneWidget);
        expect(repository.posts, 0);
        await tester.ensureVisible(find.byKey(const Key('internal-transfer-cancel')));
        await tester.tap(find.byKey(const Key('internal-transfer-cancel')).hitTestable());
        await tester.pumpAndSettle();
        expect(c.read(internalTransferProvider).amount, '19.99');
        expect(repository.posts, 0);
        await tapTransfer(tester, 'internal-transfer-review');
        await tester.ensureVisible(find.byKey(const Key('internal-transfer-confirm')));
        await tester.tap(find.byKey(const Key('internal-transfer-confirm')).hitTestable());
        await tester.pumpAndSettle();
        expect(repository.posts, 1);
        expect(journal.snapshot.records, isEmpty);
        expect(c.read(internalTransferProvider).amount, '');
        await reveal(
          tester,
          find.text(l10n.internalTransferReported),
          scrollKey: 'internal-transfer-scroll',
        );
        expect(find.text('9007199254740993'), findsOneWidget);
        expect(identity.wallets, 0);
        expect(tester.takeException(), null);
        identity.events.add(null);
        await tester.pumpAndSettle();
        expect(find.text('9007199254740993'), findsNothing);
        expect(c.read(internalTransferProvider).context, null);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
  for (final known in [false, true]) {
    testWidgets('${known ? 'known success' : 'unknown transfer'} recovery never replays a POST', (
      tester,
    ) async {
      final now = DateTime.now().toUtc(),
          identity = TestIdentityRepository()..restored = signingIdentity;
      final journal = MemoryInternalTransferJournal(
        records: [transferRecord(now: now, reply: known ? transferReply() : null)],
      );
      final repository = TestInternalTransferRepository()..now = () => now;
      addTearDown(identity.dispose);
      addTearDown(journal.close);
      final c = setup(
        tester,
        width: 320,
        scale: 1.5,
        identityRepository: identity,
        internalTransferRepository: repository,
        internalTransferJournal: journal,
        internalTransferClock: () => now,
      );
      await launch(tester, c);
      openInternalTransfer(tester.element(find.byType(Navigator).first));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(InternalTransferScreen)));
      expect(
        find.text(known ? l10n.internalTransferReplyPending : l10n.internalTransferUnknown),
        findsOneWidget,
      );
      await tapTransfer(tester, 'internal-transfer-read');
      expect(repository.posts, 0);
      expect(journal.snapshot.records.length, known ? 0 : 1);
      await reveal(
        tester,
        find.text(known ? l10n.internalTransferReported : l10n.internalTransferUnknown),
        scrollKey: 'internal-transfer-scroll',
      );
      await tapTransfer(tester, 'internal-transfer-review');
      expect(repository.posts, 0);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
  testWidgets(
    'failure preserves typed amount, language-safe error, and new asset clears input and rereads',
    (tester) async {
      final now = DateTime.now().toUtc(),
          identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestInternalTransferRepository()..now = () => now;
      addTearDown(identity.dispose);
      final c = setup(
        tester,
        width: 320,
        scale: 1.5,
        identityRepository: identity,
        internalTransferRepository: repository,
        internalTransferClock: () => now,
      );
      await launch(tester, c);
      openInternalTransfer(tester.element(find.byType(Navigator).first));
      await tester.pumpAndSettle();
      await tapTransfer(tester, 'internal-transfer-read');
      final amount = find.byKey(const Key('internal-transfer-amount'));
      await reveal(tester, amount, scrollKey: 'internal-transfer-scroll');
      await tester.enterText(amount, '1.01');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      repository.readFailure = const AccountReadFailure('accountNetwork');
      await tapTransfer(tester, 'internal-transfer-read');
      expect(c.read(internalTransferProvider).amount, '1.01');
      final l10n = AppLocalizations.of(tester.element(find.byType(InternalTransferScreen)));
      expect(find.text(l10n.accountNetwork), findsOneWidget);
      repository.readFailure = null;
      await tapTransfer(tester, 'internal-transfer-read');
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await reveal(tester, dropdown, scrollKey: 'internal-transfer-scroll');
      await tester.tap(dropdown.hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('BTC').last);
      await tester.pumpAndSettle();
      expect(c.read(internalTransferProvider).asset, 'BTC');
      expect(c.read(internalTransferProvider).amount, '');
      expect(repository.reads, 4);
      expect(repository.posts, 0);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('expiry invalidates an open confirmation without another read', (tester) async {
    var now = DateTime.now().toUtc();
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestInternalTransferRepository()..now = () => now;
    addTearDown(identity.dispose);
    final c = setup(
      tester,
      identityRepository: identity,
      internalTransferRepository: repository,
      internalTransferClock: () => now,
    );
    await launch(tester, c);
    openInternalTransfer(tester.element(find.byType(Navigator).first));
    await tester.pumpAndSettle();
    await tapTransfer(tester, 'internal-transfer-read');
    await tapTransfer(tester, 'internal-transfer-max');
    await tapTransfer(tester, 'internal-transfer-review');
    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('internal-transfer-confirm'))).onPressed,
      null,
    );
    expect(repository.reads, 1);
    expect(repository.posts, 0);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('leaving after dispatch retains late success for original wallet recovery', (
    tester,
  ) async {
    final now = DateTime.now().toUtc(),
        identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestInternalTransferRepository()..now = () => now;
    final journal = MemoryInternalTransferJournal();
    addTearDown(identity.dispose);
    addTearDown(journal.close);
    final c = setup(
      tester,
      identityRepository: identity,
      internalTransferRepository: repository,
      internalTransferJournal: journal,
      internalTransferClock: () => now,
    );
    await launch(tester, c);
    openInternalTransfer(tester.element(find.byType(Navigator).first));
    await tester.pumpAndSettle();
    await tapTransfer(tester, 'internal-transfer-read');
    await tapTransfer(tester, 'internal-transfer-max');
    await tapTransfer(tester, 'internal-transfer-review');
    repository.postGate = Completer();
    await tester.ensureVisible(find.byKey(const Key('internal-transfer-confirm')));
    await tester.tap(find.byKey(const Key('internal-transfer-confirm')).hitTestable());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.posts, 1);
    Navigator.of(tester.element(find.byType(InternalTransferScreen))).pop();
    await tester.pumpAndSettle();
    repository.postGate!.complete();
    await tester.pumpAndSettle();
    expect(journal.snapshot.records.single.reply!.transactionId, '9007199254740993');
    expect(repository.reads, 1);
    expect(find.byType(InternalTransferScreen), findsNothing);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
