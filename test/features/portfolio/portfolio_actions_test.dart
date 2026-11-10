import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/presentation/funding_screen.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';

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
      await tester.pumpAndSettle();
      final action = find.byKey(
        ValueKey('portfolio-position-BTCUSDT-BOTH-${market ? 'Market' : 'Limit'}'),
      );
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
      expect(
        tester.widget<LiveOrderScreen>(find.byType(LiveOrderScreen)).initialCloseMarket,
        market,
      );
      await tapNavigationControl(tester, 'live-order-read');
      final selector = tester.widget<SegmentedButton<bool>>(
        find.byKey(const Key('live-order-type')),
      );
      expect(selector.selected, {market});
      expect(fixture.orders.submits, 0);
      expect(fixture.identity.signatures, 0);
      expect(tester.takeException(), null);
      await fixture.close(tester);
    });
  }
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
