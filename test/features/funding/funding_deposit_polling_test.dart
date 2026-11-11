import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/presentation/funding_wallet_screens.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/subaccounts/presentation/account_components.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/deposit_wallet.dart';
import '../../support/funding_screen.dart';

const _submit = Key('funding-deposit-submit');

AccountAction _action(WidgetTester tester) => tester.widget<AccountAction>(find.byKey(_submit));
FilledButton _button(WidgetTester tester) => tester.widget<FilledButton>(
  find.descendant(of: find.byKey(_submit), matching: find.byType(FilledButton)),
);

Future<void> _openUsdt(WidgetTester tester, FundingHarness h) async {
  await h.open(tester);
  await tester.tap(find.byKey(const Key('funding-asset-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('funding-option-USDT')).last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('funding-amount')), '5');
  await h.settleGas(tester);
  expect(_button(tester).onPressed, isNotNull);
}

void main() {
  testWidgets('first wallet and amount estimate show loading without cached data', (tester) async {
    final h = FundingHarness();
    await h.open(tester);
    await tester.tap(find.byKey(const Key('funding-asset-selector')));
    await tester.pumpAndSettle();
    final walletGate = Completer<void>();
    h.wallet.gate = walletGate;
    await tester.tap(find.byKey(const Key('funding-option-USDT')).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_action(tester).busy, isTrue);
    expect(_button(tester).onPressed, isNull);
    walletGate.complete();
    await tester.pumpAndSettle();
    expect(_action(tester).busy, isFalse);

    final gasGate = Completer<void>();
    h.gas.gate = gasGate;
    await tester.enterText(find.byKey(const Key('funding-amount')), '5');
    await tester.pump(const Duration(milliseconds: 450));
    expect(_action(tester).busy, isTrue);
    expect(_button(tester).onPressed, isNull);
    gasGate.complete();
    await h.settleGas(tester);
    expect(_action(tester).busy, isFalse);
    expect(_button(tester).onPressed, isNotNull);
    await h.close(tester);
  });

  for (final clicked in [false, true]) {
    testWidgets('wallet and gas polling preserve enabled button; click=$clicked', (tester) async {
      final h = FundingHarness();
      await _openUsdt(tester, h);
      final walletGate = Completer<void>(), gasGate = Completer<void>();
      h.wallet.gate = walletGate;
      h.gas.gate = gasGate;
      final reads = h.wallet.calls.length;
      final estimates = h.gas.calls.length;
      await tester.pump(const Duration(seconds: 6));
      expect(h.wallet.calls.length, greaterThan(reads));
      expect(_action(tester).busy, isFalse);
      expect(_button(tester).onPressed, isNotNull);

      if (clicked) {
        // Explicit intent must await this read, never send from the old cache.
        await tester.tap(find.byKey(_submit));
        await tester.pump();
        expect(_action(tester).busy, isTrue);
        expect(_button(tester).onPressed, isNull);
        expect(find.byType(ApprovalConfirmScreen), findsNothing);
      }
      walletGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(h.gas.calls.length, greaterThan(estimates));
      expect(h.gas.gate!.isCompleted, isFalse);
      expect(_action(tester).busy, clicked);
      expect(_button(tester).onPressed, clicked ? isNull : isNotNull);
      expect(h.identity.transactions, isEmpty);
      gasGate.complete();
      await tester.pumpAndSettle();
      if (clicked) {
        expect(find.byType(ApprovalConfirmScreen), findsOneWidget);
      } else {
        expect(_action(tester).busy, isFalse);
        expect(_button(tester).onPressed, isNotNull);
      }
      expect(tester.takeException(), isNull);
      await h.close(tester);
    });
  }

  testWidgets('poll result updates allowance or balance after the read completes', (tester) async {
    final h = FundingHarness();
    await _openUsdt(tester, h);
    final l = AppLocalizations.of(tester.element(find.byKey(_submit)));
    final query = h.wallet.calls.last.$2;
    final gate = Completer<void>();
    h.wallet.gate = gate;
    h.wallet.result = depositSnapshot(query: query, allowance: BigInt.parse('9' * 30));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text(l.fundingApproveAsset('USDT')), findsOneWidget);
    expect(_button(tester).onPressed, isNotNull);
    gate.complete();
    await h.settleGas(tester);
    expect(find.text(l.fundingApproveAsset('USDT')), findsNothing);
    expect(_button(tester).onPressed, isNotNull);

    h.wallet.result = depositSnapshot(query: query, assetUnits: BigInt.one);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_action(tester).busy, isFalse);
    expect(_button(tester).onPressed, isNull);
    expect(find.text('5'), findsOneWidget);
    expect(find.text(l.fundingBalanceInsufficient('USDT')), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('failed polling keeps input and shows its cause without perpetual loading', (
    tester,
  ) async {
    final h = FundingHarness();
    await _openUsdt(tester, h);
    h.wallet.failure = const AccountReadFailure('accountNetwork');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_action(tester).busy, isFalse);
    expect(_button(tester).onPressed, isNull);
    expect(find.text('5'), findsOneWidget);
    expect(find.byKey(const Key('funding-error')), findsOneWidget);
    await h.close(tester);
  });

  testWidgets('editing an amount cannot reuse the quote retained by polling', (tester) async {
    final h = FundingHarness();
    await _openUsdt(tester, h);
    final gasGate = Completer<void>();
    h.gas.gate = gasGate;
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 450));
    expect(_button(tester).onPressed, isNotNull);
    await tester.enterText(find.byKey(const Key('funding-amount')), '6');
    await tester.pump(const Duration(milliseconds: 450));
    expect(_action(tester).busy, isTrue);
    expect(_button(tester).onPressed, isNull);
    gasGate.complete();
    await tester.pumpAndSettle();
    expect(_action(tester).busy, isFalse);
    expect(_button(tester).onPressed, isNotNull);
    expect(h.identity.transactions, isEmpty);
    await h.close(tester);
  });
}
