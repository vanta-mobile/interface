import 'package:decimal/decimal.dart';

import 'market_precision.dart';
export 'market_precision.dart';

class Candle {
  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.closed = false,
    this.eventTime = 0,
  });
  final int time;
  final double open, high, low, close, volume;
  final bool closed;
  final int eventTime;
}

class Market {
  const Market({
    required this.symbol,
    required this.price,
    required this.change,
    required this.mark,
    required this.index,
    required this.high,
    required this.low,
    required this.volume,
    required this.funding,
    required this.nextFunding,
    required this.candles,
    this.interval = '1m',
    this.offline = false,
    this.failure,
    this.historyLoading = false,
    this.historyExhausted = false,
    this.historyFailure,
    this.precision = const MarketPrecision(),
  });
  final String symbol, interval;
  final Decimal price;
  final double change, mark, index, high, low, volume, funding;
  final int nextFunding;
  final List<Candle> candles;
  final bool offline;
  final String? failure;
  final bool historyLoading, historyExhausted;
  final String? historyFailure;
  final MarketPrecision precision;
  String get base => symbol.replaceAll('USDT', '');
}

class BookLevel {
  const BookLevel(this.price, this.quantity);
  final double price, quantity;
}

class MarketTrade {
  const MarketTrade({
    required this.price,
    required this.quantity,
    required this.buy,
    required this.time,
  });
  final double price, quantity;
  final bool buy;
  final int time;
}

class OrderBook {
  const OrderBook({
    required this.asks,
    required this.bids,
    this.trades = const [],
    this.connected = true,
    this.offline = false,
  });
  final List<BookLevel> asks, bids;
  final List<MarketTrade> trades;
  final bool connected, offline;
}

String number(num value, [int decimals = 1]) {
  final parts = value.toStringAsFixed(decimals).split('.');
  parts[0] = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return parts.join('.');
}

String compact(num value) => value >= 1000000
    ? '${number(value / 1000000, 2)}M'
    : value >= 1000
    ? '${number(value / 1000, 2)}K'
    : number(value, 2);
