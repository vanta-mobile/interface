import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/features/market/data/order_reference_prices_repository.dart';

import '../../support/order_reference_prices.dart';

void main() {
  void scenario(
    void Function(FakeAsync, TestOrderPriceService, OrderReferencePricesRepository) run,
  ) {
    fakeAsync((clock) {
      final service = TestOrderPriceService();
      final repository = OrderReferencePricesRepository(service, 'SOLUSDT', now: () => service.now);
      final subscription = repository.events.listen((_) {});
      service.controllers.single.add({'connected': true});
      clock.flushMicrotasks();
      service.clocks.single.complete({'serverTime': service.now.millisecondsSinceEpoch});
      clock.flushMicrotasks();
      service.books.single.complete(orderBookPayload(symbol: 'SOLUSDT'));
      service.trades.single.complete(orderTradePayload());
      clock.flushMicrotasks();
      try {
        run(clock, service, repository);
      } finally {
        subscription.cancel();
        repository.dispose();
        service.dispose();
        clock.flushMicrotasks();
        expect(clock.periodicTimerCount, 0);
      }
    });
  }

  void poll(FakeAsync clock, TestOrderPriceService service, {int seconds = 6}) {
    service.now = service.now.add(Duration(seconds: seconds));
    clock.elapse(Duration(seconds: seconds));
    service.clocks.last.complete({'serverTime': service.now.millisecondsSinceEpoch});
    clock.flushMicrotasks();
  }

  test('older REST poll preserves a fresh quote and its original receipt', () {
    scenario((clock, service, repository) {
      service.controllers.single.add(orderBookEvent(symbol: 'SOLUSDT', id: 201));
      service.controllers.single.add(orderTradeEvent(symbol: 'SOLUSDT', id: 201));
      clock.flushMicrotasks();
      final book = repository.state.book, trade = repository.state.trade;
      poll(clock, service);
      service.books.last.complete(
        orderBookPayload(symbol: 'SOLUSDT', time: orderPriceClock.millisecondsSinceEpoch - 1),
      );
      service.trades.last.complete(orderTradePayload(id: 200));
      clock.flushMicrotasks();
      expect(repository.state.bookFresh, true);
      expect(repository.state.tradeFresh, true);
      expect(repository.state.bookFailure, isNull);
      expect(repository.state.tradeFailure, isNull);
      expect(repository.state.book, same(book));
      expect(repository.state.trade, same(trade));
      service.now = service.now.add(const Duration(seconds: 4));
      expect(repository.state.bookFresh, false);
      expect(repository.state.tradeFresh, false);
    });
  });

  test('expired well-formed poll is stale data, never a format failure, and recovers', () {
    scenario((clock, service, repository) {
      poll(clock, service, seconds: 11);
      service.books.last.complete(orderBookPayload(symbol: 'SOLUSDT'));
      service.trades.last.complete(orderTradePayload());
      clock.flushMicrotasks();
      expect(repository.state.bookFresh, false);
      expect(repository.state.tradeFresh, false);
      expect(repository.state.bookFailure!.reasonKey, 'livePriceBookStale');
      expect(repository.state.tradeFailure!.reasonKey, 'livePriceLastStale');
      expect(repository.state.bookFailure!.details, isNull);
      expect(repository.state.tradeFailure!.details, isNull);
      poll(clock, service);
      service.books.last.complete(
        orderBookPayload(symbol: 'SOLUSDT', time: service.now.millisecondsSinceEpoch),
      );
      service.trades.last.complete(
        orderTradePayload(id: 202, time: service.now.millisecondsSinceEpoch),
      );
      clock.flushMicrotasks();
      expect(repository.state.bookFresh, true);
      expect(repository.state.tradeFresh, true);
      expect(repository.state.bookFailure, isNull);
      expect(repository.state.tradeFailure, isNull);
    });
  });

  test('polling the same trade cannot extend its server event deadline', () {
    scenario((clock, service, repository) {
      poll(clock, service);
      service.books.last.complete(orderBookPayload(symbol: 'SOLUSDT'));
      service.trades.last.complete(orderTradePayload());
      clock.flushMicrotasks();
      expect(repository.state.tradeFresh, true);
      service.now = service.now.add(const Duration(seconds: 4));
      expect(repository.state.tradeFresh, false);
      expect(repository.state.bookFresh, false);
    });
  });

  test('an older poll cannot reverify a channel invalidated by malformed stream data', () {
    scenario((clock, service, repository) {
      service.controllers.single.add(orderBookEvent(symbol: 'SOLUSDT', id: 202));
      service.controllers.single.add(orderTradeEvent(symbol: 'SOLUSDT', id: 202));
      clock.flushMicrotasks();
      service.controllers.single.add(orderBookEvent(symbol: 'SOLUSDT', id: 203)..['B'] = '0');
      service.controllers.single.add(orderTradeEvent(symbol: 'SOLUSDT', id: 203)..['q'] = '0');
      clock.flushMicrotasks();
      poll(clock, service);
      service.books.last.complete(
        orderBookPayload(symbol: 'SOLUSDT', time: orderPriceClock.millisecondsSinceEpoch - 1),
      );
      service.trades.last.complete(orderTradePayload());
      clock.flushMicrotasks();
      expect(repository.state.bookFresh, false);
      expect(repository.state.tradeFresh, false);
      expect(repository.state.bookFailure!.reasonKey, 'livePriceBookStale');
      expect(repository.state.tradeFailure!.reasonKey, 'livePriceLastStale');
    });
  });

  test('future quote timestamps report a time mismatch after the prior quote expires', () {
    scenario((clock, service, repository) {
      poll(clock, service, seconds: 11);
      final future = service.now.add(const Duration(seconds: 11)).millisecondsSinceEpoch;
      service.books.last.complete(orderBookPayload(symbol: 'SOLUSDT', time: future));
      service.trades.last.complete(orderTradePayload(id: 999, time: future));
      clock.flushMicrotasks();
      expect(repository.state.bookFresh, false);
      expect(repository.state.tradeFresh, false);
      expect(repository.state.bookFailure!.reasonKey, 'livePriceTimestampInvalid');
      expect(repository.state.tradeFailure!.reasonKey, 'livePriceTimestampInvalid');
      expect(repository.state.tradeFailure!.details, isNull);
    });
  });

  test('a malformed clock response retains its actual format cause and endpoint', () {
    scenario((clock, service, repository) {
      service.now = service.now.add(const Duration(seconds: 6));
      clock.elapse(const Duration(seconds: 6));
      service.clocks.last.complete({'serverTime': 'not-a-timestamp'});
      clock.flushMicrotasks();
      expect(repository.state.tradeFailure!.details!.cause, ApiErrorCause.invalidResponse);
      expect(repository.state.tradeFailure!.details!.endpoint, '/fapi/v3/time');
    });
  });

  test('a malformed poll still fails only its channel with its endpoint', () {
    scenario((clock, service, repository) {
      poll(clock, service);
      service.books.last.complete(orderBookPayload(symbol: 'SOLUSDT')..['bidQty'] = '0');
      service.trades.last.complete(
        orderTradePayload(id: 202, time: service.now.millisecondsSinceEpoch),
      );
      clock.flushMicrotasks();
      expect(repository.state.bookFresh, false);
      expect(repository.state.bookFailure!.details!.cause, ApiErrorCause.invalidResponse);
      expect(repository.state.bookFailure!.details!.endpoint, '/fapi/v3/ticker/bookTicker');
      expect(repository.state.tradeFresh, true);
      poll(clock, service);
      service.books.last.complete(
        orderBookPayload(symbol: 'SOLUSDT', time: service.now.millisecondsSinceEpoch),
      );
      service.trades.last.complete(orderTradePayload()..single['qty'] = '0');
      clock.flushMicrotasks();
      expect(repository.state.bookFresh, true);
      expect(repository.state.tradeFresh, false);
      expect(repository.state.tradeFailure!.details!.endpoint, '/fapi/v3/trades');
    });
  });

  for (final delay in [const Duration(seconds: 10), const Duration(seconds: -1)]) {
    test('unreliable clock duration $delay is not malformed data', () {
      scenario((clock, service, repository) {
        service.now = service.now.add(const Duration(seconds: 6));
        clock.elapse(const Duration(seconds: 6));
        final requestCount = service.requests.length;
        service.now = service.now.add(delay);
        service.clocks.last.complete({'serverTime': service.now.millisecondsSinceEpoch});
        clock.flushMicrotasks();
        expect(service.requests.length, requestCount);
        expect(repository.state.tradeFailure!.reasonKey, 'livePriceClockUnavailable');
        expect(
          repository.state.tradeFailure!.details?.cause,
          delay.isNegative ? isNull : ApiErrorCause.timeout,
        );
      });
    });
  }
}
