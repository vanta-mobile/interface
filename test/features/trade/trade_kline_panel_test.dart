import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import 'package:vanta/features/trade/application/chart_preferences.dart';
import 'package:vanta/features/trade/application/navigation_provider.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/trade_fixture.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

KChartWidget panelChart(WidgetTester tester) => tester.widget<KChartWidget>(
  find.descendant(of: find.byKey(const Key('trade-kline')), matching: find.byType(KChartWidget)),
);

void main() {
  testWidgets('quick-order K-line follows the 12.01 layout and its shortcuts', (tester) async {
    final container = setup(tester);
    await launch(tester, container);
    container.read(tradeKlineVisibleProvider.notifier).toggle();
    await tester.pumpAndSettle();
    final panel = find.byKey(const Key('trade-kline'));
    expect(panel, findsOneWidget);
    // MA is the default overlay; the volume pane follows the shared VOL shortcut.
    expect(panelChart(tester).mainIndicators.map((i) => i.shortName), ['MA']);
    final withVolume = tester.getSize(panel).height;
    await tapVisible(tester, find.byKey(const Key('chart-quick-VOL')));
    expect(panelChart(tester).volHidden, true);
    expect(tester.getSize(panel).height, withVolume - 62);
    // 36 timeframes + 24 OHLC + 176 canvas + 32 indicators + 36 toolbar + borders.
    expect(tester.getSize(panel).height, 306);
    await tapVisible(tester, find.byKey(const Key('chart-quick-MACD')));
    expect(panelChart(tester).secondaryIndicators.map((i) => i.shortName), ['MACD']);
    await tapVisible(tester, find.byKey(const Key('timeframe-5m')));
    expect(container.read(intervalProvider), '5m');
    expect(find.byKey(const Key('chart-ohlc')), findsOneWidget);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('chart settings sheets apply timeframe, chart type and price scale', (tester) async {
    final container = setup(tester);
    await launch(tester, container);
    container.read(tradeKlineVisibleProvider.notifier).toggle();
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const Key('chart-more-timeframes')));
    expect(find.byKey(const Key('chart-timeframe-sheet')), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('trade-option-30m')));
    expect(container.read(intervalProvider), '30m');
    expect(find.text('30m ▾'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('chart-type')));
    await tapVisible(tester, find.byKey(ValueKey('trade-option-${KChartType.area}')));
    expect(container.read(chartPreferencesProvider).chartType, KChartType.area);
    expect(panelChart(tester).chartType, KChartType.area);

    await tapVisible(tester, find.byKey(const Key('chart-price-scale')));
    expect(find.text('基准为可见区域首根开盘价'), findsNWidgets(2));
    await tapVisible(tester, find.byKey(ValueKey('trade-option-${KPriceScale.logarithmic}')));
    expect(panelChart(tester).priceScale, KPriceScale.logarithmic);
    expect(find.text('价格坐标: 对数'), findsOneWidget);
    expect(container.read(currentMarketProvider), isNotNull);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('indicator choices stay a draft until Confirm; parameters validate', (tester) async {
    final container = setup(tester);
    await launch(tester, container);
    container.read(tradeKlineVisibleProvider.notifier).toggle();
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const Key('chart-indicators')));
    expect(find.byKey(const Key('chart-indicator-sheet')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('indicator-主图指标-BOLL')));
    await tapVisible(tester, find.byKey(const Key('indicator-副图指标-KDJ')));
    await tapVisible(tester, find.byKey(const Key('chart-volume-switch')));
    // Nothing applies before Confirm.
    expect(container.read(chartPreferencesProvider).main, 'MA');
    await tapVisible(tester, find.byKey(const Key('chart-indicator-confirm')));
    final preferences = container.read(chartPreferencesProvider);
    expect((preferences.main, preferences.secondary, preferences.volume), ('BOLL', 'KDJ', false));

    // Closing discards the draft.
    await tapVisible(tester, find.byKey(const Key('chart-indicators')));
    await tapVisible(tester, find.byKey(const Key('indicator-主图指标-MA')));
    await tapVisible(
      tester,
      find.descendant(
        of: find.byKey(const Key('chart-indicator-sheet')),
        matching: find.byType(IconButton),
      ),
    );
    expect(container.read(chartPreferencesProvider).main, 'BOLL');

    await tapVisible(tester, find.byKey(const Key('chart-indicators')));
    await tapVisible(tester, find.byKey(const Key('chart-parameters')));
    expect(find.byKey(const Key('chart-parameter-sheet')), findsOneWidget);
    // The editor opens on the active overlay and can switch indicators.
    expect(find.byKey(const ValueKey('parameter-BOLL-0')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('parameter-indicator')));
    await tapVisible(tester, find.byKey(const ValueKey('parameter-indicator-MACD')));
    await tester.enterText(find.byKey(const ValueKey('parameter-MACD-0')), '30');
    await tapVisible(tester, find.byKey(const Key('apply-chart-parameters')));
    expect(find.byKey(const Key('chart-parameter-sheet')), findsOneWidget);
    expect(container.read(chartPreferencesProvider).parameters['MACD'], [12, 26, 9]);
    await tester.enterText(find.byKey(const ValueKey('parameter-MACD-0')), '201');
    await tapVisible(tester, find.byKey(const Key('apply-chart-parameters')));
    expect(find.text('请输入范围内的有效数值'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('parameter-MACD-0')), '10');
    await tapVisible(tester, find.byKey(const Key('apply-chart-parameters')));
    expect(find.byKey(const Key('chart-parameter-sheet')), findsNothing);
    expect(container.read(chartPreferencesProvider).parameters['MACD'], [10, 26, 9]);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('K-line tab matches the 551px chart component of 12.08', (tester) async {
    final container = setup(tester);
    container.read(futuresWorkspaceTabProvider.notifier).select(FuturesWorkspaceTab.chart);
    await launch(tester, container);
    // MA + VOL by default: 36 + 28 + (285 + 12 + 104) + 36 + 48 + two borders.
    expect(tester.getSize(find.byKey(const Key('chart-component'))).height, 551);
    final chart = tester.widget<KChartWidget>(find.byType(KChartWidget));
    expect(chart.chartColors.nowPriceTextColor, isNotNull);
    expect(chart.chartColors.volUpColor.a, closeTo(.3, .01));
    for (final key in ['chart-ohlc', 'chart-price-scale', 'chart-type', 'chart-indicators']) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
