import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/assistant/presentation/assistant_page.dart';
import 'package:vanta/features/points/presentation/points_page.dart';
import 'package:vanta/features/portfolio/presentation/quick_order_panel.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/order_form.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';
import '../../support/workspace_navigation.dart';

void main() {
  for (final language in ['en', 'zh']) {
    for (final chart in [true, false]) {
      testWidgets('navigation retains chosen workspace/symbol through locale $language $chart', (
        tester,
      ) async {
        final fixture = NavigationFixture(tester, language: language, width: 320, scale: 1.5);
        await launch(tester, fixture.container);
        expect(find.byType(QuickOrderPanel), findsOneWidget);
        expect(find.byType(OrderForm), findsNothing);
        expect(find.byType(AssistantPage), findsNothing);
        expect(find.byType(PointsPage), findsNothing);
        await selectWorkspace(tester, chart: chart);
        fixture.container.read(symbolProvider.notifier).select('ETHUSDT');
        await tester.pumpAndSettle();
        for (final destination in ['markets', 'portfolio', 'assistant', 'points']) {
          await tapNavigationControl(tester, 'navigation-$destination');
          final navigation = find.byKey(Key('navigation-$destination'));
          expect(tester.getSize(navigation).height, greaterThanOrEqualTo(48));
          final semantics = tester.widget<Semantics>(
            find.ancestor(of: navigation, matching: find.byType(Semantics)).first,
          );
          expect(semantics.properties.selected, true);
          expect(semantics.properties.button, true);
          expect(find.byType(QuickOrderPanel), findsNothing);
          await fixture.container
              .read(localeProvider.notifier)
              .select(language == 'en' ? 'zh' : 'en');
          await tester.pumpAndSettle();
          await tapNavigationControl(tester, 'navigation-futures');
          expect(fixture.container.read(symbolProvider), 'ETHUSDT');
          expect(
            tester
                .widget<SegmentedButton<bool>>(find.byKey(const Key('trade-workspace-tabs')))
                .selected,
            {chart},
          );
          expect(find.byType(QuickOrderPanel), chart ? findsOneWidget : findsNothing);
          expect(find.byType(OrderForm), chart ? findsNothing : findsOneWidget);
          expect(find.byType(AssistantPage), findsNothing);
          expect(find.byType(PointsPage), findsNothing);
          fixture.expectNoAccountMutation();
          expect(tester.takeException(), null);
        }
        await fixture.close(tester);
      });
    }
  }

  for (final chart in [true, false]) {
    testWidgets('Markets selection returns to chosen futures workspace $chart', (tester) async {
      final fixture = NavigationFixture(tester);
      await launch(tester, fixture.container);
      await selectWorkspace(tester, chart: chart);
      await tapNavigationControl(tester, 'navigation-markets');
      await tapNavigationControl(tester, 'market-ETHUSDT');
      expect(fixture.container.read(symbolProvider), 'ETHUSDT');
      expect(
        tester
            .widget<SegmentedButton<bool>>(find.byKey(const Key('trade-workspace-tabs')))
            .selected,
        {chart},
      );
      expect(find.byType(QuickOrderPanel), chart ? findsOneWidget : findsNothing);
      fixture.expectNoAccountMutation();
      expect(tester.takeException(), null);
      await fixture.close(tester);
    });
  }

  testWidgets('fresh session resets navigation; quick input survives same-session return', (
    tester,
  ) async {
    final fixture = NavigationFixture(tester);
    await launch(tester, fixture.container);
    final quantity = find.byKey(const Key('quick-order-quantity'));
    await tester.ensureVisible(quantity);
    await tester.enterText(quantity, '0.001');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tapNavigationControl(tester, 'navigation-markets');
    await tapNavigationControl(tester, 'navigation-futures');
    expect(quickQuantity(tester), '0.001');
    await selectWorkspace(tester, chart: false);
    await tapNavigationControl(tester, 'navigation-markets');
    fixture.container.read(symbolProvider.notifier).select('ETHUSDT');
    fixture.expectNoAccountMutation();
    await fixture.close(tester);

    final fresh = NavigationFixture(tester);
    await launch(tester, fresh.container);
    expect(fresh.container.read(symbolProvider), 'BTCUSDT');
    expect(find.byType(QuickOrderPanel), findsOneWidget);
    expect(find.byType(OrderForm), findsNothing);
    expect(quickQuantity(tester), '');
    expect(AppLocalizations.of(tester.element(find.byType(QuickOrderPanel))).localeName, 'en');
    fresh.expectNoAccountMutation();
    expect(tester.takeException(), null);
    await fresh.close(tester);
  });
}
