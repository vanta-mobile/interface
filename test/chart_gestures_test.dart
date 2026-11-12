import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import 'support/trade_fixture.dart';
import 'support/workspace_navigation.dart';

void main() {
  testWidgets('mouse dragging still works after a touch pinch', (tester) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    ChartPainter painter() => tester
        .widgetList<CustomPaint>(
          find.descendant(of: find.byType(KChartWidget), matching: find.byType(CustomPaint)),
        )
        .map((w) => w.painter)
        .whereType<ChartPainter>()
        .single;
    final left = tester.getTopLeft(find.byType(KChartWidget)) + const Offset(120, 90);
    final first = await tester.startGesture(left, pointer: 1);
    final second = await tester.startGesture(left + const Offset(90, 0), pointer: 2);
    await first.moveBy(const Offset(-30, 0));
    await second.moveBy(const Offset(30, 0));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    final before = painter().scrollX;
    final mouse = await tester.startGesture(left, pointer: 3, kind: PointerDeviceKind.mouse);
    await mouse.moveBy(const Offset(50, 0));
    await tester.pump();
    await mouse.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(painter().scrollX, greaterThan(before));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  for (final start in ['still', 'drag', 'long press', 'vertical', 'fullscreen']) {
    testWidgets('pinch expands and contracts after $start, without scrolling or fling', (
      tester,
    ) async {
      final container = setup(tester);
      await launch(tester, container);
      await selectWorkspace(tester, chart: true);
      if (start == 'fullscreen') {
        await tester.tap(find.byKey(const Key('chart-expand')));
        await tester.pumpAndSettle();
        // Fullscreen is read with the phone turned; the layout is then unrotated.
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(fullscreenTurns(tester), 0);
      }
      ChartPainter painter() => tester
          .widgetList<CustomPaint>(
            find.descendant(of: find.byType(KChartWidget), matching: find.byType(CustomPaint)),
          )
          .map((w) => w.painter)
          .whereType<ChartPainter>()
          .single;
      final scroll = tester.state<ScrollableState>(
        find.ancestor(of: find.byType(KChartWidget), matching: find.byType(Scrollable)).first,
      );
      var left = tester.getTopLeft(find.byType(KChartWidget)) + const Offset(120, 90);
      final first = await tester.startGesture(left, pointer: 1);
      if (start == 'drag') {
        left += const Offset(35, 0);
        await first.moveTo(left);
        await tester.pump(const Duration(milliseconds: 150));
      } else if (start == 'long press') {
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        expect(find.byKey(const Key('candle-detail')), findsOneWidget);
      } else if (start == 'vertical') {
        left += const Offset(0, -24);
        await first.moveTo(left);
        await tester.pump(const Duration(milliseconds: 150));
      }
      final right = left + const Offset(90, 0);
      final second = await tester.startGesture(right, pointer: 2);
      final pageOffset = scroll.position.pixels;
      final initialScale = painter().scaleX;
      for (var step = 1; step <= 10; step++) {
        await first.moveTo(left - Offset(step * 4.5, 0));
        await second.moveTo(right + Offset(step * 4.5, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final zoomed = painter().scaleX;
      expect(zoomed, greaterThan(initialScale * 1.4));
      expect(find.byKey(const Key('candle-detail')), findsNothing);
      for (var step = 1; step <= 15; step++) {
        await first.moveTo(left + Offset(-45 + step * 4.5, 0));
        await second.moveTo(right + Offset(45 - step * 4.5, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(painter().scaleX, lessThan(zoomed * .7));
      expect(scroll.position.pixels, pageOffset);
      final scaleBeforeLift = painter().scaleX;
      final panBeforeLift = painter().scrollX;
      await second.up();
      await first.moveBy(const Offset(35, 0));
      await first.up();
      await tester.pumpAndSettle();
      expect(painter().scaleX, scaleBeforeLift);
      expect(painter().scrollX, panBeforeLift);
      expect(scroll.position.pixels, pageOffset);

      // A later gesture starts from the saved scale, including after cancel.
      final third = await tester.startGesture(left, pointer: 3);
      final fourth = await tester.startGesture(right, pointer: 4);
      await third.moveBy(const Offset(-40, 0));
      await fourth.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(painter().scaleX, greaterThan(scaleBeforeLift));
      await third.cancel();
      await fourth.cancel();
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('horizontal pan and two-finger zoom belong to the chart', (tester) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    final scroll = tester.state<ScrollableState>(
      find.ancestor(of: find.byType(KChartWidget), matching: find.byType(Scrollable)).first,
    );
    final initialPageOffset = scroll.position.pixels;
    ChartPainter painter() => tester
        .widgetList<CustomPaint>(
          find.descendant(of: find.byType(KChartWidget), matching: find.byType(CustomPaint)),
        )
        .map((w) => w.painter)
        .whereType<ChartPainter>()
        .single;
    final pan = await tester.startGesture(const Offset(150, 450));
    await pan.moveBy(const Offset(70, 0));
    await tester.pump();
    await pan.moveBy(const Offset(30, 0));
    await tester.pump();
    await pan.up();
    await tester.pumpAndSettle();
    expect(painter().scrollX, greaterThan(0));
    final initialScale = painter().scaleX;
    final first = await tester.startGesture(const Offset(120, 480), pointer: 1);
    final second = await tester.startGesture(const Offset(230, 480), pointer: 2);
    for (var step = 1; step <= 10; step++) {
      await first.moveTo(Offset(120 - step * 4, 480));
      await second.moveTo(Offset(230 + step * 4, 480));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(painter().scaleX, greaterThan(initialScale));
    expect(scroll.position.pixels, initialPageOffset);
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('pinch takes over after the first finger has started dragging', (tester) async {
    final container = setup(tester);
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    ChartPainter painter() => tester
        .widgetList<CustomPaint>(
          find.descendant(of: find.byType(KChartWidget), matching: find.byType(CustomPaint)),
        )
        .map((w) => w.painter)
        .whereType<ChartPainter>()
        .single;
    final first = await tester.startGesture(const Offset(120, 480), pointer: 1);
    await first.moveBy(const Offset(35, 0));
    await tester.pump(const Duration(milliseconds: 150));
    final second = await tester.startGesture(const Offset(240, 480), pointer: 2);
    final initialScale = painter().scaleX;
    for (var step = 1; step <= 10; step++) {
      await first.moveTo(Offset(155 - step * 5, 480));
      await second.moveTo(Offset(240 + step * 5, 480));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(painter().scaleX, greaterThan(initialScale * 1.4));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
}
