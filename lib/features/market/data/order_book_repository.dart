import '../../../core/market_failure.dart';
import '../domain/market.dart';
import 'aster_service.dart';
import 'order_book_mapper.dart';

class OrderBookRepository {
  const OrderBookRepository(this.service);
  final AsterService service;

  Stream<OrderBook> watch(String symbol) async* {
    List<BookLevel> bids = const [], asks = const [];
    final trades = <MarketTrade>[];
    var lastEmission = 0;
    var depthConnected = false;
    OrderBook snapshot() => OrderBook(
      asks: asks,
      bids: bids,
      trades: List.unmodifiable(trades),
      connected: depthConnected,
    );
    await for (final event in service.bookStream(symbol.toLowerCase())) {
      if (event['connected'] == true) {
        if (event['channel'] == 'depth') depthConnected = true;
        continue;
      }
      if (event['disconnected'] == true) {
        if (event['channel'] == 'depth') depthConnected = false;
        yield snapshot();
        continue;
      }
      try {
        if (event['e'] == 'depthUpdate') {
          final nextBids = mapBookLevels(event['b'], descending: true);
          final nextAsks = mapBookLevels(event['a'], descending: false);
          bids = nextBids;
          asks = nextAsks;
        } else if (event['e'] == 'aggTrade') {
          trades.insert(0, mapBookTrade(event));
          if (trades.length > 30) trades.removeLast();
        } else {
          continue;
        }
      } on FormatException {
        throw const MarketFailure('Invalid Aster order book response');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastEmission >= 250) {
        lastEmission = now;
        yield snapshot();
      }
    }
  }
}
