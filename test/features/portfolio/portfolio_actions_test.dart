import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/presentation/funding_screen.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';

import '../../support/live_order.dart';
import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';

void main() {
  for (final market in [true, false]) {
    testWidgets('portfolio opens ${market ? 'market' : 'limit'} close without submitting', (
      tester,
    ) async {
      final fixture = NavigationFixture(tester);
      await launch(tester, fixture.container);
      await tapNavigationControl(tester, 'navigation-portfolio');
      await fixture.container.read(accountReadProvider.notifier).refresh();
      // Portfolio positions now come from the signed position-risk read
      // (7844ea4 removed PortfolioOverview.positions).
      await fixture.container.read(positionRiskProvider.notifier).refresh();
      await tester.pumpAndSettle();
      // The Portfolio list renders the shared TradePositionCard, whose Market
      // and Limit actions open the Close Position sheet on the matching tab
      // (7844ea4, docs/implementation.md "Portfolio page's position list").
      final action = find.byKey(Key('trade-position-action-${market ? 1 : 2}-BTCUSDT-BOTH'));
      await tester.scrollUntilVisible(
        action,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('portfolio-page')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('position-close-sheet')), findsOneWidget);
      expect(find.byKey(const Key('position-limit-price')), market ? findsNothing : findsOneWidget);
      expect(fixture.orders.submits, 0);
      expect(fixture.identity.signatures, 0);
      expect(tester.takeException(), null);
      await fixture.close(tester);
    });
  }
  testWidgets('portfolio close all opens the design sheet; cancel submits nothing', (tester) async {
    final fixture = NavigationFixture(tester);
    // Close-all needs a position read from the last 30 seconds.
    final stored = fixture.positions.result;
    fixture.positions.result = PositionRiskSnapshot(
      address: stored.address,
      receivedAt: liveOrderClock,
      positions: stored.positions,
      units: stored.units,
    );
    await launch(tester, fixture.container);
    await tapNavigationControl(tester, 'navigation-portfolio');
    await fixture.container.read(positionRiskProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('portfolio-close-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('batch-close-confirm')), findsOneWidget);
    expect(find.textContaining('by market orders?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('batch-close-confirm')), findsNothing);
    expect(fixture.orders.submits, 0);
    expect(fixture.identity.signatures, 0);
    expect(tester.takeException(), null);
    await fixture.close(tester);
  });
  for (final operation in [FundingOperation.deposit, FundingOperation.withdraw]) {
    testWidgets('portfolio funding enters $operation without signing', (tester) async {
      final fixture = NavigationFixture(tester);
      await launch(tester, fixture.container);
      await tapNavigationControl(tester, 'navigation-portfolio');
      await tapNavigationControl(
        tester,
        'portfolio-${operation == FundingOperation.deposit ? 'deposit' : 'withdraw'}',
      );
      expect(tester.widget<FundingScreen>(find.byType(FundingScreen)).initialOperation, operation);
      fixture.expectNoAccountMutation();
      expect(tester.takeException(), null);
      await fixture.close(tester);
    });
  }
}
