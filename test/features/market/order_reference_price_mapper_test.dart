import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/order_reference_price_mapper.dart';

import '../../support/order_reference_prices.dart';

void main() {
  test('REST and stream retain exact decimal prices and transaction times', () {
    final rest = mapOrderBookQuote(
      orderBookPayload(),
      symbol: 'BTCUSDT',
      receivedAt: orderPriceClock,
    );
    expect(rest.bid.toString(), '99.123456789123456789');
    expect(rest.ask.toString(), '101.123456789123456789');
    expect(rest.updateId, null);
    final raw = orderBookEvent()..['E'] = orderPriceClock.millisecondsSinceEpoch + 5;
    final quote = mapOrderBookQuote(
      raw,
      symbol: 'BTCUSDT',
      receivedAt: orderPriceClock,
      stream: true,
    );
    expect(quote.eventTime, orderPriceClock);
    expect(quote.updateId, 100);
    expect(quote.bid, rest.bid);
  });
  for (final field in ['symbol', 'bidPrice', 'askPrice', 'bidQty', 'askQty', 'time']) {
    test('missing book $field stays unknown', () {
      final raw = orderBookPayload()..remove(field);
      expect(
        () => mapOrderBookQuote(raw, symbol: 'BTCUSDT', receivedAt: orderPriceClock),
        throwsFormatException,
      );
    });
  }
  for (final value in ['0', '-1', 'NaN', '1e2', '', 99.5, null, '1' * 161]) {
    test('invalid book price $value is rejected at boundary', () {
      final raw = orderBookPayload()..['bidPrice'] = value;
      expect(
        () => mapOrderBookQuote(raw, symbol: 'BTCUSDT', receivedAt: orderPriceClock),
        throwsFormatException,
      );
    });
  }
  test('crossed or zero-liquidity book and another symbol are rejected', () {
    for (final raw in [
      orderBookPayload(bid: '102'),
      orderBookPayload()..['bidQty'] = '0',
      orderBookPayload()..['askQty'] = '0',
      orderBookPayload(symbol: 'ETHUSDT'),
      orderBookPayload()..['time'] = 253402300800000,
    ]) {
      expect(
        () => mapOrderBookQuote(raw, symbol: 'BTCUSDT', receivedAt: orderPriceClock),
        throwsFormatException,
      );
    }
    expect(
      mapOrderBookQuote(
        orderBookPayload(bid: '101', ask: '101'),
        symbol: 'BTCUSDT',
        receivedAt: orderPriceClock,
      ).bid.toString(),
      '101',
    );
  });
  for (final field in ['u', 'E', 'T', 'B', 'A']) {
    test('stream book requires $field', () {
      final raw = orderBookEvent()..remove(field);
      expect(
        () => mapOrderBookQuote(raw, symbol: 'BTCUSDT', receivedAt: orderPriceClock, stream: true),
        throwsFormatException,
      );
    });
  }
  test('last trade uses the raw id shared with aggregate last-id and actual trade time', () {
    final rest = mapOrderTradeQuote(
      orderTradePayload(id: 9007199254740993),
      symbol: 'BTCUSDT',
      receivedAt: orderPriceClock,
    );
    final raw = orderTradeEvent(id: 9007199254740993)
      ..['E'] = orderPriceClock.millisecondsSinceEpoch + 5;
    final stream = mapOrderTradeQuote(
      raw,
      symbol: 'BTCUSDT',
      receivedAt: orderPriceClock,
      stream: true,
    );
    expect(rest.tradeId, 9007199254740993);
    expect(stream.tradeId, rest.tradeId);
    expect(stream.eventTime, orderPriceClock);
    expect(stream.price.toString(), '100.123456789123456789');
  });
  for (final value in [
    null,
    <String, Object?>{},
    <Object?>[],
    [orderTradePayload().single, orderTradePayload().single],
  ]) {
    test('REST last trade requires exactly the requested single row $value', () {
      expect(
        () => mapOrderTradeQuote(value, symbol: 'BTCUSDT', receivedAt: orderPriceClock),
        throwsFormatException,
      );
    });
  }
  for (final field in ['id', 'price', 'qty', 'time']) {
    test('missing trade $field is rejected', () {
      final raw = orderTradePayload();
      raw.single.remove(field);
      expect(
        () => mapOrderTradeQuote(raw, symbol: 'BTCUSDT', receivedAt: orderPriceClock),
        throwsFormatException,
      );
    });
  }
  test('aggregate ids, shape, event and quantity are validated independently', () {
    for (final raw in [
      orderTradeEvent()..['f'] = 999,
      orderTradeEvent()..['l'] = -1,
      orderTradeEvent()..['a'] = '100',
      orderTradeEvent()..['q'] = '0',
      orderTradeEvent()..['e'] = 'bookTicker',
      orderTradeEvent(symbol: 'ETHUSDT'),
      orderTradeEvent()..['T'] = 0,
      orderTradeEvent()..['p'] = 100.5,
      orderTradeEvent()..remove('E'),
    ]) {
      expect(
        () => mapOrderTradeQuote(raw, symbol: 'BTCUSDT', receivedAt: orderPriceClock, stream: true),
        throwsFormatException,
      );
    }
  });
}
