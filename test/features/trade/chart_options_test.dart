import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/trade/application/chart_preferences.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/chart_canvas.dart';
import 'package:vanta/main.dart';

import '../../support/market_service.dart';
import '../../support/trade_fixture.dart';

ChartPainter painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(of: find.byType(KChartWidget), matching: find.byType(CustomPaint)),
    )
    .map((w) => w.painter)
    .whereType<ChartPainter>()
    .single;

Future<void> visibleTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'all intervals and chart styles are selectable; relative axes keep quotes and tooltips raw',
    (tester) async {
      final container = setup(tester);
      await launch(tester, container);
      await visibleTap(tester, find.byKey(const Key('chart-more-timeframes')));
      await visibleTap(tester, find.byKey(const Key('timeframe-option-1M')));
      expect(container.read(intervalProvider), '1M');
      expect(container.read(currentMarketProvider)!.interval, '1M');
      await visibleTap(tester, find.byKey(const Key('chart-type')));
      await visibleTap(tester, find.byKey(const Key('chart-type-bars')));
      expect(tester.widget<KChartWidget>(find.byType(KChartWidget)).chartType, KChartType.bars);
      final price = container.read(currentMarketProvider)!.price;
      for (final type in KChartType.values) {
        container.read(chartPreferencesProvider.notifier).setChartType(type);
        await tester.pumpAndSettle();
        expect(painter(tester).chartType, type);
        expect(container.read(currentMarketProvider)!.price, price);
        expect(tester.takeException(), null);
      }
      for (final mode in KPriceScale.values) {
        await visibleTap(tester, find.byKey(const Key('chart-price-scale')));
        await visibleTap(
          tester,
          find.widgetWithText(CheckedPopupMenuItem<KPriceScale>, switch (mode) {
            KPriceScale.regular => '普通',
            KPriceScale.logarithmic => '对数',
            KPriceScale.percentage => '百分比',
            KPriceScale.indexed => '基准100',
          }),
        );
        expect(painter(tester).priceScale, mode);
        expect(painter(tester).currentPrice, price.toDouble());
        expect(container.read(currentMarketProvider)!.price, price);
        expect(tester.takeException(), null);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'parameter editor validates without losing input, resets, and applies calculation settings',
    (tester) async {
      final container = setup(tester);
      await launch(tester, container);
      container.read(chartPreferencesProvider.notifier).setMain('MA');
      await tester.pumpAndSettle();
      await visibleTap(tester, find.byKey(const Key('chart-indicators')));
      await visibleTap(tester, find.byKey(const Key('chart-parameters')));
      final first = find.byKey(const Key('parameter-MA-0'));
      await tester.enterText(first, '0');
      await visibleTap(tester, find.byKey(const Key('apply-chart-parameters')));
      expect(find.text('请输入范围内的有效数值'), findsOneWidget);
      expect(container.read(chartPreferencesProvider).parameters['MA'][0], 5);
      await visibleTap(tester, find.byKey(const Key('reset-chart-parameters')));
      expect(tester.widget<TextFormField>(first).controller!.text, '5');
      await tester.enterText(first, '3');
      await visibleTap(tester, find.byKey(const Key('apply-chart-parameters')));
      expect(container.read(chartPreferencesProvider).parameters['MA'], [3, 10, 30, 60]);
      expect(
        tester.widget<KChartWidget>(find.byType(KChartWidget)).mainIndicators.single.calcParams,
        [3, 10, 30, 60],
      );
      await visibleTap(tester, find.byKey(const Key('chart-indicators')));
      await visibleTap(tester, find.byKey(const Key('chart-parameters')));
      await visibleTap(tester, find.byKey(const Key('parameter-indicator')));
      await visibleTap(tester, find.text('MACD').last);
      await tester.enterText(find.byKey(const Key('parameter-MACD-0')), '30');
      await visibleTap(tester, find.byKey(const Key('apply-chart-parameters')));
      expect(find.text('快线周期必须小于慢线周期'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byKey(const Key('parameter-MACD-0'))).controller!.text,
        '30',
      );
      await tester.enterText(find.byKey(const Key('parameter-MACD-0')), '8');
      await visibleTap(tester, find.byKey(const Key('apply-chart-parameters')));
      expect(container.read(chartPreferencesProvider).parameters['MACD'], [8, 26, 9]);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'dragging to earlier history loads one page and preserves the visible candle position',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = TestMarketService();
      final container = ProviderContainer(
        overrides: [
          asterServiceProvider.overrideWith((ref) => service),
          instrumentsProvider.overrideWith((ref) async => testInstruments),
          bookProvider.overrideWith((ref) => Stream.value(book)),
        ],
      );
      var disposed = false;
      addTearDown(() async {
        if (!disposed) container.dispose();
        await service.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const VantaApp()),
      );
      for (var i = 0; i < 30 && container.read(currentMarketProvider) == null; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump();
      final oldState = tester.state(find.byType(ChartCanvas));
      service.gate = Completer<void>();
      final origin = tester.getTopLeft(find.byType(KChartWidget));
      final gesture = await tester.startGesture(origin + const Offset(60, 100));
      for (var i = 1; i <= 50; i++) {
        await gesture.moveTo(origin + Offset(60 + 50.0 * i, 100));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(service.requests, hasLength(2));
      expect(container.read(currentMarketProvider)!.historyLoading, true);
      final before = painter(tester);
      final time = before.datas![before.mStartIndex].time;
      final x = before.translateXtoX(before.getX(before.mStartIndex));
      service.gate!.complete();
      for (var i = 0; i < 30 && container.read(currentMarketProvider)!.historyLoading; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump();
      final after = painter(tester);
      final index = after.datas!.indexWhere((c) => c.time == time);
      expect(after.datas, hasLength(400));
      expect(after.translateXtoX(after.getX(index)), closeTo(x, .01));
      expect(tester.state(find.byType(ChartCanvas)), same(oldState));
      expect(find.byKey(const Key('chart-loading')), findsNothing);
      expect(service.activeStreams, 1);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      disposed = true;
      await tester.pump();
    },
  );
}
