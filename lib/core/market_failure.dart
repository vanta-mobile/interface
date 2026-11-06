import 'errors/api_error_details.dart';

class MarketFailure implements Exception {
  const MarketFailure(this.message, {this.details});
  final ApiErrorDetails? details;
  final String message;
  String get displayMessage => details?.message ?? message;
}
