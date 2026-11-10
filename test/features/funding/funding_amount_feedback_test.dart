import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/application/withdraw_info_provider.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/presentation/funding_components.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/funding_screen.dart';

FilledButton submit(WidgetTester tester, String type) => tester.widget<FilledButton>(
  find.descendant(of: find.byKey(Key('funding-$type-submit')), matching: find.byType(FilledButton)),
);
AppLocalizations l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(FundingAmountField)));
bool invalid(WidgetTester tester) =>
    tester.widget<FundingAmountField>(find.byType(FundingAmountField)).error;

Future<void> selectUsdt(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('funding-asset-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('funding-option-USDT')).last);
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in [const Locale('en'), const Locale('zh')]) {
    testWidgets('deposit balance and native gas feedback disable submit: $locale', (tester) async {
      final h = FundingHarness();
      await h.open(tester, locale: locale, size: const Size(320, 700), textScale: 1.5);
      final text = l(tester);
      await tester.enterText(find.byKey(const Key('funding-amount')), '11');
      await h.settleGas(tester);
      expect(find.text(text.fundingBalanceInsufficient('BNB')), findsOneWidget);
      expect(invalid(tester), true);
      expect(submit(tester, 'deposit').onPressed, isNull);
      expect(h.gas.calls, isEmpty);
      h.gas.failure = const AccountReadFailure('depositGasBalanceInsufficient');
      await tester.enterText(find.byKey(const Key('funding-amount')), '10');
      await h.settleGas(tester);
      expect(find.text(text.fundingGasInsufficient('BNB')), findsOneWidget);
      expect(invalid(tester), true);
      expect(submit(tester, 'deposit').onPressed, isNull);
      h.gas.failure = null;
      await tester.enterText(find.byKey(const Key('funding-amount')), '1');
      await h.settleGas(tester);
      expect(invalid(tester), false);
      expect(submit(tester, 'deposit').onPressed, isNotNull);
      expect(h.identity.transactions, isEmpty);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
    testWidgets('withdrawal balance and fee feedback disable submit; Max reserves fee: $locale', (
      tester,
    ) async {
      final h = FundingHarness();
      await h.open(tester, locale: locale, operation: FundingOperation.withdraw);
      await selectUsdt(tester);
      await h.container.read(withdrawInfoProvider.notifier).refresh();
      await tester.pumpAndSettle();
      final text = l(tester);
      await tester.enterText(find.byKey(const Key('funding-amount')), '3');
      await tester.pump();
      expect(find.text(text.fundingBalanceInsufficient('USDT')), findsOneWidget);
      expect(invalid(tester), true);
      expect(submit(tester, 'withdraw').onPressed, isNull);
      await tester.enterText(find.byKey(const Key('funding-amount')), '2.3');
      await tester.pump();
      expect(find.text(text.fundingWithdrawalFeeInsufficient('USDT')), findsOneWidget);
      expect(invalid(tester), true);
      expect(submit(tester, 'withdraw').onPressed, isNull);
      await tester.tap(find.byKey(const Key('funding-max')));
      await tester.pump();
      expect(find.text('2.216543210987654323'), findsOneWidget);
      expect(invalid(tester), false);
      expect(submit(tester, 'withdraw').onPressed, isNotNull);
      expect(h.wallet.calls, isEmpty, reason: 'platform withdrawals do not consume wallet gas');
      expect(h.withdrawals.prepared, isEmpty);
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
  }
  testWidgets('token approval needs native gas; stale estimates cannot enable another amount', (
    tester,
  ) async {
    final h = FundingHarness();
    await h.open(tester);
    await selectUsdt(tester);
    h.gas.failure = const AccountReadFailure('depositGasBalanceInsufficient');
    await tester.enterText(find.byKey(const Key('funding-amount')), '5');
    await h.settleGas(tester);
    expect(find.text(l(tester).fundingGasTopUp('BNB')), findsOneWidget);
    expect(submit(tester, 'deposit').onPressed, isNull);
    expect(invalid(tester), true);
    h.gas.failure = null;
    final old = Completer<void>();
    h.gas.gate = old;
    await tester.enterText(find.byKey(const Key('funding-amount')), '6');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    final oldCurrent = h.gas.isCurrent!;
    expect(submit(tester, 'deposit').onPressed, isNull);
    await tester.enterText(find.byKey(const Key('funding-amount')), '7');
    await tester.pump();
    expect(oldCurrent(), false);
    h.gas.gate = null;
    h.gas.failure = const AccountReadFailure('depositGasBalanceInsufficient');
    await h.settleGas(tester);
    expect(submit(tester, 'deposit').onPressed, isNull);
    old.complete();
    await tester.pumpAndSettle();
    expect(find.text(l(tester).fundingGasTopUp('BNB')), findsOneWidget);
    expect(submit(tester, 'deposit').onPressed, isNull);
    h.gas.failure = null;
    await tester.enterText(find.byKey(const Key('funding-amount')), '8');
    await h.settleGas(tester);
    expect(submit(tester, 'deposit').onPressed, isNotNull);
    expect(h.identity.transactions, isEmpty);
    await h.close(tester);
  });
}
