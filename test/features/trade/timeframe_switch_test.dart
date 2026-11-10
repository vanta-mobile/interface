import 'package:vanta/features/trade/application/navigation_provider.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/market/domain/candle_series.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/chart_canvas.dart';
import 'package:vanta/main.dart';

import '../../support/market_service.dart';
import '../../support/trade_fixture.dart' show book;

void main() {
  testWidgets(
    'charts load on demand, idle work stays current, and visited charts switch without a loading frame',
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
      Future<void> waitForInterval(String interval) async {
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          if (container.read(currentMarketProvider)?.interval == interval) return;
        }
        fail('Chart did not load $interval');
      }

      await waitForInterval('1m');
      expect(service.requests, hasLength(1));
      expect(service.requests.single.key, const SeriesKey('BTCUSDT', '1m'));
      // Run reconciliation/retry timers: even while idle, no other chart loads.
      await tester.pump(const Duration(seconds: 61));
      await tester.pump(const Duration(milliseconds: 20));
      expect(service.requests.every((r) => r.key == const SeriesKey('BTCUSDT', '1m')), true);
      expect(service.tickerRequests, ['BTCUSDT']);
      expect(service.connections, hasLength(1));
      for (final interval in ['5m', '15m']) {
        final previousInterval = container.read(currentMarketProvider)!.interval;
        await tester.tap(find.byKey(Key('timeframe-$interval')));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const Key('chart-loading')), findsOneWidget);
        expect(
          tester.widget<ChartCanvas>(find.byType(ChartCanvas)).market.interval,
          previousInterval,
        );
        expect(tester.widget<Opacity>(find.byKey(const Key('chart-visual'))).opacity, .35);
        expect(
          container.read(currentMarketProvider),
          null,
          reason: 'The visual preview must not become current pricing or trading data',
        );
        await waitForInterval(interval);
        await tester.pump();
      }
      expect(service.requests.where((r) => r.start == null).map((r) => r.key), [
        const SeriesKey('BTCUSDT', '1m'),
        const SeriesKey('BTCUSDT', '5m'),
        const SeriesKey('BTCUSDT', '15m'),
      ]);
      service.gate = Completer<void>();
      final buttonPosition = tester.getTopLeft(find.byKey(const Key('timeframe-5m')));
      for (final interval in ['5m', '15m', '1m', '5m']) {
        await tester.tap(find.byKey(Key('timeframe-$interval')));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final chart = tester.widget<ChartCanvas>(find.byType(ChartCanvas));
        expect(chart.market.interval, interval);
        expect(chart.market.candles.last.close, 110 + quickCandleIntervals.indexOf(interval));
        expect(
          tester.getTopLeft(find.byKey(const Key('timeframe-5m'))),
          buttonPosition,
          reason: 'Cache reconciliation must not move the timeframe controls',
        );
        expect(find.text('历史行情 · 重连中'), findsOneWidget);
        expect(tester.takeException(), null);
      }
      service.gate!.complete();
      await tester.pump(const Duration(milliseconds: 20));
      container.read(symbolProvider.notifier).select('COIN99USDT');
      await tester.pump();
      await waitForInterval('5m');
      expect(container.read(currentMarketProvider)!.symbol, 'COIN99USDT');
      final requestCount = service.requests.length;
      final tickerCount = service.tickerRequests.length;
      await tester.pump(const Duration(seconds: 61));
      await tester.pump(const Duration(milliseconds: 20));
      expect(service.requests.skip(requestCount).map((r) => r.key), isNotEmpty);
      expect(
        service.requests
            .skip(requestCount)
            .every((r) => r.key == const SeriesKey('COIN99USDT', '5m')),
        true,
        reason: 'Inactive BTC charts must stop reconciliation and retry timers',
      );
      expect(service.tickerRequests.skip(tickerCount), ['COIN99USDT']);
      expect(service.activeStreams, 1);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      disposed = true;
      await tester.pump();
    },
  );
}
