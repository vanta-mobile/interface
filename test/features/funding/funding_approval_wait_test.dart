import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';
import 'package:vanta/features/funding/application/deposit_approval_provider.dart';
import 'package:vanta/features/funding/domain/deposit_approval.dart';
import 'package:vanta/features/funding/presentation/funding_wallet_screens.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/subaccounts/presentation/account_components.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/deposit_gas.dart';
import '../../support/deposit_wallet.dart';
import '../../support/funding_screen.dart';

const _submit = Key('funding-deposit-submit');

AccountAction _action(WidgetTester tester) => tester.widget<AccountAction>(find.byKey(_submit));
FilledButton _button(WidgetTester tester) => tester.widget<FilledButton>(
  find.descendant(of: find.byKey(_submit), matching: find.byType(FilledButton)),
);

Future<void> _chooseUsdt(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('funding-asset-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('funding-option-USDT')).last);
  await tester.pumpAndSettle();
}

Future<void> _sendApproval(WidgetTester tester, FundingHarness h) async {
  await _chooseUsdt(tester);
  await tester.enterText(find.byKey(const Key('funding-amount')), '5');
  await h.settleGas(tester);
  await tester.tap(find.byKey(_submit));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('funding-open-wallet')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(ApprovalConfirmScreen), findsNothing);
}

Future<void> _poll(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 7));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('own approval waits through pending polls until fresh allowance changes', (
    tester,
  ) async {
    final h = FundingHarness();
    await h.open(tester);
    final query = depositQuery(minimum: '0.01');
    final unapproved = depositSnapshot(query: query, allowance: BigInt.zero);
    h.wallet.result = unapproved;
    h.gas.result = gasQuote(query: query, wallet: unapproved, amount: '5');
    final l = AppLocalizations.of(tester.element(find.byKey(_submit)));
    await _sendApproval(tester, h);
    expect(_action(tester).busy, isTrue);
    expect(_button(tester).onPressed, isNull);
    await _poll(tester);
    expect(_action(tester).busy, isTrue);
    expect(h.identity.transactions, hasLength(1));

    final snapshot = depositSnapshot(query: query, allowance: BigInt.parse('9' * 30));
    h.wallet.result = snapshot;
    h.gas.result = gasQuote(query: query, wallet: snapshot, amount: '5');
    await _poll(tester);
    await h.settleGas(tester);
    expect(_action(tester).busy, isFalse);
    expect(_button(tester).onPressed, isNotNull);
    expect(find.text(l.fundingApproveAsset('USDT')), findsNothing);
    expect(h.identity.transactions, hasLength(1));
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets('a successful receipt still waits for the current allowance read', (tester) async {
    final h = FundingHarness();
    await h.open(tester);
    final query = depositQuery(minimum: '0.01');
    final unapproved = depositSnapshot(query: query, allowance: BigInt.zero);
    h.wallet.result = unapproved;
    h.gas.result = gasQuote(query: query, wallet: unapproved, amount: '5');
    await _sendApproval(tester, h);
    h.approvalReceipts.result = DepositApprovalReceipt(
      hash: '0x${'b' * 64}',
      bound: true,
      matchesIntent: true,
      status: DepositReceiptStatus.succeeded,
      confirmations: 2,
      blockNumber: BigInt.from(123),
    );
    await _poll(tester);
    expect(h.container.read(pendingDepositApprovalsProvider), isEmpty);
    expect(_action(tester).busy, isTrue);
    final approved = depositSnapshot(query: query, allowance: BigInt.parse('9' * 30));
    h.wallet.result = approved;
    h.gas.result = gasQuote(query: query, wallet: approved, amount: '5');
    await _poll(tester);
    await h.settleGas(tester);
    expect(_action(tester).busy, isFalse);
    expect(_button(tester).onPressed, isNotNull);
    expect(h.identity.transactions, hasLength(1));
    await h.close(tester);
  });

  testWidgets('closing and reopening the page never restores approval loading', (tester) async {
    final h = FundingHarness();
    await h.open(tester);
    await _sendApproval(tester, h);
    expect(_action(tester).busy, isTrue);
    await tester.tap(find.byKey(const Key('accounts-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(_submit), findsNothing);
    await tester.tap(find.byKey(const Key('open-funding')));
    await tester.pumpAndSettle();
    await _chooseUsdt(tester);
    await tester.enterText(find.byKey(const Key('funding-amount')), '5');
    await h.settleGas(tester);
    expect(h.container.read(pendingDepositApprovalsProvider), hasLength(1));
    expect(_action(tester).busy, isFalse);
    expect(_button(tester).onPressed, isNotNull);
    await _poll(tester);
    expect(_action(tester).busy, isFalse);
    expect(h.identity.transactions, hasLength(1));
    await h.close(tester);
  });

  for (final outcome in [DepositReceiptStatus.reverted, DepositReceiptStatus.replaced]) {
    testWidgets('terminal approval $outcome releases loading and shows cause', (tester) async {
      final h = FundingHarness();
      await h.open(tester);
      await _sendApproval(tester, h);
      expect(_action(tester).busy, isTrue);
      h.approvalReceipts.result = DepositApprovalReceipt(
        hash: '0x${'b' * 64}',
        bound: true,
        matchesIntent: outcome != DepositReceiptStatus.replaced,
        status: outcome,
        confirmations: 2,
        blockNumber: BigInt.from(123),
      );
      await _poll(tester);
      await h.settleGas(tester);
      expect(_action(tester).busy, isFalse);
      expect(find.byKey(const Key('funding-error')), findsOneWidget);
      expect(h.identity.transactions, hasLength(1));
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
  }

  for (final rejected in [false, true]) {
    testWidgets('wallet unknown or rejection never starts confirmation wait: rejected=$rejected', (
      tester,
    ) async {
      final h = FundingHarness();
      h.identity.transactionResult = rejected
          ? const WalletTransactionResult.rejected()
          : const WalletTransactionResult.unknown();
      await h.open(tester);
      await _sendApproval(tester, h);
      await tester.pumpAndSettle();
      expect(_action(tester).busy, isFalse);
      expect(h.identity.transactions, hasLength(1));
      await h.close(tester);
    });
  }

  testWidgets('confirmation read failure stops loading and preserves amount', (tester) async {
    final h = FundingHarness();
    await h.open(tester);
    await _sendApproval(tester, h);
    expect(_action(tester).busy, isTrue);
    h.wallet.failure = const AccountReadFailure('accountNetwork');
    await _poll(tester);
    await tester.pumpAndSettle();
    expect(_action(tester).busy, isFalse);
    expect(find.text('5'), findsOneWidget);
    expect(find.byKey(const Key('funding-error')), findsOneWidget);
    expect(h.identity.transactions, hasLength(1));
    await h.close(tester);
  });

  testWidgets('reset approval waits for zero allowance then offers the next explicit approval', (
    tester,
  ) async {
    final h = FundingHarness();
    await h.open(tester);
    await _sendApproval(tester, h);
    expect(_action(tester).busy, isTrue);
    final query = depositQuery(minimum: '0.01');
    final snapshot = depositSnapshot(query: query, allowance: BigInt.zero);
    h.wallet.result = snapshot;
    h.gas.result = gasQuote(query: query, wallet: snapshot, amount: '5');
    await _poll(tester);
    await h.settleGas(tester);
    expect(_action(tester).busy, isFalse);
    expect(_button(tester).onPressed, isNotNull);
    final l = AppLocalizations.of(tester.element(find.byKey(_submit)));
    expect(find.text(l.fundingApproveAsset('USDT')), findsOneWidget);
    expect(h.identity.transactions, hasLength(1));
    await h.close(tester);
  });
}
