import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';
import 'package:vanta/features/funding/application/deposit_approval_provider.dart';
import 'package:vanta/features/funding/application/deposit_submission_provider.dart';
import 'package:vanta/features/funding/domain/deposit_approval.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/funding/presentation/funding_status_screens.dart';
import 'package:vanta/features/funding/presentation/funding_wallet_screens.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/subaccounts/presentation/account_components.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/deposit_wallet.dart';
import '../../support/funding_info.dart';
import '../../support/funding_screen.dart';

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(const Key('funding-tab-deposit'))));
FilledButton _submit(WidgetTester tester) => tester.widget<FilledButton>(
  find.descendant(
    of: find.byKey(const Key('funding-deposit-submit')),
    matching: find.byType(FilledButton),
  ),
);

void main() {
  testWidgets('BNB Max reports missing gas, then a deposit goes form → wallet → processing', (
    tester,
  ) async {
    final h = FundingHarness();
    await h.open(tester);
    final l = _l(tester);
    expect(find.text(l.fundingAccountTitle), findsOneWidget);
    expect(find.text(l.fundingNetworkBnb), findsOneWidget);
    expect(find.text('BNB'), findsOneWidget);
    expect(find.text('10 BNB'), findsOneWidget);
    expect(find.text(l.fundingDepositTime(l.fundingNetworkBnb)), findsOneWidget);
    expect(h.wallet.calls.length, 1);
    expect(_submit(tester).onPressed, isNull);

    h.gas.failure = const AccountReadFailure('depositGasBalanceInsufficient');
    await tester.tap(find.byKey(const Key('funding-max')));
    await h.settleGas(tester);
    expect(find.text('10'), findsOneWidget);
    expect(find.text(l.fundingGasInsufficient('BNB')), findsOneWidget);
    expect(_submit(tester).onPressed, isNull);

    h.gas.failure = null;
    await tester.enterText(find.byKey(const Key('funding-amount')), '0.1');
    await h.settleGas(tester);
    expect(find.byKey(const Key('funding-error')), findsNothing);
    await tester.tap(find.byKey(const Key('funding-deposit-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(DepositConfirmScreen), findsOneWidget);
    expect(find.text(l.fundingConfirmDepositTitle), findsOneWidget);
    expect(find.text(l.fundingFuturesAmount('0.1 BNB')), findsOneWidget);
    expect(h.identity.transactions, isEmpty);

    await tester.tap(find.byKey(const Key('funding-open-wallet')));
    await tester.pumpAndSettle();
    expect(h.identity.transactions.length, 1);
    expect(find.byType(DepositProcessingScreen), findsOneWidget);
    expect(find.text(l.fundingDepositProcessing), findsOneWidget);
    expect(find.text(l.fundingStepChainPending), findsOneWidget);
    expect(find.text(l.fundingStepCrediting), findsOneWidget);

    h.depositReceipts.result = DepositApprovalReceipt(
      hash: '0x${'b' * 64}',
      bound: true,
      matchesIntent: true,
      status: DepositReceiptStatus.succeeded,
      confirmations: 2,
      blockNumber: BigInt.from(123),
    );
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text(l.fundingStepChainConfirmed), findsOneWidget);
    expect(h.container.read(pendingDepositSubmissionsProvider), isNotEmpty);
    await tester.tap(find.byKey(const Key('funding-back-portfolio')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-funding')), findsOneWidget);
    expect(h.identity.signatures, 0);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets('wallet rejection and Cancel return to the kept form without sending again', (
    tester,
  ) async {
    final h = FundingHarness();
    await h.open(tester);
    await tester.enterText(find.byKey(const Key('funding-amount')), '0.5');
    await h.settleGas(tester);
    await tester.tap(find.byKey(const Key('funding-deposit-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('funding-wallet-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(DepositConfirmScreen), findsNothing);
    expect(find.text('0.5'), findsOneWidget);
    expect(h.identity.transactions, isEmpty);

    h.identity.transactionResult = const WalletTransactionResult.rejected();
    await tester.tap(find.byKey(const Key('funding-deposit-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('funding-open-wallet')));
    await tester.pumpAndSettle();
    expect(h.identity.transactions.length, 1);
    expect(find.byType(DepositConfirmScreen), findsNothing);
    expect(find.text('0.5'), findsOneWidget);
    expect(find.byKey(const Key('funding-error')), findsNothing);
    expect(h.container.read(pendingDepositSubmissionsProvider), isEmpty);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets('USDT approval returns to the form and Deposit appears after its receipt', (
    tester,
  ) async {
    final h = FundingHarness();
    await h.open(tester);
    final l = _l(tester);
    await tester.tap(find.byKey(const Key('funding-asset-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('funding-option-USDT')).last);
    await tester.pumpAndSettle();
    expect(find.text('123.456789012345678901 USDT'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('funding-amount')), '5');
    await h.settleGas(tester);
    expect(find.text(l.fundingApproveAsset('USDT')), findsOneWidget);

    await tester.tap(find.byKey(const Key('funding-deposit-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(ApprovalConfirmScreen), findsOneWidget);
    expect(find.text(l.fundingApproveTitle('USDT')), findsOneWidget);
    await tester.tap(find.byKey(const Key('funding-open-wallet')));
    // The pending approval keeps a spinner running, so pump fixed frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ApprovalConfirmScreen), findsNothing);
    expect(h.container.read(pendingDepositApprovalsProvider), hasLength(1));
    expect(
      tester.widget<AccountAction>(find.byKey(const Key('funding-deposit-submit'))).busy,
      isTrue,
    );

    final query = depositQuery(minimum: '0.01');
    h.wallet.result = depositSnapshot(query: query, allowance: BigInt.parse('9' * 30));
    h.approvalReceipts.result = DepositApprovalReceipt(
      hash: '0x${'b' * 64}',
      bound: true,
      matchesIntent: true,
      status: DepositReceiptStatus.succeeded,
      confirmations: 2,
      blockNumber: BigInt.from(123),
    );
    await tester.pump(const Duration(seconds: 7));
    await h.settleGas(tester);
    expect(h.container.read(pendingDepositApprovalsProvider), isEmpty);
    expect(find.text(l.fundingDeposit), findsWidgets);
    expect(_submit(tester).onPressed, isNotNull);
    expect(h.identity.signatures, 0);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  for (final size in [const Size(393, 640), const Size(844, 390)]) {
    testWidgets('a long asset dropdown stays on screen at $size and scrolls', (tester) async {
      final h = FundingHarness();
      h.catalog.rows = [
        fundingAssetRow(asset: 'BNB', native: true)..['minDeposit'] = '0.01',
        for (var i = 0; i < 20; i++) fundingAssetRow(asset: 'TK$i')..['minDeposit'] = '0.01',
      ];
      await h.open(tester, size: size);
      await tester.tap(find.byKey(const Key('funding-asset-selector')));
      await tester.pumpAndSettle();
      final menu = tester.getRect(find.byKey(const Key('funding-dropdown-scroll')));
      expect(menu.top, greaterThanOrEqualTo(0));
      expect(menu.bottom, lessThanOrEqualTo(size.height - 16));
      final last = find.byKey(const Key('funding-option-TK19'));
      expect(last.hitTestable(), findsNothing);
      await tester.scrollUntilVisible(
        last,
        100,
        scrollable: find.descendant(
          of: find.byKey(const Key('funding-dropdown-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('funding-dropdown-scroll')), findsNothing);
      expect(find.text('TK19'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
  }

  testWidgets('with a device grant the processing page polls chain and then credit', (
    tester,
  ) async {
    final h = FundingHarness();
    await h.open(tester, deviceGrant: true);
    final l = _l(tester);
    await tester.enterText(find.byKey(const Key('funding-amount')), '0.1');
    await h.settleGas(tester);
    await tester.tap(find.byKey(const Key('funding-deposit-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('funding-open-wallet')));
    await tester.pumpAndSettle();
    expect(find.text(l.fundingStepChainPending), findsOneWidget);
    // Credit is not read before the chain receipt succeeds.
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(h.history.calls, 0);

    h.depositReceipts.result = DepositApprovalReceipt(
      hash: '0x${'b' * 64}',
      bound: true,
      matchesIntent: true,
      status: DepositReceiptStatus.succeeded,
      confirmations: 2,
      blockNumber: BigInt.from(123),
    );
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text(l.fundingStepChainConfirmed), findsOneWidget);

    // No exact SUCCESS record yet: the deposit stays pending and is retried.
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(h.history.calls, 1);
    expect(h.container.read(pendingDepositSubmissionsProvider), hasLength(1));
    expect(find.text(l.fundingStepChainConfirmed), findsOneWidget);

    h.history
      ..now = DateTime.now().toUtc().add(const Duration(minutes: 1))
      ..records = [
        TransferRecord(
          id: 'credit-1',
          market: TransferMarket.perp,
          type: TransferType.deposit,
          status: TransferStatus.success,
          asset: 'BNB',
          amount: Decimal.parse('0.1'),
          recordTime: DateTime.now().toUtc(),
          chainId: 56,
          txHash: '0x${'b' * 64}',
        ),
      ];
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(h.history.calls, 2);
    expect(h.container.read(depositSubmissionProvider).credited, isTrue);
    expect(h.container.read(pendingDepositSubmissionsProvider), isEmpty);
    await tester.pump(const Duration(seconds: 22));
    await tester.pumpAndSettle();
    expect(h.history.calls, 2);
    expect(h.identity.signatures, 0);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });
}
