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
      expect(find.text('深度图'), findsNothing);
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
    container.read(chartPreferencesProvider.notifier).setChartType(KChartType.line);
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
  testWidgets('indicator shortcuts carry into fullscreen; header tabs and actions are gone', (
    tester,
  ) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    for (final key in ['chart-type', 'chart-indicators']) {
      expect(find.byKey(Key(key)), findsNothing);
    }
    for (final value in ['CCI', 'BOLL', 'VOL']) {
      await tester.ensureVisible(find.byKey(Key('chart-quick-$value')));
      await tester.tap(find.byKey(Key('chart-quick-$value')));
      await tester.pumpAndSettle();
    }
    var chart = tester.widget<KChartWidget>(find.byType(KChartWidget));
    expect(chart.secondaryIndicators.map((i) => i.shortName), ['CCI']);
    expect(chart.mainIndicators.map((i) => i.shortName), ['BOLL']);
    expect(chart.volHidden, true);
    await tester.ensureVisible(find.byKey(const Key('chart-expand')));
    await tester.pumpAndSettle();
    final orientations = recordOrientationRequests(tester);
    await tester.tap(find.byKey(const Key('chart-expand')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chart-fullscreen')), findsOneWidget);
    // The phone is asked to turn landscape; the layout itself is not turned.
    expect(orientations, [landscapeOnly]);
    expect(fullscreenTurns(tester), 0);
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    final canvas = tester.getSize(find.byKey(const Key('chart-canvas-area')).last);
    expect(canvas.width, greaterThan(canvas.height));
    expect(find.byKey(const Key('trade-settings')), findsNothing);
    chart = tester.widget<KChartWidget>(find.byType(KChartWidget).last);
    expect(chart.secondaryIndicators.single.shortName, 'CCI');
    expect(tester.takeException(), null);
    await tester.tap(find.byKey(const Key('chart-expand')).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chart-fullscreen')), findsNothing);
    // Leaving restores the app's normal rotation instead of keeping a lock.
    expect(orientations, [landscapeOnly, <String>[]]);
    expect(container.read(chartPreferencesProvider).main, 'BOLL');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('phone landscape enters fullscreen; exit stays until portrait, which re-arms it', (
    tester,
  ) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chart-fullscreen')), findsOneWidget);
    expect(fullscreenTurns(tester), 0);
    expect(find.byKey(const Key('trade-settings')), findsNothing);
    await tester.tap(find.byKey(const Key('chart-expand')).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chart-fullscreen')), findsNothing);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chart-fullscreen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chart-expand')).last);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chart-fullscreen')), findsNothing);
    await selectWorkspace(tester, chart: false);
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chart-fullscreen')), findsNothing);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('tablet split view that keeps portrait turns the landscape layout instead', (
    tester,
  ) async {
    final container = setup(tester, width: 768);
    tester.view.physicalSize = const Size(768, 1024);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    await tester.ensureVisible(find.byKey(const Key('chart-expand')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-expand')));
    await tester.pumpAndSettle();
    expect(fullscreenTurns(tester), 1);
    final canvas = tester.getSize(find.byKey(const Key('chart-canvas-area')).last);
    expect(canvas.width, greaterThan(canvas.height));
    expect(tester.takeException(), null);
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
  testWidgets('chart keeps the selected indicator and opens market details', (tester) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    await tester.tap(find.byKey(const Key('chart-quick-MACD')));
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
