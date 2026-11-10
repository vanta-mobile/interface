import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/application/deposit_approval_provider.dart';
import 'package:vanta/features/funding/data/deposit_approval_journal.dart';
import 'package:vanta/features/funding/domain/deposit_approval.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';
import 'package:vanta/features/funding/presentation/deposit_approval_panel.dart';
import 'package:vanta/features/funding/presentation/deposit_approval_recovery_screen.dart';
import 'package:vanta/features/funding/presentation/deposit_wallet_screen.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_approval.dart';
import '../../support/deposit_gas.dart';
import '../../support/deposit_wallet.dart';
import '../../support/trade_fixture.dart';
import 'deposit_wallet_widget_test.dart' show reveal, open;

void main() {
  const user = AuthIdentity(
    id: 'wallet',
    walletAddress: accountAddress,
    walletKind: WalletKind.external,
    signingAvailable: true,
  );
  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    for (final reset in [false, true]) {
      testWidgets(
        'explicit ${reset ? 'reset' : 'precise approval'} review, cancel, send, read-only recovery fits $spec',
        (tester) async {
          final now = DateTime.now().toUtc();
          final identity = ApprovalIdentityRepository()..restored = user;
          final quote = approvalQuote(now: now, reset: reset), query = depositQuery();
          final gas = TestDepositGasRepository()..result = quote;
          final journal = MemoryDepositApprovalJournal(),
              receipts = TestApprovalReceiptRepository();
          addTearDown(identity.dispose);
          addTearDown(journal.close);
          final container = setup(
            tester,
            width: spec.$1,
            scale: 1.5,
            language: Locale(spec.$3),
            identityRepository: identity,
            depositWalletRepository: TestDepositWalletRepository()..result = quote.wallet,
            depositGasRepository: gas,
            depositApprovalJournal: journal,
            depositApprovalReceiptRepository: receipts,
            depositGasClock: () => now,
          );
          tester.view.physicalSize = Size(spec.$1, spec.$2);
          await launch(tester, container);
          open(tester, query);
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(tester.element(find.byType(DepositWalletScreen)));
          Future<void> tap(String key, {String scroll = 'deposit-wallet-scroll'}) async {
            final target = find.byKey(Key(key));
            await reveal(tester, target, scrollKey: scroll);
            await tester.tap(target.hitTestable());
            await tester.pumpAndSettle();
          }

          await tap('deposit-wallet-read');
          final amount = find.byKey(const Key('deposit-amount'));
          await reveal(tester, amount);
          await tester.enterText(amount, '1');
          await tester.pumpAndSettle();
          await tap('deposit-gas-estimate');
          await tap('deposit-approval-prepare');
          expect(find.byType(DepositApprovalReviewScreen), findsOneWidget);
          expect(identity.transactions, isEmpty);
          expect(journal.snapshot.records, isEmpty);
          await reveal(
            tester,
            find.text(l10n.depositSpenderScope),
            scrollKey: 'deposit-approval-review-scroll',
          );
          expect(find.text(depositVaults[56]!), findsOneWidget);
          await tap('deposit-approval-cancel', scroll: 'deposit-approval-review-scroll');
          expect(identity.transactions, isEmpty);
          expect(journal.snapshot.records, isEmpty);
          await reveal(tester, amount);
          expect(tester.widget<TextField>(amount).controller!.text, '1');
          await tap('deposit-approval-prepare');
          await tap('deposit-approval-confirm', scroll: 'deposit-approval-review-scroll');
          expect(identity.transactions.length, 1);
          expect(identity.wallets, 0);
          expect(journal.snapshot.records.single.hash, '0x${'b' * 64}');
          expect(receipts.calls, isEmpty);
          await tap('deposit-approval-recovery-entry');
          expect(find.byType(DepositApprovalRecoveryScreen), findsOneWidget);
          final hashField = find.byKey(const Key('deposit-approval-original-hash'));
          await reveal(tester, hashField, scrollKey: 'deposit-approval-recovery-scroll');
          final candidate = '0x${'c' * 64}';
          await tester.enterText(hashField, candidate);
          await tester.pumpAndSettle();
          await reveal(
            tester,
            find.text(l10n.depositApprovalRecoveryScope),
            scrollKey: 'deposit-approval-recovery-scroll',
          );
          await reveal(tester, hashField, scrollKey: 'deposit-approval-recovery-scroll');
          expect(tester.widget<TextField>(hashField).controller!.text, candidate);
          receipts.failure = const AccountReadFailure('depositRpcFailed');
          await tap('deposit-approval-check', scroll: 'deposit-approval-recovery-scroll');
          await reveal(tester, hashField, scrollKey: 'deposit-approval-recovery-scroll');
          expect(tester.widget<TextField>(hashField).controller!.text, candidate);
          expect(journal.snapshot.records.length, 1);
          receipts.failure = null;
          receipts.result = DepositApprovalReceipt(
            hash: candidate,
            bound: true,
            status: DepositReceiptStatus.succeeded,
            confirmations: 2,
            blockNumber: quote.wallet.blockNumber,
            gasFee: BigInt.from(21000000000000),
          );
          await tap('deposit-approval-check', scroll: 'deposit-approval-recovery-scroll');
          await reveal(
            tester,
            find.text(l10n.depositApprovalReceiptSucceeded),
            scrollKey: 'deposit-approval-recovery-scroll',
          );
          expect(journal.snapshot.records, isEmpty);
          expect(identity.transactions.length, 1);
          expect(gas.calls.length, 4);
          expect(receipts.calls.last.$2, candidate);
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
          container.dispose();
        },
      );
    }
  }
  testWidgets(
    'stopping receipt check preserves input and late response, wallet change hides record',
    (tester) async {
      final identity = ApprovalIdentityRepository()..restored = user;
      final journal = MemoryDepositApprovalJournal(records: [approvalRecord()]);
      final receipts = TestApprovalReceiptRepository()..gate = Completer();
      addTearDown(identity.dispose);
      addTearDown(journal.close);
      final container = setup(
        tester,
        identityRepository: identity,
        depositApprovalJournal: journal,
        depositApprovalReceiptRepository: receipts,
      );
      await launch(tester, container);
      Navigator.of(tester.element(find.byType(Navigator).first))
          .push<void>(MaterialPageRoute(builder: (_) => const DepositApprovalRecoveryScreen()));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('deposit-approval-original-hash'));
      await reveal(tester, field, scrollKey: 'deposit-approval-recovery-scroll');
      final hash = '0x${'d' * 64}';
      await tester.enterText(field, hash);
      final check = find.byKey(const Key('deposit-approval-check'));
      await reveal(tester, check, scrollKey: 'deposit-approval-recovery-scroll');
      await tester.tap(check.hitTestable());
      await tester.pump();
      final stop = find.byKey(const Key('deposit-approval-check-stop'));
      await tester.ensureVisible(stop);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(stop.hitTestable());
      await tester.pumpAndSettle();
      receipts.gate!.complete();
      await tester.pumpAndSettle();
      await reveal(tester, field, scrollKey: 'deposit-approval-recovery-scroll');
      expect(tester.widget<TextField>(field).controller!.text, hash);
      expect(journal.snapshot.records.single.hash, null);
      expect(container.read(depositApprovalProvider).receipt, null);
      identity.events.add(
        const AuthIdentity(
          id: 'other',
          walletAddress: '0x3333333333333333333333333333333333333333',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DepositApprovalRecoveryCard), findsNothing);
      expect(identity.transactions, isEmpty);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
