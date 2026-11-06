import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/market_sessions.dart';
import 'package:vanta/features/market/domain/candle_series.dart';

import '../../support/market_service.dart';

void main() {
  test(
    'browsing adds earlier pages, deduplicates intent, keeps latest quotes, and stops at listing',
    () async {
      final service = TestMarketService();
      final sessions = MarketSessions(service, testInstruments);
      addTearDown(() async {
        await sessions.dispose();
        await service.close();
      });
      final sync = sessions.select('1m', 'BTCUSDT');
      await waitForMarket(() => sync.initialized && sync.overview.repairing == 0);
      final original = sync.market('BTCUSDT')!;
      expect(service.requests, hasLength(1));
      service.gate = Completer<void>();
      final pending = sync.loadOlder();
      await Future<void>.delayed(Duration.zero);
      final duplicate = sync.loadOlder();
      expect(service.requests, hasLength(2));
      expect(service.requests.last.end, original.candles.first.time - 1);
      expect(service.requests.last.start, null);
      expect(sync.market('BTCUSDT')!.historyLoading, true);
      expect(sync.market('BTCUSDT')!.price, original.price);
      service.gate!.complete();
      await pending;
      await duplicate;
      var market = sync.market('BTCUSDT')!;
      expect(market.candles, hasLength(400));
      expect(market.candles.map((c) => c.time).toSet(), hasLength(400));
      expect(market.price, original.price);
      expect(market.candles.last, same(original.candles.last));
      service.gate = null;
      // Preserve browsed candles beyond the old 600-bar rolling capacity.
      await sync.loadOlder();
      await sync.loadOlder();
      market = sync.market('BTCUSDT')!;
      expect(market.candles, hasLength(800));
      service.earliestTime = market.candles.first.time;
      await sync.loadOlder();
      expect(sync.market('BTCUSDT')!.historyExhausted, true);
      final count = service.requests.length;
      await sync.loadOlder();
      expect(service.requests, hasLength(count));
      expect(service.requests.every((r) => r.key == const SeriesKey('BTCUSDT', '1m')), true);
      expect(service.activeStreams, 1);
    },
  );
  test('history failure preserves prices, retries explicitly, and isolates late responses after switching', () async {
    final service = TestMarketService();
    final sessions = MarketSessions(service, testInstruments);
    addTearDown(() async {
      await sessions.dispose();
      await service.close();
    });
    final first = sessions.select('1m', 'BTCUSDT');
    await waitForMarket(() => first.initialized && first.overview.repairing == 0);
    service.failRequests = true;
    await first.loadOlder();
    expect(first.market('BTCUSDT')!.historyFailure, 'Aster HTTP 503');
    expect(first.market('BTCUSDT')!.candles, hasLength(200));
    expect(
      first.failure,
      null,
      reason: 'Browsing errors must not change current market availability',
    );
    service.failRequests = false;
    await first.loadOlder();
    expect(first.market('BTCUSDT')!.historyFailure, null);
    expect(first.market('BTCUSDT')!.candles, hasLength(400));
    service.gate = Completer<void>();
    final oldPage = first.loadOlder();
    await Future<void>.delayed(Duration.zero);
    final next = sessions.select('5m', 'COIN99USDT');
    service.gate!.complete();
    await oldPage;
    await waitForMarket(() => next.initialized && next.overview.repairing == 0);
    expect(first.market('BTCUSDT')!.candles, hasLength(600));
    expect(next.market('COIN99USDT')!.candles, hasLength(200));
    expect(next.market('COIN99USDT')!.interval, '5m');
    final count = service.requests.length;
    await first.loadOlder();
    expect(service.requests, hasLength(count), reason: 'Inactive charts must not load');
  });
  test('weekly and monthly history pages use server open times and calendar gap repair', () async {
    final service = TestMarketService();
    final sessions = MarketSessions(service, testInstruments);
    addTearDown(() async {
      await sessions.dispose();
      await service.close();
    });
    for (final interval in ['1w', '1M']) {
      final sync = sessions.select(interval, 'BTCUSDT');
      await waitForMarket(() => sync.initialized && sync.overview.repairing == 0);
      final first = sync.market('BTCUSDT')!.candles.first.time;
      await sync.loadOlder();
      final candles = sync.market('BTCUSDT')!.candles;
      expect(candles, hasLength(400));
      expect(candles[199].time, shiftCandleOpen(interval, first, -1));
      expect(sync.series.missingRange, null);
      expect(sync.failure, null);
    }
  });
}
