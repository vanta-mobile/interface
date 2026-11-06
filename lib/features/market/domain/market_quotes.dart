import '../../../core/errors/api_error_details.dart';
import 'market_quote.dart';

enum QuoteConnection { connecting, live, partial, offline }

enum QuoteFailure { snapshot, data }

/// State of the public quote list, independent of chart sessions and orders.
class MarketQuotes {
  MarketQuotes({
    required Iterable<MarketQuote> quotes,
    this.connection = QuoteConnection.connecting,
    this.updatedAt,
    this.failure,
    this.errorDetails,
    this.refreshing = false,
  }) : quotes = List.unmodifiable(quotes);

  final List<MarketQuote> quotes;
  final QuoteConnection connection;
  final DateTime? updatedAt;
  final QuoteFailure? failure;
  final ApiErrorDetails? errorDetails;
  final bool refreshing;
}
