import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/primitives.dart';

import '../../support/aster_account.dart';
import '../../support/portfolio_account_tools.dart';
import '../../support/position_risk.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await openPortfolioAccountTools(tester);
    final button = find.byKey(const Key('open-position-risk'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('read-position-risk')),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('position-risk-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('signed-out risk entry requires login without reading or creating a wallet', (
    tester,
  ) async {
    final identity = TestIdentityRepository();
    final risk = TestPositionRiskRepository();
    addTearDown(identity.dispose);
    final container = setup(tester, identityRepository: identity, positionRiskRepository: risk);
    await launch(tester, container);
    await open(tester);
    expect(find.text('仓位风险'), findsOneWidget);
    expect(risk.calls, 0);
    await tester.tap(find.byKey(const Key('read-position-risk')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(risk.calls, 0);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('read snapshot, filter locally, retain failed data and clear on logout', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final risk = TestPositionRiskRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      positionRiskRepository: risk,
      language: const Locale('en'),
    );
    await launch(tester, container);
    await open(tester);
    expect(risk.calls, 0);
    risk.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('read-position-risk')));
    await tester.pump();
    expect(find.text('Confirm the account read signature in your wallet.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('read-position-risk'))).onPressed,
      null,
    );
    risk.gate!.complete();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('position-risk-time')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('position-risk-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('position-risk-time')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('position-risk-current-symbol')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('position-risk-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('position-risk-current-symbol')));
    await tester.pumpAndSettle();
    expect(find.text('Position records (1)'), findsOneWidget);
    expect(risk.calls, 1);
    container.read(symbolProvider.notifier).select('NOTLISTED');
    await tester.pumpAndSettle();
    expect(find.text('No position records for the selected symbol.'), findsOneWidget);
    risk.failure = const AccountReadFailure('accountNetwork');
    await tester.scrollUntilVisible(
      find.byKey(const Key('read-position-risk')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('position-risk-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('read-position-risk')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('position-risk-stale')), findsOneWidget);
    expect(find.byKey(const Key('account-read-error')), findsOneWidget);
    expect(container.read(positionRiskProvider).account!.positions.length, 2);
    identity.events.add(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('position-risk-wallet')), findsNothing);
    expect(container.read(positionRiskProvider).account, null);
    expect(identity.wallets, 0);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final spec in [
    (360.0, 844.0, 1.0, 'zh'),
    (390.0, 844.0, 2.0, 'en'),
    (844.0, 390.0, 1.5, 'zh'),
  ]) {
    testWidgets('risk values, zero liquidation and debt fit $spec', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final risk = TestPositionRiskRepository()
        ..result = mapPositionRisk(
          [
            positionRiskRow()
              ..['positionAmt'] = '0'
              ..['notional'] = '0'
              ..['isolatedWallet'] = '-2.000000000000000001'
              ..['liquidationPrice'] = '0',
          ],
          address: accountAddress,
          receivedAt: DateTime.utc(2026),
        );
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$3,
        language: Locale(spec.$4),
        identityRepository: identity,
        positionRiskRepository: risk,
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      await launch(tester, container);
      await open(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('read-position-risk')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('position-risk-page')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('read-position-risk')));
      await tester.pumpAndSettle();
      final balance = find.byWidgetPredicate(
        (widget) =>
            widget is ValueRow &&
            widget.label == (spec.$4 == 'en' ? 'Isolated wallet balance' : '逐仓钱包余额') &&
            widget.value.contains('-2.000000000000000001'),
      );
      await tester.scrollUntilVisible(
        balance,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('position-risk-page')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(balance, findsOneWidget);
      expect(find.textContaining(spec.$4 == 'en' ? '(unit unavailable)' : '（单位待确认）'), findsWidgets);
      // Unknown leverage/units now also produce unknown margin/ROE fields.
      expect(find.text('—'), findsWidgets);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
