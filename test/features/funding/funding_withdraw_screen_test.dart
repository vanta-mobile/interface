import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/application/withdraw_info_provider.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/funding/presentation/funding_status_screens.dart';
import 'package:vanta/features/funding/presentation/funding_wallet_screens.dart';
import 'package:vanta/features/funding/presentation/rebalance_sheet.dart';
import 'package:vanta/features/portfolio/application/rebalance_provider.dart';
import 'package:vanta/features/funding/domain/funding_fee.dart';
import 'package:vanta/features/funding/presentation/funding_components.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/funding_fee.dart';
import '../../support/funding_screen.dart';
import '../../support/rebalance.dart';

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(const Key('funding-tab-withdraw'))));
FilledButton _withdraw(WidgetTester tester) => tester.widget<FilledButton>(
  find.descendant(
    of: find.byKey(const Key('funding-withdraw-submit')),
    matching: find.byType(FilledButton),
  ),
);

Future<void> _selectUsdt(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('funding-asset-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('funding-option-USDT')).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('withdrawal signs only from the wallet step and tracks failure by request ID', (
    tester,
  ) async {
    final h = FundingHarness();
    await h.open(tester, operation: FundingOperation.withdraw);
    final l = _l(tester);
    expect(find.text(l.fundingWithdrawFrom), findsOneWidget);
    expect(find.text(l.fundingWithdrawChainHint), findsOneWidget);
    expect(find.byKey(const Key('funding-fee')), findsOneWidget);
    // Without a device grant navigation never reads private limits.
    expect(h.withdrawInfo.calls, 0);
    expect(h.rebalance.reads, 0);
    await _selectUsdt(tester);
    await h.container.read(withdrawInfoProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.text('2.340000000000000002 USDT'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('funding-amount')), '3');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('funding-error')), findsOneWidget);
    expect(_withdraw(tester).onPressed, isNull);
    await tester.tap(find.byKey(const Key('funding-max')));
    await tester.pumpAndSettle();
    expect(find.text('2.216543210987654323'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('funding-amount')), '1.5');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('funding-error')), findsNothing);

    await tester.tap(find.byKey(const Key('funding-withdraw-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(WithdrawConfirmScreen), findsOneWidget);
    expect(find.text(l.fundingConfirmWithdrawTitle), findsOneWidget);
    expect(h.withdrawals.prepared, isEmpty);
    await tester.tap(find.byKey(const Key('funding-open-wallet')));
    await tester.pumpAndSettle();
    expect(h.withdrawals.prepared.single.$2, '1.5');
    expect(h.withdrawals.submits, 1);
    expect(find.byType(WithdrawalStatusScreen), findsOneWidget);
    expect(find.text(l.fundingWithdrawProcessing), findsOneWidget);
    expect(find.text(l.fundingStepNetwork), findsOneWidget);

    h.history
      ..now = DateTime.now().toUtc()
      ..records = [
        TransferRecord(
          id: 'W-20261103-0841',
          market: TransferMarket.perp,
          type: TransferType.withdraw,
          status: TransferStatus.failed,
          asset: 'USDT',
          amount: Decimal.parse('1.5'),
          recordTime: DateTime.now().toUtc(),
          chainId: 56,
        ),
      ];
    await tester.fling(find.text(l.fundingWithdrawProcessing), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text(l.fundingWithdrawFailedTitle), findsOneWidget);
    expect(find.text('W-20261103-0841'), findsOneWidget);
    expect(find.text(l.fundingWithdrawFailedHint), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets('a changed platform fee stops before signing and keeps the amount', (tester) async {
    final h = FundingHarness()..withdrawals.fee = Decimal.parse('9');
    await h.open(tester, operation: FundingOperation.withdraw);
    final l = _l(tester);
    await _selectUsdt(tester);
    await tester.enterText(find.byKey(const Key('funding-amount')), '1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('funding-withdraw-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('funding-open-wallet')));
    await tester.pumpAndSettle();
    expect(h.withdrawals.submits, 0);
    expect(find.byType(WithdrawConfirmScreen), findsNothing);
    expect(find.text(l.withdrawalFeeChanged), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('negative USDT blocks withdraw until Rebalance clears it', (tester) async {
    final h = FundingHarness();
    await h.open(tester, operation: FundingOperation.withdraw);
    final l = _l(tester);
    await h.container.read(rebalanceProvider.notifier).load();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('funding-rebalance-alert')), findsOneWidget);
    expect(find.text(l.fundingRebalanceRequired), findsOneWidget);
    expect(find.byKey(const Key('funding-withdraw-submit')), findsNothing);

    await tester.tap(find.byKey(const Key('funding-rebalance')));
    await tester.pumpAndSettle();
    expect(find.byType(RebalanceSheet), findsOneWidget);
    expect(find.text(l.fundingRebalanceHint), findsOneWidget);
    h.rebalance.context = rebalanceContext(usdt: '0');
    await tester.tap(find.byKey(const Key('funding-rebalance-confirm')));
    await tester.pumpAndSettle();
    expect(h.rebalance.posts, 1);
    expect(find.byType(RebalanceSheet), findsNothing);
    expect(find.byKey(const Key('funding-rebalance-alert')), findsNothing);
    expect(find.byKey(const Key('funding-withdraw-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  for (final (size, locale) in [
    (const Size(320, 640), const Locale('zh')),
    (const Size(844, 390), const Locale('en')),
  ]) {
    testWidgets('funding tabs and dropdowns fit $size $locale at 1.5 text', (tester) async {
      final h = FundingHarness();
      await h.open(tester, size: size, locale: locale, textScale: 1.5);
      await tester.tap(find.byKey(const Key('funding-network')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('funding-option-56')), findsWidgets);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('funding-tab-withdraw')));
      await tester.pumpAndSettle();
      await h.container.read(rebalanceProvider.notifier).load();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('funding-rebalance-alert')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
  }

  testWidgets('with a device grant the status page polls until a final status', (tester) async {
    final h = FundingHarness();
    h.rebalance.context = rebalanceContext(usdt: '0');
    await h.open(tester, operation: FundingOperation.withdraw, deviceGrant: true);
    // The grant also loads limits and the Rebalance check on entry.
    expect(h.withdrawInfo.calls, 1);
    expect(h.rebalance.reads, 1);
    final l = _l(tester);
    await _selectUsdt(tester);
    await tester.enterText(find.byKey(const Key('funding-amount')), '1.5');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('funding-withdraw-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('funding-open-wallet')));
    await tester.pumpAndSettle();
    expect(find.text(l.fundingWithdrawProcessing), findsOneWidget);
    final opened = h.history.calls;
    expect(opened, greaterThanOrEqualTo(1));
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(h.history.calls, opened + 1);
    expect(find.text(l.fundingWithdrawProcessing), findsOneWidget);

    h.history
      ..now = DateTime.now().toUtc().add(const Duration(minutes: 1))
      ..records = [
        TransferRecord(
          id: 'W-20261103-0841',
          market: TransferMarket.perp,
          type: TransferType.withdraw,
          status: TransferStatus.success,
          asset: 'USDT',
          amount: Decimal.parse('1.5'),
          recordTime: DateTime.now().toUtc(),
          chainId: 56,
        ),
      ];
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text(l.fundingWithdrawCompleted), findsOneWidget);
    final settled = h.history.calls;
    await tester.pump(const Duration(seconds: 22));
    await tester.pumpAndSettle();
    expect(h.history.calls, settled);
    expect(tester.takeException(), isNull);
    await h.close(tester);
  });

  testWidgets('switching token reloads only the fee row with a skeleton', (tester) async {
    final h = FundingHarness();
    await h.open(tester, operation: FundingOperation.withdraw);
    expect(find.byKey(const Key('funding-fee')), findsOneWidget);
    const usdt = FundingFeeQuery(market: TransferMarket.perp, chainId: 56, asset: 'USDT');
    final gate = Completer<FundingFeeQuote>();
    h.fees.gates[usdt] = gate;
    await tester.enterText(find.byKey(const Key('funding-amount')), '0.02');
    await tester.pump();
    final calls = h.fees.calls.length;
    await tester.enterText(find.byKey(const Key('funding-amount')), '0.03');
    await tester.pump();
    expect(h.fees.calls.length, calls, reason: 'the fee does not depend on the amount');
    await tester.tap(find.byKey(const Key('funding-asset-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('funding-option-USDT')).last);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('funding-fee')), findsNothing);
    expect(find.byType(FundingSkeleton), findsOneWidget);
    gate.complete(fundingFeeFixture(usdt));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('funding-fee')), findsOneWidget);
    expect(find.byType(FundingSkeleton), findsNothing);
    await h.close(tester);
  });
}
