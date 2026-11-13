import 'package:vanta/features/trade/application/navigation_provider.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/chart_canvas.dart';
import 'package:vanta/main.dart';

import '../../support/market_service.dart';
import '../../support/startup_intro.dart';
import '../../support/trade_fixture.dart' show book;

void main() {
  testWidgets('initial and fullscreen loading respect reduced motion and enlarged landscape text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final service = TestMarketService()..gate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        initialLocaleProvider.overrideWithValue(const Locale('en')),
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
    container.read(futuresWorkspaceTabProvider.notifier).select(FuturesWorkspaceTab.chart);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VantaApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('empty-chart-grid')), findsOneWidget);
    expect(find.byKey(const Key('chart-loading')), findsOneWidget);
    expect(find.byType(ChartCanvas), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.binding.hasScheduledFrame, false);
    await tester.tap(find.byKey(const Key('chart-expand')));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(844, 430);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('empty-chart-grid')), findsOneWidget);
    expect(tester.takeException(), null);
    service.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ChartCanvas), findsOneWidget);
    service.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('timeframe-5m')));
    await tester.pumpAndSettle();
    expect(find.text('1m → 5m'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<Opacity>(find.byKey(const Key('chart-visual'))).opacity, .35);
    expect(tester.binding.hasScheduledFrame, false);
    expect(tester.takeException(), null);
    service.gate!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<ChartCanvas>(find.byType(ChartCanvas)).market.interval, '5m');
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    disposed = true;
    await tester.pump();
  });

  testWidgets(
    'slow switches retain a labeled frozen chart, failures retry, and new symbols have no old prices',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = TestMarketService();
      final container = ProviderContainer(
        overrides: [
          initialLocaleProvider.overrideWithValue(const Locale('zh')),
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
      container.read(futuresWorkspaceTabProvider.notifier).select(FuturesWorkspaceTab.chart);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const VantaApp()),
      );
      await pumpPastStartupIntro(tester);
      Future<void> settleData() async {
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          if (container.read(currentMarketProvider) != null) return;
        }
        fail('Chart data did not arrive');
      }

      await settleData();
      final previousState = tester.state(find.byType(ChartCanvas));
      final position = tester.getTopLeft(find.byKey(const Key('timeframe-5m')));
      final canvasSize = tester.getSize(find.byKey(const Key('chart-canvas-area')));
      service.gate = Completer<void>();
      for (final interval in ['5m', '15m', '1h']) {
        await tester.tap(find.byKey(Key('timeframe-$interval')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const Key('chart-loading')), findsOneWidget);
        expect(find.text('1m → $interval'), findsOneWidget);
        expect(tester.widget<ChartCanvas>(find.byType(ChartCanvas)).market.interval, '1m');
        expect(
          tester.state(find.byType(ChartCanvas)),
          same(previousState),
          reason: 'Preserve the old viewport while waiting',
        );
        expect(tester.widget<Opacity>(find.byKey(const Key('chart-visual'))).opacity, .35);
        final ignored = tester.widgetList<IgnorePointer>(
          find.ancestor(of: find.byType(ChartCanvas), matching: find.byType(IgnorePointer)),
        );
        expect(ignored.any((widget) => widget.ignoring), true);
        expect(tester.getTopLeft(find.byKey(const Key('timeframe-5m'))), position);
        expect(tester.getSize(find.byKey(const Key('chart-canvas-area'))), canvasSize);
        expect(container.read(currentMarketProvider), null);
        expect(container.read(asterMarketProvider).isLoading, true);
      }
      service.failRequests = true;
      service.gate!.complete();
      for (var i = 0; i < 20 && container.read(asterMarketProvider).isLoading; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('Aster HTTP 503'), findsOneWidget);
      expect(find.byType(ChartCanvas), findsNothing);
      expect(find.byKey(const Key('chart-loading')), findsNothing);
      expect(container.read(asterMarketProvider).isLoading, false);
      expect(container.read(asterMarketProvider).hasError, true);
      service.failRequests = false;
      service.gate = null;
      await tester.tap(find.byKey(const Key('status-retry')));
      await settleData();
      await tester.pump();
      expect(tester.widget<ChartCanvas>(find.byType(ChartCanvas)).market.interval, '1h');
      expect(tester.widget<Opacity>(find.byKey(const Key('chart-visual'))).opacity, 1);
      expect(find.byKey(const Key('chart-loading')), findsNothing);
      expect(container.read(asterMarketProvider).isLoading, false);
      expect(container.read(asterMarketProvider).requireValue.interval, '1h');
      service.gate = Completer<void>();
      container.read(symbolProvider.notifier).select('COIN99USDT');
      await tester.pump();
      expect(
        find.byType(ChartCanvas),
        findsNothing,
        reason: 'Never preview another symbol under the new symbol',
      );
      expect(find.byKey(const Key('empty-chart-grid')), findsOneWidget);
      expect(find.byKey(const Key('chart-loading')), findsOneWidget);
      expect(container.read(currentMarketProvider), null);
      service.gate!.complete();
      await settleData();
      await tester.pump();
      expect(tester.widget<ChartCanvas>(find.byType(ChartCanvas)).market.symbol, 'COIN99USDT');
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      disposed = true;
      await tester.pump();
    },
  );
}
