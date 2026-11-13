import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import 'package:vanta/features/market/domain/market.dart';
import 'package:vanta/features/trade/application/chart_preferences.dart';

import 'support/trade_fixture.dart';
import 'support/workspace_navigation.dart';

ChartPainter painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(of: find.byType(KChartWidget), matching: find.byType(CustomPaint)),
    )
    .map((widget) => widget.painter)
    .whereType<ChartPainter>()
    .single;

double rightSpace(WidgetTester tester) {
  final chart = painter(tester);
  return chart.mWidth - chart.translateXtoX(chart.getX(chart.datas!.length - 1));
}

/// Moves along the chart's own x axis, including the turned portrait fullscreen.
Future<void> pan(WidgetTester tester, double dx) async {
  final box = tester.renderObject<RenderBox>(find.byType(KChartWidget).last);
  final x = dx < 0 ? box.size.width * .8 : box.size.width * .2;
  final gesture = await tester.startGesture(box.localToGlobal(Offset(x, 90)));
  for (var step = 1; step <= 10; step++) {
    await gesture.moveTo(box.localToGlobal(Offset(x + dx * step / 10, 90)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  for (final spec in [(390.0, false, false), (360.0, false, true), (844.0, true, false)]) {
    testWidgets('future space has a boundary and can return at $spec', (tester) async {
      final container = setup(tester, width: spec.$1);
      container.read(chartPreferencesProvider.notifier).setLine(spec.$3);
      await launch(tester, container);
      await selectWorkspace(tester, chart: true);
      if (spec.$2) {
        // The fullscreen action sits in the chart's bottom action bar (12.08).
        await tester.ensureVisible(find.byKey(const Key('chart-expand')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('chart-expand')));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(844, 430);
        await tester.pumpAndSettle();
      }
      final initial = rightSpace(tester);
      await pan(tester, -160);
      expect(rightSpace(tester), greaterThan(initial + 40));
      expect(painter(tester).scrollX, lessThan(0));
      for (var i = 0; i < 3; i++) {
        await pan(tester, -160);
      }
      var width = painter(tester).mWidth;
      expect(rightSpace(tester), closeTo(width * .6, 1));
      expect(painter(tester).mStopIndex, fixture.candles.length - 1);
      expect(painter(tester).datas!.length, fixture.candles.length);
      if (spec.$2) {
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();
        width = painter(tester).mWidth;
        expect(rightSpace(tester), closeTo(width * .6, 1));
      }
      await pan(tester, 160);
      expect(rightSpace(tester), lessThan(width * .6 - 40));
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('pinch keeps future space stable in screen pixels', (tester) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    await pan(tester, -160);
    final gap = rightSpace(tester);
    final width = painter(tester).mWidth;
    final origin = tester.getTopLeft(find.byType(KChartWidget));
    final first = await tester.startGesture(origin + const Offset(120, 90), pointer: 1);
    final second = await tester.startGesture(origin + const Offset(230, 90), pointer: 2);
    await first.moveBy(const Offset(-45, 0));
    await second.moveBy(const Offset(45, 0));
    await tester.pump();
    expect(painter(tester).scaleX, greaterThan(1.4));
    expect(rightSpace(tester), closeTo(gap, 1));
    expect(rightSpace(tester), lessThanOrEqualTo(width * .6 + 1));
    await first.moveTo(origin + const Offset(150, 90));
    await second.moveTo(origin + const Offset(200, 90));
    await tester.pump();
    expect(painter(tester).scaleX, lessThan(1));
    expect(rightSpace(tester), closeTo(gap, 1));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('a live candle preserves the dragged future space', (tester) async {
    final updates = StreamController<Market>();
    addTearDown(updates.close);
    final container = setup(tester, marketStream: updates.stream);
    updates.add(fixture);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    await pan(tester, -160);
    final gap = rightSpace(tester);
    final last = fixture.candles.last;
    updates.add(
      Market(
        symbol: fixture.symbol,
        price: fixture.price,
        change: fixture.change,
        mark: fixture.mark,
        index: fixture.index,
        high: fixture.high,
        low: fixture.low,
        volume: fixture.volume,
        funding: fixture.funding,
        nextFunding: fixture.nextFunding,
        candles: [
          ...fixture.candles,
          Candle(
            time: last.time + 60000,
            open: last.close,
            high: last.high,
            low: last.low,
            close: last.close,
            volume: 1,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(painter(tester).datas!.length, fixture.candles.length + 1);
    expect(rightSpace(tester), closeTo(gap, 1));
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
