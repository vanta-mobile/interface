import '../../portfolio/domain/account_snapshot.dart';

import 'package:decimal/decimal.dart';

enum MarkPriceConnection { connecting, online, offline }

class MarkPriceQuote {
  const MarkPriceQuote({
    required this.symbol,
    required this.price,
    required this.eventTime,
    required this.receivedAt,
  });
  final String symbol;
  final Decimal price;
  final DateTime eventTime, receivedAt;
}

/// Freshness belongs to each symbol. Activity on another symbol must not
/// make a silent, malformed or disconnected price look current.
class MarkPrices {
  MarkPrices({
    Map<String, MarkPriceQuote> quotes = const {},
    Set<String> fresh = const {},
    Set<String> invalid = const {},
    this.connection = MarkPriceConnection.connecting,
    this.snapshotFailed = false,
    this.failure,
  }) : quotes = Map.unmodifiable(quotes),
       fresh = Set.unmodifiable(fresh),
       invalid = Set.unmodifiable(invalid);
  final Map<String, MarkPriceQuote> quotes;
  final Set<String> fresh, invalid;
  final MarkPriceConnection connection;
  final bool snapshotFailed;
  final AccountReadFailure? failure;
}
