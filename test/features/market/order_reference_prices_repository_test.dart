import 'package:fake_async/fake_async.dart';
import 'package:vanta/core/market_failure.dart';
import 'package:vanta/core/errors/api_error_details.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/order_reference_prices_repository.dart';
import 'package:vanta/features/market/domain/order_reference_prices.dart';

import '../../support/order_reference_prices.dart';

void main() {
  late TestOrderPriceService service;
  late OrderReferencePricesRepository repository;
  StreamSubscription<OrderReferencePrices>? subscription;
  setUp(() {
    service = TestOrderPriceService();
    repository = OrderReferencePricesRepository(service, 'BTCUSDT', now: () => service.now);
  });
  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    await repository.dispose();
    await service.dispose();
  });
  void listen() => subscription = repository.events.listen((_) {});
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test(
    'silent stream polls before receipt expiry, deduplicates, preserves API cause and stops',
    () {
      fakeAsync((clock) {
        final service = TestOrderPriceService();
        final repository = OrderReferencePricesRepository(
          service,
          'BTCUSDT',
          now: () => service.now,
        );
        final sub = repository.events.listen((_) {});
        service.controllers.single.add({'connected': true});
        clock.flushMicrotasks();
        service.clocks.single.complete({'serverTime': service.now.millisecondsSinceEpoch});
        clock.flushMicrotasks();
        service.books.single.complete(orderBookPayload());
        service.trades.single.complete(orderTradePayload());
        clock.flushMicrotasks();
        expect(repository.state.bookFresh, true);
        service.now = service.now.add(const Duration(seconds: 6));
        clock.elapse(const Duration(seconds: 6));
        expect(service.clocks.length, 2);
        expect(repository.state.bookFresh, true);
        clock.elapse(const Duration(seconds: 6));
        expect(service.clocks.length, 2); // The previous poll is still pending.
        service.clocks.last.complete({'serverTime': service.now.millisecondsSinceEpoch});
        clock.flushMicrotasks();
        service.books.last.completeError(
          const MarketFailure(
            'service unavailable',
            details: ApiErrorDetails(message: 'Book temporarily unavailable', status: 503),
          ),
        );
        service.trades.last.complete(
          orderTradePayload(id: 202, time: service.now.millisecondsSinceEpoch),
        );
        clock.flushMicrotasks();
        expect(repository.state.bookFailure!.details!.message, 'Book temporarily unavailable');
        expect(repository.state.bookFailure!.details!.status, 503);
        expect(repository.state.tradeFresh, true);
        repository.setActive(false);
        clock.flushMicrotasks();
        final requests = service.requests.length;
        service.now = service.now.add(const Duration(minutes: 1));
        clock.elapse(const Duration(minutes: 1));
        expect(service.requests.length, requests);
        sub.cancel();
        repository.dispose();
        service.dispose();
        clock.flushMicrotasks();
        expect(clock.periodicTimerCount, 0);
      });
    },
  );
  test('construction and disposal without a consumer never create public requests', () async {
    expect(service.channels, isEmpty);
    expect(service.requests, isEmpty);
    await repository.dispose();
    await repository.reconnect();
    await repository.setActive(false);
    expect(service.channels, isEmpty);
  });
  test(
    'only selected exact book/trade public channels and three bootstrap endpoints are used',
    () async {
      listen();
      await service.seed();
      expect(service.channels.single, ['btcusdt@bookTicker', 'btcusdt@aggTrade']);
      expect(service.requests.map((request) => request.$1), [
        '/fapi/v3/time',
        '/fapi/v3/ticker/bookTicker',
        '/fapi/v3/trades',
      ]);
      expect(service.requests[0].$2, null);
      expect(service.requests[1].$2, {'symbol': 'BTCUSDT'});
      expect(service.requests[2].$2, {'symbol': 'BTCUSDT', 'limit': '1'});
      expect(repository.state.bookFresh, true);
      expect(repository.state.tradeFresh, true);
      expect(repository.state.book!.bid.toString(), '99.123456789123456789');
      expect(repository.state.trade!.price.toString(), '100.123456789123456789');
      expect(repository.state.connection, OrderPriceConnection.online);
    },
  );
  test('clock round-trip uncertainty counts toward quote expiry', () async {
    listen();
    service.controllers.single.add({'connected': true});
    await flush();
    final serverTime = service.now.millisecondsSinceEpoch;
    service.now = service.now.add(const Duration(seconds: 4));
    service.clocks.single.complete({'serverTime': serverTime});
    await flush();
    // The transaction is six seconds older than the server timestamp. With
    // four seconds of clock-request uncertainty its safe age is ten seconds.
    service.books.single.complete(orderBookPayload(time: serverTime - 6000));
    service.trades.single.complete(orderTradePayload(time: serverTime - 6000));
    await flush();
    expect(repository.state.bookFresh, false);
    expect(repository.state.tradeFresh, false);
    service.controllers.single.add(orderBookEvent(time: serverTime));
    service.controllers.single.add(orderTradeEvent(time: serverTime));
    await flush();
    expect(repository.state.bookFresh, true);
    expect(repository.state.tradeFresh, true);
    service.now = service.now.add(const Duration(seconds: 6));
    expect(repository.state.bookFresh, false);
    expect(repository.state.tradeFresh, false);
  });
  test(
    'related cross symbol requests Last only and never downloads or subscribes a book',
    () async {
      await repository.dispose();
      repository = OrderReferencePricesRepository(
        service,
        'ETHUSDT',
        includeBook: false,
        now: () => service.now,
      );
      listen();
      await service.connect();
      expect(service.channels.single, ['ethusdt@aggTrade']);
      expect(service.books, isEmpty);
      service.trades.single.complete(orderTradePayload());
      await flush();
      expect(repository.state.tradeFresh, true);
      expect(repository.state.book, isNull);
      expect(repository.state.bookFailed, false);
      expect(service.requests.map((r) => r.$1), ['/fapi/v3/time', '/fapi/v3/trades']);
      service.controllers.single.add(orderBookEvent(symbol: 'ETHUSDT'));
      await flush();
      expect(repository.state.book, isNull);
    },
  );
  test('consumers share the socket and last cancellation releases it', () async {
    listen();
    final second = repository.events.listen((_) {});
    await service.seed();
    expect(service.channels.length, 1);
    await second.cancel();
    expect(service.cancelled, 0);
    await subscription!.cancel();
    subscription = null;
    expect(service.cancelled, 1);
    expect(repository.state.bookFresh, false);
    listen();
    expect(service.channels.length, 2);
  });
  test('no event can be accepted before clock bootstrap or while disconnected', () async {
    listen();
    service.controllers.single.add({'connected': true});
    await flush();
    service.controllers.single.add(orderBookEvent());
    service.controllers.single.add(orderTradeEvent());
    await flush();
    expect(repository.state.book, null);
    expect(repository.state.trade, null);
    service.clocks.single.complete({'serverTime': service.now.millisecondsSinceEpoch});
    await flush();
    service.books.single.complete(orderBookPayload());
    service.trades.single.complete(orderTradePayload());
    await flush();
    service.controllers.single.add({'disconnected': true});
    await flush();
    service.controllers.single.add(orderBookEvent(id: 999));
    await flush();
    expect(repository.state.bookFresh, false);
    expect(repository.state.book!.updateId, null);
  });
  for (final channel in ['book', 'trade']) {
    test(
      '$channel snapshot failure preserves the other channel and valid stream recovers',
      () async {
        listen();
        await service.connect();
        if (channel == 'book') {
          service.books.single.completeError(const FormatException());
          service.trades.single.complete(orderTradePayload());
        } else {
          service.books.single.complete(orderBookPayload());
          service.trades.single.complete([]);
        }
        await flush();
        expect(repository.state.bookFresh, channel != 'book');
        expect(repository.state.tradeFresh, channel != 'trade');
        service.controllers.single.add(channel == 'book' ? orderBookEvent() : orderTradeEvent());
        await flush();
        expect(repository.state.bookFresh, true);
        expect(repository.state.tradeFresh, true);
        expect(repository.state.bookFailed, false);
        expect(repository.state.tradeFailed, false);
      },
    );
  }
  test('same millisecond with a higher update/trade id is a genuine new value', () async {
    listen();
    await service.seed();
    service.controllers.single.add(orderBookEvent(id: 100));
    service.controllers.single.add(orderTradeEvent(id: 201));
    await flush();
    service.controllers.single.add(orderBookEvent(id: 101, bid: '100'));
    service.controllers.single.add(orderTradeEvent(id: 202, price: '101'));
    await flush();
    expect(repository.state.book!.bid.toString(), '100');
    expect(repository.state.trade!.price.toString(), '101');
  });
  test(
    'repeated ids, older timestamps and wrong symbols never replace a quote or receipt',
    () async {
      listen();
      await service.seed();
      service.controllers.single.add(orderBookEvent());
      service.controllers.single.add(orderTradeEvent());
      await flush();
      final book = repository.state.book, trade = repository.state.trade;
      service.now = service.now.add(const Duration(seconds: 9));
      for (final event in [
        orderBookEvent(bid: '1'),
        orderTradeEvent(price: '1'),
        orderBookEvent(id: 999, time: orderPriceClock.millisecondsSinceEpoch - 1),
        orderTradeEvent(id: 999, time: orderPriceClock.millisecondsSinceEpoch - 1),
        orderBookEvent(id: 999, symbol: 'ETHUSDT'),
        orderTradeEvent(symbol: 'ETHUSDT'),
      ]) {
        service.controllers.single.add(event);
      }
      await flush();
      expect(repository.state.book, same(book));
      expect(repository.state.trade, same(trade));
      service.now = service.now.add(const Duration(seconds: 1));
      expect(repository.state.bookFresh, false);
      expect(repository.state.tradeFresh, false);
    },
  );
  test('receipt and exchange age expire independently for book and trade', () async {
    listen();
    await service.seed();
    service.now = service.now.add(const Duration(seconds: 9));
    service.controllers.single.add(orderBookEvent(time: service.now.millisecondsSinceEpoch));
    await flush();
    service.now = service.now.add(const Duration(seconds: 1));
    expect(repository.state.bookFresh, true);
    expect(repository.state.tradeFresh, false);
    service.controllers.single.add(orderTradeEvent(time: service.now.millisecondsSinceEpoch));
    await flush();
    expect(repository.state.tradeFresh, true);
  });
  test('a recently received old REST transaction still expires at its exchange deadline', () async {
    listen();
    service.now = service.now.add(const Duration(seconds: 9));
    await service.connect();
    service.books.single.complete(orderBookPayload());
    service.trades.single.complete(orderTradePayload());
    await flush();
    expect(repository.state.bookFresh, true);
    service.now = service.now.add(const Duration(seconds: 1));
    expect(repository.state.bookFresh, false);
    expect(repository.state.tradeFresh, false);
  });
  test('calibrated server time tolerates a skewed local clock, rollback invalidates', () async {
    service.now = DateTime.utc(2030);
    listen();
    service.controllers.single.add({'connected': true});
    await flush();
    service.clocks.single.complete({'serverTime': orderPriceClock.millisecondsSinceEpoch});
    await flush();
    service.books.single.complete(orderBookPayload());
    service.trades.single.complete(orderTradePayload());
    await flush();
    expect(repository.state.bookFresh, true);
    expect(repository.state.tradeFresh, true);
    service.now = service.now.subtract(const Duration(microseconds: 1));
    expect(repository.state.bookFresh, false);
    expect(repository.state.tradeFresh, false);
  });
  test(
    'delayed and implausible future stream transactions do not displace current quotes',
    () async {
      listen();
      await service.seed();
      final book = repository.state.book, trade = repository.state.trade;
      for (final offset in [-10000, 10001]) {
        service.controllers.single.add(
          orderBookEvent(id: 999, time: service.now.millisecondsSinceEpoch + offset),
        );
        service.controllers.single.add(
          orderTradeEvent(id: 999, time: service.now.millisecondsSinceEpoch + offset),
        );
      }
      await flush();
      expect(repository.state.book, same(book));
      expect(repository.state.trade, same(trade));
    },
  );
  test(
    'malformed book invalidates only that channel and recovery needs a valid newer event',
    () async {
      listen();
      await service.seed();
      service.controllers.single.add(orderBookEvent(id: 101)..['B'] = '0');
      await flush();
      expect(repository.state.bookFresh, false);
      expect(repository.state.bookFailed, true);
      expect(repository.state.tradeFresh, true);
      service.controllers.single.add(orderBookEvent(id: 102));
      await flush();
      expect(repository.state.bookFresh, true);
      expect(repository.state.bookFailed, false);
    },
  );
  test('late REST cannot overwrite either stream, including a later REST timestamp', () async {
    listen();
    await service.connect();
    service.controllers.single.add(orderBookEvent(bid: '100'));
    service.controllers.single.add(orderTradeEvent(price: '102'));
    await flush();
    service.books.single.complete(orderBookPayload(time: service.now.millisecondsSinceEpoch + 1));
    service.trades.single.complete(
      orderTradePayload(id: 999, time: service.now.millisecondsSinceEpoch + 1),
    );
    await flush();
    expect(repository.state.book!.bid.toString(), '100');
    expect(repository.state.trade!.price.toString(), '102');
  });
  test('a malformed in-flight stream event cannot be healed by an older REST response', () async {
    listen();
    await service.connect();
    service.controllers.single.add(orderBookEvent()..['B'] = '0');
    service.controllers.single.add(orderTradeEvent()..['q'] = '0');
    await flush();
    service.books.single.complete(orderBookPayload());
    service.trades.single.complete(orderTradePayload());
    await flush();
    expect(repository.state.bookFresh, false);
    expect(repository.state.tradeFresh, false);
    expect(repository.state.bookFailed, true);
    expect(repository.state.tradeFailed, true);
  });
  test(
    'reconnect requires all new snapshots; responses from an older connection are discarded',
    () async {
      listen();
      await service.connect();
      service.controllers.single.add({'disconnected': true});
      await flush();
      expect(repository.state.connection, OrderPriceConnection.offline);
      await service.connect();
      service.books.first.complete(orderBookPayload(bid: '1'));
      service.trades.first.complete(orderTradePayload(price: '1'));
      await flush();
      expect(repository.state.bookFresh, false);
      expect(repository.state.tradeFresh, false);
      service.books.last.complete(orderBookPayload());
      service.trades.last.complete(orderTradePayload());
      await flush();
      expect(repository.state.bookFresh, true);
      expect(repository.state.tradeFresh, true);
      expect(repository.state.book!.bid.toString(), '99.123456789123456789');
      service.controllers.single.add({'connected': true});
      await flush();
      expect(service.clocks.length, 2);
    },
  );
  test('pause cancels transport and late snapshots; resume starts a separate connection', () async {
    listen();
    await service.connect();
    await repository.setActive(false);
    service.books.single.complete(orderBookPayload());
    service.trades.single.complete(orderTradePayload());
    await flush();
    expect(service.cancelled, 1);
    expect(repository.state.connection, OrderPriceConnection.offline);
    expect(repository.state.book, null);
    await repository.setActive(true);
    await service.connect(1);
    service.books.last.complete(orderBookPayload());
    service.trades.last.complete(orderTradePayload());
    await flush();
    expect(repository.state.bookFresh, true);
    expect(service.channels.length, 2);
  });
  test('inactive listen and activation without consumers do not start transport', () async {
    await repository.setActive(false);
    listen();
    expect(service.channels, isEmpty);
    await subscription!.cancel();
    subscription = null;
    await repository.setActive(true);
    expect(service.channels, isEmpty);
    listen();
    expect(service.channels.length, 1);
  });
  test('freshness expiry is published without any further socket event', () async {
    listen();
    await service.seed();
    final expired = repository.events.firstWhere((state) => !state.bookFresh && !state.tradeFresh);
    service.now = service.now.add(const Duration(seconds: 10));
    final state = await expired.timeout(const Duration(seconds: 2));
    expect(state.book, isNotNull);
    expect(state.trade, isNotNull);
    expect(state.connection, OrderPriceConnection.online);
  });
  test('disposal during clock bootstrap never starts late REST or another socket', () async {
    listen();
    service.controllers.single.add({'connected': true});
    await flush();
    await subscription!.cancel();
    subscription = null;
    await repository.dispose();
    service.clocks.single.complete({'serverTime': service.now.millisecondsSinceEpoch});
    await flush();
    expect(service.books, isEmpty);
    expect(service.trades, isEmpty);
    expect(service.cancelled, 1);
    await repository.reconnect();
    expect(service.channels.length, 1);
  });
  for (final failure in ['shape', 'negative', 'slow', 'backward']) {
    test('invalid or unreliable public clock $failure never starts quote snapshots', () async {
      listen();
      service.controllers.single.add({'connected': true});
      await flush();
      if (failure == 'slow') service.now = service.now.add(const Duration(seconds: 10));
      if (failure == 'backward') service.now = service.now.subtract(const Duration(seconds: 1));
      service.clocks.single.complete(
        failure == 'shape'
            ? []
            : {'serverTime': failure == 'negative' ? -1 : orderPriceClock.millisecondsSinceEpoch},
      );
      await flush();
      expect(service.books, isEmpty);
      expect(service.trades, isEmpty);
      expect(repository.state.bookFresh, false);
      expect(repository.state.tradeFresh, false);
      expect(repository.state.bookFailed, true);
      expect(repository.state.tradeFailed, true);
    });
  }
}
