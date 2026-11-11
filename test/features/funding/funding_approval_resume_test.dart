import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';
import 'package:vanta/features/funding/application/deposit_approval_provider.dart';
import 'package:vanta/features/funding/application/deposit_wallet_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/funding/presentation/funding_wallet_screens.dart';
import 'package:vanta/features/subaccounts/presentation/account_components.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/deposit_approval.dart';
import '../../support/deposit_gas.dart';
import '../../support/deposit_wallet.dart';
import '../../support/funding_screen.dart';

const _submit = Key('funding-deposit-submit');
final _query = depositQuery(minimum: '0.01');
final _ample = BigInt.parse('9' * 30);

Future<void> _choose(WidgetTester tester, String asset) async {
  await tester.tap(find.byKey(const Key('funding-asset-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('funding-option-$asset')).last);
  await tester.pumpAndSettle();
}

void _allowance(FundingHarness h, BigInt units, {String amount = '5'}) {
  final snapshot = depositSnapshot(query: _query, allowance: units);
  h.wallet.result = snapshot;
  h.gas.result = gasQuote(query: _query, wallet: snapshot, amount: amount);
}

Future<void> _openUsdt(WidgetTester tester, FundingHarness h) async {
  await h.open(tester);
  await _choose(tester, 'USDT');
  await tester.enterText(find.byKey(const Key('funding-amount')), '5');
  await h.settleGas(tester);
}

void main() {
  testWidgets('old approval is ignored after reselect/hot reload; latest allowance wins', (
    tester,
  ) async {
    final h = FundingHarness();
    await _openUsdt(tester, h);
    final l = AppLocalizations.of(tester.element(find.byKey(_submit)));
    await h.container.read(depositApprovalJournalProvider).prepare(approvalRecord());
    await tester.pumpAndSettle();
    expect(tester.widget<AccountAction>(find.byKey(_submit)).busy, isFalse);
    expect(find.text(l.depositApprovalOpenRecovery), findsNothing);
    expect(find.text(l.fundingApproveAsset('USDT')), findsOneWidget);

    h.wallet.result = null;
    await _choose(tester, 'BNB');
    await _choose(tester, 'USDT');
    final reassemble = tester.binding.reassembleApplication();
    await tester.pump();
    await reassemble;
    await tester.pumpAndSettle();
    expect(tester.widget<AccountAction>(find.byKey(_submit)).busy, isFalse);
    expect(find.text(l.depositApprovalOpenRecovery), findsNothing);

    _allowance(h, _ample);
    await h.container.read(depositWalletProvider(_query).notifier).refresh();
    await tester.enterText(find.byKey(const Key('funding-amount')), '5');
    await h.settleGas(tester);
    expect(find.text(l.fundingDeposit), findsWidgets);
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    expect(find.byType(DepositConfirmScreen), findsOneWidget);
    expect(h.identity.transactions, isEmpty);
    await h.close(tester);
  });

  for (final sufficient in [false, true]) {
    testWidgets('click rereads allowance and chooses correct review: sufficient=$sufficient', (
      tester,
    ) async {
      final h = FundingHarness();
      await _openUsdt(tester, h);
      if (!sufficient) {
        _allowance(h, _ample);
        await h.container.read(depositWalletProvider(_query).notifier).refresh();
        await h.settleGas(tester);
      }
      // Change chain state after the form renders, without notifying its cache.
      _allowance(h, sufficient ? _ample : BigInt.zero);
      final reads = h.wallet.calls.length;
      await tester.tap(find.byKey(_submit));
      await tester.pumpAndSettle();
      expect(h.wallet.calls.length, greaterThan(reads));
      expect(
        find.byType(sufficient ? DepositConfirmScreen : ApprovalConfirmScreen),
        findsOneWidget,
      );
      expect(find.byType(sufficient ? ApprovalConfirmScreen : DepositConfirmScreen), findsNothing);
      expect(h.identity.transactions, isEmpty);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
  }

  testWidgets('polling, return from wallet and amount changes follow actual allowance', (
    tester,
  ) async {
    final h = FundingHarness();
    await _openUsdt(tester, h);
    final l = AppLocalizations.of(tester.element(find.byKey(_submit)));
    _allowance(h, _ample);
    await tester.pump(const Duration(seconds: 7));
    await h.settleGas(tester);
    expect(find.text(l.fundingApproveAsset('USDT')), findsNothing);
    expect(find.text(l.fundingDeposit), findsWidgets);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    _allowance(h, BigInt.parse('3000000000000000000'));
    final reads = h.wallet.calls.length;
    await tester.pump(const Duration(seconds: 7));
    expect(h.wallet.calls.length, reads);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await h.settleGas(tester);
    expect(find.text(l.fundingApproveAsset('USDT')), findsOneWidget);
    _allowance(h, BigInt.parse('3000000000000000000'), amount: '2');
    await tester.enterText(find.byKey(const Key('funding-amount')), '2');
    await h.settleGas(tester);
    expect(find.text(l.fundingApproveAsset('USDT')), findsNothing);
    expect(find.text(l.fundingDeposit), findsWidgets);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets('leaving an unresolved wallet prompt does not spin or offer recovery', (
    tester,
  ) async {
    final h = FundingHarness();
    final gate = Completer<void>();
    h.identity.transactionGate = gate;
    await _openUsdt(tester, h);
    final l = AppLocalizations.of(tester.element(find.byKey(_submit)));
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('funding-open-wallet')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('funding-wallet-cancel')));
    await tester.pumpAndSettle();
    expect(tester.widget<AccountAction>(find.byKey(_submit)).busy, isFalse);
    expect(find.text(l.depositApprovalOpenRecovery), findsNothing);
    expect(find.text('5'), findsOneWidget);
    // A fresh explicit attempt can open its own review while the old request
    // retains its result handler. Merely opening a review never resends it.
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    expect(find.byType(ApprovalConfirmScreen), findsOneWidget);
    expect(h.identity.transactions, hasLength(1));
    h.identity.transactionResult = const WalletTransactionResult.unknown();
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ApprovalConfirmScreen), findsOneWidget);
    expect(h.identity.transactions, hasLength(1));
    await h.close(tester);
  });

  testWidgets('failed latest allowance read preserves amount and stops before a wallet review', (
    tester,
  ) async {
    final h = FundingHarness();
    await _openUsdt(tester, h);
    h.wallet.failure = const AccountReadFailure('accountNetwork');
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
    expect(find.byType(ApprovalConfirmScreen), findsNothing);
    expect(find.byType(DepositConfirmScreen), findsNothing);
    expect(tester.widget<AccountAction>(find.byKey(_submit)).busy, isFalse);
    expect(find.text('5'), findsOneWidget);
    expect(h.identity.transactions, isEmpty);
    expect(find.byKey(const Key('funding-error')), findsOneWidget);
    await h.close(tester);
  });

  for (final edit in [false, true]) {
    testWidgets('slow prepare completes only for unchanged input: edit=$edit', (tester) async {
      final h = FundingHarness();
      await _openUsdt(tester, h);
      final gate = Completer<void>();
      h.gas.gate = gate;
      await tester.tap(find.byKey(_submit));
      await tester.pump();
      // The entry's balance refresh also schedules the debounced gas read.
      // Its revision must not be mistaken for a user edit during slow RPCs.
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.widget<AccountAction>(find.byKey(_submit)).busy, isTrue);
      if (edit) {
        await tester.enterText(find.byKey(const Key('funding-amount')), '2');
      }
      gate.complete();
      await h.settleGas(tester);
      expect(find.byType(ApprovalConfirmScreen), edit ? findsNothing : findsOneWidget);
      expect(h.identity.transactions, isEmpty);
      if (edit) expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
  }
}
