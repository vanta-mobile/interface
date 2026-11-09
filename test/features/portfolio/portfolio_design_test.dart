import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

import '../../support/asset_indices.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/portfolio_overview_provider.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_pnl_screen.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_history_chart.dart';
import 'package:vanta/features/trade/presentation/widgets/app_bottom_navigation.dart';

import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';

Future<void> preview(WidgetTester tester) async {
  await tapNavigationControl(tester, 'navigation-explore');
  await tapNavigationControl(tester, 'portfolio-preview-entry');
}

Future<void> scrollPortfolioTop(WidgetTester tester) async {
  final scroll = tester.state<ScrollableState>(
    find
        .descendant(of: find.byKey(const Key('portfolio-page')), matching: find.byType(Scrollable))
        .first,
  );
  scroll.position.jumpTo(0);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('restored external identity shows the connection entry and refresh does not sign', (
    tester,
  ) async {
    final fixture = NavigationFixture(tester);
    fixture.identity.restored = const AuthIdentity(
      id: 'restored-external',
      walletAddress: '0x2222222222222222222222222222222222222222',
      walletKind: WalletKind.external,
    );
    await launch(tester, fixture.container);
    await tapNavigationControl(tester, 'navigation-portfolio');
    expect(find.byKey(const Key('portfolio-login')), findsOneWidget);
    expect(find.text('Connect a wallet'), findsOneWidget);
    expect(find.byKey(const Key('portfolio-account-selector')), findsNothing);
    expect(find.byKey(const Key('portfolio-deposit')), findsNothing);
    expect(find.byKey(const Key('portfolio-withdraw')), findsNothing);
    await fixture.container.read(portfolioRefreshProvider)();
    fixture.expectNoAccountMutation();
    await tapNavigationControl(tester, 'portfolio-login');
    expect(find.byKey(const Key('connect-external-wallet')), findsOneWidget);
    expect(find.byKey(const Key('logout-identity')), findsNothing);
    expect(fixture.identity.restored?.walletAddress, '0x2222222222222222222222222222222222222222');
    expect(tester.takeException(), null);
    await fixture.close(tester);
  });

  testWidgets('signed out portfolio follows design with four ordered destinations', (tester) async {
    final fixture = NavigationFixture(tester, signedIn: false);
    await launch(tester, fixture.container);
    await tapNavigationControl(tester, 'navigation-portfolio');
    expect(find.text('Log in to view your assets and performance.'), findsOneWidget);
    expect(find.text('Log in to view your balances'), findsOneWidget);
    expect(find.byKey(const Key('portfolio-login')), findsOneWidget);
    expect(find.byKey(const Key('account-button')), findsNothing);
    expect(find.text(r'$3,840.00'), findsNothing);
    final destinations = find.descendant(
      of: find.byType(AppBottomNavigation),
      matching: find.byType(InkWell),
    );
    expect(destinations, findsNWidgets(4));
    final keys = tester.widgetList<InkWell>(destinations).map((w) => w.key).toList();
    expect(keys, [
      const ValueKey('navigation-markets'),
      const ValueKey('navigation-futures'),
      const ValueKey('navigation-explore'),
      const ValueKey('navigation-portfolio'),
    ]);
    fixture.expectNoAccountMutation();
    expect(tester.takeException(), null);
    await fixture.close(tester);
  });

  testWidgets('static preview exposes design interactions and never signs or writes', (
    tester,
  ) async {
    final fixture = NavigationFixture(tester);
    await launch(tester, fixture.container);
    await preview(tester);
    expect(find.text('Static design sample. No real funds or orders.'), findsOneWidget);
    expect(find.text(r'$3,840.00'), findsOneWidget);
    await tapNavigationControl(tester, 'portfolio-deposit');
    expect(
      find.text('This is a static preview. Switch to your account to continue.'),
      findsOneWidget,
    );
    ScaffoldMessenger.of(tester.element(find.byKey(const Key('portfolio-deposit'))))
        .clearSnackBars();
    await tester.pumpAndSettle();
    await scrollPortfolioTop(tester);
    await tapNavigationControl(tester, 'portfolio-value-history-toggle');
    expect(find.byKey(const Key('portfolio-value-history-collapse')), findsOneWidget);
    await tapNavigationControl(tester, 'portfolio-value-history-collapse');
    expect(find.byKey(const Key('portfolio-value-history-collapse')), findsNothing);
    await scrollPortfolioTop(tester);
    await tapNavigationControl(tester, 'portfolio-balance-visibility');
    expect(find.text(r'$3,840.00'), findsNothing);
    await scrollPortfolioTop(tester);
    await tapNavigationControl(tester, 'portfolio-balance-visibility');
    await tester.scrollUntilVisible(
      find.byKey(const Key('portfolio-assets-tab-assets')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('portfolio-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapNavigationControl(tester, 'portfolio-assets-tab-assets');
    await tapNavigationControl(tester, 'portfolio-asset-USDT');
    expect(find.text('Margin balance'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await scrollPortfolioTop(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('portfolio-pnl-entry')),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('portfolio-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapNavigationControl(tester, 'portfolio-pnl-entry');
    expect(find.byType(PortfolioPnlScreen), findsOneWidget);
    await tapNavigationControl(tester, 'portfolio-period-30D');
    expect(find.text('PnL data unavailable for this account'), findsOneWidget);
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('portfolio-month-next'))).onPressed,
      isNull,
    );
    expect(find.text(r'+$21.83'), findsOneWidget);
    await tapNavigationControl(tester, 'portfolio-month-previous');
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(r'+$21.83'), findsNothing);
    fixture.expectNoAccountMutation();
    expect(tester.takeException(), null);
    await fixture.close(tester);
  });

  for (final language in ['en', 'zh']) {
    for (final size in [const Size(320, 700), const Size(844, 390), const Size(768, 1024)]) {
      testWidgets('portfolio, assets and PnL fit $size $language at 1.5 text', (tester) async {
        final fixture = NavigationFixture(
          tester,
          language: language,
          width: size.width,
          scale: 1.5,
        );
        tester.view.physicalSize = size;
        await launch(tester, fixture.container);
        await preview(tester);
        await tester.drag(find.byKey(const Key('portfolio-page')), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        await tester.scrollUntilVisible(
          find.byKey(const Key('portfolio-assets-tab-assets')),
          200,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('portfolio-page')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tapNavigationControl(tester, 'portfolio-assets-tab-assets');
        expect(tester.takeException(), null);
        await scrollPortfolioTop(tester);
        await tester.scrollUntilVisible(
          find.byKey(const Key('portfolio-pnl-entry')),
          100,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('portfolio-page')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tapNavigationControl(tester, 'portfolio-pnl-entry');
        await tapNavigationControl(tester, 'portfolio-pnl-view-true');
        await tester.drag(find.byKey(const Key('portfolio-pnl-page')), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        fixture.expectNoAccountMutation();
        await fixture.close(tester);
      });
    }
  }

  testWidgets('live account refresh awaits repository and does not inject preview performance', (
    tester,
  ) async {
    final fixture = NavigationFixture(tester);
    await launch(tester, fixture.container);
    await tapNavigationControl(tester, 'navigation-portfolio');
    fixture.account.gate = Completer<void>();
    var settled = false;
    final refresh = fixture.container.read(portfolioRefreshProvider)().then((_) => settled = true);
    await tester.pump();
    expect(settled, false);
    expect(fixture.container.read(accountReadProvider).busy, true);
    fixture.account.gate!.complete();
    await refresh;
    await tester.pumpAndSettle();
    expect(settled, true);
    expect(fixture.account.calls, 1);
    expect(fixture.container.read(portfolioOverviewProvider).performance.history, isEmpty);
    expect(find.text(r'+$124.35'), findsNothing);
    await scrollPortfolioTop(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('portfolio-pnl-entry')),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('portfolio-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapNavigationControl(tester, 'portfolio-pnl-entry');
    expect(find.text('PnL data unavailable for this account'), findsOneWidget);
    expect(find.byType(PortfolioHistoryChart), findsOneWidget);
    expect(tester.takeException(), null);
    await fixture.close(tester);
  });
  testWidgets('refresh awaits public valuation and preserves real units and data on failure', (
    tester,
  ) async {
    final indices = TestAssetIndexRepository();
    final fixture = NavigationFixture(tester, assetIndexRepository: indices);
    await launch(tester, fixture.container);
    await tapNavigationControl(tester, 'navigation-portfolio');
    indices.gate = Completer<AssetIndexSnapshot>();
    var settled = false;
    final refresh = fixture.container.read(portfolioRefreshProvider)().then((_) => settled = true);
    await tester.pump();
    expect(settled, false);
    indices.gate!.complete(assetIndexFixture(DateTime.now().toUtc()));
    await refresh;
    await tester.pumpAndSettle();
    final actual = fixture.container.read(portfolioOverviewProvider);
    expect(actual.totalUsd, Decimal.parse('100.000000000000000001') * Decimal.parse('0.99836'));
    expect(actual.positions.single.quantity, Decimal.parse('0.000000000000000001'));
    expect(actual.positions.single.base, 'BTC');
    expect(actual.positions.single.long, false);
    expect(actual.performance.pnl, isNull);
    fixture.account.failure = const AccountReadFailure('accountNetwork');
    indices.gate = null;
    await fixture.container.read(portfolioRefreshProvider)();
    await tester.pumpAndSettle();
    expect(
      fixture.container.read(portfolioOverviewProvider).assets.first.balance,
      actual.assets.first.balance,
    );
    expect(fixture.container.read(accountReadProvider).failure, isNotNull);
    expect(fixture.orders.submits, 0);
    expect(fixture.identity.signatures, 0);
    expect(tester.takeException(), null);
    await fixture.close(tester);
  });
}
