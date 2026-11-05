import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/market/application/market_sessions.dart';
import 'package:vanta/features/market/application/market_sync.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/market/domain/candle_series.dart';

import '../../support/market_service.dart';

void main() {
  test('only the selected chart loads immediately without waiting for a WS handshake', () async {
    final service = TestMarketService()..autoConnect = false;
    final sessions = MarketSessions(service, testInstruments);
    addTearDown(() async {
      await sessions.dispose();
      await service.close();
    });
    final sync = sessions.select('5m', 'COIN99USDT');
    final published = Completer<void>();
    final subscription = sync.updates.listen((changed) {
      if (changed.contains('COIN99USDT') &&
          sync.market('COIN99USDT') != null &&
          !published.isCompleted) {
        published.complete();
      }
    });
    addTearDown(subscription.cancel);
    await published.future.timeout(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(service.requests, hasLength(1), reason: 'No other symbols or intervals may preload');
    expect(service.requests.single.key, const SeriesKey('COIN99USDT', '5m'));
    expect(service.requests.single.start, null);
    expect(service.connections.single.key, const SeriesKey('COIN99USDT', '5m'));
    expect(sync.connected, false);
    expect(sync.market('COIN99USDT')!.offline, true);
    expect(sync.market('BTCUSDT'), null);
    expect(sync.overview.loaded, 1);
    expect(sync.overview.total, 1);
  });

  test('an unvisited interval stays cold until it is selected', () async {
    final service = TestMarketService();
    final sessions = MarketSessions(service, testInstruments);
    addTearDown(() async {
      await sessions.dispose();
      await service.close();
    });
    final first = sessions.select('1m', 'BTCUSDT');
    await waitForMarket(() => first.overview.repairing == 0 && first.initialized);
    expect(service.requests, hasLength(1));
    service.gate = Completer<void>();
    final five = sessions.select('5m', 'BTCUSDT');
    expect(five.market('BTCUSDT'), null);
    expect(service.requests, hasLength(2));
    expect(service.requests.last.key, const SeriesKey('BTCUSDT', '5m'));
    service.gate!.complete();
    await waitForMarket(() => five.market('BTCUSDT') != null);
    expect(five.market('BTCUSDT')!.candles.last.close, 111);
  });

  test(
    'visited charts reuse separate symbol and interval caches without repeating initial history',
    () async {
      final service = TestMarketService();
      final sessions = MarketSessions(service, testInstruments);
      addTearDown(() async {
        await sessions.dispose();
        await service.close();
      });
      final first = sessions.select('1m', 'BTCUSDT');
      await waitForMarket(() => first.initialized && first.overview.repairing == 0);
      final original = first.series;
      final five = sessions.select('5m', 'BTCUSDT');
      await waitForMarket(() => five.initialized && five.overview.repairing == 0);
      final other = sessions.select('5m', 'COIN99USDT');
      await waitForMarket(() => other.initialized && other.overview.repairing == 0);
      service.gate = Completer<void>();
      final returned = sessions.select('1m', 'BTCUSDT');
      expect(returned, same(first));
      expect(returned.series, same(original));
      expect(returned.market('BTCUSDT')!.interval, '1m');
      expect(returned.market('BTCUSDT')!.candles.last.close, 110);
      expect(returned.market('BTCUSDT')!.offline, true);
      expect(returned.market('COIN99USDT'), null);
      expect(service.requests.where((r) => r.start == null), hasLength(3));
      expect(service.requests.last.start, isNotNull, reason: 'Only reconcile the cached boundary');
      expect(service.connections.last.key, const SeriesKey('BTCUSDT', '1m'));
      expect(service.activeStreams, 1);
      service.gate!.complete();
    },
  );

  test('rapid switches bound outstanding requests, drop obsolete queues, and keep one chart subscription', () async {
    final service = TestMarketService()..gate = Completer<void>();
    final sessions = MarketSessions(service, testInstruments);
    addTearDown(() async {
      await sessions.dispose();
      await service.close();
    });
    MarketSync? current;
    for (final interval in [...candleIntervals, '1m', '5m', '15m']) {
      current = sessions.select(interval, 'BTCUSDT');
    }
    expect(service.activeStreams, 1);
    expect(service.maximumStreams, 1);
    expect(service.active, 5);
    service.gate!.complete();
    await waitForMarket(() => current!.initialized && current.overview.repairing == 0);
    final market = current!.market('BTCUSDT')!;
    expect(market.interval, '15m');
    expect(market.candles.every((c) => c.time % 900000 == 0), true);
    expect(market.candles.last.close, 112);
    expect(
      service.requests.where((r) => r.key.interval == '1d'),
      isEmpty,
      reason: 'The queued 1d chart was left before its request could start',
    );
    expect(service.requests.every((r) => r.key.symbol == 'BTCUSDT'), true);
    expect(service.maximum, lessThanOrEqualTo(5));
    expect(service.connections.last.key, const SeriesKey('BTCUSDT', '15m'));
  });

  test('late old-chart responses remain isolated after changing symbol and interval', () async {
    final service = TestMarketService()..gate = Completer<void>();
    final sessions = MarketSessions(service, testInstruments);
    addTearDown(() async {
      await sessions.dispose();
      await service.close();
    });
    final first = sessions.select('1m', 'BTCUSDT');
    final five = sessions.select('5m', 'COIN99USDT');
    expect(five.market('COIN99USDT'), null);
    service.gate!.complete();
    await waitForMarket(() => first.initialized && five.initialized);
    expect(first.market('BTCUSDT')!.candles.last.close, 110);
    expect(first.market('BTCUSDT')!.offline, true);
    expect(five.market('BTCUSDT'), null);
    expect(five.market('COIN99USDT')!.candles.last.close, 111);
    expect(five.market('COIN99USDT')!.interval, '5m');
    expect(five.market('COIN99USDT')!.candles.every((c) => c.time % 300000 == 0), true);
    expect(service.requests, hasLength(2));
  });

  test('failed refresh preserves cached candles with an offline/error indication', () async {
    final service = TestMarketService();
    final sessions = MarketSessions(service, testInstruments);
    addTearDown(() async {
      await sessions.dispose();
      await service.close();
    });
    final five = sessions.select('5m', 'BTCUSDT');
    await waitForMarket(() => five.initialized && five.overview.repairing == 0);
    sessions.select('1m', 'BTCUSDT');
    service.failRequests = true;
    sessions.select('5m', 'BTCUSDT');
    await waitForMarket(() => five.failure != null);
    expect(five.market('BTCUSDT')!.candles, hasLength(200));
    expect(five.market('BTCUSDT')!.offline, true);
    expect(five.market('BTCUSDT')!.failure, 'Aster HTTP 503');
  });

  test('Riverpod exposes visited cached charts synchronously while reconnecting', () async {
    final service = TestMarketService();
    final container = ProviderContainer(
      overrides: [
        asterServiceProvider.overrideWith((ref) => service),
        instrumentsProvider.overrideWith((ref) async => testInstruments),
      ],
    );
    final listener = container.listen(currentMarketProvider, (_, _) {});
    addTearDown(() async {
      listener.close();
      container.dispose();
      await service.close();
    });
    await waitForMarket(() => container.read(currentMarketProvider)?.interval == '1m');
    container.read(intervalProvider.notifier).select('5m');
    expect(container.read(currentMarketProvider), null);
    await waitForMarket(() => container.read(currentMarketProvider)?.interval == '5m');
    service.gate = Completer<void>();
    container.read(intervalProvider.notifier).select('1m');
    expect(container.read(currentMarketProvider)!.interval, '1m');
    expect(container.read(currentMarketProvider)!.candles.last.close, 110);
    container.read(intervalProvider.notifier).select('5m');
    expect(container.read(currentMarketProvider)!.interval, '5m');
    expect(container.read(currentMarketProvider)!.candles.last.close, 111);
    expect(service.requests.where((r) => r.start == null), hasLength(2));
    service.gate!.complete();
  });
}
