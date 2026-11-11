import '../../portfolio/domain/account_snapshot.dart';

import 'package:decimal/decimal.dart';

enum OrderPriceConnection { connecting, online, offline }

/// Exact public prices for financial input conversion. Chart coordinates and
/// their double-based depth model are deliberately not an input to this model.
class OrderBookQuote {
  const OrderBookQuote({
    required this.symbol,
    required this.bid,
    required this.ask,
    required this.eventTime,
    required this.receivedAt,
    this.updateId,
  });
  final String symbol;
  final Decimal bid, ask;
  final DateTime eventTime, receivedAt;
  final int? updateId;
}

class OrderTradeQuote {
  const OrderTradeQuote({
    required this.symbol,
    required this.price,
    required this.tradeId,
    required this.eventTime,
    required this.receivedAt,
  });
  final String symbol;
  final Decimal price;

  /// Raw trade id for REST, last raw trade id for an aggregate stream event.
  final int tradeId;
  final DateTime eventTime, receivedAt;
}

class OrderReferencePrices {
  const OrderReferencePrices({
    required this.symbol,
    required this.checkedAt,
    this.connection = OrderPriceConnection.connecting,
    this.book,
    this.trade,
    this.bookFresh = false,
    this.tradeFresh = false,
    this.bookFailure,
    this.tradeFailure,
    this.bookFailed = false,
    this.tradeFailed = false,
  });
  final String symbol;
  final DateTime checkedAt;
  final OrderPriceConnection connection;
  final OrderBookQuote? book;
  final OrderTradeQuote? trade;
  final AccountReadFailure? bookFailure, tradeFailure;
  final bool bookFresh, tradeFresh, bookFailed, tradeFailed;
}
