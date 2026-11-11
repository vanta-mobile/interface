import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import 'package:vanta/features/trade/application/chart_preferences.dart';
import 'package:vanta/features/trade/application/providers.dart';

import 'support/trade_fixture.dart';
import 'support/workspace_navigation.dart';

void main() {
  for (final spec in [(360.0, 1.0), (390.0, 1.5), (768.0, 1.0), (1440.0, 1.0)]) {
    testWidgets('responsive layout ${spec.$1} at text scale ${spec.$2}', (tester) async {
      final container = setup(tester, width: spec.$1, scale: spec.$2);
      await launch(tester, container);
      await selectWorkspace(tester, chart: true);
      await selectWorkspace(tester, chart: false);
      expect(tester.takeException(), null);
      expect(find.byType(KChartWidget), findsNothing);
      await selectWorkspace(tester, chart: true);
      final chart = tester.widget<KChartWidget>(find.byType(KChartWidget));
      expect(chart.secondaryIndicators, isEmpty);
      expect(tester.getSize(find.byKey(const Key('chart-canvas-area'))).height, lessThan(400));
      expect(chart.volHidden, false);
      await selectWorkspace(tester, chart: false);
      await tester.ensureVisible(find.byKey(const Key('trade-pending-quantity')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await selectWorkspace(tester, chart: true);
      await tester.ensureVisible(find.text('深度图'));
      await tester.tap(find.text('深度图'));
      await tester.pumpAndSettle();
      expect(find.byType(KChartWidget), findsNothing);
      await tester.ensureVisible(find.byType(DepthChart));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('one-finger vertical gesture over native chart scrolls the page', (tester) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    final scroll = tester.state<ScrollableState>(
      find.ancestor(of: find.byType(KChartWidget), matching: find.byType(Scrollable)).first,
    );
    final initialOffset = scroll.position.pixels;
    final gesture = await tester.startGesture(const Offset(170, 530));
    await gesture.moveBy(const Offset(0, -220));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, greaterThan(initialOffset + 150));
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('line mode and Trade show real account entry without demo controls', (tester) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    await tester.tap(find.byKey(const Key('chart-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<KChartType>, '折线图'));
    await tester.pumpAndSettle();
    expect(tester.widget<KChartWidget>(find.byType(KChartWidget)).isLine, true);
    await selectWorkspace(tester, chart: false);
    expect(find.byKey(const Key('submit-order')), findsNothing);
    expect(find.byKey(const Key('enter-demo')), findsNothing);
    expect(find.byKey(const Key('trade-live-order')), findsOneWidget);
    expect(container.read(accountProvider).connected, false);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('100 market dropdown filters and selects instrument without changing data identity', (
    tester,
  ) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    await tester.tap(find.byKey(const Key('trade-market-selector')));
    await tester.pumpAndSettle();
    expect(find.text('100 / 100 个永续合约'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'ETH');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-ETHUSDT')));
    await tester.pumpAndSettle();
    expect(container.read(symbolProvider), 'ETHUSDT');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('market list shows public metrics and filters session favorites', (tester) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    await tester.tap(find.byKey(const Key('trade-market-selector')));
    await tester.pumpAndSettle();

    expect(find.textContaining('价格'), findsWidgets);
    expect(find.textContaining('24h 成交额'), findsWidgets);
    expect(find.textContaining('资金费率'), findsWidgets);
    await tester.tap(find.byKey(const Key('favorite-BTCUSDT')));
    await tester.pumpAndSettle();
    expect(container.read(favoriteSymbolsProvider), contains('BTCUSDT'));

    await tester.tap(
      find.descendant(of: find.byKey(const Key('market-list-filter')), matching: find.text('自选')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market-BTCUSDT')), findsOneWidget);
    expect(find.byKey(const Key('market-ETHUSDT')), findsNothing);

    await tester.tap(find.byKey(const Key('favorite-BTCUSDT')));
    await tester.pumpAndSettle();
    expect(container.read(favoriteSymbolsProvider), isEmpty);
    expect(find.text('还没有自选合约'), findsOneWidget);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('lower indicators replace each other and overlays stay in the same price pane', (
    tester,
  ) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    KChartWidget chart() => tester.widget<KChartWidget>(find.byType(KChartWidget));
    expect(chart().secondaryIndicators, isEmpty);
    await tester.ensureVisible(find.byKey(const Key('chart-quick-MACD')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-quick-MACD')));
    await tester.pumpAndSettle();
    expect(chart().secondaryIndicators.map((i) => i.shortName), ['MACD']);
    await tester.ensureVisible(find.byKey(const Key('chart-quick-RSI')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('chart-quick-RSI')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-quick-RSI')));
    await tester.pumpAndSettle();
    expect(chart().secondaryIndicators.map((i) => i.shortName), ['RSI']);
    await tester.ensureVisible(find.byKey(const Key('chart-quick-MA')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-quick-MA')));
    await tester.pumpAndSettle();
    expect(chart().mainIndicators.map((i) => i.shortName), ['MA']);
    expect(find.byType(KChartWidget), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('chart-quick-RSI')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-quick-RSI')));
    await tester.pumpAndSettle();
    expect(chart().secondaryIndicators, isEmpty);
    await tester.ensureVisible(find.byKey(const Key('chart-quick-VOL')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-quick-VOL')));
    await tester.pumpAndSettle();
    expect(chart().volHidden, true);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('indicator sheet exposes all five indicators and updates fullscreen preferences', (
    tester,
  ) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    await tester.tap(find.byKey(const Key('chart-indicators')));
    await tester.pumpAndSettle();
    for (final value in ['MACD', 'KDJ', 'RSI', 'WR', 'CCI']) {
      await tester.tap(find.widgetWithText(ChoiceChip, value));
      await tester.pumpAndSettle();
      expect(container.read(chartPreferencesProvider).secondary, value);
    }
    await tester.tap(find.widgetWithText(ChoiceChip, 'BOLL'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-volume-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    final chart = tester.widget<KChartWidget>(find.byType(KChartWidget));
    expect(chart.secondaryIndicators.map((i) => i.shortName), ['CCI']);
    expect(chart.mainIndicators.map((i) => i.shortName), ['BOLL']);
    expect(chart.volHidden, true);
    await tester.tap(find.byKey(const Key('chart-expand')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trade-settings')), findsNothing);
    expect(
      tester.widget<KChartWidget>(find.byType(KChartWidget)).secondaryIndicators.single.shortName,
      'CCI',
    );
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.tap(find.byKey(const Key('chart-expand')));
    await tester.pumpAndSettle();
    expect(container.read(chartPreferencesProvider).main, 'BOLL');
    expect(find.byKey(const Key('trade-settings')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('long press shows a bounded crosshair tooltip without scrolling the page', (
    tester,
  ) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    final scroll = tester.state<ScrollableState>(
      find.ancestor(of: find.byType(KChartWidget), matching: find.byType(Scrollable)).first,
    );
    final initialOffset = scroll.position.pixels;
    final gesture = await tester.startGesture(const Offset(170, 480));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.byKey(const Key('candle-detail')), findsOneWidget);
    await gesture.moveBy(const Offset(10, 25), timeStamp: const Duration(milliseconds: 650));
    await tester.pump();
    expect(scroll.position.pixels, initialOffset);
    expect(tester.takeException(), null);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('candle-detail')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('depth and price reuse one workspace and preserve selected indicator', (
    tester,
  ) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    await tester.tap(find.byKey(const Key('chart-quick-MACD')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深度图'));
    await tester.pumpAndSettle();
    expect(find.byType(DepthChart), findsOneWidget);
    expect(find.byType(KChartWidget), findsNothing);
    await tester.tap(find.text('图表'));
    await tester.pumpAndSettle();
    expect(find.byType(DepthChart), findsNothing);
    expect(
      tester.widget<KChartWidget>(find.byType(KChartWidget)).secondaryIndicators.single.shortName,
      'MACD',
    );
    expect(find.text('Aster · USDT'), findsOneWidget);
    expect(find.text('形成中'), findsNothing);
    expect(find.text('已收盘'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('chart-market-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-market-status')));
    await tester.pumpAndSettle();
    expect(find.text('行情详情'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('形成中'), findsOneWidget);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
